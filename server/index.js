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
const url = require('url');
const path = require('path');
const fs = require('fs');
const { WebSocketServer, WebSocket } = require('ws');
const Database = require('better-sqlite3');

const PORT = process.env.PORT || 8080;
const DATA_DIR = process.env.DATA_DIR || path.join(__dirname, 'data');
const ADMIN_USER = process.env.ADMIN_USER || 'anze';
const ADMIN_PASS = process.env.ADMIN_PASS || 'Anziajeto';

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

function checkAdminAuth(req) {
    const authHeader = req.headers['authorization'];
    if (!authHeader || !authHeader.startsWith('Basic ')) return false;
    const creds = Buffer.from(authHeader.split(' ')[1], 'base64').toString('utf8');
    const [user, pass] = creds.split(':');
    return user === ADMIN_USER && pass === ADMIN_PASS;
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

    // SKRITA ADMIN NADZORNA PLOŠČA (Dostopna samo na lokalnem portu 8080)
    if (pathname === '/sank-uprava-x77') {
        if (!checkAdminAuth(req)) {
            res.writeHead(401, {
                'WWW-Authenticate': 'Basic realm="SankFinder Uprava"',
                'Content-Type': 'text/plain; charset=utf-8'
            });
            res.end('Dostop zavrnjen. Vnesite skrbniške podatke.');
            return;
        }
        res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
        res.end(renderAdminDashboardHtml());
        return;
    }

    // ADMIN API: PRIDOBI CELOVITE PODATKE ZA NADZORNO PLOŠČO
    if (pathname === '/api/admin/data') {
        if (!checkAdminAuth(req)) {
            res.writeHead(401, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'Nepooblaščen dostop' }));
            return;
        }

        const rooms = stmtGetAllRooms.all();
        const members = stmtGetAllMembers.all();
        const messages = stmtGetAllMessages.all();
        const totalDrinks = members.reduce((acc, m) => acc + (m.drinks_count || 0), 0);

        // Seznam naprav z odprtim appom
        const liveDevicesList = [];
        for (const [ws, dev] of appConnectedClients.entries()) {
            if (ws.readyState === WebSocket.OPEN) {
                liveDevicesList.push({
                    deviceId: dev.deviceId,
                    model: dev.model,
                    osVersion: dev.osVersion,
                    appVersion: dev.appVersion,
                    currentScreen: dev.currentScreen,
                    ip: dev.ip,
                    connectedAt: dev.connectedAt,
                    lastSeen: dev.lastSeen
                });
            }
        }

        const allKnownDevices = stmtGetAllAppDevices.all();
        const pushHistory = stmtGetRecentPushNotifications.all();
        const rawSettings = stmtGetAllSettings.all();
        const settingsMap = {};
        for (const s of rawSettings) {
            settingsMap[s.key] = s.value;
        }

        const totalKnownCount = stmtCountAppDevices.get().count;
        const totalPushCount = stmtCountPushNotifications.get().count;

        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
            overview: {
                onlineAppDevicesCount: liveDevicesList.length,
                totalKnownDevicesCount: totalKnownCount,
                totalPushSentCount: totalPushCount,
                activeRoomsCount: rooms.length,
                totalMembers: members.length,
                totalMessages: messages.length,
                totalDrinks: totalDrinks,
                uptimeSeconds: Math.floor(process.uptime()),
                nodeVersion: process.version,
                memoryUsageMb: Math.round(process.memoryUsage().rss / 1024 / 1024)
            },
            liveDevices: liveDevicesList,
            allDevices: allKnownDevices,
            pushHistory: pushHistory,
            rooms: rooms,
            members: members,
            messages: messages,
            settings: settingsMap
        }));
        return;
    }

    // ADMIN API: POŠLJI GLOBALNO POTISNO OBVESTILO (NA CELOTEN APP ALI NAPRAVO)
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
                const targetDeviceId = (data.targetDeviceId || '').trim();

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
                        if (!targetDeviceId || dev.deviceId === targetDeviceId) {
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
                stmtInsertPushNotification.run(title, message, category, targetDeviceId || 'all', sentCount);

                res.writeHead(200, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({
                    success: true,
                    message: `Potisno obvestilo uspešno oddano na ${sentCount} naprav.`,
                    sentCount: sentCount
                }));
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
                }

                res.writeHead(200, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ success: true, message: 'Nastavitve posodobljene.' }));
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
            // Poskusi se lokalno na 127.0.0.1
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

    // ADMIN API: SPOROČILA DOLOČENE SOBE
    if (pathname === '/api/admin/room/messages') {
        if (!checkAdminAuth(req)) {
            res.writeHead(401, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'Nepooblaščen dostop' }));
            return;
        }
        const code = (parsedUrl.query.code || '').toUpperCase();
        const msgs = stmtGetRecentMessages.all(code).reverse();
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ success: true, messages: msgs }));
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

                // Nemudoma obvesti vse v sobi, da se sporočilo odstrani z zaslona
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

    // ADMIN API: POŠLJI SPOROČILO V SOBO KOT SKRBNIK
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

                const resDb = stmtInsertMessage.run(code, 'admin', 'Uprava (Admin)', 'admin', content);

                broadcastToRoom(code, {
                    type: 'new_message',
                    id: resDb.lastInsertRowid,
                    senderId: 'admin',
                    senderName: 'Uprava (Admin)',
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

    // ADMIN API: IZBRIS SOBE
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

    // JAVNI API: USTVARJANJE SOBE (za Pivsko Klapo)
    if (pathname === '/api/rooms/create' && req.method === 'POST') {
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
                const members = stmtGetMembers.all(code);
                const messages = stmtGetRecentMessages.all(code).reverse();

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
        const appVersion = parsedUrl.query.version || '1.0';
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

        // Pošlji začetne nastavitve (npr. MOTD), če obstajajo
        const motdSetting = stmtGetSetting.get('motd');
        if (motdSetting && motdSetting.value) {
            try {
                ws.send(JSON.stringify({ type: 'motd', message: motdSetting.value }));
            } catch (e) {}
        }
    }

    // 4B. SQUAD POVEZAVA (PIVSKA KLAPA)
    const initialCode = (parsedUrl.query.code || '').toUpperCase();
    const initialName = parsedUrl.query.name || 'Prijatelj';
    const initialUserId = parsedUrl.query.userId || ('user_' + Date.now());

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

            // 1. Poročanje o spremembi zaslona v aplikaciji
            if (msg.type === 'screen_change' && msg.screen) {
                const dev = appConnectedClients.get(ws);
                if (dev) {
                    dev.currentScreen = msg.screen;
                    dev.lastSeen = new Date().toISOString();
                    stmtUpdateDeviceScreen.run(msg.screen, dev.deviceId);
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
            stmtUpsertMember.run({
                id: ws.user.id,
                roomCode: code,
                name: ws.user.name,
                lat: msg.lat,
                lon: msg.lon,
                drinksCount: ws.user.drinksCount || 0
            });

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

            const res = stmtInsertMessage.run(code, ws.user.id, ws.user.name, msg.msgType || 'text', content);

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

// Periodično čiščenje starih sob vsako uro
setInterval(() => {
    try {
        stmtCleanOldRooms.run();
        stmtCleanOldMembers.run();
        stmtCleanOldMessages.run();
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
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>ŠankFinder | Razvojna Nadzorna Plošča (Celoten App)</title>
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;600&display=swap" rel="stylesheet">
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
      padding: 14px 28px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      position: sticky;
      top: 0;
      z-index: 50;
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
      padding: 4px 10px;
      border-radius: 6px;
      font-size: 11px;
      font-weight: 800;
      letter-spacing: 1px;
    }
    .brand-title { font-size: 18px; font-weight: 800; }
    .status-badge {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      background: var(--green-bg);
      color: var(--green);
      padding: 5px 12px;
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
    }

    /* NAVIGACIJSKI MENI */
    .tabs-bar {
      background: #0f1628;
      border-bottom: 1px solid var(--border);
      display: flex;
      gap: 4px;
      padding: 0 28px;
      overflow-x: auto;
    }
    .tab-btn {
      background: transparent;
      color: var(--text-muted);
      border: none;
      padding: 14px 20px;
      font-family: inherit;
      font-size: 13.5px;
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
      padding: 24px 28px;
      max-width: 1400px;
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
      grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
      gap: 16px;
      margin-bottom: 24px;
    }
    .stat-card {
      background: var(--card-bg);
      border: 1px solid var(--border);
      border-radius: 14px;
      padding: 18px 20px;
      position: relative;
    }
    .stat-label {
      font-size: 11.5px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      color: var(--text-muted);
      font-weight: 700;
    }
    .stat-number {
      font-size: 28px;
      font-weight: 800;
      color: var(--gold);
      margin-top: 6px;
    }
    .stat-sub {
      font-size: 11px;
      color: var(--text-muted);
      margin-top: 4px;
    }

    /* PANELI */
    .panel {
      background: var(--card-bg);
      border: 1px solid var(--border);
      border-radius: 14px;
      padding: 22px;
      margin-bottom: 24px;
    }
    .panel-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 16px;
      flex-wrap: wrap;
      gap: 12px;
    }
    .panel-title {
      font-size: 16px;
      font-weight: 800;
    }
    .search-input {
      background: #090e18;
      border: 1px solid var(--border);
      color: var(--text);
      padding: 8px 14px;
      border-radius: 8px;
      font-family: inherit;
      font-size: 13px;
      width: 260px;
      outline: none;
      transition: border-color 0.2s;
    }
    .search-input:focus { border-color: var(--gold); }
    table { width: 100%; border-collapse: collapse; font-size: 13px; text-align: left; }
    th {
      color: var(--text-muted);
      font-size: 11px;
      text-transform: uppercase;
      font-weight: 700;
      letter-spacing: 0.5px;
      padding: 10px 12px;
      border-bottom: 1px solid var(--border);
    }
    td { padding: 12px; border-bottom: 1px solid rgba(34, 47, 71, 0.4); }
    tr:last-child td { border-bottom: none; }
    tr:hover td { background: rgba(255,255,255,0.015); }
    .mono { font-family: 'JetBrains Mono', monospace; font-size: 12px; }
    .code-badge {
      background: var(--gold-bg);
      color: var(--gold);
      border: 1px solid rgba(245, 158, 11, 0.3);
      padding: 3px 7px;
      border-radius: 6px;
      font-weight: 700;
      font-family: 'JetBrains Mono', monospace;
    }

    /* GUMBI */
    .btn {
      background: var(--gold);
      color: #000;
      border: none;
      padding: 8px 16px;
      border-radius: 8px;
      font-family: inherit;
      font-weight: 700;
      font-size: 12.5px;
      cursor: pointer;
      display: inline-flex;
      align-items: center;
      gap: 6px;
      transition: all 0.2s;
    }
    .btn:hover { background: var(--gold-hover); }
    .btn-blue {
      background: var(--blue-bg);
      color: #60a5fa;
      border: 1px solid rgba(59, 130, 246, 0.3);
    }
    .btn-blue:hover { background: var(--blue); color: #fff; }
    .btn-red {
      background: var(--red-bg);
      color: #f87171;
      border: 1px solid rgba(239, 68, 68, 0.3);
    }
    .btn-red:hover { background: var(--red); color: #fff; }

    /* OBRAZEC */
    .form-group { margin-bottom: 16px; }
    .form-group label { display: block; font-size: 12px; font-weight: 700; color: var(--text-muted); margin-bottom: 6px; text-transform: uppercase; letter-spacing: 0.5px; }
    .form-control {
      width: 100%;
      background: #090e18;
      border: 1px solid var(--border);
      color: var(--text);
      padding: 10px 12px;
      border-radius: 8px;
      font-family: inherit;
      font-size: 13.5px;
      outline: none;
    }
    .form-control:focus { border-color: var(--gold); }
    textarea.form-control { resize: vertical; min-height: 80px; }

    .grid-2 {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 20px;
    }
    @media (max-width: 900px) {
      .grid-2 { grid-template-columns: 1fr; }
    }

    /* MODAL ZA KLEPET */
    .modal-overlay {
      display: none;
      position: fixed;
      inset: 0;
      background: rgba(0,0,0,0.75);
      backdrop-filter: blur(4px);
      z-index: 100;
      justify-content: center;
      align-items: center;
      padding: 16px;
    }
    .modal {
      background: #111a2c;
      border: 1px solid var(--border);
      border-radius: 16px;
      width: 100%;
      max-width: 650px;
      max-height: 85vh;
      display: flex;
      flex-direction: column;
      overflow: hidden;
    }
    .modal-head {
      padding: 16px 20px;
      border-bottom: 1px solid var(--border);
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    .modal-body {
      padding: 16px 20px;
      overflow-y: auto;
      flex: 1;
      display: flex;
      flex-direction: column;
      gap: 10px;
      max-height: 400px;
    }
    .msg-bubble {
      background: #1a2538;
      padding: 10px 14px;
      border-radius: 10px;
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
      gap: 10px;
    }
    .msg-sender { font-size: 11px; font-weight: 800; color: var(--gold); }
    .msg-text { font-size: 13px; margin-top: 3px; }
    .modal-foot {
      padding: 14px 20px;
      border-top: 1px solid var(--border);
      display: flex;
      gap: 10px;
      background: #0d1524;
    }
  </style>
</head>
<body>

  <header>
    <div class="brand">
      <span class="badge-tag">UPRAVA</span>
      <h1 class="brand-title">ŠankFinder Nadzorna Plošča (Celoten App)</h1>
    </div>
    <div style="display:flex; align-items:center; gap: 12px;">
      <div class="status-badge">
        <span class="pulse-dot"></span>
        Strežnik Aktiven
      </div>
      <button class="btn" onclick="fetchData()">Osveži</button>
    </div>
  </header>

  <!-- NAVIGACIJSKI MENI (5 ZAVIHKOV ZA CELOTEN APP) -->
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
      Pivska Klapa (Sobe & Klepet)
      <span class="tab-pill" id="badge-rooms">0</span>
    </button>
    <button class="tab-btn" onclick="switchTab('config')">
      Konfiguracija & Šank Tedna
    </button>
  </div>

  <div class="content">

    <!-- ZAVIHEK 1: GLAVNI PREGLED CELOTNE APLIKACIJE -->
    <div class="tab-pane active" id="tab-overview">
      <div class="stats-row">
        <div class="stat-card">
          <div class="stat-label">Aktivne Naprave v Živo</div>
          <div class="stat-number" id="stat-online-devices" style="color: var(--green);">0</div>
          <div class="stat-sub">Trenutno odprta aplikacija</div>
        </div>
        <div class="stat-card">
          <div class="stat-label">Vse Registrirane Naprave</div>
          <div class="stat-number" id="stat-total-devices">0</div>
          <div class="stat-sub">Baza znanih namestitev</div>
        </div>
        <div class="stat-card">
          <div class="stat-label">Poslana Push Obvestila</div>
          <div class="stat-number" id="stat-push-sent" style="color: var(--blue);">0</div>
          <div class="stat-sub">Dostavljena na telefone</div>
        </div>
        <div class="stat-card">
          <div class="stat-label">Aktivne Pivske Klape</div>
          <div class="stat-number" id="stat-rooms">0</div>
          <div class="stat-sub">Sobe v teku</div>
        </div>
        <div class="stat-card">
          <div class="stat-label">Skupaj Štetih Pijač</div>
          <div class="stat-number" id="stat-drinks">0</div>
          <div class="stat-sub">Osebni pivski seštevki</div>
        </div>
        <div class="stat-card">
          <div class="stat-label">OSRM Usmerjevalnik</div>
          <div class="stat-number" id="stat-osrm" style="font-size: 20px; margin-top: 10px; color: var(--green);">Preverjam...</div>
          <div class="stat-sub" id="stat-osrm-sub">Lokalni usmerjevalnik</div>
        </div>
      </div>

      <div class="grid-2">
        <div class="panel">
          <div class="panel-header">
            <h2 class="panel-title">Hitro Push Obvestilo za Vse Uporabnike</h2>
          </div>
          <div class="form-group">
            <label>Naslov Obvestila</label>
            <input type="text" class="form-control" id="quick-push-title" placeholder="Npr. Petkov Happy Hour v Ljubljani!">
          </div>
          <div class="form-group">
            <label>Sporočilo</label>
            <textarea class="form-control" id="quick-push-msg" placeholder="Vnesite kratko obvestilo, ki se bo prikazalo vsem uporabnikom..."></textarea>
          </div>
          <button class="btn" onclick="sendQuickPush()">Pošlji Vsem Uporabnikom</button>
        </div>

        <div class="panel">
          <div class="panel-header">
            <h2 class="panel-title">Stanje Sistemskih Storitev</h2>
          </div>
          <table>
            <thead>
              <tr><th>Storitev</th><th>Vrata / Protokol</th><th>Stanje</th></tr>
            </thead>
            <tbody>
              <tr>
                <td><strong>Nginx Reverse Proxy</strong></td>
                <td class="mono">Port 80/443 (SSL)</td>
                <td><span style="color: var(--green); font-weight: 700;">Deluje</span></td>
              </tr>
              <tr>
                <td><strong>OSRM Slovenija Usmerjevalnik</strong></td>
                <td class="mono">Port 5000 (HTTP)</td>
                <td id="osrm-service-status"><span style="color: var(--green); font-weight: 700;">Deluje</span></td>
              </tr>
              <tr>
                <td><strong>ŠankFinder Master Gateway</strong></td>
                <td class="mono">Port 8080 (WS/REST)</td>
                <td><span style="color: var(--green); font-weight: 700;">Aktiven (Node)</span></td>
              </tr>
              <tr>
                <td><strong>SQLite Baza (WAL)</strong></td>
                <td class="mono">data/squad.db</td>
                <td><span style="color: var(--green); font-weight: 700;">Povezana</span></td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <!-- ZAVIHEK 2: GLOBALNA PUSH OBVESTILA -->
    <div class="tab-pane" id="tab-push">
      <div class="grid-2">
        <div class="panel">
          <div class="panel-header">
            <h2 class="panel-title">Center za Potisna Obvestila (Push Center)</h2>
          </div>
          <div class="form-group">
            <label>Naslov Obvestila</label>
            <input type="text" class="form-control" id="push-title" placeholder="Npr. Akcija v lokalih ali Novo obvestilo">
          </div>
          <div class="form-group">
            <label>Vsebina Obvestila</label>
            <textarea class="form-control" id="push-message" placeholder="Besedilo obvestila, ki ga telefon prikaže kot sistemsko obvestilo z zvokom in vibracijo..."></textarea>
          </div>
          <div class="form-group">
            <label>Kategorija</label>
            <select class="form-control" id="push-category">
              <option value="splosno">Splošno obvestilo</option>
              <option value="happy_hour">Akcija / Happy Hour</option>
              <option value="pomembno">Nujno tehnično opozorilo</option>
            </select>
          </div>
          <div class="form-group">
            <label>Ciljna Naprava</label>
            <select class="form-control" id="push-target">
              <option value="">Vsi uporabniki aplikacije (Globalni broadcast)</option>
            </select>
          </div>
          <button class="btn" onclick="sendGlobalPush()">Pošlji Potisno Obvestilo na Telefone</button>
        </div>

        <div class="panel">
          <div class="panel-header">
            <h2 class="panel-title">Zgodovina Poslanih Potisnih Obvestil</h2>
          </div>
          <table>
            <thead>
              <tr>
                <th>Čas</th>
                <th>Naslov</th>
                <th>Vsebina</th>
                <th>Doseg</th>
              </tr>
            </thead>
            <tbody id="push-history-body">
              <tr><td colspan="4" style="text-align:center; color: var(--text-muted);">Ni preteklih obvestil.</td></tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <!-- ZAVIHEK 3: AKTIVNE NAPRAVE V ŽIVO -->
    <div class="tab-pane" id="tab-devices">
      <div class="panel">
        <div class="panel-header">
          <h2 class="panel-title">Aktivne Naprave v Živo (Telemetrija Odjemalcev)</h2>
          <input type="text" class="search-input" id="search-devices" placeholder="Išči model, IP, zaslon..." onkeyup="filterTable('search-devices', 'devices-body')">
        </div>
        <table>
          <thead>
            <tr>
              <th>Model Naprave</th>
              <th>Sistem</th>
              <th>Trenuten Zaslon</th>
              <th>IP Naslov</th>
              <th>Povezan Od</th>
              <th>Akcija</th>
            </tr>
          </thead>
          <tbody id="devices-body">
            <tr><td colspan="6" style="text-align:center; color: var(--text-muted);">Trenutno ni povezanih naprav v živo.</td></tr>
          </tbody>
        </table>
      </div>

      <div class="panel" style="margin-top: 20px;">
        <div class="panel-header">
          <h2 class="panel-title">Vse Zaznane & Registrirane Naprave (Apple & Android v bazi)</h2>
          <input type="text" class="search-input" id="search-all-devices" placeholder="Išči model, sistem, zaslon..." onkeyup="filterTable('search-all-devices', 'all-devices-body')">
        </div>
        <table>
          <thead>
            <tr>
              <th>Model Naprave</th>
              <th>Sistem & Platforma</th>
              <th>Zadnji Zaslon</th>
              <th>IP Naslov</th>
              <th>Prvič Viden</th>
              <th>Nazadnje Aktiven</th>
              <th>Akcija</th>
            </tr>
          </thead>
          <tbody id="all-devices-body">
            <tr><td colspan="7" style="text-align:center; color: var(--text-muted);">Ni zabeleženih naprav.</td></tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- ZAVIHEK 4: PIVSKA KLAPA (SOBE & KLEPET) -->
    <div class="tab-pane" id="tab-squad">
      <div class="panel">
        <div class="panel-header">
          <h2 class="panel-title">Aktivne Pivske Klape (Sobe)</h2>
          <input type="text" class="search-input" id="search-rooms" placeholder="Išči sobo ali kodo..." onkeyup="filterTable('search-rooms', 'rooms-body')">
        </div>
        <table>
          <thead>
            <tr>
              <th>Koda</th>
              <th>Ime Klape</th>
              <th>Ustvarjeno</th>
              <th>Akcije</th>
            </tr>
          </thead>
          <tbody id="rooms-body">
            <tr><td colspan="4" style="text-align:center; color: var(--text-muted);">Nalaganje sob...</td></tr>
          </tbody>
        </table>
      </div>

      <div class="panel">
        <div class="panel-header">
          <h2 class="panel-title">Zadnja Klepet Sporočila v Živo</h2>
          <input type="text" class="search-input" id="search-msgs" placeholder="Filtriraj sporočila..." onkeyup="filterTable('search-msgs', 'msgs-body')">
        </div>
        <table>
          <thead>
            <tr>
              <th>Čas</th>
              <th>Soba</th>
              <th>Pošiljatelj</th>
              <th>Vsebina</th>
              <th>Akcija</th>
            </tr>
          </thead>
          <tbody id="msgs-body">
            <tr><td colspan="5" style="text-align:center; color: var(--text-muted);">Nalaganje sporočil...</td></tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- ZAVIHEK 5: KONFIGURACIJA IN ŠANK TEDNA -->
    <div class="tab-pane" id="tab-config">
      <div class="grid-2">
        <div class="panel">
          <div class="panel-header">
            <h2 class="panel-title">Sporočilo Dneva (MOTD za Aplikacijo)</h2>
          </div>
          <p style="font-size: 13px; color: var(--text-muted); margin-bottom: 14px;">
            To sporočilo se samodejno prikaže vsem uporabnikom, ko odprejo aplikacijo ali se povežejo.
          </p>
          <div class="form-group">
            <label>Besedilo Sporočila Dneva</label>
            <textarea class="form-control" id="cfg-motd" placeholder="Npr. Dobrodošli v ŠankFinderju! Danes imajo vsi lokali v centru akcijo."></textarea>
          </div>
          <button class="btn" onclick="saveMotd()">Shrani in Objavi MOTD</button>
        </div>

        <div class="panel">
          <div class="panel-header">
            <h2 class="panel-title">OSRM Diagnostika Usmerjevanja</h2>
          </div>
          <p style="font-size: 13px; color: var(--text-muted); margin-bottom: 14px;">
            Preverite hitrost lokalnega usmerjevalnika za pešce in vožnjo po Sloveniji.
          </p>
          <div style="margin-bottom: 16px;">
            <div style="font-size: 13px;">Odzivni čas: <strong id="osrm-latency" style="color: var(--green);">-</strong></div>
          </div>
          <button class="btn btn-blue" onclick="testOsrm()">Testiraj OSRM Hitrost</button>
        </div>
      </div>
    </div>

  </div>

  <!-- MODALNO OKNO ZA OGLED KLEPETA SOBE -->
  <div class="modal-overlay" id="chat-modal">
    <div class="modal">
      <div class="modal-head">
        <h3 id="modal-room-title">Klepet Sobe</h3>
        <button class="btn btn-red" onclick="closeChatModal()">Zapri</button>
      </div>
      <div class="modal-body" id="modal-chat-body"></div>
      <div class="modal-foot">
        <input type="text" class="form-control" id="modal-admin-msg" placeholder="Napišite sporočilo kot Uprava...">
        <button class="btn" onclick="sendAdminRoomMsg()">Pošlji</button>
      </div>
    </div>
  </div>

  <script>
    let activeRoomCodeForModal = null;
    let allDataCache = null;

    function switchTab(tabId) {
      document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
      document.querySelectorAll('.tab-pane').forEach(p => p.classList.remove('active'));

      const targetBtn = Array.from(document.querySelectorAll('.tab-btn')).find(b => b.getAttribute('onclick').includes(tabId));
      if (targetBtn) targetBtn.classList.add('active');

      const targetPane = document.getElementById('tab-' + tabId);
      if (targetPane) targetPane.classList.add('active');
    }

    async function fetchData() {
      try {
        const res = await fetch('/api/admin/data');
        if (!res.ok) throw new Error('Napaka pri pridobivanju podatkov: ' + res.status);
        const data = await res.json();
        allDataCache = data;

        // 1. Posodobi statistiko na vrhu
        document.getElementById('stat-online-devices').textContent = data.overview.onlineAppDevicesCount;
        document.getElementById('stat-total-devices').textContent = data.overview.totalKnownDevicesCount;
        document.getElementById('stat-push-sent').textContent = data.overview.totalPushSentCount;
        document.getElementById('stat-rooms').textContent = data.overview.activeRoomsCount;
        document.getElementById('stat-drinks').textContent = data.overview.totalDrinks;

        // Značke na zavihkih
        document.getElementById('badge-push').textContent = data.overview.totalPushSentCount;
        document.getElementById('badge-devices').textContent = data.overview.onlineAppDevicesCount;
        document.getElementById('badge-rooms').textContent = data.overview.activeRoomsCount;

        // 2. Tabela naprav v živo in vseh naprav
        renderLiveDevices(data.liveDevices);
        renderAllDevices(data.allDevices, data.liveDevices);

        // 3. Tabela zgodovine push obvestil
        renderPushHistory(data.pushHistory);

        // 4. Posodobi spustni seznam ciljnih naprav v push obrazcu
        updateTargetDevicesDropdown(data.liveDevices, data.allDevices);

        // 5. Tabela sob
        renderRooms(data.rooms);

        // 6. Tabela zadnjih sporočil
        renderMessages(data.messages);

        // 7. Nastavitve (MOTD)
        if (data.settings && data.settings.motd) {
          const motdEl = document.getElementById('cfg-motd');
          if (document.activeElement !== motdEl) {
            motdEl.value = data.settings.motd;
          }
        }

      } catch (err) {
        console.error('Napaka pri osveževanju:', err);
      }
    }

    function getOsBadge(os, model) {
      const isApple = (os && os.toLowerCase().includes('ios')) || (model && (model.toLowerCase().includes('iphone') || model.toLowerCase().includes('ipad') || model.toLowerCase().includes('apple')));
      if (isApple) {
        return '<span class="tab-pill" style="background:rgba(0,122,255,0.18); color:#0A84FF; border:1px solid rgba(0,122,255,0.4); font-weight:700;"> Apple iOS</span>';
      }
      return '<span class="tab-pill" style="background:rgba(61,220,132,0.18); color:#3DDC84; border:1px solid rgba(61,220,132,0.4); font-weight:700;">🤖 Android</span>';
    }

    function renderLiveDevices(devices) {
      const tbody = document.getElementById('devices-body');
      if (!devices || devices.length === 0) {
        tbody.innerHTML = '<tr><td colspan="6" style="text-align:center; color: var(--text-muted);">Trenutno ni aktivno povezanih naprav v živo.</td></tr>';
        return;
      }
      tbody.innerHTML = devices.map(d => \`
        <tr>
          <td><span style="display:inline-block; width:8px; height:8px; border-radius:50%; background:#3DDC84; margin-right:6px; box-shadow:0 0 8px #3DDC84;"></span><strong>\${escapeHtml(d.model)}</strong> <span class="mono" style="font-size:11px; color:var(--text-muted);">(\${escapeHtml(d.deviceId)})</span></td>
          <td>\${getOsBadge(d.osVersion, d.model)} <span class="mono" style="font-size:11px; margin-left:4px;">\${escapeHtml(d.osVersion || '')}</span></td>
          <td><span style="color:var(--gold); font-weight:700;">\${escapeHtml(d.currentScreen || 'Glavna')}</span></td>
          <td class="mono">\${escapeHtml(d.ip)}</td>
          <td>\${formatTime(d.connectedAt)}</td>
          <td>
            <button class="btn btn-blue" onclick="openTargetPush('\${escapeHtml(d.deviceId)}')">Pošlji Obvestilo</button>
          </td>
        </tr>
      \`).join('');
    }

    function renderPushHistory(history) {
      const tbody = document.getElementById('push-history-body');
      if (!history || history.length === 0) {
        tbody.innerHTML = '<tr><td colspan="4" style="text-align:center; color: var(--text-muted);">Ni preteklih obvestil.</td></tr>';
        return;
      }
      tbody.innerHTML = history.map(h => \`
        <tr>
          <td style="white-space:nowrap;">\${formatTime(h.created_at)}</td>
          <td><strong>\${escapeHtml(h.title)}</strong></td>
          <td>\${escapeHtml(h.message)}</td>
          <td><span class="tab-pill">\${h.sent_count} naprav</span></td>
        </tr>
      \`).join('');
    }

    function renderAllDevices(devices, liveDevices) {
      const tbody = document.getElementById('all-devices-body');
      if (!tbody) return;
      if (!devices || devices.length === 0) {
        tbody.innerHTML = '<tr><td colspan="7" style="text-align:center; color: var(--text-muted);">Ni zabeleženih naprav.</td></tr>';
        return;
      }
      const liveSet = new Set((liveDevices || []).map(d => d.deviceId));
      tbody.innerHTML = devices.map(d => {
        const isOnline = liveSet.has(d.device_id);
        const statusDot = isOnline 
          ? '<span style="display:inline-block; width:8px; height:8px; border-radius:50%; background:#3DDC84; margin-right:6px; box-shadow:0 0 6px #3DDC84;" title="Povezan v živo"></span>'
          : '<span style="display:inline-block; width:8px; height:8px; border-radius:50%; background:#64748B; margin-right:6px;" title="Neaktiven"></span>';
        return \`
          <tr>
            <td>\${statusDot}<strong>\${escapeHtml(d.model)}</strong> <span class="mono" style="font-size:11px; color:var(--text-muted);">(\${escapeHtml(d.device_id)})</span></td>
            <td>\${getOsBadge(d.os_version, d.model)} <span class="mono" style="font-size:11px; margin-left:4px;">\${escapeHtml(d.os_version || '')}</span></td>
            <td><span style="color:var(--gold); font-weight:600;">\${escapeHtml(d.current_screen || 'Glavna')}</span></td>
            <td class="mono">\${escapeHtml(d.ip)}</td>
            <td style="font-size:12px;">\${formatTime(d.first_seen)}</td>
            <td style="font-size:12px;"><strong>\${formatTime(d.last_seen)}</strong></td>
            <td>
              <button class="btn btn-blue" onclick="openTargetPush('\${escapeHtml(d.device_id)}')">Obvesti</button>
            </td>
          </tr>
        \`;
      }).join('');
    }

    function updateTargetDevicesDropdown(liveDevices, allDevices) {
      const select = document.getElementById('push-target');
      const currentVal = select.value;
      let html = '<option value="">Vsi uporabniki aplikacije (Globalni broadcast)</option>';
      
      const devices = (allDevices && allDevices.length > 0) ? allDevices : (liveDevices || []);
      const liveSet = new Set((liveDevices || []).map(d => d.deviceId));
      
      if (devices && devices.length > 0) {
        devices.forEach(d => {
          const devId = d.device_id || d.deviceId;
          const model = d.model || 'Naprava';
          const os = d.os_version || d.osVersion || '';
          const isApple = os.toLowerCase().includes('ios') || model.toLowerCase().includes('iphone') || model.toLowerCase().includes('ipad');
          const osPrefix = isApple ? '🍎 [Apple]' : '🤖 [Android]';
          const isOnline = liveSet.has(devId);
          const statusText = isOnline ? '🟢 NA SPLETU' : '⚪ Neaktiven';
          html += \`<option value="\${escapeHtml(devId)}">\${osPrefix} \${escapeHtml(model)} (\${escapeHtml(devId)}) - \${statusText}</option>\`;
        });
      }
      select.innerHTML = html;
      select.value = currentVal;
    }

    function openTargetPush(devId) {
      switchTab('push');
      document.getElementById('push-target').value = devId;
      document.getElementById('push-title').focus();
    }

    function renderRooms(rooms) {
      const tbody = document.getElementById('rooms-body');
      if (!rooms || rooms.length === 0) {
        tbody.innerHTML = '<tr><td colspan="4" style="text-align:center; color: var(--text-muted);">Ni aktivnih sob.</td></tr>';
        return;
      }
      tbody.innerHTML = rooms.map(r => \`
        <tr>
          <td><span class="code-badge">\${escapeHtml(r.code)}</span></td>
          <td><strong>\${escapeHtml(r.name)}</strong></td>
          <td>\${formatTime(r.created_at)}</td>
          <td>
            <button class="btn btn-blue" onclick="openChatModal('\${r.code}', '\${escapeHtml(r.name)}')">Odpri Klepet</button>
            <button class="btn btn-red" onclick="deleteRoom('\${r.code}')">Zapri Sobo</button>
          </td>
        </tr>
      \`).join('');
    }

    function renderMessages(messages) {
      const tbody = document.getElementById('msgs-body');
      if (!messages || messages.length === 0) {
        tbody.innerHTML = '<tr><td colspan="5" style="text-align:center; color: var(--text-muted);">Ni sporočil.</td></tr>';
        return;
      }
      tbody.innerHTML = messages.map(m => \`
        <tr>
          <td style="white-space:nowrap;">\${formatTime(m.created_at)}</td>
          <td><span class="code-badge">\${escapeHtml(m.room_code)}</span></td>
          <td><strong>\${escapeHtml(m.sender_name)}</strong></td>
          <td>\${escapeHtml(m.content)}</td>
          <td>
            <button class="btn btn-red" onclick="deleteMessage(\${m.id})">Izbriši</button>
          </td>
        </tr>
      \`).join('');
    }

    async function sendGlobalPush() {
      const title = document.getElementById('push-title').value.trim();
      const message = document.getElementById('push-message').value.trim();
      const category = document.getElementById('push-category').value;
      const targetDeviceId = document.getElementById('push-target').value;

      if (!message) {
        alert('Vnesite vsebino obvestila!');
        return;
      }

      try {
        const res = await fetch('/api/admin/push/send', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ title, message, category, targetDeviceId })
        });
        const d = await res.json();
        if (d.success) {
          alert('Uspešno: ' + d.message);
          document.getElementById('push-message').value = '';
          fetchData();
        } else {
          alert('Napaka: ' + d.error);
        }
      } catch (e) {
        alert('Napaka pri pošiljanju: ' + e.message);
      }
    }

    async function sendQuickPush() {
      const title = document.getElementById('quick-push-title').value.trim() || 'ŠankFinder Obvestilo';
      const message = document.getElementById('quick-push-msg').value.trim();
      if (!message) {
        alert('Vnesite vsebino sporočila!');
        return;
      }
      try {
        const res = await fetch('/api/admin/push/send', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ title, message, category: 'splosno', targetDeviceId: '' })
        });
        const d = await res.json();
        if (d.success) {
          alert('Potisno obvestilo poslano vsem uporabnikom!');
          document.getElementById('quick-push-msg').value = '';
          fetchData();
        }
      } catch (e) {
        alert('Napaka: ' + e.message);
      }
    }

    async function saveMotd() {
      const motd = document.getElementById('cfg-motd').value.trim();
      try {
        const res = await fetch('/api/admin/settings/update', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ motd })
        });
        const d = await res.json();
        if (d.success) alert('Sporočilo dneva (MOTD) je bilo shranjeno in oddano!');
      } catch (e) {
        alert('Napaka: ' + e.message);
      }
    }

    async function testOsrm() {
      document.getElementById('osrm-latency').textContent = 'Testiram...';
      try {
        const res = await fetch('/api/admin/osrm/ping');
        const d = await res.json();
        if (d.status === 'online') {
          document.getElementById('osrm-latency').textContent = d.latencyMs + ' ms (Odziven)';
          document.getElementById('stat-osrm').textContent = d.latencyMs + ' ms';
        } else {
          document.getElementById('osrm-latency').textContent = 'Nedosegljiv (' + (d.error || 'napaka') + ')';
        }
      } catch (e) {
        document.getElementById('osrm-latency').textContent = 'Napaka: ' + e.message;
      }
    }

    async function deleteMessage(id) {
      if (!confirm('Ali res želite takoj izbrisati to sporočilo iz baze in vseh telefonov?')) return;
      try {
        const res = await fetch('/api/admin/message/delete', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ id })
        });
        const d = await res.json();
        if (d.success) {
          fetchData();
          if (activeRoomCodeForModal) loadRoomChat(activeRoomCodeForModal);
        }
      } catch (e) {
        alert('Napaka pri brisanju: ' + e.message);
      }
    }

    async function deleteRoom(code) {
      if (!confirm('Ali res želite zapreti in izbrisati celotno klapa sobo ' + code + '?')) return;
      try {
        const res = await fetch('/api/admin/room/delete', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ code })
        });
        const d = await res.json();
        if (d.success) fetchData();
      } catch (e) {
        alert('Napaka: ' + e.message);
      }
    }

    async function openChatModal(code, name) {
      activeRoomCodeForModal = code;
      document.getElementById('modal-room-title').textContent = 'Klepet Sobe: ' + name + ' (' + code + ')';
      document.getElementById('chat-modal').style.display = 'flex';
      await loadRoomChat(code);
    }

    function closeChatModal() {
      document.getElementById('chat-modal').style.display = 'none';
      activeRoomCodeForModal = null;
    }

    async function loadRoomChat(code) {
      try {
        const res = await fetch('/api/admin/room/messages?code=' + code);
        const data = await res.json();
        const box = document.getElementById('modal-chat-body');
        if (!data.messages || data.messages.length === 0) {
          box.innerHTML = '<div style="text-align:center; color:var(--text-muted); padding:20px;">V tej sobi še ni sporočil.</div>';
          return;
        }
        box.innerHTML = data.messages.map(m => \`
          <div class="msg-bubble">
            <div>
              <div class="msg-sender">\${escapeHtml(m.sender_name)} <span style="color:var(--text-muted); font-weight:normal; font-size:10px;">\${formatTime(m.created_at)}</span></div>
              <div class="msg-text">\${escapeHtml(m.content)}</div>
            </div>
            <button class="btn btn-red" style="padding:3px 7px; font-size:11px;" onclick="deleteMessage(\${m.id})">Briši</button>
          </div>
        \`).join('');
        box.scrollTop = box.scrollHeight;
      } catch (e) {}
    }

    async function sendAdminRoomMsg() {
      if (!activeRoomCodeForModal) return;
      const inp = document.getElementById('modal-admin-msg');
      const content = inp.value.trim();
      if (!content) return;
      try {
        const res = await fetch('/api/admin/message/send', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ code: activeRoomCodeForModal, content })
        });
        inp.value = '';
        await loadRoomChat(activeRoomCodeForModal);
      } catch (e) {}
    }

    function filterTable(inputId, bodyId) {
      const q = document.getElementById(inputId).value.toLowerCase();
      const rows = document.getElementById(bodyId).getElementsByTagName('tr');
      for (const row of rows) {
        row.style.display = row.textContent.toLowerCase().includes(q) ? '' : 'none';
      }
    }

    function formatTime(iso) {
      if (!iso) return '-';
      try {
        const d = new Date(iso);
        return d.toLocaleTimeString('sl-SI', { hour: '2-digit', minute: '2-digit', second: '2-digit' });
      } catch (e) { return iso; }
    }

    function escapeHtml(str) {
      if (!str) return '';
      return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;');
    }

    // Začetni zagon in interval osveževanja vsakih 5 sekund
    fetchData();
    testOsrm();
    setInterval(fetchData, 5000);
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
