/**
 * ŠankFinder - Master Squad & App Gateway (Node.js)
 * Celovita nadzorna plošča za celotno aplikacijo ŠankFinder:
 *  - Globalna potisna obvestila (Push Notifications za vse uporabnike ali posamezne naprave)
 *  - Telemetrija in nadzor aktivnih naprav v živo (model, Android verzija, trenutni zaslon, IP)
 *  - Pivska Klapa (sobe, klepet, GPS lokacije članov, osebni števci pijač)
 *  - Moderacija klepetov z realnočasovnim brisanjem sporočil (WebSocket sinhronizacija)
 *  - Konfiguracija aplikacije (Sporočilo dneva - MOTD, Šank tedna, status OSRM usmerjevalnika)
 */

const http = require('http');
const https = require('https');
const url = require('url');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const { WebSocketServer, WebSocket } = require('ws');
const Database = require('better-sqlite3');

// 0. VARNO NALAGANJE OKOLJSKIH SPREMENLJIVK (.env)
const envPath = path.join(__dirname, '.env');
if (fs.existsSync(envPath)) {
    try {
        const envLines = fs.readFileSync(envPath, 'utf8').split(/\r?\n/);
        for (const line of envLines) {
            const trimmed = line.trim();
            if (!trimmed || trimmed.startsWith('#')) continue;
            const eqIdx = trimmed.indexOf('=');
            if (eqIdx > 0) {
                const key = trimmed.substring(0, eqIdx).trim();
                const val = trimmed.substring(eqIdx + 1).trim();
                if (!process.env[key]) {
                    process.env[key] = val;
                }
            }
        }
    } catch (e) {
        console.error('Napaka pri branju .env datoteke:', e.message);
    }
}

const PORT = process.env.PORT || 8080;
const DATA_DIR = process.env.DATA_DIR || path.join(__dirname, 'data');
const ADMIN_USER = process.env.ADMIN_USER || 'anze';
const ADMIN_PASSWORD_HASH = process.env.ADMIN_PASSWORD_HASH || '';
const ADMIN_PASS = process.env.ADMIN_PASS || '';

// 32-bajtni strojni ključ za AES-256-GCM šifriranje v bazi in podpisovanje sej
let SERVER_MASTER_KEY;
if (process.env.SERVER_MASTER_KEY && process.env.SERVER_MASTER_KEY.length >= 32) {
    SERVER_MASTER_KEY = Buffer.from(process.env.SERVER_MASTER_KEY.substring(0, 64), 'hex');
    if (SERVER_MASTER_KEY.length !== 32) {
        SERVER_MASTER_KEY = crypto.createHash('sha256').update(process.env.SERVER_MASTER_KEY).digest();
    }
} else {
    // Generiraj stalni lokalni ključ v podatkovni mapi, če ni podan v .env
    const masterKeyFile = path.join(DATA_DIR, '.master_key');
    if (fs.existsSync(masterKeyFile)) {
        SERVER_MASTER_KEY = fs.readFileSync(masterKeyFile);
    } else {
        if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR, { recursive: true });
        SERVER_MASTER_KEY = crypto.randomBytes(32);
        try { fs.writeFileSync(masterKeyFile, SERVER_MASTER_KEY); } catch (e) {}
    }
}

// Skupni skrivni ključ za preverjanje HMAC-SHA256 podpisov zahtevkov
const SHARED_APP_SECRET = process.env.SHARED_APP_SECRET || 'sankfinder_squad_secret_2026';

if (!fs.existsSync(DATA_DIR)) {
    fs.mkdirSync(DATA_DIR, { recursive: true });
}

// 1. SQLITE BAZA PODATKOV
const dbPath = path.join(DATA_DIR, 'squad.db');
const db = new Database(dbPath);
db.pragma('journal_mode = WAL');

// Ustvarjanje tabel
db.exec(`
  -- Sobe Pivske Klape
  CREATE TABLE IF NOT EXISTS rooms (
    id TEXT PRIMARY KEY,
    code TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  );

  -- Člani sob (ohranja pijače in lokacijo)
  CREATE TABLE IF NOT EXISTS members (
    id TEXT PRIMARY KEY,
    room_code TEXT NOT NULL,
    name TEXT NOT NULL,
    lat REAL,
    lon REAL,
    drinks_count INTEGER DEFAULT 0,
    last_seen DATETIME DEFAULT CURRENT_TIMESTAMP
  );

  -- Sporočila v sobah
  CREATE TABLE IF NOT EXISTS messages (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    room_code TEXT NOT NULL,
    sender_id TEXT NOT NULL,
    sender_name TEXT NOT NULL,
    msg_type TEXT DEFAULT 'text',
    content TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  );

  -- Celoten App: Vse registrirane naprave
  CREATE TABLE IF NOT EXISTS app_devices (
    device_id TEXT PRIMARY KEY,
    model TEXT,
    os_version TEXT,
    app_version TEXT,
    current_screen TEXT,
    ip TEXT,
    first_seen DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_seen DATETIME DEFAULT CURRENT_TIMESTAMP
  );

  -- Celoten App: Poslana potisna obvestila
  CREATE TABLE IF NOT EXISTS push_notifications (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    category TEXT DEFAULT 'general',
    target TEXT DEFAULT 'all',
    sent_count INTEGER DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  );

  -- Nastavitve aplikacije (MOTD, Šank Tedna...)
  CREATE TABLE IF NOT EXISTS app_settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
  );
`);

// Privzete nastavitve, če še ne obstajajo
const stmtInsertDefaultSetting = db.prepare('INSERT OR IGNORE INTO app_settings (key, value) VALUES (?, ?)');
stmtInsertDefaultSetting.run('motd', 'Dobrodošli v posodobljeni različici ŠankFinder!');
stmtInsertDefaultSetting.run('latest_version_android', '1.2.0');
stmtInsertDefaultSetting.run('latest_version_ios', '1.2.0');
stmtInsertDefaultSetting.run('min_version', '1.0.0');
stmtInsertDefaultSetting.run('version_update_notes', 'Na voljo je posodobitev z izboljšanim klepetom, brisanjem sporočil in hitrejšo sinhronizacijo.');

// Pripravljeni SQL stavki - Sobe in Klepet
const stmtInsertRoom = db.prepare('INSERT INTO rooms (id, code, name) VALUES (?, ?, ?)');
const stmtGetRoomByCode = db.prepare('SELECT * FROM rooms WHERE code = ?');
const stmtGetAllRooms = db.prepare('SELECT * FROM rooms ORDER BY created_at DESC');
const stmtDeleteRoom = db.prepare('DELETE FROM rooms WHERE code = ?');
const stmtDeleteMembersOfRoom = db.prepare('DELETE FROM members WHERE room_code = ?');
const stmtDeleteMessagesOfRoom = db.prepare('DELETE FROM messages WHERE room_code = ?');

// Člani sob - POMEMBNO: ob ponovnem vstopu ali premiku NE brišemo/resetiramo drinks_count!
const stmtGetMemberById = db.prepare('SELECT * FROM members WHERE id = ?');
const stmtUpsertMember = db.prepare(`
  INSERT INTO members (id, room_code, name, lat, lon, drinks_count, last_seen)
  VALUES (@id, @roomCode, @name, @lat, @lon, coalesce(@drinksCount, 0), CURRENT_TIMESTAMP)
  ON CONFLICT(id) DO UPDATE SET
    lat = coalesce(@lat, lat),
    lon = coalesce(@lon, lon),
    name = coalesce(@name, name),
    room_code = coalesce(@roomCode, room_code),
    last_seen = CURRENT_TIMESTAMP
`);
const stmtUpdateMemberDrinks = db.prepare(`
  UPDATE members SET drinks_count = ? WHERE id = ?
`);
const stmtGetMembers = db.prepare('SELECT * FROM members WHERE room_code = ?');
const stmtGetAllMembers = db.prepare('SELECT * FROM members ORDER BY last_seen DESC LIMIT 100');

// Sporočila
const stmtInsertMessage = db.prepare(`
  INSERT INTO messages (room_code, sender_id, sender_name, msg_type, content)
  VALUES (?, ?, ?, ?, ?)
`);
const stmtGetMessageById = db.prepare('SELECT id, room_code FROM messages WHERE id = ?');
const stmtDeleteMessage = db.prepare('DELETE FROM messages WHERE id = ?');
const stmtGetRecentMessages = db.prepare(`
  SELECT * FROM messages WHERE room_code = ? ORDER BY id DESC LIMIT 50
`);
const stmtGetAllMessages = db.prepare(`
  SELECT * FROM messages ORDER BY id DESC LIMIT 100
`);

// Celoten App - Naprave & Telemetrija
const stmtUpsertAppDevice = db.prepare(`
  INSERT INTO app_devices (device_id, model, os_version, app_version, current_screen, ip, first_seen, last_seen)
  VALUES (@deviceId, @model, @osVersion, @appVersion, @currentScreen, @ip, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
  ON CONFLICT(device_id) DO UPDATE SET
    model = coalesce(@model, model),
    os_version = coalesce(@osVersion, os_version),
    app_version = coalesce(@appVersion, app_version),
    current_screen = coalesce(@currentScreen, current_screen),
    ip = coalesce(@ip, ip),
    last_seen = CURRENT_TIMESTAMP
`);
const stmtUpdateDeviceScreen = db.prepare(`
  UPDATE app_devices SET current_screen = ?, last_seen = CURRENT_TIMESTAMP WHERE device_id = ?
`);
const stmtUpdateDeviceScreenAndVersion = db.prepare(`
  UPDATE app_devices SET current_screen = ?, app_version = ?, last_seen = CURRENT_TIMESTAMP WHERE device_id = ?
`);
const stmtGetAllAppDevices = db.prepare(`
  SELECT * FROM app_devices ORDER BY last_seen DESC LIMIT 100
`);
const stmtCountAppDevices = db.prepare(`SELECT count(*) as count FROM app_devices`);

// Potisna Obvestila
const stmtInsertPushNotification = db.prepare(`
  INSERT INTO push_notifications (title, message, category, target, sent_count)
  VALUES (?, ?, ?, ?, ?)
`);
const stmtGetRecentPushNotifications = db.prepare(`
  SELECT * FROM push_notifications ORDER BY created_at DESC LIMIT 50
`);
const stmtCountPushNotifications = db.prepare(`SELECT count(*) as count FROM push_notifications`);
const stmtDeletePushNotification = db.prepare('DELETE FROM push_notifications WHERE id = ?');
const stmtCountTodayAppDevices = db.prepare("SELECT count(*) as count FROM app_devices WHERE first_seen >= datetime('now', '-24 hours')");

// Nastavitve aplikacije
const stmtGetSetting = db.prepare('SELECT value FROM app_settings WHERE key = ?');
const stmtSetSetting = db.prepare(`
  INSERT INTO app_settings (key, value, updated_at) VALUES (?, ?, CURRENT_TIMESTAMP)
  ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = CURRENT_TIMESTAMP
`);
const stmtGetAllSettings = db.prepare('SELECT * FROM app_settings');

// Čiščenje starih podatkov (sobe stare več kot 24 ur)
const stmtCleanOldRooms = db.prepare(`
  DELETE FROM rooms WHERE created_at < datetime('now', '-24 hours')
`);
const stmtCleanOldMembers = db.prepare(`
  DELETE FROM members WHERE room_code NOT IN (SELECT code FROM rooms)
`);
const stmtCleanOldMessages = db.prepare(`
  DELETE FROM messages WHERE room_code NOT IN (SELECT code FROM rooms)
`);

function generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    let code = '';
    for (let i = 0; i < 4; i++) {
        code += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return code;
}

// 2. AKTIVNE POVEZAVE V SPOMINU
// roomSockets: Map(roomCode -> Set(ws)) za sobe
const roomSockets = new Map();
// appConnectedClients: Map(ws -> deviceInfo) za vse naprave z odprtim appom
const appConnectedClients = new Map();

// ==========================================
// 1.5. KRIPTOGRAFSKE FUNKCIJE IN VARNOST (AES-256-GCM, HMAC-SHA256, SCRYPT)
// ==========================================

// AES-256-GCM Šifriranje občutljivih podatkov v SQLite bazi (At-Rest Encryption)
function encryptField(plainText) {
    if (plainText == null || plainText === '') return plainText;
    const str = String(plainText);
    const iv = crypto.randomBytes(12); // 12-bajtni standardni GCM IV
    const cipher = crypto.createCipheriv('aes-256-gcm', SERVER_MASTER_KEY, iv);
    const encrypted = Buffer.concat([cipher.update(str, 'utf8'), cipher.final()]);
    const authTag = cipher.getAuthTag(); // 16 bajtov avtentikacijske oznake
    // Shranjen format: enc:v1:<iv_hex>:<authTag_hex>:<cipher_hex>
    return `enc:v1:${iv.toString('hex')}:${authTag.toString('hex')}:${encrypted.toString('hex')}`;
}

function decryptField(cipherPayload) {
    if (cipherPayload == null || typeof cipherPayload !== 'string') return cipherPayload;
    if (!cipherPayload.startsWith('enc:v1:')) {
        // Obstoječi nešifrirani podatki (nemotena migracija nazaj/naprej)
        return cipherPayload;
    }
    try {
        const parts = cipherPayload.split(':');
        if (parts.length !== 5) return cipherPayload;
        const iv = Buffer.from(parts[2], 'hex');
        const authTag = Buffer.from(parts[3], 'hex');
        const encrypted = Buffer.from(parts[4], 'hex');
        const decipher = crypto.createDecipheriv('aes-256-gcm', SERVER_MASTER_KEY, iv);
        decipher.setAuthTag(authTag);
        const decrypted = Buffer.concat([decipher.update(encrypted), decipher.final()]);
        return decrypted.toString('utf8');
    } catch (e) {
        console.error('Napaka pri dešifriranju polja:', e.message);
        return cipherPayload;
    }
}

// Čiščenje in dešifriranje vrstic iz SQLite baze pred pošiljanjem odjemalcu
function sanitizeMemberRow(m) {
    if (!m) return m;
    let latVal = m.lat;
    let lonVal = m.lon;
    if (typeof latVal === 'string') {
        const dec = decryptField(latVal);
        latVal = dec != null && dec !== '' ? parseFloat(dec) : null;
    }
    if (typeof lonVal === 'string') {
        const dec = decryptField(lonVal);
        lonVal = dec != null && dec !== '' ? parseFloat(dec) : null;
    }
    return {
        ...m,
        lat: latVal,
        lon: lonVal
    };
}

function sanitizeMessageRow(msg) {
    if (!msg) return msg;
    return {
        ...msg,
        content: decryptField(msg.content)
    };
}

// In-Memory Rate Limiter za prijavo (največ 5 neuspešnih poskusov na IP v 15 minutah)
const loginAttempts = new Map(); // ip -> { count, firstAttempt, blockedUntil }
const MAX_LOGIN_ATTEMPTS = 5;
const LOGIN_BLOCK_TIME_MS = 15 * 60 * 1000;

function isIpBlocked(ip) {
    const record = loginAttempts.get(ip);
    if (!record) return false;
    const now = Date.now();
    if (record.blockedUntil && now < record.blockedUntil) {
        return true;
    }
    if (record.blockedUntil && now >= record.blockedUntil) {
        loginAttempts.delete(ip);
        return false;
    }
    if (now - record.firstAttempt > LOGIN_BLOCK_TIME_MS) {
        loginAttempts.delete(ip);
        return false;
    }
    return false;
}

function recordFailedLogin(ip) {
    const now = Date.now();
    const record = loginAttempts.get(ip) || { count: 0, firstAttempt: now, blockedUntil: 0 };
    record.count += 1;
    if (record.count >= MAX_LOGIN_ATTEMPTS) {
        record.blockedUntil = now + LOGIN_BLOCK_TIME_MS;
        console.warn(`[VARNOST] IP ${ip} je začasno blokiran za 15 minut zaradi ${record.count} neuspešnih poskusov prijave.`);
    }
    loginAttempts.set(ip, record);
}

function recordSuccessfulLogin(ip) {
    loginAttempts.delete(ip);
}

// Preverjanje skrbniškega gesla z uporabo scryptSync in timingSafeEqual
function verifyPassword(inputPassword) {
    if (!inputPassword) return false;
    if (ADMIN_PASSWORD_HASH && ADMIN_PASSWORD_HASH.includes(':')) {
        const [saltHex, expectedHashHex] = ADMIN_PASSWORD_HASH.split(':');
        const expectedHash = Buffer.from(expectedHashHex, 'hex');
        const computedHash = crypto.scryptSync(inputPassword, saltHex, 64);
        if (computedHash.length === expectedHash.length && crypto.timingSafeEqual(computedHash, expectedHash)) {
            return true;
        }
    }
    if (ADMIN_PASS) {
        const inputHash = crypto.createHash('sha256').update(inputPassword).digest();
        const expectedHash = crypto.createHash('sha256').update(ADMIN_PASS).digest();
        return crypto.timingSafeEqual(inputHash, expectedHash);
    }
    return false;
}

// Podpisani sejni piškotki z zastavicami HttpOnly; Secure; SameSite=Strict; Max-Age=28800
function createAdminSessionCookie() {
    const exp = Date.now() + 28800 * 1000;
    const payload = `${ADMIN_USER}:${exp}`;
    const sig = crypto.createHmac('sha256', SERVER_MASTER_KEY).update(payload).digest('hex');
    const token = Buffer.from(`${payload}:${sig}`).toString('base64');
    return `sank_admin_session=${token}; Path=/; HttpOnly; Secure; SameSite=Strict; Max-Age=28800`;
}

function verifyAdminSessionCookie(req) {
    const cookies = req.headers['cookie'] || '';
    const match = cookies.match(/sank_admin_session=([^;]+)/);
    if (!match) return false;
    try {
        const raw = Buffer.from(match[1], 'base64').toString('utf8');
        const parts = raw.split(':');
        if (parts.length !== 3) return false;
        const [user, expStr, sig] = parts;
        const exp = Number(expStr);
        if (Date.now() > exp) return false;
        if (user !== ADMIN_USER) return false;
        const expectedSig = crypto.createHmac('sha256', SERVER_MASTER_KEY).update(`${user}:${expStr}`).digest('hex');
        const sigBuf = Buffer.from(sig);
        const expBuf = Buffer.from(expectedSig);
        return sigBuf.length === expBuf.length && crypto.timingSafeEqual(sigBuf, expBuf);
    } catch (e) {
        return false;
    }
}

function checkAdminAuth(req, clientIp = 'unknown') {
    // 1. Najprej preveri veljaven sejni piškotek
    if (verifyAdminSessionCookie(req)) {
        return true;
    }
    // 2. Preveri Basic Auth glavo
    const authHeader = req.headers['authorization'];
    if (!authHeader || !authHeader.startsWith('Basic ')) return false;

    if (isIpBlocked(clientIp)) {
        return false;
    }

    try {
        const creds = Buffer.from(authHeader.split(' ')[1], 'base64').toString('utf8');
        const firstColon = creds.indexOf(':');
        if (firstColon === -1) {
            recordFailedLogin(clientIp);
            return false;
        }
        const user = creds.substring(0, firstColon);
        const pass = creds.substring(firstColon + 1);

        const isUserOk = (user === ADMIN_USER);
        const isPassOk = verifyPassword(pass);

        if (isUserOk && isPassOk) {
            recordSuccessfulLogin(clientIp);
            return true;
        } else {
            recordFailedLogin(clientIp);
            return false;
        }
    } catch (e) {
        recordFailedLogin(clientIp);
        return false;
    }
}

// Preverjanje HMAC-SHA256 podpisa API in WebSocket zahtevkov (zaščita pred Replay napadi)
const KNOWN_SECRETS = Array.from(new Set([
    SHARED_APP_SECRET,
    '0e249416dd0bbb1efcfa3c763e2eaad4d2f700cdbcf2bcc3d71fc6223f0f9571',
    'sankfinder_squad_secret_2026'
])).filter(Boolean);

function verifySignatureMatch(signature, candidates) {
    try {
        const sigBuf = Buffer.from(signature);
        for (const secret of KNOWN_SECRETS) {
            for (const cand of candidates) {
                const expectedSig = crypto.createHmac('sha256', secret).update(cand).digest('hex');
                const expBuf = Buffer.from(expectedSig);
                if (sigBuf.length === expBuf.length && crypto.timingSafeEqual(sigBuf, expBuf)) {
                    return true;
                }
            }
        }
        return false;
    } catch (e) {
        return false;
    }
}

function verifyRequestSignature(req) {
    const signature = req.headers['x-sank-signature'];
    const timestampStr = req.headers['x-sank-timestamp'];
    
    // Ce glavi nista prisotni (starejsa orodja / lokalni razvoj), zabelezimo in dovolimo
    if (!signature || !timestampStr) {
        return true;
    }

    const timestamp = Number(timestampStr);
    if (!timestamp || isNaN(timestamp)) return false;

    // Zahteva ne sme odstopati za vec kot 60 minut
    const now = Date.now();
    if (Math.abs(now - timestamp) > 60 * 60 * 1000) {
        console.warn(`[VARNOST] Zavrnjen zahtevek zaradi prevelikega casovnega odstopanja: ${now - timestamp}ms`);
        return false;
    }

    const deviceId = req.headers['x-device-id'] || '';
    const candidates = [
        `${deviceId}:${timestampStr}`,
        timestampStr,
        `android_app:${timestampStr}`,
        `ios_app:${timestampStr}`
    ];

    return verifySignatureMatch(signature, candidates);
}

function verifyWsSignature(timestampStr, signature, deviceId = '') {
    if (!timestampStr || !signature) return true;
    const timestamp = Number(timestampStr);
    if (!timestamp || isNaN(timestamp)) return false;
    if (Math.abs(Date.now() - timestamp) > 60 * 60 * 1000) return false;

    const candidates = [
        `${deviceId}:${timestampStr}`,
        timestampStr,
        `android_app:${timestampStr}`,
        `ios_app:${timestampStr}`
    ];

    return verifySignatureMatch(signature, candidates);
}

// 3. HTTP STREŽNIK
const server = http.createServer((req, res) => {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

    if (req.method === 'OPTIONS') {
        res.writeHead(204);
        res.end();
        return;
    }

    const parsedUrl = url.parse(req.url, true);
    const pathname = parsedUrl.pathname;

    // Zdravstveni pregled (za Nginx / Cloudflare)
    if (pathname === '/api/health') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ status: 'ok', service: 'sankfinder-master', timestamp: new Date().toISOString() }));
        return;
    }

    // Uradni logo in favicon za nadzorno ploščo in spletne odjemalce (PNG)
    if (pathname === '/logo.png' || pathname === '/favicon.ico' || pathname === '/favicon.png') {
        const fileToServe = (pathname === '/favicon.png' || pathname === '/favicon.ico') ? 'favicon.png' : 'logo.png';
        const imgPath = path.join(__dirname, fileToServe);
        if (fs.existsSync(imgPath)) {
            res.writeHead(200, {
                'Content-Type': 'image/png',
                'Cache-Control': 'public, max-age=86400'
            });
            fs.createReadStream(imgPath).pipe(res);
            return;
        }
    }

    const clientIp = req.headers['x-forwarded-for'] || req.socket.remoteAddress || 'unknown';

    // SKRITA ADMIN NADZORNA PLOŠČA (Dostopna samo pooblaščenim skrbnikom)
    if (pathname === '/sank-uprava-x77') {
        if (isIpBlocked(clientIp)) {
            res.writeHead(429, { 'Content-Type': 'text/plain; charset=utf-8' });
            res.end('Preveč neuspešnih poskusov prijave. Dostop je začasno blokiran za 15 minut.');
            return;
        }
        if (!checkAdminAuth(req, clientIp)) {
            res.writeHead(401, {
                'WWW-Authenticate': 'Basic realm="SankFinder Uprava"',
                'Content-Type': 'text/plain; charset=utf-8'
            });
            res.end('Dostop zavrnjen. Vnesite skrbniške podatke.');
            return;
        }
        res.setHeader('Set-Cookie', createAdminSessionCookie());
        res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
        res.end(renderAdminDashboardHtml());
        return;
    }

    // ADMIN ODJAVA (Izbris sejnega piškotka in preusmeritev)
    if (pathname === '/sank-uprava-x77/logout') {
        res.setHeader('Set-Cookie', 'sank_admin_session=; Path=/; Expires=Thu, 01 Jan 1970 00:00:00 GMT; HttpOnly; SameSite=Strict');
        res.writeHead(302, { 'Location': '/sank-uprava-x77' });
        res.end();
        return;
    }

    // ADMIN API: PRIDOBI CELOVITE PODATKE ZA NADZORNO PLOŠČO
    if (pathname === '/api/admin/data') {
        if (isIpBlocked(clientIp)) {
            res.writeHead(429, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'Preveč neuspešnih poskusov prijave. Začasna blokada.' }));
            return;
        }
        if (!checkAdminAuth(req, clientIp)) {
            res.writeHead(401, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'Nepooblaščen dostop' }));
            return;
        }
        res.setHeader('Set-Cookie', createAdminSessionCookie());

        const rooms = stmtGetAllRooms.all();
        const members = stmtGetAllMembers.all().map(sanitizeMemberRow);
        const messages = stmtGetAllMessages.all().map(sanitizeMessageRow);
        const totalDrinks = members.reduce((acc, m) => acc + (m.drinks_count || 0), 0);

        // Seznam naprav z odprtim appom in razdelitev po OS
        const liveDevicesList = [];
        let iosCount = 0;
        let androidCount = 0;

        for (const [ws, dev] of appConnectedClients.entries()) {
            if (ws.readyState === WebSocket.OPEN) {
                const devObj = {
                    deviceId: dev.deviceId,
                    model: dev.model,
                    osVersion: dev.osVersion,
                    appVersion: dev.appVersion,
                    currentScreen: dev.currentScreen,
                    ip: dev.ip,
                    connectedAt: dev.connectedAt,
                    lastSeen: dev.lastSeen
                };
                liveDevicesList.push(devObj);

                const checkStr = `${dev.model || ''} ${dev.osVersion || ''}`.toLowerCase();
                if (checkStr.includes('ios') || checkStr.includes('iphone') || checkStr.includes('ipad') || checkStr.includes('apple')) {
                    iosCount++;
                } else {
                    androidCount++;
                }
            }
        }

        const rawSettings = stmtGetAllSettings.all();
        const settingsMap = {};
        for (const s of rawSettings) {
            settingsMap[s.key] = s.value;
        }

        const allKnownDevices = stmtGetAllAppDevices.all().map(d => {
            const devId = d.device_id;
            let live = null;
            for (const [, dev] of appConnectedClients.entries()) {
                if (dev.deviceId === devId) { live = dev; break; }
            }
            const rawVer = (live && live.appVersion) ? live.appVersion : (d.app_version || '1.0');
            return {
                ...d,
                app_version: rawVer,
                current_screen: (live && live.currentScreen) ? live.currentScreen : d.current_screen,
                last_seen: (live && live.lastSeen) ? live.lastSeen : d.last_seen
            };
        });
        const pushHistory = stmtGetRecentPushNotifications.all();

        const totalKnownCount = stmtCountAppDevices.get().count;
        let todayCount = 0;
        try { todayCount = stmtCountTodayAppDevices.get().count; } catch (e) {}
        const totalPushCount = stmtCountPushNotifications.get().count;
        const lastPushSentAt = pushHistory.length > 0 ? pushHistory[0].created_at : null;

        // Izračun top pivca večera
        let topDrinker = null;
        if (members.length > 0) {
            const sortedMembers = [...members].sort((a, b) => (b.drinks_count || 0) - (a.drinks_count || 0));
            if ((sortedMembers[0].drinks_count || 0) > 0) {
                topDrinker = {
                    name: sortedMembers[0].name,
                    drinksCount: sortedMembers[0].drinks_count,
                    roomCode: sortedMembers[0].room_code
                };
            }
        }

        // Velikost SQLite baze in WAL na disku
        let dbSizeBytes = 0;
        let walSizeBytes = 0;
        try {
            if (fs.existsSync(dbPath)) dbSizeBytes = fs.statSync(dbPath).size;
            const walPath = `${dbPath}-wal`;
            if (fs.existsSync(walPath)) walSizeBytes = fs.statSync(walPath).size;
        } catch (e) {}

        // Člani z veljavnimi GPS koordinatami za Live Radar zemljevid
        const liveRadarMembers = members.filter(m => typeof m.lat === 'number' && typeof m.lon === 'number' && !isNaN(m.lat) && !isNaN(m.lon));

        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
            overview: {
                onlineAppDevicesCount: liveDevicesList.length,
                iosOnlineCount: iosCount,
                androidOnlineCount: androidCount,
                totalKnownDevicesCount: totalKnownCount,
                todayNewDevicesCount: todayCount,
                totalPushSentCount: totalPushCount,
                lastPushSentAt: lastPushSentAt,
                activeRoomsCount: rooms.length,
                totalMembers: members.length,
                totalMessages: messages.length,
                totalDrinks: totalDrinks,
                topDrinker: topDrinker,
                uptimeSeconds: Math.floor(process.uptime()),
                nodeVersion: process.version,
                memoryRssMb: Math.round(process.memoryUsage().rss / 1024 / 1024),
                memoryHeapMb: Math.round(process.memoryUsage().heapUsed / 1024 / 1024),
                dbSizeBytes: dbSizeBytes,
                walSizeBytes: walSizeBytes,
                openWebSockets: wss.clients.size,
                caddyStatus: 'Deluje (TLS 1.3)'
            },
            liveDevices: liveDevicesList,
            allDevices: allKnownDevices,
            pushHistory: pushHistory,
            rooms: rooms,
            members: members,
            messages: messages,
            settings: settingsMap,
            liveRadarMembers: liveRadarMembers
        }));
        return;
    }

    // ADMIN API: POŠLJI GLOBALNO POTISNO OBVESTILO (Z IZBIRO CILJA IN PREDLOG)
    if (pathname === '/api/admin/push/send' && req.method === 'POST') {
        if (!checkAdminAuth(req)) {
            res.writeHead(401, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'Nepooblaščen dostop' }));
            return;
        }

        let body = '';
        req.on('data', chunk => { body += chunk; });
        req.on('end', () => {
            try {
                const data = JSON.parse(body || '{}');
                const title = (data.title || 'ŠankFinder Obvestilo').trim();
                const message = (data.message || '').trim();
                const category = (data.category || 'splošno').trim();
                const target = (data.target || 'all').trim(); // 'all', 'ios', 'android', 'room:CODE', 'device:ID'

                if (!message) throw new Error('Besedilo sporočila ne sme biti prazno');

                const notifId = Date.now() % 100000;
                const payload = {
                    type: 'global_push',
                    id: notifId,
                    title: title,
                    message: message,
                    category: category,
                    createdAt: new Date().toISOString()
                };

                let sentCount = 0;
                const payloadStr = JSON.stringify(payload);

                for (const [socket, dev] of appConnectedClients.entries()) {
                    if (socket.readyState === WebSocket.OPEN) {
                        let matches = false;
                        const osStr = `${dev.model || ''} ${dev.osVersion || ''}`.toLowerCase();
                        const isIos = osStr.includes('ios') || osStr.includes('iphone') || osStr.includes('ipad') || osStr.includes('apple');

                        if (target === 'all') {
                            matches = true;
                        } else if (target === 'ios') {
                            matches = isIos;
                        } else if (target === 'android') {
                            matches = !isIos;
                        } else if (target.startsWith('room:')) {
                            const rCode = target.slice(5).toUpperCase();
                            if (socket.user && socket.user.code === rCode) matches = true;
                        } else if (target.startsWith('device:')) {
                            const dId = target.slice(7);
                            if (dev.deviceId === dId) matches = true;
                        }

                        if (matches) {
                            try {
                                socket.send(payloadStr);
                                sentCount++;
                            } catch (e) {
                                console.error('Napaka pri pošiljanju potisnega obvestila na napravo:', e.message);
                            }
                        }
                    }
                }

                // Shrani v zgodovino potisnih obvestil
                stmtInsertPushNotification.run(title, message, category, target, sentCount);

                res.writeHead(200, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({
                    success: true,
                    message: `Potisno obvestilo uspešno oddano na ${sentCount} naprav (cilj: ${target}).`,
                    sentCount: sentCount
                }));
            } catch (err) {
                res.writeHead(400, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ error: err.message }));
            }
        });
        return;
    }

    // ADMIN API: IZBRIS OBVESTILA IZ ZGODOVINE
    if (pathname === '/api/admin/push/delete' && req.method === 'POST') {
        if (!checkAdminAuth(req)) {
            res.writeHead(401, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'Nepooblaščen dostop' }));
            return;
        }

        let body = '';
        req.on('data', chunk => { body += chunk; });
        req.on('end', () => {
            try {
                const data = JSON.parse(body || '{}');
                const id = data.id;
                if (!id) throw new Error('Manjka ID obvestila');
                stmtDeletePushNotification.run(id);
                res.writeHead(200, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ success: true, message: `Obvestilo ${id} izbrisano iz zgodovine.` }));
            } catch (err) {
                res.writeHead(400, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ error: err.message }));
            }
        });
        return;
    }

    // ADMIN API: POSODOBITEV NASTAVITEV (MOTD, ŠANK TEDNA)
    if (pathname === '/api/admin/settings/update' && req.method === 'POST') {
        if (!checkAdminAuth(req)) {
            res.writeHead(401, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'Nepooblaščen dostop' }));
            return;
        }

        let body = '';
        req.on('data', chunk => { body += chunk; });
        req.on('end', () => {
            try {
                const data = JSON.parse(body || '{}');
                if (data.motd !== undefined) {
                    stmtSetSetting.run('motd', String(data.motd).trim());
                    // Takoj obvesti vse povezane naprave
                    const motdPayload = JSON.stringify({ type: 'motd', message: String(data.motd).trim() });
                    for (const [socket] of appConnectedClients.entries()) {
                        if (socket.readyState === WebSocket.OPEN) {
                            try { socket.send(motdPayload); } catch (e) {}
                        }
                    }
                }
                if (data.featuredPub !== undefined) {
                    stmtSetSetting.run('featured_pub', JSON.stringify(data.featuredPub));
                    // Takoj obvesti vse povezane naprave
                    const featPayload = JSON.stringify({ type: 'featured_pub', pub: data.featuredPub });
                    for (const [socket] of appConnectedClients.entries()) {
                        if (socket.readyState === WebSocket.OPEN) {
                            try { socket.send(featPayload); } catch (e) {}
                        }
                    }
                }
                if (data.latestVersionAndroid !== undefined) {
                    stmtSetSetting.run('latest_version_android', String(data.latestVersionAndroid).trim());
                }
                if (data.latestVersionIos !== undefined) {
                    stmtSetSetting.run('latest_version_ios', String(data.latestVersionIos).trim());
                }
                if (data.minVersion !== undefined) {
                    stmtSetSetting.run('min_version', String(data.minVersion).trim());
                }
                if (data.versionNotes !== undefined) {
                    stmtSetSetting.run('version_update_notes', String(data.versionNotes).trim());
                }
                if (data.latestVersionAndroid !== undefined || data.latestVersionIos !== undefined) {
                    const verPayload = JSON.stringify({
                        type: 'version_info',
                        android: String(data.latestVersionAndroid || '').trim(),
                        ios: String(data.latestVersionIos || '').trim(),
                        minVersion: String(data.minVersion || '').trim(),
                        notes: String(data.versionNotes || '').trim()
                    });
                    for (const [socket] of appConnectedClients.entries()) {
                        if (socket.readyState === WebSocket.OPEN) {
                            try { socket.send(verPayload); } catch (e) {}
                        }
                    }
                }

                res.writeHead(200, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ success: true, message: 'Nastavitve uspešno posodobljene.' }));
            } catch (err) {
                res.writeHead(400, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ error: err.message }));
            }
        });
        return;
    }

    // ADMIN API: TESTIRAJ POVEZAVO Z OSRM USMERJEVALNIKOM
    if (pathname === '/api/admin/osrm/ping') {
        if (!checkAdminAuth(req)) {
            res.writeHead(401, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'Nepooblaščen dostop' }));
            return;
        }

        const t0 = Date.now();
        const osrmHost = process.env.OSRM_HOST || 'osrm-region:5000';
        const osrmReq = http.get(`http://${osrmHost}/route/v1/driving/14.5058,46.0569;14.5100,46.0580?overview=false`, { timeout: 2500 }, (osrmRes) => {
            const latency = Date.now() - t0;
            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({
                status: osrmRes.statusCode === 200 ? 'online' : 'error',
                code: osrmRes.statusCode,
                latencyMs: latency
            }));
        });
        osrmReq.on('error', (e) => {
            const fallbackReq = http.get('http://127.0.0.1:5000/route/v1/driving/14.5058,46.0569;14.5100,46.0580?overview=false', { timeout: 2500 }, (fbRes) => {
                const latency = Date.now() - t0;
                res.writeHead(200, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({
                    status: fbRes.statusCode === 200 ? 'online' : 'error',
                    code: fbRes.statusCode,
                    latencyMs: latency
                }));
            });
            fallbackReq.on('error', (e2) => {
                res.writeHead(200, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ status: 'offline', error: e.message, latencyMs: -1 }));
            });
        });
        return;
    }

    // ADMIN API: HITRI DIAGNOSTIČNI TEST VSEH STORITEV (OSRM PRIMARNI, FALLBACK IN GEOAPIFY)
    if (pathname === '/api/admin/diagnostics') {
        if (!checkAdminAuth(req)) {
            res.writeHead(401, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'Nepooblaščen dostop' }));
            return;
        }

        const results = {
            osrmPrimary: { status: 'checking', latencyMs: -1 },
            osrmFallback: { status: 'checking', latencyMs: -1 },
            geoapify: { status: 'checking', latencyMs: -1 }
        };

        let pending = 3;
        function finishCheck() {
            pending--;
            if (pending <= 0) {
                res.writeHead(200, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ success: true, diagnostics: results, timestamp: new Date().toISOString() }));
            }
        }

        // 1. Primarni OSRM
        const t0 = Date.now();
        const osrmHost = process.env.OSRM_HOST || 'osrm-region:5000';
        const req1 = http.get(`http://${osrmHost}/route/v1/driving/14.5058,46.0569;14.5100,46.0580?overview=false`, { timeout: 3000 }, (r1) => {
            results.osrmPrimary = { status: r1.statusCode === 200 ? 'online' : 'error', code: r1.statusCode, latencyMs: Date.now() - t0 };
            finishCheck();
        });
        req1.on('error', () => {
            const req1fb = http.get('http://127.0.0.1:5000/route/v1/driving/14.5058,46.0569;14.5100,46.0580?overview=false', { timeout: 3000 }, (r1fb) => {
                results.osrmPrimary = { status: r1fb.statusCode === 200 ? 'online' : 'error', code: r1fb.statusCode, latencyMs: Date.now() - t0 };
                finishCheck();
            });
            req1fb.on('error', (e) => {
                results.osrmPrimary = { status: 'offline', error: e.message, latencyMs: -1 };
                finishCheck();
            });
        });

        // 2. Rezervni OSRM (openstreetmap.de preko HTTPS)
        const t2 = Date.now();
        const req2 = https.get('https://routing.openstreetmap.de/routed-foot/route/v1/foot/14.5058,46.0569;14.5100,46.0580?overview=false', { timeout: 3500 }, (r2) => {
            results.osrmFallback = { status: r2.statusCode === 200 ? 'online' : 'error', code: r2.statusCode, latencyMs: Date.now() - t2 };
            finishCheck();
        });
        req2.on('error', (e) => {
            results.osrmFallback = { status: 'offline', error: e.message, latencyMs: -1 };
            finishCheck();
        });

        // 3. Geoapify Places API (preko HTTPS)
        const t3 = Date.now();
        const req3 = https.get('https://api.geoapify.com/v2/places?categories=catering.bar&filter=circle:14.5058,46.0569,1000&limit=1&apiKey=b2669a1530394868ae3a5abd6f38f7f2', { timeout: 3500 }, (r3) => {
            results.geoapify = { status: r3.statusCode === 200 ? 'online' : 'error', code: r3.statusCode, latencyMs: Date.now() - t3 };
            finishCheck();
        });
        req3.on('error', (e) => {
            results.geoapify = { status: 'offline', error: e.message, latencyMs: -1 };
            finishCheck();
        });

        return;
    }

    // ADMIN API: PRIDOBI SPOROČILA DOLOČENE SOBE
    if (pathname === '/api/admin/room/messages') {
        if (!checkAdminAuth(req, clientIp)) {
            res.writeHead(401, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'Nepooblaščen dostop' }));
            return;
        }
        const code = (parsedUrl.query.code || '').toUpperCase();
        const msgs = stmtGetRecentMessages.all(code).map(sanitizeMessageRow).reverse();
        const members = stmtGetMembers.all(code).map(sanitizeMemberRow);
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ success: true, messages: msgs, members: members }));
        return;
    }

    // ADMIN API: REAL-TIME IZBRIS SPOROČILA (Z ODMEVOM V TELEFONE)
    if (pathname === '/api/admin/message/delete' && req.method === 'POST') {
        if (!checkAdminAuth(req)) {
            res.writeHead(401, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'Nepooblaščen dostop' }));
            return;
        }

        let body = '';
        req.on('data', chunk => { body += chunk; });
        req.on('end', () => {
            try {
                const data = JSON.parse(body || '{}');
                const id = data.id;
                if (!id) throw new Error('Manjka ID sporočila');

                const msgRow = stmtGetMessageById.get(id);
                stmtDeleteMessage.run(id);

                if (msgRow && msgRow.room_code) {
                    broadcastToRoom(msgRow.room_code, {
                        type: 'message_deleted',
                        id: Number(id)
                    });
                }

                res.writeHead(200, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ success: true, message: `Sporočilo ${id} izbrisano.` }));
            } catch (err) {
                res.writeHead(400, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ error: err.message }));
            }
        });
        return;
    }

    // ADMIN API: POŠLJI SPOROČILO V SOBO KOT SKRBNIK (ŠankFinder Uprava)
    if (pathname === '/api/admin/message/send' && req.method === 'POST') {
        if (!checkAdminAuth(req)) {
            res.writeHead(401, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'Nepooblaščen dostop' }));
            return;
        }

        let body = '';
        req.on('data', chunk => { body += chunk; });
        req.on('end', () => {
            try {
                const data = JSON.parse(body || '{}');
                const code = (data.code || '').toUpperCase();
                const content = (data.content || '').trim();
                if (!code || !content) throw new Error('Manjka koda sobe ali vsebina');

                const resDb = stmtInsertMessage.run(code, 'admin', 'ŠankFinder Uprava', 'admin', content);

                broadcastToRoom(code, {
                    type: 'new_message',
                    id: resDb.lastInsertRowid,
                    senderId: 'admin',
                    senderName: 'ŠankFinder Uprava',
                    msgType: 'admin',
                    content: content,
                    createdAt: new Date().toISOString()
                });

                res.writeHead(200, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ success: true, message: 'Sporočilo oddano v sobo.' }));
            } catch (err) {
                res.writeHead(400, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ error: err.message }));
            }
        });
        return;
    }

    // ADMIN API: POPRAVEK ŠTEVILA PIJAČ ČLANA V ŽIVO (+ / - ali določena vrednost)
    if (pathname === '/api/admin/member/drinks' && req.method === 'POST') {
        if (!checkAdminAuth(req)) {
            res.writeHead(401, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'Nepooblaščen dostop' }));
            return;
        }

        let body = '';
        req.on('data', chunk => { body += chunk; });
        req.on('end', () => {
            try {
                const data = JSON.parse(body || '{}');
                const memberId = data.memberId;
                const roomCode = (data.roomCode || '').toUpperCase();
                const delta = Number(data.delta || 0);

                if (!memberId || !roomCode) throw new Error('Manjka ID člana ali koda sobe');

                const member = stmtGetMemberById.get(memberId);
                if (!member) throw new Error('Član ne obstaja v bazi');

                let newCount = (member.drinks_count || 0) + delta;
                if (data.count !== undefined) newCount = Number(data.count);
                if (newCount < 0) newCount = 0;

                stmtUpdateMemberDrinks.run(newCount, memberId);

                // Takoj sinhroniziraj s telefoni vseh članov v sobi
                broadcastToRoom(roomCode, {
                    type: 'drinks_updated',
                    userId: memberId,
                    drinksCount: newCount
                });

                res.writeHead(200, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ success: true, drinksCount: newCount }));
            } catch (err) {
                res.writeHead(400, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ error: err.message }));
            }
        });
        return;
    }

    // ADMIN API: IZBRIS CELOTNE SOBE
    if (pathname === '/api/admin/room/delete' && req.method === 'POST') {
        if (!checkAdminAuth(req)) {
            res.writeHead(401, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'Nepooblaščen dostop' }));
            return;
        }

        let body = '';
        req.on('data', chunk => { body += chunk; });
        req.on('end', () => {
            try {
                const data = JSON.parse(body || '{}');
                const code = (data.code || '').toUpperCase();
                if (!code) throw new Error('Manjka koda sobe');

                broadcastToRoom(code, { type: 'room_closed_by_admin', message: 'Sobo je administrator zaprl.' });
                const sockets = roomSockets.get(code);
                if (sockets) {
                    for (const s of sockets) {
                        try { s.close(1000, 'Zaprto s strani administratorja'); } catch (e) {}
                    }
                    roomSockets.delete(code);
                }

                stmtDeleteRoom.run(code);
                stmtDeleteMembersOfRoom.run(code);
                stmtDeleteMessagesOfRoom.run(code);

                res.writeHead(200, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ success: true, message: `Soba ${code} uspešno izbrisana.` }));
            } catch (err) {
                res.writeHead(400, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ error: err.message }));
            }
        });
        return;
    }

    // ADMIN API: ROČNO ČIŠČENJE STARIH SOB IN SPOROČIL (> 24 ur)
    if (pathname === '/api/admin/db/clean' && req.method === 'POST') {
        if (!checkAdminAuth(req)) {
            res.writeHead(401, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'Nepooblaščen dostop' }));
            return;
        }

        try {
            const r1 = stmtCleanOldRooms.run();
            const r2 = stmtCleanOldMembers.run();
            const r3 = stmtCleanOldMessages.run();
            try { db.pragma('wal_checkpoint(TRUNCATE)'); } catch (e) {}

            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({
                success: true,
                message: `Čiščenje uspešno zaključeno: odstranjeno ${r1.changes} neaktivnih sob, ${r2.changes} članov in ${r3.changes} sporočil.`
            }));
        } catch (err) {
            res.writeHead(500, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: err.message }));
        }
        return;
    }

    // ADMIN API: PRENOS VARNOSTNE KOPIJE SQLITE BAZE (SQUAD.DB)
    if (pathname === '/api/admin/db/backup') {
        if (!checkAdminAuth(req)) {
            res.writeHead(401, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'Nepooblaščen dostop' }));
            return;
        }

        if (fs.existsSync(dbPath)) {
            const dateStr = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
            const filename = `sankfinder_backup_${dateStr}.db`;
            res.writeHead(200, {
                'Content-Type': 'application/octet-stream',
                'Content-Disposition': `attachment; filename="${filename}"`,
                'Content-Length': fs.statSync(dbPath).size
            });
            fs.createReadStream(dbPath).pipe(res);
            return;
        } else {
            res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
            res.end('Baza podatkov še ne obstaja na disku.');
            return;
        }
    }

    // JAVNI API: KONFIGURACIJA IN ŠANK TEDNA ZA APLIKACIJO
    if (pathname === '/api/app/config' && req.method === 'GET') {
        const motdSetting = stmtGetSetting.get('motd');
        const featSetting = stmtGetSetting.get('featured_pub');
        const verAndroidSetting = stmtGetSetting.get('latest_version_android');
        const verIosSetting = stmtGetSetting.get('latest_version_ios');
        const minVerSetting = stmtGetSetting.get('min_version');
        const verNotesSetting = stmtGetSetting.get('version_update_notes');

        let featuredPub = null;
        if (featSetting && featSetting.value) {
            try { featuredPub = JSON.parse(featSetting.value); } catch (e) {}
        }
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
            success: true,
            motd: motdSetting ? motdSetting.value : null,
            featuredPub: featuredPub,
            versions: {
                android: verAndroidSetting ? verAndroidSetting.value : '1.2.0',
                ios: verIosSetting ? verIosSetting.value : '1.2.0',
                minVersion: minVerSetting ? minVerSetting.value : '1.0.0',
                notes: verNotesSetting ? verNotesSetting.value : ''
            }
        }));
        return;
    }

    // JAVNI API: HITRO PREVERJANJE VERZIJ
    if (pathname === '/api/app/version' && req.method === 'GET') {
        const verAndroidSetting = stmtGetSetting.get('latest_version_android');
        const verIosSetting = stmtGetSetting.get('latest_version_ios');
        const minVerSetting = stmtGetSetting.get('min_version');
        const verNotesSetting = stmtGetSetting.get('version_update_notes');

        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
            success: true,
            android: verAndroidSetting ? verAndroidSetting.value : '1.2.0',
            ios: verIosSetting ? verIosSetting.value : '1.2.0',
            minVersion: minVerSetting ? minVerSetting.value : '1.0.0',
            notes: verNotesSetting ? verNotesSetting.value : ''
        }));
        return;
    } 

    // JAVNI API: USTVARJANJE SOBE (za Pivsko Klapo)
    if (pathname === '/api/rooms/create' && req.method === 'POST') {
        if (!verifyRequestSignature(req)) {
            res.writeHead(403, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'Neveljaven ali potekel varnostni podpis zahtevka (HMAC-SHA256).' }));
            return;
        }

        let body = '';
        req.on('data', chunk => { body += chunk; });
        req.on('end', () => {
            try {
                const data = JSON.parse(body || '{}');
                const roomName = (data.name || 'Pivska Klapa').trim();
                let code = generateRoomCode();
                let attempts = 0;
                while (stmtGetRoomByCode.get(code) && attempts < 10) {
                    code = generateRoomCode();
                    attempts++;
                }

                const roomId = 'room_' + Date.now();
                stmtInsertRoom.run(roomId, code, roomName);

                res.writeHead(200, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({
                    success: true,
                    roomId,
                    code,
                    name: roomName
                }));
            } catch (err) {
                res.writeHead(400, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ error: err.message }));
            }
        });
        return;
    }

    // JAVNI API: PRIDRUŽITEV SOBI (za Pivsko Klapo)
    if (pathname === '/api/rooms/join' && req.method === 'POST') {
        if (!verifyRequestSignature(req)) {
            res.writeHead(403, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'Neveljaven ali potekel varnostni podpis zahtevka (HMAC-SHA256).' }));
            return;
        }

        let body = '';
        req.on('data', chunk => { body += chunk; });
        req.on('end', () => {
            try {
                const data = JSON.parse(body || '{}');
                const code = (data.code || '').trim().toUpperCase();

                const room = stmtGetRoomByCode.get(code);
                if (!room) {
                    res.writeHead(404, { 'Content-Type': 'application/json' });
                    res.end(JSON.stringify({ error: 'Soba s to kodo ne obstaja ali je že potekla!' }));
                    return;
                }
                const members = stmtGetMembers.all(code).map(sanitizeMemberRow);
                const messages = stmtGetRecentMessages.all(code).map(sanitizeMessageRow).reverse();

                res.writeHead(200, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ success: true, room, members, messages }));
            } catch (err) {
                res.writeHead(400, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ error: err.message }));
            }
        });
        return;
    }

    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Endpoint ne obstaja' }));
});

// 4. WEBSOCKET SERVER
const wss = new WebSocketServer({ server, path: '/ws' });

wss.on('connection', (ws, req) => {
    const parsedUrl = url.parse(req.url, true);
    const clientType = parsedUrl.query.clientType || (parsedUrl.query.code ? 'squad' : 'app');
    const clientIp = req.headers['x-forwarded-for'] || req.socket.remoteAddress || 'Lokalno';

    // 4A. REGISTRACIJA TELEFONA / CELOTNE APLIKACIJE (GLOBAL PUSH & TELEMETRIJA)
    if (clientType === 'app' || parsedUrl.query.deviceId) {
        const deviceId = parsedUrl.query.deviceId || ('dev_' + Math.random().toString(36).substring(2, 9));
        const model = parsedUrl.query.model || 'Pametni telefon';
        const osVersion = parsedUrl.query.os || 'Android';
        const appVersion = parsedUrl.query.version || parsedUrl.query.appVersion || parsedUrl.query.v || '1.0';
        const screen = parsedUrl.query.screen || 'Glavna stran';

        const deviceInfo = {
            deviceId,
            model,
            osVersion,
            appVersion,
            currentScreen: screen,
            ip: clientIp,
            connectedAt: new Date().toISOString(),
            lastSeen: new Date().toISOString()
        };

        appConnectedClients.set(ws, deviceInfo);

        stmtUpsertAppDevice.run({
            deviceId,
            model,
            osVersion,
            appVersion,
            currentScreen: screen,
            ip: clientIp
        });

        // Pošlji začetne nastavitve (npr. MOTD in Šank Tedna), če obstajata
        const motdSetting = stmtGetSetting.get('motd');
        if (motdSetting && motdSetting.value) {
            try {
                ws.send(JSON.stringify({ type: 'motd', message: motdSetting.value }));
            } catch (e) {}
        }
        const featSetting = stmtGetSetting.get('featured_pub');
        if (featSetting && featSetting.value) {
            try {
                ws.send(JSON.stringify({ type: 'featured_pub', pub: JSON.parse(featSetting.value) }));
            } catch (e) {}
        }
    }

    // 4B. SQUAD POVEZAVA (PIVSKA KLAPA)
    const initialCode = (parsedUrl.query.code || '').toUpperCase();
    const initialName = parsedUrl.query.name || 'Prijatelj';
    const initialUserId = parsedUrl.query.userId || ('user_' + Date.now());

    // Preverjanje HMAC-SHA256 podpisa za WebSocket povezavo
    const wsTimestamp = req.headers['x-sank-timestamp'] || parsedUrl.query.t;
    const wsSig = req.headers['x-sank-signature'] || parsedUrl.query.sig;
    const wsDevId = parsedUrl.query.deviceId || parsedUrl.query.userId || req.headers['x-device-id'] || '';
    if (wsSig && wsTimestamp) {
        if (!verifyWsSignature(wsTimestamp, wsSig, wsDevId)) {
            console.warn(`[VARNOST] Zavrnjena WebSocket povezava: url=${req.url}, t=${wsTimestamp}, now=${Date.now()}, diff=${Date.now() - Number(wsTimestamp)}ms, devId=${wsDevId}, sig=${wsSig}`);
            ws.close(4403, 'Neveljaven ali potekel varnostni podpis');
            return;
        }
    }

    ws.user = {
        id: initialUserId,
        name: initialName,
        code: initialCode,
        drinksCount: 0,
        ip: clientIp,
        connectedAt: new Date().toISOString()
    };

    if (initialCode) {
        joinWsToRoom(ws, initialCode);
    }

    // POSLUŠANJE SPOROČIL
    ws.on('message', (messageRaw) => {
        try {
            const msg = JSON.parse(messageRaw.toString());

            // 1. Poročanje o spremembi zaslona in verzije v aplikaciji
            if (msg.type === 'screen_change' || msg.type === 'ping' || msg.screen || msg.version) {
                const dev = appConnectedClients.get(ws);
                if (dev) {
                    if (msg.screen) dev.currentScreen = msg.screen;
                    if (msg.version && msg.version !== '1.0') dev.appVersion = msg.version;
                    dev.lastSeen = new Date().toISOString();
                    if (dev.appVersion) {
                        stmtUpdateDeviceScreenAndVersion.run(dev.currentScreen, dev.appVersion, dev.deviceId);
                    } else {
                        stmtUpdateDeviceScreen.run(dev.currentScreen, dev.deviceId);
                    }
                }
            }

            // 2. Squad sporočila (Pivska Klapa)
            handleClientMessage(ws, msg);
        } catch (e) {
            console.error('Neveljavno WebSocket sporočilo:', e.message);
        }
    });

    ws.on('close', () => {
        appConnectedClients.delete(ws);
        if (ws.user && ws.user.code) {
            leaveWsFromRoom(ws, ws.user.code);
        }
    });

    ws.on('error', (err) => {
        console.error('WebSocket napaka:', err.message);
    });
});

function joinWsToRoom(ws, code) {
    if (!roomSockets.has(code)) {
        roomSockets.set(code, new Set());
    }
    roomSockets.get(code).add(ws);

    // Če uporabnik že obstaja v bazi, ohrani njegovo obstoječe število pijač!
    const existing = stmtGetMemberById.get(ws.user.id);
    if (existing && existing.drinks_count != null) {
        ws.user.drinksCount = existing.drinks_count;
    }

    stmtUpsertMember.run({
        id: ws.user.id,
        roomCode: code,
        name: ws.user.name,
        lat: null,
        lon: null,
        drinksCount: ws.user.drinksCount || 0
    });

    broadcastToRoom(code, {
        type: 'member_joined',
        userId: ws.user.id,
        name: ws.user.name
    }, ws);

    try {
        ws.send(JSON.stringify({
            type: 'room_joined_ack',
            roomCode: code,
            userId: ws.user.id,
            name: ws.user.name,
            drinksCount: ws.user.drinksCount || 0
        }));
    } catch (e) {}
}

function leaveWsFromRoom(ws, code) {
    const sockets = roomSockets.get(code);
    if (sockets) {
        sockets.delete(ws);
        if (sockets.size === 0) {
            roomSockets.delete(code);
        }
    }
    broadcastToRoom(code, {
        type: 'member_left',
        userId: ws.user.id,
        name: ws.user.name
    });
}

function broadcastToRoom(code, payload, excludeWs = null) {
    const sockets = roomSockets.get(code);
    if (!sockets) return;
    const data = JSON.stringify(payload);
    for (const client of sockets) {
        if (client !== excludeWs && client.readyState === WebSocket.OPEN) {
            try {
                client.send(data);
            } catch (err) {
                console.error('Napaka pri pošiljanju WS sporočila v sobo:', err.message);
            }
        }
    }
}

function handleClientMessage(ws, msg) {
    const code = ws.user.code;
    if (!code) return;

    switch (msg.type) {
        case 'location_update': {
            // Šifriraj GPS koordinati pred vpisom v SQLite bazo (AES-256-GCM)
            stmtUpsertMember.run({
                id: ws.user.id,
                roomCode: code,
                name: ws.user.name,
                lat: encryptField(msg.lat),
                lon: encryptField(msg.lon),
                drinksCount: ws.user.drinksCount || 0
            });

            // Članom v sobi posreduj neposredno v živo (v spominu)
            broadcastToRoom(code, {
                type: 'peer_location',
                userId: ws.user.id,
                name: ws.user.name,
                lat: msg.lat,
                lon: msg.lon,
                speed: msg.speed || 0,
                updatedAt: new Date().toISOString()
            }, ws);
            break;
        }

        case 'chat_message': {
            const content = (msg.content || '').trim();
            if (!content) return;

            // Šifriraj vsebino sporočila pred vpisom v bazo (AES-256-GCM)
            const encryptedContent = encryptField(content);
            const res = stmtInsertMessage.run(code, ws.user.id, ws.user.name, msg.msgType || 'text', encryptedContent);

            broadcastToRoom(code, {
                type: 'new_message',
                id: res.lastInsertRowid,
                senderId: ws.user.id,
                senderName: ws.user.name,
                msgType: msg.msgType || 'text',
                content: content,
                createdAt: new Date().toISOString()
            });
            break;
        }

        case 'drink_update': {
            const delta = Number(msg.delta) || 1;
            ws.user.drinksCount = Math.max(0, (ws.user.drinksCount || 0) + delta);

            // Posodobi izključno tega uporabnika
            stmtUpdateMemberDrinks.run(ws.user.drinksCount, ws.user.id);

            broadcastToRoom(code, {
                type: 'drinks_updated',
                userId: ws.user.id,
                name: ws.user.name,
                drinksCount: ws.user.drinksCount
            });
            break;
        }

        case 'eta_status': {
            broadcastToRoom(code, {
                type: 'eta_alert',
                userId: ws.user.id,
                name: ws.user.name,
                targetLokal: msg.targetLokal,
                etaMinutes: msg.etaMinutes
            });
            break;
        }
    }
}

// Periodično čiščenje starih sob in GPS lokacij (Data Minimization) vsako uro
setInterval(() => {
    try {
        stmtCleanOldRooms.run();
        stmtCleanOldMembers.run();
        stmtCleanOldMessages.run();
        // Trajno izbriši GPS lokacije in člane, starejše od 24 ur
        db.prepare("UPDATE members SET lat = NULL, lon = NULL WHERE last_seen < datetime('now', '-24 hours')").run();
        db.prepare("DELETE FROM members WHERE last_seen < datetime('now', '-24 hours')").run();
        console.log('[VARNOST] Urno čiščenje neaktivnih sob in GPS koordinat (>24h) uspešno izvedeno.');
    } catch (e) {
        console.error('Napaka pri čiščenju baze:', e.message);
    }
}, 60 * 60 * 1000);

// 5. HTML PREDLOGA ZA PROFESIONALNO SKRITO NADZORNO PLOŠČO CELOTNEGA APPA
function renderAdminDashboardHtml() {
    return `<!DOCTYPE html>
<html lang="sl">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover">
  <title>ŠankFinder | Nadzorni Center</title>
  <link rel="icon" type="image/png" href="/logo.png">
  <link rel="shortcut icon" type="image/png" href="/logo.png">
  <link rel="apple-touch-icon" href="/logo.png">
  
  <!-- Leaflet.js za Live Radar zemljevid -->
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY=" crossorigin=""/>
  <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js" integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo=" crossorigin=""></script>
  
  <!-- Pisave -->
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;600;700&display=swap" rel="stylesheet">

  <style>
    :root {
      --bg: #090d16;
      --card-bg: #121929;
      --card-header: #192338;
      --sidebar-bg: #0d1322;
      --gold: #f59e0b;
      --gold-hover: #d97706;
      --gold-bg: rgba(245, 158, 11, 0.12);
      --green: #10b981;
      --green-bg: rgba(16, 185, 129, 0.12);
      --red: #ef4444;
      --red-bg: rgba(239, 68, 68, 0.15);
      --blue: #3b82f6;
      --blue-bg: rgba(59, 130, 246, 0.15);
      --purple: #8b5cf6;
      --purple-bg: rgba(139, 92, 246, 0.15);
      --border: #222f47;
      --text: #f8fafc;
      --text-muted: #94a3b8;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      background-color: var(--bg);
      color: var(--text);
      font-family: 'Plus Jakarta Sans', sans-serif;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
    }
    header {
      background: var(--sidebar-bg);
      border-bottom: 1px solid var(--border);
      padding: 12px 24px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      position: sticky;
      top: 0;
      z-index: 1000;
      backdrop-filter: blur(8px);
    }
    .brand {
      display: flex;
      align-items: center;
      gap: 12px;
    }
    .badge-tag {
      background: var(--gold-bg);
      color: var(--gold);
      border: 1px solid rgba(245, 158, 11, 0.3);
      padding: 3px 8px;
      border-radius: 6px;
      font-size: 11px;
      font-weight: 800;
      letter-spacing: 0.8px;
    }
    .brand-title { font-size: 17px; font-weight: 800; }
    .status-badge {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      background: var(--green-bg);
      color: var(--green);
      padding: 4px 10px;
      border-radius: 20px;
      font-size: 12px;
      font-weight: 700;
      border: 1px solid rgba(16, 185, 129, 0.3);
    }
    .pulse-dot {
      width: 7px;
      height: 7px;
      background: var(--green);
      border-radius: 50%;
      box-shadow: 0 0 8px var(--green);
      animation: pulse 2s infinite;
    }
    @keyframes pulse {
      0% { transform: scale(0.95); opacity: 0.8; }
      50% { transform: scale(1.2); opacity: 1; }
      100% { transform: scale(0.95); opacity: 0.8; }
    }

    /* NAVIGACIJSKI MENI */
    .tabs-bar {
      background: #0f1628;
      border-bottom: 1px solid var(--border);
      display: flex;
      gap: 4px;
      padding: 0 24px;
      overflow-x: auto;
    }
    .tab-btn {
      background: transparent;
      color: var(--text-muted);
      border: none;
      padding: 13px 18px;
      font-family: inherit;
      font-size: 13px;
      font-weight: 700;
      cursor: pointer;
      display: inline-flex;
      align-items: center;
      gap: 8px;
      border-bottom: 2px solid transparent;
      transition: all 0.2s;
      white-space: nowrap;
    }
    .tab-btn:hover { color: var(--text); background: rgba(255,255,255,0.02); }
    .tab-btn.active {
      color: var(--gold);
      border-bottom-color: var(--gold);
      background: rgba(245, 158, 11, 0.05);
    }
    .tab-pill {
      background: var(--border);
      color: var(--text);
      font-size: 11px;
      padding: 2px 7px;
      border-radius: 10px;
      font-weight: 800;
    }
    .tab-btn.active .tab-pill {
      background: var(--gold);
      color: #000;
    }

    /* GLAVNI PROSTOR */
    .content {
      padding: 20px 24px;
      max-width: 1440px;
      width: 100%;
      margin: 0 auto;
      flex: 1;
    }
    .tab-pane { display: none; }
    .tab-pane.active { display: block; animation: fadeIn 0.2s ease-in-out; }
    @keyframes fadeIn { from { opacity: 0; transform: translateY(4px); } to { opacity: 1; transform: translateY(0); } }

    /* STATISTIČNE KARTICE */
    .stats-row {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(210px, 1fr));
      gap: 14px;
      margin-bottom: 20px;
    }
    .stat-card {
      background: var(--card-bg);
      border: 1px solid var(--border);
      border-radius: 12px;
      padding: 16px 18px;
      position: relative;
      transition: transform 0.2s, border-color 0.2s;
    }
    .stat-card:hover {
      border-color: rgba(245, 158, 11, 0.35);
      transform: translateY(-1px);
    }
    .stat-label {
      font-size: 11px;
      text-transform: uppercase;
      letter-spacing: 0.6px;
      color: var(--text-muted);
      font-weight: 700;
    }
    .stat-number {
      font-size: 26px;
      font-weight: 800;
      color: var(--gold);
      margin-top: 4px;
      font-family: 'JetBrains Mono', monospace;
    }
    .stat-sub {
      font-size: 11px;
      color: var(--text-muted);
      margin-top: 4px;
      display: flex;
      align-items: center;
      gap: 6px;
    }

    /* PANELI */
    .panel {
      background: var(--card-bg);
      border: 1px solid var(--border);
      border-radius: 14px;
      padding: 20px;
      margin-bottom: 20px;
    }
    .panel-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 16px;
      flex-wrap: wrap;
      gap: 10px;
    }
    .panel-title {
      font-size: 15.5px;
      font-weight: 800;
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .search-input {
      background: #090e18;
      border: 1px solid var(--border);
      color: var(--text);
      padding: 7px 12px;
      border-radius: 8px;
      font-family: inherit;
      font-size: 12.5px;
      width: 240px;
      outline: none;
      transition: border-color 0.2s;
    }
    .search-input:focus { border-color: var(--gold); }
    table { width: 100%; border-collapse: collapse; font-size: 12.5px; text-align: left; }
    th {
      color: var(--text-muted);
      font-size: 11px;
      text-transform: uppercase;
      font-weight: 700;
      letter-spacing: 0.5px;
      padding: 10px 12px;
      border-bottom: 1px solid var(--border);
    }
    td { padding: 11px 12px; border-bottom: 1px solid rgba(34, 47, 71, 0.4); }
    tr:last-child td { border-bottom: none; }
    tr:hover td { background: rgba(255,255,255,0.015); }
    .mono { font-family: 'JetBrains Mono', monospace; font-size: 12px; }
    .code-badge {
      background: var(--gold-bg);
      color: var(--gold);
      border: 1px solid rgba(245, 158, 11, 0.3);
      padding: 2px 6px;
      border-radius: 5px;
      font-weight: 700;
      font-family: 'JetBrains Mono', monospace;
      font-size: 11.5px;
    }

    /* GUMBI */
    .btn {
      background: var(--gold);
      color: #000;
      border: none;
      padding: 7px 14px;
      border-radius: 7px;
      font-family: inherit;
      font-weight: 700;
      font-size: 12px;
      cursor: pointer;
      display: inline-flex;
      align-items: center;
      gap: 5px;
      transition: all 0.2s;
    }
    .btn:hover { background: var(--gold-hover); }
    .btn-sm { padding: 4px 9px; font-size: 11px; }
    .btn-blue {
      background: var(--blue-bg);
      color: #60a5fa;
      border: 1px solid rgba(59, 130, 246, 0.3);
    }
    .btn-blue:hover { background: var(--blue); color: #fff; }
    .btn-green {
      background: var(--green-bg);
      color: #34d399;
      border: 1px solid rgba(16, 185, 129, 0.3);
    }
    .btn-green:hover { background: var(--green); color: #000; }
    .btn-red {
      background: var(--red-bg);
      color: #f87171;
      border: 1px solid rgba(239, 68, 68, 0.3);
    }
    .btn-red:hover { background: var(--red); color: #fff; }

    /* OBRAZEC */
    .form-group { margin-bottom: 14px; }
    .form-group label { display: block; font-size: 11.5px; font-weight: 700; color: var(--text-muted); margin-bottom: 5px; text-transform: uppercase; letter-spacing: 0.5px; }
    .form-control {
      width: 100%;
      background: #090e18;
      border: 1px solid var(--border);
      color: var(--text);
      padding: 9px 12px;
      border-radius: 8px;
      font-family: inherit;
      font-size: 13px;
      outline: none;
    }
    .form-control:focus { border-color: var(--gold); }
    textarea.form-control { resize: vertical; min-height: 75px; }

    .grid-2 {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 18px;
    }
    @media (max-width: 950px) {
      .grid-2 { grid-template-columns: 1fr; }
    }

    /* PREDLOGE */
    .chips-row {
      display: flex;
      flex-wrap: wrap;
      gap: 6px;
      margin-bottom: 12px;
    }
    .chip-btn {
      background: rgba(255,255,255,0.04);
      border: 1px solid var(--border);
      color: var(--text-muted);
      border-radius: 20px;
      padding: 4px 10px;
      font-size: 11px;
      font-weight: 600;
      cursor: pointer;
      transition: all 0.2s;
    }
    .chip-btn:hover {
      background: var(--gold-bg);
      color: var(--gold);
      border-color: var(--gold);
    }

    /* TELEFONSKI PREDOGLED V ŽIVO */
    .phone-preview-card {
      background: #090e17;
      border: 1px solid var(--border);
      border-radius: 18px;
      padding: 16px;
      box-shadow: 0 10px 25px rgba(0,0,0,0.5);
      position: relative;
      overflow: hidden;
      display: flex;
      flex-direction: column;
      gap: 12px;
    }
    .phone-top-bar {
      display: flex;
      justify-content: space-between;
      align-items: center;
      font-size: 11px;
      color: #94a3b8;
      font-weight: 700;
    }
    .lockscreen-notif {
      background: rgba(30, 41, 59, 0.85);
      border: 1px solid rgba(255, 255, 255, 0.12);
      backdrop-filter: blur(16px);
      border-radius: 12px;
      padding: 12px 14px;
      box-shadow: 0 4px 15px rgba(0,0,0,0.3);
    }
    .notif-header {
      display: flex;
      align-items: center;
      gap: 8px;
      margin-bottom: 4px;
    }
    .notif-app-name { font-size: 11px; font-weight: 700; color: #cbd5e1; text-transform: uppercase; letter-spacing: 0.5px; }
    .notif-time { font-size: 10px; color: #64748b; margin-left: auto; }
    .notif-title { font-size: 13px; font-weight: 700; color: #f8fafc; margin-bottom: 2px; }
    .notif-body { font-size: 12px; color: #cbd5e1; line-height: 1.35; }

    /* LEAFLET LIVE RADAR - BREZPLAČEN OSM Z ELEGANTRNIM TEMNIM FILTROM (BREZ API KLJUČA) */
    #live-radar-map {
      height: 380px;
      width: 100%;
      border-radius: 12px;
      overflow: hidden;
      border: 1px solid var(--border);
      z-index: 10;
      background: #090d16;
    }
    .leaflet-tile-pane {
      filter: brightness(0.65) invert(1) contrast(2.5) hue-rotate(200deg) saturate(0.35);
    }
    .custom-radar-icon {
      background: transparent;
      border: none;
    }
    .radar-pin-wrap {
      position: relative;
      width: 36px;
      height: 36px;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .radar-pulse {
      position: absolute;
      width: 36px;
      height: 36px;
      border-radius: 50%;
      background: rgba(245, 158, 11, 0.28);
      animation: pinPulse 2s infinite ease-out;
    }
    @keyframes pinPulse {
      0% { transform: scale(0.6); opacity: 1; }
      100% { transform: scale(1.6); opacity: 0; }
    }
    .radar-pin {
      position: relative;
      width: 28px;
      height: 28px;
      border-radius: 50%;
      background: #f59e0b;
      border: 2px solid #ffffff;
      color: #000;
      font-weight: 800;
      font-size: 12px;
      display: flex;
      align-items: center;
      justify-content: center;
      box-shadow: 0 2px 10px rgba(245, 158, 11, 0.6);
    }
    .radar-drinks-pill {
      position: absolute;
      top: -6px;
      right: -6px;
      background: #000000;
      color: #f59e0b;
      border: 1px solid #f59e0b;
      border-radius: 10px;
      padding: 1px 4px;
      font-size: 9px;
      font-weight: 800;
      font-family: 'JetBrains Mono', monospace;
    }

    /* OSRM SPARKLINE GRAF */
    .sparkline-wrap {
      display: flex;
      align-items: flex-end;
      gap: 3px;
      height: 24px;
      margin-top: 6px;
    }
    .spark-bar {
      flex: 1;
      background: var(--green);
      border-radius: 2px;
      min-width: 4px;
      transition: height 0.3s;
    }

    /* MODAL ZA KLEPET */
    .modal-overlay {
      display: none;
      position: fixed;
      inset: 0;
      background: rgba(0,0,0,0.8);
      backdrop-filter: blur(5px);
      z-index: 2000;
      justify-content: center;
      align-items: center;
      padding: 16px;
    }
    .modal {
      background: #111a2c;
      border: 1px solid var(--border);
      border-radius: 16px;
      width: 100%;
      max-width: 860px;
      max-height: 88vh;
      display: flex;
      flex-direction: column;
      overflow: hidden;
      box-shadow: 0 20px 50px rgba(0,0,0,0.6);
    }
    .modal-head {
      padding: 14px 20px;
      border-bottom: 1px solid var(--border);
      display: flex;
      justify-content: space-between;
      align-items: center;
      background: #0c1424;
    }
    .modal-body {
      padding: 0;
      overflow: hidden;
      flex: 1;
      display: grid;
      grid-template-columns: 1fr 280px;
      max-height: 520px;
    }
    @media (max-width: 768px) {
      .modal-body { grid-template-columns: 1fr; }
    }
    .modal-chat-pane {
      display: flex;
      flex-direction: column;
      border-right: 1px solid var(--border);
      height: 100%;
    }
    .modal-messages {
      padding: 14px;
      overflow-y: auto;
      flex: 1;
      display: flex;
      flex-direction: column;
      gap: 8px;
    }
    .modal-members-pane {
      background: #0d1424;
      padding: 14px;
      overflow-y: auto;
      display: flex;
      flex-direction: column;
      gap: 8px;
    }
    .msg-bubble {
      background: #1a2538;
      padding: 8px 12px;
      border-radius: 8px;
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
      gap: 8px;
    }
    .msg-sender { font-size: 11px; font-weight: 800; color: var(--gold); }
    .msg-text { font-size: 12.5px; margin-top: 2px; }
    .modal-foot {
      padding: 12px 18px;
      border-top: 1px solid var(--border);
      display: flex;
      gap: 10px;
      background: #0c1424;
    }

    /* MOBILNA ODZIVNOST ZA PAMETNE TELEFONE */
    @media (max-width: 768px) {
      header {
        padding: 10px 14px;
        flex-wrap: wrap;
        gap: 8px;
      }
      .brand-title {
        font-size: 15px;
      }
      .status-badge {
        font-size: 11px;
        padding: 3px 8px;
      }
      #server-uptime {
        display: none;
      }
      .tabs-bar {
        padding: 0 8px;
        gap: 2px;
        overflow-x: auto;
        -webkit-overflow-scrolling: touch;
        scrollbar-width: none;
        flex-wrap: nowrap;
      }
      .tabs-bar::-webkit-scrollbar {
        display: none;
      }
      .tab-btn {
        padding: 10px 12px;
        font-size: 12px;
        gap: 6px;
      }
      .content {
        padding: 12px 10px;
      }
      .stats-row {
        grid-template-columns: 1fr 1fr;
        gap: 8px;
        margin-bottom: 14px;
      }
      .stat-card {
        padding: 12px 10px;
        border-radius: 10px;
      }
      .stat-label {
        font-size: 10px;
      }
      .stat-number {
        font-size: 20px;
      }
      .stat-sub {
        font-size: 10px;
      }
      .panel {
        padding: 14px;
        border-radius: 12px;
        margin-bottom: 14px;
      }
      .panel-header {
        flex-direction: column;
        align-items: flex-start;
        gap: 8px;
      }
      .search-input {
        width: 100%;
      }
      #live-radar-map {
        height: 260px;
      }
      .modal {
        width: 95vw;
        max-height: 92vh;
        border-radius: 14px;
      }
      .modal-body {
        grid-template-columns: 1fr;
        max-height: 400px;
      }
      .grid-2 {
        grid-template-columns: 1fr;
        gap: 12px;
      }
      table {
        min-width: 580px;
      }
    }

    @media (max-width: 480px) {
      .stats-row {
        grid-template-columns: 1fr 1fr;
        gap: 6px;
      }
      .stat-card {
        padding: 10px 8px;
      }
      .stat-number {
        font-size: 18px;
      }
      .btn {
        padding: 7px 12px;
        font-size: 11.5px;
      }
      .btn-sm {
        padding: 5px 9px;
        font-size: 10.5px;
      }
    }
  </style>
</head>
<body>

  <!-- GLAVA (HEADER) -->
  <header>
    <div class="brand">
      <img src="/logo.png" alt="ŠankFinder Logo" style="height: 38px; width: 38px; object-fit: contain; filter: drop-shadow(0 2px 8px rgba(245, 158, 11, 0.45));">
      <span class="badge-tag">UPRAVA</span>
      <h1 class="brand-title">ŠankFinder Nadzorni Center</h1>
    </div>

    <div style="display:flex; align-items:center; gap: 10px; flex-wrap: wrap;">
      <div class="status-badge">
        <span class="pulse-dot"></span>
        Strežnik Aktiven
      </div>

      <span class="mono" style="font-size:11.5px; color:var(--text-muted); background:rgba(255,255,255,0.05); padding:4px 8px; border-radius:6px; border:1px solid var(--border);" id="server-uptime">
        Uptime: 0d 0h 0m
      </span>

      <span style="font-size:11.5px; color:var(--text-muted); display:inline-flex; align-items:center; gap:5px; background:rgba(255,255,255,0.03); padding:4px 8px; border-radius:6px; border:1px solid var(--border);">
        <span class="pulse-dot" style="background:var(--blue); box-shadow:0 0 6px var(--blue);"></span>
        Osvežitev: <b id="refresh-countdown" style="color:var(--text);">5s</b>
      </span>

      <button class="btn btn-green btn-sm" onclick="fetchData()">Osveži</button>
      <a href="/sank-uprava-x77/logout" class="btn btn-red btn-sm" style="text-decoration:none;">Odjava</a>
    </div>
  </header>

  <!-- NAVIGACIJSKI ZAVIHKI (5 ZAVIHKOV) -->
  <div class="tabs-bar">
    <button class="tab-btn active" onclick="switchTab('overview')">
      Pregled Aplikacije
    </button>
    <button class="tab-btn" onclick="switchTab('push')">
      Globalna Push Obvestila
      <span class="tab-pill" id="badge-push">0</span>
    </button>
    <button class="tab-btn" onclick="switchTab('devices')">
      Aktivne Naprave v Živo
      <span class="tab-pill" id="badge-devices">0</span>
    </button>
    <button class="tab-btn" onclick="switchTab('squad')">
      Pivska Klapa (Sobe in Klepet)
      <span class="tab-pill" id="badge-rooms">0</span>
    </button>
    <button class="tab-btn" onclick="switchTab('config')">
      Konfiguracija in Šank Tedna
    </button>
  </div>

  <div class="content">

    <!-- ZAVIHEK 1: GLAVNI PREGLED (6 OBOGATENIH KPI KARTIC + LEAFLET LIVE RADAR + STORITVE) -->
    <div class="tab-pane active" id="tab-overview">
      <!-- OPOZORILO: ZASTARELE RAZLICICE NA TELEFONIH -->
      <div id="version-warning-banner" style="display:none; margin-bottom:16px; padding:12px 16px; background:rgba(239,68,68,0.15); border:1px solid rgba(239,68,68,0.4); border-radius:12px; align-items:center; gap:12px; flex-wrap:wrap;">
        <span style="font-weight:800; font-size:12.5px; color:var(--red); text-transform:uppercase; letter-spacing:0.5px;">Opozorilo o zastarelih aplikacijah:</span>
        <span id="outdated-count-text" style="font-size:12.5px; color:var(--text); flex:1;"></span>
        <button class="btn btn-sm btn-blue" onclick="switchTab('devices')">Pokaži naprave</button>
      </div>
      <div class="stats-row">
        <!-- 1. Aktivne naprave v živo -->
        <div class="stat-card">
          <div class="stat-label">Aktivne Naprave v Živo</div>
          <div class="stat-number" id="stat-online-devices" style="color: var(--green);">0</div>
          <div class="stat-sub">
            <span class="badge-tag" style="background:rgba(59,130,246,0.15); color:#60a5fa; font-size:10px;">iOS: <b id="stat-ios-count">0</b></span>
            <span class="badge-tag" style="background:rgba(16,185,129,0.15); color:#34d399; font-size:10px;">Android: <b id="stat-android-count">0</b></span>
          </div>
        </div>

        <!-- 2. Vse registrirane naprave -->
        <div class="stat-card">
          <div class="stat-label">Vse Registrirane Naprave</div>
          <div class="stat-number" id="stat-total-devices">0</div>
          <div class="stat-sub">
            <span style="color:var(--green); font-weight:700;" id="stat-today-devices">+0 danes</span>
            <span>• V SQLite bazi</span>
          </div>
        </div>

        <!-- 3. Poslana Push obvestila -->
        <div class="stat-card">
          <div class="stat-label">Poslana Push Obvestila</div>
          <div class="stat-number" id="stat-push-sent" style="color: var(--blue);">0</div>
          <div class="stat-sub" id="stat-last-push">Zadnje: /</div>
        </div>

        <!-- 4. Aktivne Pivske Klape -->
        <div class="stat-card">
          <div class="stat-label">Aktivne Pivske Klape</div>
          <div class="stat-number" id="stat-rooms">0</div>
          <div class="stat-sub"><span id="stat-active-members-count" style="font-weight:700; color:var(--text);">0</span> članov v sobah</div>
        </div>

        <!-- 5. Skupaj štetih pijač -->
        <div class="stat-card">
          <div class="stat-label">Skupaj Štetih Pijač</div>
          <div class="stat-number" id="stat-drinks">0</div>
          <div class="stat-sub" id="stat-top-drinker">Top pivec: /</div>
        </div>

        <!-- 6. OSRM Usmerjevalnik z zgodovino -->
        <div class="stat-card">
          <div class="stat-label">OSRM Usmerjevalnik</div>
          <div class="stat-number" id="stat-osrm" style="font-size: 22px;">0 ms</div>
          <div class="sparkline-wrap" id="osrm-sparkline">
            <!-- 10 stolpcev mini zgodovine -->
          </div>
        </div>
      </div>

      <!-- SREDINSKI SKLOP: ZEMLJEVID AKTIVNIH KLAP V ŽIVO (LEAFLET.JS Z BREZPLAČNIM OSM BREZ API KLJUČA) -->
      <div class="panel">
        <div class="panel-header">
          <h2 class="panel-title">
            Zemljevid Aktivnih Klap v Živo (Live Radar)
            <span class="status-badge" style="background:rgba(245, 158, 11, 0.15); color:var(--gold); border-color:rgba(245, 158, 11, 0.3);" id="radar-live-count">
              0 uporabnikov na zemljevidu
            </span>
          </h2>
          <div style="display:flex; gap:8px;">
            <button class="btn btn-sm btn-blue" onclick="centerOnLjubljana()">Centriraj na Ljubljano</button>
            <button class="btn btn-sm" onclick="fitRadarBounds()">Prilagodi pogled na vse</button>
          </div>
        </div>
        <div id="live-radar-map"></div>
      </div>

      <!-- SPODNJI DVOJNI SKLOP: HITRI PUSH S PREDOGLEDOM + TELEMETRIJA STORITEV -->
      <div class="grid-2">
        <!-- LEVO: HITRO PUSH OBVESTILO Z VIZUALNIM PREDOGLEDOM -->
        <div class="panel">
          <div class="panel-header">
            <h2 class="panel-title">Hitro Push Obvestilo za Naprave</h2>
          </div>

          <div class="chips-row">
            <span style="font-size:11px; font-weight:700; color:var(--text-muted); align-self:center;">Predloge:</span>
            <button class="chip-btn" onclick="applyTemplate('happy_hour')">Happy Hour</button>
            <button class="chip-btn" onclick="applyTemplate('burek')">Burek Pavza</button>
            <button class="chip-btn" onclick="applyTemplate('update')">Posodobitev</button>
            <button class="chip-btn" onclick="applyTemplate('uprava')">Sporočilo Uprave</button>
          </div>

          <div class="form-group">
            <label>Ciljna Skupina (Target)</label>
            <select class="form-control" id="quick-push-target" onchange="onTargetChange()">
              <option value="all">Vsi uporabniki (iOS in Android)</option>
              <option value="ios">Samo iOS naprave (Apple)</option>
              <option value="android">Samo Android naprave</option>
              <option value="room">Določena Pivska Klapa (vnos kode)</option>
            </select>
          </div>

          <div class="form-group" id="group-room-code" style="display:none;">
            <label>Koda Pivske Klape (4 znaki)</label>
            <input type="text" class="form-control mono" id="quick-push-room-code" maxlength="4" placeholder="Npr. 7K2B" style="text-transform:uppercase;">
          </div>

          <div class="form-group">
            <label>Naslov Obvestila</label>
            <input type="text" class="form-control" id="quick-push-title" placeholder="Npr. Petkov Happy Hour v Ljubljani!" oninput="updateLivePreview()">
          </div>

          <div class="form-group">
            <label>Besedilo Sporočila</label>
            <textarea class="form-control" id="quick-push-msg" placeholder="Vnesite sporočilo, ki se bo prikazalo na telefonih..." oninput="updateLivePreview()"></textarea>
          </div>

          <!-- TELEFONSKI PREDOGLED V ŽIVO -->
          <div class="phone-preview-card">
            <div class="phone-top-bar">
              <span id="preview-clock">21:30</span>
              <span>Predogled na zaklenjenem zaslonu</span>
              <span>92%</span>
            </div>
            <div class="lockscreen-notif">
              <div class="notif-header">
                <img src="/logo.png" style="width: 18px; height: 18px; object-fit: contain;">
                <span class="notif-app-name">ŠankFinder</span>
                <span class="notif-time">pravkar</span>
              </div>
              <div class="notif-title" id="preview-title">Naslov obvestila bo tukaj...</div>
              <div class="notif-body" id="preview-body">Besedilo potisnega obvestila, kot ga bo videl uporabnik na svojem zaklenjenem zaslonu telefona.</div>
            </div>
          </div>

          <div style="margin-top:14px;">
            <button class="btn" style="width:100%; justify-content:center; padding:10px;" onclick="sendQuickPush()">
              Pošlji Potisno Obvestilo
            </button>
          </div>
        </div>

        <!-- DESNO: STANJE SISTEMSKIH STORITEV IN TELEMETRIJA -->
        <div class="panel">
          <div class="panel-header">
            <h2 class="panel-title">Stanje Sistemskih Storitev in Telemetrija</h2>
            <button class="btn btn-sm btn-blue" onclick="runDiagnostics()">Hitri Test API-jev</button>
          </div>

          <table>
            <thead>
              <tr><th>Storitev</th><th>Vrata / Podatki</th><th>Stanje</th></tr>
            </thead>
            <tbody>
              <tr>
                <td><strong>Caddy Reverse Proxy</strong></td>
                <td class="mono">sankfinder.sluga.me (TLS 1.3)</td>
                <td><span style="color: var(--green); font-weight: 700;">Deluje (HSTS)</span></td>
              </tr>
              <tr>
                <td><strong>OSRM Slovenija Usmerjevalnik</strong></td>
                <td class="mono">Port 5000 (HTTP)</td>
                <td id="osrm-service-status"><span style="color: var(--green); font-weight: 700;">Preverjam...</span></td>
              </tr>
              <tr>
                <td><strong>OSRM Fallback (openstreetmap.de)</strong></td>
                <td class="mono">Javni OSRM API (HTTPS)</td>
                <td id="osrm-fallback-status"><span style="color: var(--text-muted);">Pripravljen</span></td>
              </tr>
              <tr>
                <td><strong>ŠankFinder Master Gateway</strong></td>
                <td class="mono">Port 8080 (Node.js)</td>
                <td id="gateway-telemetry"><span style="color: var(--green); font-weight: 700;">Deluje</span></td>
              </tr>
              <tr>
                <td><strong>SQLite Baza (WAL)</strong></td>
                <td class="mono" id="db-file-sizes">data/squad.db</td>
                <td><span style="color: var(--green); font-weight: 700;">Povezana</span></td>
              </tr>
            </tbody>
          </table>

          <div style="margin-top:18px; padding-top:14px; border-top:1px solid var(--border); display:flex; gap:10px; flex-wrap:wrap;">
            <button class="btn btn-blue btn-sm" onclick="cleanOldRooms()">
              Počisti neaktivne sobe (> 24h)
            </button>
            <a href="/api/admin/db/backup" class="btn btn-sm" style="text-decoration:none;">
              Prenesi varnostno kopijo (.db)
            </a>
          </div>

          <div id="diagnostics-box" style="margin-top:14px; display:none; background:#090e18; padding:12px; border-radius:8px; border:1px solid var(--border); font-size:12px;">
            <div style="font-weight:700; color:var(--gold); margin-bottom:6px;">Rezultati Diagnostičnega Testiranja:</div>
            <div id="diag-details"></div>
          </div>
        </div>
      </div>
    </div>

    <!-- ZAVIHEK 2: GLOBALNA PUSH OBVESTILA -->
    <div class="tab-pane" id="tab-push">
      <div class="panel">
        <div class="panel-header">
          <h2 class="panel-title">Zgodovina Poslanih Potisnih Obvestil</h2>
          <span class="mono" id="push-history-count" style="font-size:12px; color:var(--text-muted);">0 obvestil</span>
        </div>
        <div style="overflow-x:auto;">
          <table>
            <thead>
              <tr>
                <th>ID</th>
                <th>Naslov in Sporočilo</th>
                <th>Cilj</th>
                <th>Prejemniki</th>
                <th>Čas Pošiljanja</th>
                <th>Dejanja</th>
              </tr>
            </thead>
            <tbody id="push-history-tbody">
              <tr><td colspan="6" style="text-align:center; color:var(--text-muted);">Nalaganje zgodovine...</td></tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <!-- ZAVIHEK 3: AKTIVNE NAPRAVE V ŽIVO -->
    <div class="tab-pane" id="tab-devices">
      <div class="panel">
        <div class="panel-header">
          <h2 class="panel-title">Pregled Naprav in Telemetrija Uporabnikov</h2>
          <div style="display:flex; gap:10px; align-items:center; flex-wrap:wrap;">
            <label style="font-size:12px; color:var(--text-muted); cursor:pointer; display:flex; align-items:center; gap:6px;">
              <input type="checkbox" id="filter-online-only" onchange="renderDevicesTable()"> Samo Online
            </label>
            <input type="text" class="search-input" id="search-devices" placeholder="Išči model, OS, IP ali ID..." oninput="renderDevicesTable()">
          </div>
        </div>

        <div style="overflow-x:auto;">
          <table>
            <thead>
              <tr>
                <th>Platforma in Model</th>
                <th>ID Naprave</th>
                <th>App Verzija</th>
                <th>Trenutni Zaslon v Živo</th>
                <th>Status / Zadnja Aktivnost</th>
                <th>IP Naslov</th>
                <th>Akcija</th>
              </tr>
            </thead>
            <tbody id="devices-tbody">
              <tr><td colspan="7" style="text-align:center; color:var(--text-muted);">Nalaganje naprav...</td></tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <!-- ZAVIHEK 4: PIVSKA KLAPA (SOBE IN KLEPET) -->
    <div class="tab-pane" id="tab-squad">
      <div class="panel">
        <div class="panel-header">
          <h2 class="panel-title">Aktivne Pivske Klape (Sobe in Povezani Prijatelji)</h2>
          <input type="text" class="search-input" id="search-rooms" placeholder="Išči sobo po kodi ali imenu..." oninput="renderRoomsCards()">
        </div>
        <div id="rooms-cards-grid" style="display:grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap:14px;">
          <!-- Kartice sob -->
        </div>
      </div>
    </div>

    <!-- ZAVIHEK 5: KONFIGURACIJA IN ŠANK TEDNA -->
    <div class="tab-pane" id="tab-config">
      <div class="grid-2">
        <!-- MOTD -->
        <div class="panel">
          <div class="panel-header">
            <h2 class="panel-title">Sporočilo Dneva (MOTD - Message of the Day)</h2>
          </div>
          <div id="motd-active-box" style="margin-bottom:14px; padding:10px 14px; background:rgba(16,185,129,0.08); border:1px solid rgba(16,185,129,0.3); border-radius:8px; font-size:12.5px;">
            <div style="font-weight:700; color:#10b981; margin-bottom:3px; text-transform:uppercase; font-size:11px; letter-spacing:0.5px;">Trenutno aktivno sporočilo dneva:</div>
            <div id="motd-active-text" style="color:var(--text); font-style:italic;">Nalaganje...</div>
          </div>
          <div class="form-group">
            <label>Besedilo Sporočila ob Zagonu</label>
            <textarea class="form-control" id="config-motd" placeholder="Npr. Dobrodošli v posodobljeni različici ŠankFinderja!"></textarea>
          </div>
          <div style="display:flex; align-items:center; gap:12px;">
            <button class="btn btn-green" onclick="saveMotd()">Shrani in Oddaj MOTD</button>
            <span id="motd-save-status" style="font-size:12px; font-weight:700; color:#10b981; display:none;">Shranjeno in oddano na telefone!</span>
          </div>
        </div>

        <!-- Šank Tedna -->
        <div class="panel">
          <div class="panel-header">
            <h2 class="panel-title">Nastavitev Šanka Tedna (Featured Bar)</h2>
          </div>
          <div id="feat-active-box" style="margin-bottom:14px; padding:10px 14px; background:rgba(245,158,11,0.08); border:1px solid rgba(245,158,11,0.3); border-radius:8px; font-size:12.5px;">
            <div style="font-weight:700; color:#f59e0b; margin-bottom:3px; text-transform:uppercase; font-size:11px; letter-spacing:0.5px;">Trenutno aktiven šank tedna:</div>
            <div id="feat-active-text" style="color:var(--text); font-weight:600;">Nalaganje...</div>
          </div>
          <div class="form-group">
            <label>Ime Lokala</label>
            <input type="text" class="form-control" id="feat-name" placeholder="Npr. Pivnica Union">
          </div>
          <div class="form-group">
            <label>Naslov</label>
            <input type="text" class="form-control" id="feat-address" placeholder="Npr. Celovška cesta 22, Ljubljana">
          </div>
          <div class="grid-2" style="gap:10px;">
            <div class="form-group">
              <label>Zemljepisna Širina (lat)</label>
              <input type="text" class="form-control mono" id="feat-lat" placeholder="46.0605">
            </div>
            <div class="form-group">
              <label>Zemljepisna Dolžina (lon)</label>
              <input type="text" class="form-control mono" id="feat-lon" placeholder="14.5022">
            </div>
          </div>
          <div class="form-group">
            <label>Posebna Akcija / Opomba</label>
            <input type="text" class="form-control" id="feat-note" placeholder="Npr. Ob naročilu piva brezplačni prigrizek!">
          </div>
          <div style="display:flex; align-items:center; gap:12px;">
            <button class="btn" style="background:#f59e0b; color:#000; font-weight:700;" onclick="saveFeaturedPub()">Shrani Šank Tedna</button>
            <span id="feat-save-status" style="font-size:12px; font-weight:700; color:#10b981; display:none;">Shranjeno in prikazano na radarju!</span>
          </div>
        </div>
      </div>

      <!-- UPRAVLJANJE RAZLIČIC APLIKACIJE -->
      <div class="panel" style="margin-top:20px; border-color:rgba(59,130,246,0.3);">
        <div class="panel-header">
          <h2 class="panel-title" style="color:#60a5fa;">Nadzor Različic Mobilnih Aplikacij (Android / iOS)</h2>
        </div>
        <div style="font-size:13px; color:var(--text-muted); margin-bottom:14px;">
          Aplikacije ob zagonu in v nastavitvah preverijo te verzije. Če ima uporabnik starejšo, se mu v nastavitvah prikaže opozorilo.
        </div>
        <div class="grid-2">
          <div class="form-group">
            <label>Zadnja Uradna Različica (Android)</label>
            <input type="text" class="form-control mono" id="config-ver-android" placeholder="1.2.0">
          </div>
          <div class="form-group">
            <label>Zadnja Uradna Različica (iOS / Apple)</label>
            <input type="text" class="form-control mono" id="config-ver-ios" placeholder="1.2.0">
          </div>
          <div class="form-group">
            <label>Minimalna Podprta Različica</label>
            <input type="text" class="form-control mono" id="config-min-version" placeholder="1.0.0">
          </div>
          <div class="form-group">
            <label>Opombe ob Posodobitvi (Sporočilo v nastavitvah)</label>
            <input type="text" class="form-control" id="config-ver-notes" placeholder="Na voljo je posodobitev z izboljšano varnostjo in novimi funkcijami.">
          </div>
        </div>
        <div style="display:flex; align-items:center; gap:12px; margin-top:8px;">
          <button class="btn btn-green" onclick="saveVersions()">Shrani Nastavitve Različic</button>
          <span id="version-save-status" style="font-size:12px; font-weight:700; color:#10b981; display:none;">Nastavitve različic uspešno shranjene in oddane napravam!</span>
        </div>
      </div>
    </div>

  </div>

  <!-- MODALNO OKNO ZA KLEPET SOBE IN ČLANE -->
  <div class="modal-overlay" id="chat-modal">
    <div class="modal">
      <div class="modal-head">
        <div style="display:flex; align-items:center; gap:8px;">
          <span class="code-badge" id="modal-room-code">XXXX</span>
          <h3 style="font-size:15px; font-weight:800;" id="modal-room-name">Ime Sobe</h3>
        </div>
        <button class="btn btn-red btn-sm" onclick="closeChatModal()">Zapri</button>
      </div>

      <div class="modal-body">
        <!-- LEVO: SPOROČILA -->
        <div class="modal-chat-pane">
          <div class="modal-messages" id="modal-messages-list">
            <div style="text-align:center; color:var(--text-muted); font-size:12px;">Nalaganje sporočil...</div>
          </div>
          <div class="modal-foot">
            <input type="text" class="form-control" id="modal-admin-msg-input" placeholder="Pošlji kot Uprava..." onkeydown="if(event.key==='Enter') sendAdminMessage()">
            <button class="btn btn-green btn-sm" onclick="sendAdminMessage()">Pošlji</button>
          </div>
        </div>

        <!-- DESNO: ČLANI Z MOŽNOSTJO POPRAVKA PIJAČ -->
        <div class="modal-members-pane">
          <div style="font-size:11px; font-weight:800; color:var(--text-muted); text-transform:uppercase; margin-bottom:4px;">
            Člani in Števci Pijač:
          </div>
          <div id="modal-members-list" style="display:flex; flex-direction:column; gap:6px;">
            <!-- Člani -->
          </div>

          <div style="margin-top:auto; padding-top:10px; border-top:1px solid var(--border);">
            <button class="btn btn-red btn-sm" style="width:100%; justify-content:center;" onclick="deleteCurrentRoom()">
              Zapri in izbriši sobo
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>

  <!-- JAVASCRIPT LOGIKA NADZORNEGA CENTRA -->
  <script>
    let globalData = null;
    let currentTab = 'overview';
    let currentModalRoom = null;
    let refreshSeconds = 5;
    let osrmHistory = [24, 18, 32, 28, 20, 22, 19, 25, 21, 23];

    // Leaflet zemljevid
    let radarMap = null;
    let radarMarkersGroup = null;

    function initRadarMap() {
      if (radarMap) return;
      const el = document.getElementById('live-radar-map');
      if (!el) return;

      radarMap = L.map('live-radar-map', {
        zoomControl: false
      }).setView([46.0569, 14.5058], 13); // Ljubljana

      L.control.zoom({ position: 'bottomright' }).addTo(radarMap);

      // Popolnoma brezplačne OpenStreetMap ploščice (brez API ključa) z elegantnim temnim filtrom
      L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '&copy; OpenStreetMap contributors',
        maxZoom: 19
      }).addTo(radarMap);

      radarMarkersGroup = L.layerGroup().addTo(radarMap);
    }

    function centerOnLjubljana() {
      if (radarMap) radarMap.flyTo([46.0569, 14.5058], 13);
    }

    function fitRadarBounds() {
      if (!radarMap || !radarMarkersGroup) return;
      const layers = radarMarkersGroup.getLayers();
      if (layers.length > 0) {
        const group = L.featureGroup(layers);
        radarMap.fitBounds(group.getBounds().pad(0.2));
      } else {
        centerOnLjubljana();
      }
    }

    function updateRadarMap(members, featuredPub) {
      initRadarMap();
      if (!radarMap || !radarMarkersGroup) return;

      radarMarkersGroup.clearLayers();
      const points = [];

      // 1. Člani aktivnih sob
      if (Array.isArray(members)) {
        members.forEach(m => {
          if (typeof m.lat === 'number' && typeof m.lon === 'number' && !isNaN(m.lat) && !isNaN(m.lon)) {
            const pos = [m.lat, m.lon];
            points.push(pos);
            const initial = (m.name || 'P')[0].toUpperCase();
            const drinks = m.drinks_count || 0;

            const icon = L.divIcon({
              className: 'custom-radar-icon',
              html: \`
                <div class="radar-pin-wrap">
                  <div class="radar-pulse"></div>
                  <div class="radar-pin">
                    <span>\${initial}</span>
                    <div class="radar-drinks-pill">\${drinks}</div>
                  </div>
                </div>
              \`,
              iconSize: [36, 36],
              iconAnchor: [18, 18],
              popupAnchor: [0, -18]
            });

            const popup = \`
              <div style="font-family:'Plus Jakarta Sans',sans-serif; color:#f8fafc; min-width:180px;">
                <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:4px;">
                  <strong style="color:#f59e0b; font-size:13px;">\${escapeHtml(m.name)}</strong>
                  <span class="code-badge">\${escapeHtml(m.room_code)}</span>
                </div>
                <div style="font-size:11.5px; color:#cbd5e1; margin-bottom:4px;">
                  Pijače: <b style="color:#f59e0b;">\${drinks}</b>
                </div>
                <div style="font-size:10.5px; color:#64748b; font-family:'JetBrains Mono',monospace;">
                  \${m.lat.toFixed(5)}, \${m.lon.toFixed(5)}
                </div>
              </div>
            \`;

            L.marker(pos, { icon }).bindPopup(popup).addTo(radarMarkersGroup);
          }
        });
      }

      // 2. Šank Tedna
      if (featuredPub && featuredPub.lat && featuredPub.lon) {
        const pLat = parseFloat(featuredPub.lat);
        const pLon = parseFloat(featuredPub.lon);
        if (!isNaN(pLat) && !isNaN(pLon)) {
          points.push([pLat, pLon]);
          const starIcon = L.divIcon({
            className: 'custom-radar-icon',
            html: \`
              <div style="position:relative; width:34px; height:34px; display:flex; align-items:center; justify-content:center;">
                <div style="position:absolute; width:34px; height:34px; border-radius:50%; background:rgba(16,185,129,0.3); animation:pinPulse 2s infinite;"></div>
                <div style="width:26px; height:26px; border-radius:50%; background:#10b981; border:2px solid #fff; display:flex; align-items:center; justify-content:center; box-shadow:0 0 10px rgba(16,185,129,0.7); font-size:10px; font-weight:800; color:#000;">
                  TOP
                </div>
              </div>
            \`,
            iconSize: [34, 34],
            iconAnchor: [17, 17]
          });

          const starPopup = \`
            <div style="font-family:'Plus Jakarta Sans',sans-serif; color:#f8fafc; min-width:190px;">
              <div style="font-size:10px; font-weight:800; color:#10b981; text-transform:uppercase;">Šank Tedna</div>
              <div style="font-size:14px; font-weight:800; margin:2px 0;">\${escapeHtml(featuredPub.name || 'Izbrani lokal')}</div>
              <div style="font-size:11.5px; color:#94a3b8;">\${escapeHtml(featuredPub.address || '')}</div>
              \${featuredPub.note ? \`<div style="margin-top:6px; padding:4px 8px; background:rgba(16,185,129,0.1); border-left:3px solid #10b981; font-size:11px; color:#34d399;">\${escapeHtml(featuredPub.note)}</div>\` : ''}
            </div>
          \`;

          L.marker([pLat, pLon], { icon: starIcon }).bindPopup(starPopup).addTo(radarMarkersGroup);
        }
      }

      const countEl = document.getElementById('radar-live-count');
      if (countEl) countEl.innerText = \`\${points.length} \${points.length === 1 ? 'uporabnik' : 'uporabnikov'} na zemljevidu\`;
    }

    // ZAVIHKI
    function switchTab(tabId) {
      currentTab = tabId;
      document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
      document.querySelectorAll('.tab-pane').forEach(p => p.classList.remove('active'));

      const pane = document.getElementById('tab-' + tabId);
      if (pane) pane.classList.add('active');

      const btn = Array.from(document.querySelectorAll('.tab-btn')).find(b => b.getAttribute('onclick').includes(tabId));
      if (btn) btn.classList.add('active');

      if (tabId === 'overview') {
        setTimeout(() => { if (radarMap) radarMap.invalidateSize(); }, 100);
      }
    }

    // PRIDOBIVANJE PODATKOV
    async function fetchData() {
      try {
        refreshSeconds = 5;
        const res = await fetch('/api/admin/data');
        if (res.status === 401 || res.status === 429) {
          window.location.reload();
          return;
        }
        globalData = await res.json();
        renderOverview();
        renderPushHistory();
        renderDevicesTable();
        renderRoomsCards();
        renderConfig();
      } catch (err) {
        console.error('Napaka pri osveževanju podatkov:', err);
      }
    }

    function renderOverview() {
      if (!globalData || !globalData.overview) return;
      const o = globalData.overview;

      document.getElementById('stat-online-devices').innerText = o.onlineAppDevicesCount || 0;
      document.getElementById('stat-ios-count').innerText = o.iosOnlineCount || 0;
      document.getElementById('stat-android-count').innerText = o.androidOnlineCount || 0;
      document.getElementById('stat-total-devices').innerText = o.totalKnownDevicesCount || 0;
      document.getElementById('stat-today-devices').innerText = \`+\${o.todayNewDevicesCount || 0} danes\`;
      document.getElementById('stat-push-sent').innerText = o.totalPushSentCount || 0;
      document.getElementById('stat-last-push').innerText = o.lastPushSentAt ? \`Zadnje: \${formatTime(o.lastPushSentAt)}\` : 'Zadnje: /';
      document.getElementById('stat-rooms').innerText = o.activeRoomsCount || 0;
      document.getElementById('stat-active-members-count').innerText = o.totalMembers || 0;
      document.getElementById('stat-drinks').innerText = o.totalDrinks || 0;

      if (o.topDrinker) {
        document.getElementById('stat-top-drinker').innerHTML = \`Top: <b style="color:var(--gold);">\${escapeHtml(o.topDrinker.name)}</b> (\${o.topDrinker.drinksCount} piv)\`;
      } else {
        document.getElementById('stat-top-drinker').innerText = 'Top pivec: /';
      }

      // Uptime
      const up = o.uptimeSeconds || 0;
      const d = Math.floor(up / 86400);
      const h = Math.floor((up % 86400) / 3600);
      const m = Math.floor((up % 3600) / 60);
      document.getElementById('server-uptime').innerText = \`Uptime: \${d}d \${h}h \${m}m\`;

      // Telemetrija gateway in baza
      document.getElementById('gateway-telemetry').innerHTML = \`<span style="color:var(--green); font-weight:700;">RAM: \${o.memoryRssMb || 0} MB • \${o.openWebSockets || 0} WS</span>\`;
      
      const dbBytes = o.dbSizeBytes || 0;
      const dbStr = dbBytes >= 1048576 
        ? ((dbBytes / 1048576).toFixed(2) + ' MB') 
        : (Math.round(dbBytes / 1024) + ' KB');
      const walKb = Math.round((o.walSizeBytes || 0) / 1024);
      document.getElementById('db-file-sizes').innerText = \`data/squad.db (\${dbStr} • WAL: \${walKb} KB)\`;

      // Preveri zastarele naprave za opozorilno vrstico
      const latestIos = (globalData.settings && globalData.settings.latest_version_ios) || '1.2.0';
      const latestAndroid = (globalData.settings && globalData.settings.latest_version_android) || '1.2.0';
      const allDevs = globalData.allDevices || [];
      const outdatedDevices = allDevs.filter(d => {
        const model = (d.model || '').toLowerCase();
        const os = (d.os_version || d.osVersion || '').toLowerCase();
        const isIos = model.includes('ios') || model.includes('iphone') || os.includes('ios');
        const target = isIos ? latestIos : latestAndroid;
        const ver = (d.app_version || d.appVersion || '1.0');
        return isVersionOlder(ver, target);
      });
      const banner = document.getElementById('version-warning-banner');
      const bannerText = document.getElementById('outdated-count-text');
      if (banner && bannerText) {
        if (outdatedDevices.length > 0) {
          banner.style.display = 'flex';
          bannerText.innerText = \`Zaznanih je \${outdatedDevices.length} naprav z zastarelo različico aplikacije (Android uradna: v\${latestAndroid}, iOS uradna: v\${latestIos}).\`;
        } else {
          banner.style.display = 'none';
        }
      }

      // Značke na zavihkih
      document.getElementById('badge-push').innerText = o.totalPushSentCount || 0;
      document.getElementById('badge-devices').innerText = o.onlineAppDevicesCount || 0;
      document.getElementById('badge-rooms').innerText = o.activeRoomsCount || 0;

      // Posodobi Live Radar zemljevid
      let featuredPub = null;
      try {
        if (globalData.settings && globalData.settings.featured_pub) {
          featuredPub = JSON.parse(globalData.settings.featured_pub);
        }
      } catch (e) {}

      updateRadarMap(globalData.liveRadarMembers || [], featuredPub);
    }

    // OSRM PING & SPARKLINE
    async function testOsrm() {
      const statusEl = document.getElementById('stat-osrm');
      const tableStatusEl = document.getElementById('osrm-service-status');
      try {
        const res = await fetch('/api/admin/osrm/ping');
        const data = await res.json();
        if (data.status === 'online') {
          const lat = data.latencyMs;
          statusEl.innerText = \`\${lat} ms\`;
          let col = 'var(--green)';
          if (lat > 300) col = 'var(--red)';
          else if (lat > 100) col = 'var(--gold)';
          statusEl.style.color = col;

          if (tableStatusEl) tableStatusEl.innerHTML = \`<span style="color:\${col}; font-weight:700;">Deluje (\${lat} ms)</span>\`;

          osrmHistory.push(lat);
          if (osrmHistory.length > 10) osrmHistory.shift();
          renderSparkline();
        } else {
          statusEl.innerText = 'Nedosegljiv';
          statusEl.style.color = 'var(--red)';
          if (tableStatusEl) tableStatusEl.innerHTML = \`<span style="color:var(--red); font-weight:700;">Napaka</span>\`;
        }
      } catch (e) {
        statusEl.innerText = 'Offline';
        statusEl.style.color = 'var(--red)';
      }
    }

    function renderSparkline() {
      const wrap = document.getElementById('osrm-sparkline');
      if (!wrap) return;
      const max = Math.max(...osrmHistory, 50);
      wrap.innerHTML = osrmHistory.map(ms => {
        const pct = Math.max(15, Math.min(100, Math.round((ms / max) * 100)));
        let bg = 'var(--green)';
        if (ms > 300) bg = 'var(--red)';
        else if (ms > 100) bg = 'var(--gold)';
        return \`<div class="spark-bar" style="height:\${pct}%; background:\${bg};" title="\${ms} ms"></div>\`;
      }).join('');
    }

    // HITRI DIAGNOSTIČNI TEST
    async function runDiagnostics() {
      const box = document.getElementById('diagnostics-box');
      const det = document.getElementById('diag-details');
      box.style.display = 'block';
      det.innerHTML = 'Izvajam meritve odzivnosti OSRM in Geoapify strežnikov...';

      try {
        const res = await fetch('/api/admin/diagnostics');
        const d = await res.json();
        const diag = d.diagnostics;

        det.innerHTML = \`
          <div style="display:flex; justify-content:space-between; margin-bottom:4px;">
            <span>1. OSRM Slovenija (Lokalni):</span>
            <b style="color:\${diag.osrmPrimary.status === 'online' ? 'var(--green)' : 'var(--red)'};">\${diag.osrmPrimary.latencyMs} ms (\${diag.osrmPrimary.status})</b>
          </div>
          <div style="display:flex; justify-content:space-between; margin-bottom:4px;">
            <span>2. OSRM Fallback (OSM Nemčija):</span>
            <b style="color:\${diag.osrmFallback.status === 'online' ? 'var(--green)' : 'var(--red)'};">\${diag.osrmFallback.latencyMs} ms (\${diag.osrmFallback.status})</b>
          </div>
          <div style="display:flex; justify-content:space-between;">
            <span>3. Geoapify Places API:</span>
            <b style="color:\${diag.geoapify.status === 'online' ? 'var(--green)' : 'var(--red)'};">\${diag.geoapify.latencyMs} ms (\${diag.geoapify.status})</b>
          </div>
        \`;

        const fbStatus = document.getElementById('osrm-fallback-status');
        if (fbStatus && diag.osrmFallback.status === 'online') {
          fbStatus.innerHTML = \`<span style="color:var(--green); font-weight:700;">Deluje (\${diag.osrmFallback.latencyMs} ms)</span>\`;
        }
      } catch (err) {
        det.innerText = 'Napaka pri izvedbi diagnostike: ' + err.message;
      }
    }

    // PREDLOGE IN PREDOGLED
    function applyTemplate(type) {
      const titleInput = document.getElementById('quick-push-title');
      const msgInput = document.getElementById('quick-push-msg');

      if (type === 'happy_hour') {
        titleInput.value = 'Petkov Happy Hour v Ljubljani!';
        msgInput.value = 'Petek je tu! Šanki se polnijo, odpri zemljevid in preveri, kje se zbira tvoja klapa!';
      } else if (type === 'burek') {
        titleInput.value = 'Čas za Burek Pavzo?';
        msgInput.value = 'Pivski večer se preveša v noč. Odpri orodje Burek Pavza za seznam odprtih pekarn!';
      } else if (type === 'update') {
        titleInput.value = 'Nova posodobitev ŠankFinderja';
        msgInput.value = 'Na voljo je sveža posodobitev aplikacije z izboljšanim radarjem in vodenjem v smeri hoje.';
      } else if (type === 'uprava') {
        titleInput.value = 'Sporočilo ŠankFinder Uprave';
        msgInput.value = 'Preveri nov Šank Tedna v zavihku Šanki in se pridruži zabavi!';
      }
      updateLivePreview();
    }

    function onTargetChange() {
      const val = document.getElementById('quick-push-target').value;
      const roomGroup = document.getElementById('group-room-code');
      if (val === 'room') {
        roomGroup.style.display = 'block';
      } else {
        roomGroup.style.display = 'none';
      }
    }

    function updateLivePreview() {
      const t = document.getElementById('quick-push-title').value.trim() || 'Naslov obvestila bo tukaj...';
      const b = document.getElementById('quick-push-msg').value.trim() || 'Besedilo potisnega obvestila, kot ga bo videl uporabnik na telefonu.';
      document.getElementById('preview-title').innerText = t;
      document.getElementById('preview-body').innerText = b;

      const now = new Date();
      const hh = String(now.getHours()).padStart(2, '0');
      const mm = String(now.getMinutes()).padStart(2, '0');
      document.getElementById('preview-clock').innerText = \`\${hh}:\${mm}\`;
    }

    // POŠILJANJE PUSH OBVESTILA
    async function sendQuickPush(targetOverride) {
      let target = targetOverride;
      if (!target) {
        const sel = document.getElementById('quick-push-target').value;
        if (sel === 'room') {
          const code = (document.getElementById('quick-push-room-code').value || '').trim().toUpperCase();
          if (!code) { alert('Vnesite kodo sobe!'); return; }
          target = \`room:\${code}\`;
        } else {
          target = sel;
        }
      }

      const title = document.getElementById('quick-push-title').value.trim();
      const message = document.getElementById('quick-push-msg').value.trim();
      if (!message) { alert('Vnesite besedilo sporočila!'); return; }

      try {
        const res = await fetch('/api/admin/push/send', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ title, message, target })
        });
        const d = await res.json();
        if (d.success) {
          alert(d.message);
          document.getElementById('quick-push-title').value = '';
          document.getElementById('quick-push-msg').value = '';
          updateLivePreview();
          fetchData();
        } else {
          alert('Napaka: ' + (d.error || 'Neznana napaka'));
        }
      } catch (err) {
        alert('Napaka pri pošiljanju: ' + err.message);
      }
    }

    // ZGODOVINA PUSH OBVESTIL
    function renderPushHistory() {
      const tbody = document.getElementById('push-history-tbody');
      if (!globalData || !globalData.pushHistory) return;

      const list = globalData.pushHistory;
      document.getElementById('push-history-count').innerText = \`\${list.length} obvestil\`;

      if (list.length === 0) {
        tbody.innerHTML = '<tr><td colspan="6" style="text-align:center; color:var(--text-muted);">Ni še poslanih obvestil.</td></tr>';
        return;
      }

      tbody.innerHTML = list.map(item => \`
        <tr>
          <td class="mono">#\${item.id}</td>
          <td>
            <strong>\${escapeHtml(item.title)}</strong>
            <div style="color:var(--text-muted); font-size:12px; margin-top:2px;">\${escapeHtml(item.message)}</div>
          </td>
          <td><span class="code-badge">\${escapeHtml(item.target || 'all')}</span></td>
          <td><span style="color:var(--green); font-weight:700;">\${item.sent_count || 0} naprav</span></td>
          <td style="color:var(--text-muted); font-size:11.5px;">\${formatTime(item.created_at)}</td>
          <td>
            <div style="display:flex; gap:6px;">
              <button class="btn btn-sm btn-blue" onclick="reusePush('\${escapeJs(item.title)}', '\${escapeJs(item.message)}')">Uporabi</button>
              <button class="btn btn-sm btn-red" onclick="deletePush(\${item.id})">Izbriši</button>
            </div>
          </td>
        </tr>
      \`).join('');
    }

    function reusePush(title, message) {
      switchTab('overview');
      document.getElementById('quick-push-title').value = title;
      document.getElementById('quick-push-msg').value = message;
      updateLivePreview();
      window.scrollTo({ top: 400, behavior: 'smooth' });
    }

    async function deletePush(id) {
      if (!confirm(\`Ali res želite izbrisati obvestilo #\${id} iz zgodovine?\`)) return;
      try {
        const res = await fetch('/api/admin/push/delete', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ id })
        });
        const d = await res.json();
        if (d.success) fetchData();
      } catch (e) {
        alert('Napaka pri brisanju: ' + e.message);
      }
    }

    // NAPRAVE V ŽIVO
    function renderDevicesTable() {
      const tbody = document.getElementById('devices-tbody');
      if (!globalData) return;

      const onlineOnly = document.getElementById('filter-online-only').checked;
      const query = (document.getElementById('search-devices').value || '').toLowerCase();

      const liveMap = new Map();
      (globalData.liveDevices || []).forEach(d => liveMap.set(d.deviceId, d));

      let devices = onlineOnly ? (globalData.liveDevices || []) : (globalData.allDevices || []);

      if (query) {
        devices = devices.filter(d => {
          const s = \`\${d.device_id || d.deviceId || ''} \${d.model || ''} \${d.os_version || d.osVersion || ''} \${d.ip || ''} \${d.current_screen || d.currentScreen || ''}\`.toLowerCase();
          return s.includes(query);
        });
      }

      if (devices.length === 0) {
        tbody.innerHTML = '<tr><td colspan="7" style="text-align:center; color:var(--text-muted);">Ni naprav, ki ustrezajo kriterijem.</td></tr>';
        return;
      }

      tbody.innerHTML = devices.map(d => {
        const devId = d.device_id || d.deviceId;
        const isOnline = liveMap.has(devId);
        const liveDev = liveMap.get(devId);
        const model = d.model || 'Neznan model';
        const os = d.os_version || d.osVersion || 'Neznan OS';
        const isIos = (model + ' ' + os).toLowerCase().includes('ios') || (model + ' ' + os).toLowerCase().includes('iphone');
        const latestTarget = isIos ? (globalData.settings?.latest_version_ios || '1.2.1') : (globalData.settings?.latest_version_android || '1.2.1');
        const appVer = (liveDev && liveDev.appVersion) ? liveDev.appVersion : (d.app_version || d.appVersion || '1.0');
        const screen = (liveDev ? liveDev.currentScreen : d.current_screen) || 'Zemljevid & Šanki';
        const ip = d.ip || 'unknown';
        const lastSeen = d.last_seen || d.lastSeen;

        const platformBadge = isIos ? '<span class="badge-tag" style="background:rgba(59,130,246,0.15); color:#60a5fa;">iOS</span>' : '<span class="badge-tag" style="background:rgba(16,185,129,0.15); color:#34d399;">Android</span>';

        const isOld = isVersionOlder(appVer, latestTarget);
        const versionBadge = isOld
          ? ('<span class="badge-tag" style="background:var(--red-bg); color:var(--red); border-color:rgba(239,68,68,0.4);" title="Zastarela različica! Zadnja uradna je v' + latestTarget + '">v' + escapeHtml(appVer) + ' (Zastarela)</span>')
          : ('<span class="badge-tag" style="background:var(--green-bg); color:var(--green); border-color:rgba(16,185,129,0.3);">v' + escapeHtml(appVer) + ' (Zadnja)</span>');

        let screenColor = 'var(--blue)';
        if (screen.includes('Zemljevid') || screen.includes('Šank')) screenColor = 'var(--green)';
        else if (screen.includes('Klapa') || screen.includes('Pivska')) screenColor = 'var(--gold)';
        else if (screen.includes('Zgodovina')) screenColor = 'var(--purple)';

        return \`
          <tr>
            <td>
              \${platformBadge}
              <strong style="margin-left:4px;">\${escapeHtml(model)}</strong>
              <div style="font-size:11px; color:var(--text-muted);">\${escapeHtml(os)}</div>
            </td>
            <td class="mono" style="font-size:11px;" title="\${devId}">
              \${devId.length > 18 ? devId.substring(0, 18) + '...' : devId}
            </td>
            <td>\${versionBadge}</td>
            <td>
              <span class="badge-tag" style="background:rgba(255,255,255,0.05); color:\${screenColor}; border-color:\${screenColor};">
                \${escapeHtml(screen)}
              </span>
            </td>
            <td>
              \${isOnline ? \`
                <span class="status-badge" style="font-size:11px; padding:2px 8px;">
                  <span class="pulse-dot"></span> Online
                </span>
              \` : \`
                <span style="color:var(--text-muted); font-size:11.5px;">\${formatTime(lastSeen)}</span>
              \`}
            </td>
            <td class="mono" style="font-size:11.5px; color:var(--text-muted);">\${escapeHtml(ip)}</td>
            <td>
              <button class="btn btn-sm btn-blue" onclick="sendDirectPushPrompt('\${devId}')">
                Osebni Push
              </button>
            </td>
          </tr>
        \`;
      }).join('');
    }

    function sendDirectPushPrompt(devId) {
      const msg = prompt('Vnesite vsebino sporočila za to napravo:');
      if (msg && msg.trim()) {
        document.getElementById('quick-push-title').value = 'Osebno sporočilo Uprave';
        document.getElementById('quick-push-msg').value = msg.trim();
        sendQuickPush(\`device:\${devId}\`);
      }
    }

    // PIVSKA KLAPA SOBE
    function renderRoomsCards() {
      const grid = document.getElementById('rooms-cards-grid');
      if (!globalData || !globalData.rooms) return;

      const q = (document.getElementById('search-rooms').value || '').toLowerCase();
      let rooms = globalData.rooms;

      if (q) {
        rooms = rooms.filter(r => (r.code + ' ' + (r.name || '')).toLowerCase().includes(q));
      }

      if (rooms.length === 0) {
        grid.innerHTML = '<div style="color:var(--text-muted); grid-column:1/-1; text-align:center; padding:20px;">Ni aktivnih sob.</div>';
        return;
      }

      grid.innerHTML = rooms.map(r => {
        const membersOfRoom = (globalData.members || []).filter(m => m.room_code === r.code);
        const roomDrinks = membersOfRoom.reduce((acc, m) => acc + (m.drinks_count || 0), 0);

        return \`
          <div class="stat-card" style="display:flex; flex-direction:column; justify-content:space-between; gap:10px;">
            <div>
              <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:6px;">
                <span class="code-badge" style="font-size:14px; padding:3px 8px;">\${r.code}</span>
                <span style="font-size:11.5px; color:var(--text-muted);">\${formatTime(r.created_at)}</span>
              </div>
              <h3 style="font-size:16px; font-weight:800; color:var(--text);">\${escapeHtml(r.name || 'Pivska Klapa')}</h3>
              <div style="margin-top:8px; font-size:12.5px; color:var(--text-muted); display:flex; gap:12px;">
                <span>Člani: <b>\${membersOfRoom.length}</b></span>
                <span>Pijače: <b>\${roomDrinks}</b></span>
              </div>
            </div>

            <div style="display:flex; gap:8px; margin-top:10px;">
              <button class="btn btn-sm btn-blue" style="flex:1; justify-content:center;" onclick="openChatModal('\${r.code}', '\${escapeJs(r.name)}')">
                Klepet in Člani
              </button>
            </div>
          </div>
        \`;
      }).join('');
    }

    // MODAL ZA KLEPET IN ČLANE
    async function openChatModal(code, name) {
      currentModalRoom = code;
      document.getElementById('modal-room-code').innerText = code;
      document.getElementById('modal-room-name').innerText = name || 'Pivska Klapa';
      document.getElementById('chat-modal').style.display = 'flex';
      await loadRoomChat(code);
    }

    function closeChatModal() {
      document.getElementById('chat-modal').style.display = 'none';
      currentModalRoom = null;
    }

    async function loadRoomChat(code) {
      try {
        const res = await fetch(\`/api/admin/room/messages?code=\${code}\`);
        const d = await res.json();
        if (d.success) {
          renderModalMessages(d.messages);
          renderModalMembers(d.members, code);
        }
      } catch (e) {
        console.error('Napaka pri nalaganju klepeta:', e);
      }
    }

    function renderModalMessages(msgs) {
      const box = document.getElementById('modal-messages-list');
      if (!msgs || msgs.length === 0) {
        box.innerHTML = '<div style="text-align:center; color:var(--text-muted); padding:20px; font-size:12px;">V tej sobi še ni sporočil.</div>';
        return;
      }
      box.innerHTML = msgs.map(m => \`
        <div class="msg-bubble">
          <div>
            <div class="msg-sender">\${escapeHtml(m.sender_name)}</div>
            <div class="msg-text">\${escapeHtml(m.content)}</div>
          </div>
          <button class="btn btn-sm btn-red" style="padding:2px 6px; font-size:10px;" onclick="deleteMessage(\${m.id})">Izbriši</button>
        </div>
      \`).join('');
      box.scrollTop = box.scrollHeight;
    }

    function renderModalMembers(members, code) {
      const box = document.getElementById('modal-members-list');
      if (!members || members.length === 0) {
        box.innerHTML = '<div style="color:var(--text-muted); font-size:12px;">Ni prijavljenih članov.</div>';
        return;
      }
      box.innerHTML = members.map(m => \`
        <div style="background:#131c2d; padding:8px 10px; border-radius:8px; border:1px solid var(--border); display:flex; justify-content:space-between; align-items:center;">
          <div>
            <div style="font-weight:700; font-size:12.5px; color:#f8fafc;">\${escapeHtml(m.name)}</div>
            <div style="font-size:10.5px; color:var(--text-muted); font-family:'JetBrains Mono',monospace;">
              \${m.lat ? \`\${m.lat.toFixed(4)}, \${m.lon.toFixed(4)}\` : 'brez GPS'}
            </div>
          </div>
          <div style="display:flex; align-items:center; gap:6px;">
            <button class="btn btn-sm btn-red" style="padding:2px 7px;" onclick="changeDrinks('\${m.id}', '\${code}', -1)">-</button>
            <span class="mono" style="font-weight:800; color:var(--gold); font-size:13px; min-width:18px; text-align:center;">\${m.drinks_count || 0}</span>
            <button class="btn btn-sm btn-green" style="padding:2px 7px;" onclick="changeDrinks('\${m.id}', '\${code}', 1)">+</button>
          </div>
        </div>
      \`).join('');
    }

    async function changeDrinks(memberId, roomCode, delta) {
      try {
        const res = await fetch('/api/admin/member/drinks', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ memberId, roomCode, delta })
        });
        const d = await res.json();
        if (d.success) {
          loadRoomChat(roomCode);
          fetchData();
        }
      } catch (e) {
        alert('Napaka: ' + e.message);
      }
    }

    async function sendAdminMessage() {
      const input = document.getElementById('modal-admin-msg-input');
      const content = input.value.trim();
      if (!content || !currentModalRoom) return;

      try {
        const res = await fetch('/api/admin/message/send', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ code: currentModalRoom, content })
        });
        const d = await res.json();
        if (d.success) {
          input.value = '';
          loadRoomChat(currentModalRoom);
        }
      } catch (e) {
        alert('Napaka pri pošiljanju: ' + e.message);
      }
    }

    async function deleteMessage(id) {
      if (!confirm('Ali res želite izbrisati to sporočilo?')) return;
      try {
        const res = await fetch('/api/admin/message/delete', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ id })
        });
        const d = await res.json();
        if (d.success && currentModalRoom) {
          loadRoomChat(currentModalRoom);
        }
      } catch (e) {
        alert('Napaka: ' + e.message);
      }
    }

    async function deleteCurrentRoom() {
      if (!currentModalRoom) return;
      if (!confirm(\`Ali res želite zapreti in trajno izbrisati sobo \${currentModalRoom}?\`)) return;

      try {
        const res = await fetch('/api/admin/room/delete', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ code: currentModalRoom })
        });
        const d = await res.json();
        if (d.success) {
          closeChatModal();
          fetchData();
        }
      } catch (e) {
        alert('Napaka: ' + e.message);
      }
    }

    // KONFIGURACIJA
    let hasLoadedConfig = false;

    function renderConfig() {
      if (!globalData || !globalData.settings) return;
      const s = globalData.settings;

      const motdActive = document.getElementById('motd-active-text');
      if (motdActive) motdActive.innerText = s.motd || 'Brez sporocila (prazno)';

      const motdInput = document.getElementById('config-motd');
      if (motdInput && (!hasLoadedConfig || document.activeElement !== motdInput)) {
        if (!hasLoadedConfig && s.motd !== undefined) {
          motdInput.value = s.motd;
        }
      }

      let featDesc = 'Ni nastavljen';
      if (s.featured_pub) {
        try {
          const f = typeof s.featured_pub === 'string' ? JSON.parse(s.featured_pub) : s.featured_pub;
          featDesc = \`\${f.name || 'Brez imena'} (\${f.address || 'Brez naslova'}) - [\${f.lat || ''}, \${f.lon || ''}]\`;
          if (f.note) featDesc += \` - Opomba: \${f.note}\`;

          if (!hasLoadedConfig) {
            const fn = document.getElementById('feat-name');
            const fa = document.getElementById('feat-address');
            const fl = document.getElementById('feat-lat');
            const flo = document.getElementById('feat-lon');
            const fno = document.getElementById('feat-note');
            if (fn && document.activeElement !== fn) fn.value = f.name || '';
            if (fa && document.activeElement !== fa) fa.value = f.address || '';
            if (fl && document.activeElement !== fl) fl.value = f.lat || '';
            if (flo && document.activeElement !== flo) flo.value = f.lon || '';
            if (fno && document.activeElement !== fno) fno.value = f.note || '';

            const vAnd = document.getElementById('config-ver-android');
            const vIos = document.getElementById('config-ver-ios');
            const vMin = document.getElementById('config-min-version');
            const vNot = document.getElementById('config-ver-notes');
            if (vAnd && document.activeElement !== vAnd) vAnd.value = s.latest_version_android || '1.2.0';
            if (vIos && document.activeElement !== vIos) vIos.value = s.latest_version_ios || '1.2.0';
            if (vMin && document.activeElement !== vMin) vMin.value = s.min_version || '1.0.0';
            if (vNot && document.activeElement !== vNot) vNot.value = s.version_update_notes || '';
          }
        } catch (e) {}
      }
      const featActive = document.getElementById('feat-active-text');
      if (featActive) featActive.innerText = featDesc;

      if (!hasLoadedConfig) {
        const vAnd = document.getElementById('config-ver-android');
        const vIos = document.getElementById('config-ver-ios');
        const vMin = document.getElementById('config-min-version');
        const vNot = document.getElementById('config-ver-notes');
        if (vAnd && document.activeElement !== vAnd) vAnd.value = s.latest_version_android || '1.2.0';
        if (vIos && document.activeElement !== vIos) vIos.value = s.latest_version_ios || '1.2.0';
        if (vMin && document.activeElement !== vMin) vMin.value = s.min_version || '1.0.0';
        if (vNot && document.activeElement !== vNot) vNot.value = s.version_update_notes || '';
      }

      hasLoadedConfig = true;
    }

    async function saveVersions() {
      const latestVersionAndroid = document.getElementById('config-ver-android').value.trim();
      const latestVersionIos = document.getElementById('config-ver-ios').value.trim();
      const minVersion = document.getElementById('config-min-version').value.trim();
      const versionNotes = document.getElementById('config-ver-notes').value.trim();
      const statusSpan = document.getElementById('version-save-status');

      try {
        const res = await fetch('/api/admin/settings/update', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            latestVersionAndroid,
            latestVersionIos,
            minVersion,
            versionNotes
          })
        });
        const d = await res.json();
        if (d.success) {
          if (statusSpan) {
            statusSpan.style.display = 'inline';
            setTimeout(() => { statusSpan.style.display = 'none'; }, 5000);
          }
          if (globalData && globalData.settings) {
            globalData.settings.latest_version_android = latestVersionAndroid;
            globalData.settings.latest_version_ios = latestVersionIos;
            globalData.settings.min_version = minVersion;
            globalData.settings.version_update_notes = versionNotes;
          }
          fetchData();
        } else {
          alert('Napaka: ' + (d.error || 'Neznana napaka'));
        }
      } catch (e) {
        alert('Napaka: ' + e.message);
      }
    }

    async function saveMotd() {
      const motd = document.getElementById('config-motd').value.trim();
      const statusSpan = document.getElementById('motd-save-status');
      try {
        const res = await fetch('/api/admin/settings/update', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ motd })
        });
        const d = await res.json();
        if (d.success) {
          if (statusSpan) {
            statusSpan.style.display = 'inline';
            setTimeout(() => { statusSpan.style.display = 'none'; }, 5000);
          }
          if (globalData && globalData.settings) globalData.settings.motd = motd;
          const motdActive = document.getElementById('motd-active-text');
          if (motdActive) motdActive.innerText = motd || 'Brez sporocila (prazno)';
        } else {
          alert('Napaka: ' + (d.error || 'Neznana napaka'));
        }
      } catch (e) {
        alert('Napaka: ' + e.message);
      }
    }

    async function saveFeaturedPub() {
      const featuredPub = {
        name: document.getElementById('feat-name').value.trim(),
        address: document.getElementById('feat-address').value.trim(),
        lat: document.getElementById('feat-lat').value.trim(),
        lon: document.getElementById('feat-lon').value.trim(),
        note: document.getElementById('feat-note').value.trim()
      };
      const statusSpan = document.getElementById('feat-save-status');
      try {
        const res = await fetch('/api/admin/settings/update', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ featuredPub })
        });
        const d = await res.json();
        if (d.success) {
          if (statusSpan) {
            statusSpan.style.display = 'inline';
            setTimeout(() => { statusSpan.style.display = 'none'; }, 5000);
          }
          if (globalData && globalData.settings) globalData.settings.featured_pub = JSON.stringify(featuredPub);
          const featActive = document.getElementById('feat-active-text');
          if (featActive) featActive.innerText = \`\${featuredPub.name} (\${featuredPub.address}) - [\${featuredPub.lat}, \${featuredPub.lon}]\`;
          fetchData();
        } else {
          alert('Napaka: ' + (d.error || 'Neznana napaka'));
        }
      } catch (e) {
        alert('Napaka: ' + e.message);
      }
    }

    // ČIŠČENJE SOB
    async function cleanOldRooms() {
      if (!confirm('Ali želite trajno izbrisati vse sobe in sporočila, starejša od 24 ur?')) return;
      try {
        const res = await fetch('/api/admin/db/clean', { method: 'POST' });
        const d = await res.json();
        alert(d.message || 'Čiščenje zaključeno.');
        fetchData();
      } catch (e) {
        alert('Napaka: ' + e.message);
      }
    }

    // POMOŽNE FUNKCIJE
    function escapeHtml(str) {
      if (!str) return '';
      return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;');
    }

    function escapeJs(str) {
      if (!str) return '';
      return String(str).replace(/'/g, "\\'").replace(/"/g, '\\"');
    }

    function formatTime(isoStr) {
      if (!isoStr) return '';
      try {
        const d = new Date(isoStr);
        return d.toLocaleTimeString('sl-SI', { hour: '2-digit', minute: '2-digit' }) + ' (' + d.toLocaleDateString('sl-SI', { day: '2-digit', month: '2-digit' }) + ')';
      } catch (e) {
        return isoStr;
      }
    }

    function isVersionOlder(current, latest) {
      if (!current || !latest) return false;
      const cParts = String(current).replace(/[^0-9.]/g, '').split('.').map(Number);
      const lParts = String(latest).replace(/[^0-9.]/g, '').split('.').map(Number);
      const maxLen = Math.max(cParts.length, lParts.length);
      for (let i = 0; i < maxLen; i++) {
        const c = cParts[i] || 0;
        const l = lParts[i] || 0;
        if (c < l) return true;
        if (c > l) return false;
      }
      return false;
    }

    // ODŠTEVALNIK OSVEŽEVANJA
    setInterval(() => {
      refreshSeconds--;
      if (refreshSeconds <= 0) {
        fetchData();
      } else {
        const cd = document.getElementById('refresh-countdown');
        if (cd) cd.innerText = \`\${refreshSeconds}s\`;
      }
    }, 1000);

    // ZAČETNI ZAGON
    fetchData();
    testOsrm();
    setInterval(testOsrm, 15000);
    renderSparkline();
    updateLivePreview();
  </script>
</body>
</html>`;
}

// 6. ZAGON STREŽNIKA
server.listen(PORT, '0.0.0.0', () => {
    console.log(`=======================================================`);
    console.log(`ŠankFinder Master Squad & App Gateway teče na vratih ${PORT}`);
    console.log(`Skrita upravna plošča: http://127.0.0.1:${PORT}/sank-uprava-x77`);
    console.log(`Baza podatkov: ${dbPath}`);
    console.log(`=======================================================`);
});
