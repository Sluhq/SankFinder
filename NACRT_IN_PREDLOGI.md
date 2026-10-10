# 🍻 ŠankFinder – Načrt razvoja, Arhitektura Chata in Strežniška Navodila

> **Datum posodobitve:** Oktober 2026  
> **Status projekta:** Produkcijska različica z lokalno peš navigacijo, orodji in načrtom za Pivsko Klapo (Live Chat + Radar prijateljev)

---

## 1. Pregled trenutnega stanja aplikacije (Kaj je narejeno)

| Področje | Funkcionalnost | Stanje | Podrobnosti |
|---|---|:---:|---|
| **Šanki (Seznam)** | Seznam lokalov & Iskalnik | ✅ Deluje | Iskanje lokalov po imenu/naslovu/tipu, dinamični limit (10, 25, 50, po meri). |
| **Šanki (Seznam)** | Delovni čas, telefon & navigacija | ✅ Deluje | Hitri klic lokala, shranjevanje med priljubljene, začetek peš navigacije. |
| **Orodja (Igre & Pomoč)** | Ruleta šankov | ✅ Deluje | Naključen izbor med trenutno naloženimi lokali z direktno navigacijo. |
| **Orodja (Igre & Pomoč)** | Burek pavza & Nočna lakota | ✅ Deluje | Pekarna Legiša (Rimska cesta - 300 m od Krakova), Legiša Dunajska, Dunajska pekarna, Nobel, Olimpija, Dvojka itd. Prikaz delovnega časa in live statusa (`🟢 Odprto zdaj` / `🔴 Zaprto`) ter filter samo za odprte točke. |
| **Orodja (Igre & Pomoč)** | Kolo "Kdo plača rundo?" | ✅ Deluje | Interaktivno kolo s fizikalnim pojemanjem, žrebanje plačnika runde in pivske misli. |
| **Orodja (Igre & Pomoč)** | Razdeli račun (Bill Splitter) | ✅ Deluje | Enakomerna ali posamična delitev zneska z izbiro napitnine (0%, 5%, 10%, 15%). |
| **Orodja (Igre & Pomoč)** | Končal sem / Klic taksija | ✅ Deluje | Naključno prepričevanje (3 do 6 dialogov), nato melanholičen klicnik za Taxi Metro / Laguna brez prekrivanja gumbov. |
| **Zemljevid & Navigacija** | OpenStreetMap (OSMDroid) | ✅ Deluje | Kartografija v živo, kompas/azimut, gladko sledenje uporabniku, turn-by-turn HUD vodenje. |
| **Zemljevid & Navigacija** | Lasten OSRM peš usmerjevalnik | ✅ Deluje | Primarni strežnik na `https://sankfinder.sluga.me`, rezervni na OSM.de. |
| **Zgodovina & Računi** | ML Kit OCR & FURS QR koda | ✅ Deluje | Samodejno branje davčnih računov in digitalni davčni račun ŠankFinder. |
| **Nastavitve** | Diagnostični center & DataStore | ✅ Deluje | Reaktivni limit lokalov (10, 25, 50, po meri), radij iskanja, diagnostika senzorjev in dovoljenj. |

---

## 2. Načrt: "Pivska Klapa" (Skupinsko šankanje, Chat & Live Lokacija)

### 2.1 Ali rabiva strežnik z bazo podatkov?
**DA, vendar na najenostavnejši, najhitrejši in najcenejši način.**
Za deljenje lokacije v živo in takojšen klepet med telefoni potrebujemo:
1. **Strežniški servis (Backend):** Posreduje koordinate in sporočila med telefoni prek **WebSockets** protokola v realnem času (zamiki < 50 ms).
2. **Bazo podatkov (Database):** Hrani začasne seje, sporočila in števce pijač za ta večer.

### 2.2 Ali lahko to teče na ISTEM strežniku kot OSRM (`sankfinder.sluga.me`)?
**DA! 100% priporočljivo je, da teče na istem strežniku!**
- Tvoj strežnik že ima javni IP, domeno `sankfinder.sluga.me`, Docker in urejen SSL certifikat (Caddy/Nginx).
- OSRM za Slovenijo porabi le ~300 MB RAM-a. Chat & Location strežnik v Node.js/Go pa porabi le **~30 do 50 MB RAM-a**. Skupaj bosta delovala brez kakršnihkoli težav.
- Vse ostane pod tvojo lastno kontrolo, brez naročnin na zunanje servise.

---

## 3. Tehnična Arhitektura Strežnika in Baze

```
+-------------------------------------------------------------------------+
|                  Tvoj Linux Strežnik (sankfinder.sluga.me)              |
|                                                                         |
|    Caddy / Nginx Obratni Proxy (Vrata 80 / 443 - SSL)                   |
|         │                                    │                          |
|         ├── /route/* (port 5000)             └── /api/* in /ws (port 8080)
|         ▼                                    ▼                          |
|    [Docker: osrm-sankfinder]            [Docker: sankfinder-squad-server]
|    (Izračun pešpoti)                    (Fastify / WebSockets + SQLite) 
|                                                      │                  |
|                                                      ▼                  |
|                                            [sankfinder_squad.db]        |
|                                            (Seje, Klepet, Lokacije)     |
+-------------------------------------------------------------------------+
```

### 3.1 Izbira baze: SQLite (Vgrajena, nič dodatne namestitve)
Za večerne pivske seje **NI** nobene potrebe po ločenem MySQL ali PostgreSQL strežniku.
- **SQLite** je ena sama datoteka (`sankfinder_squad.db`), ki jo Docker kontejner mounta na disk.
- Z vklopljenim WAL načinom (*Write-Ahead Logging*) zmore več kot **50.000 transakcij/s**.
- **Samodejno čiščenje:** Strežnik vsako uro samodejno pobriše seje in sporočila, starejša od 24 ur:
  ```sql
  DELETE FROM rooms WHERE created_at < datetime('now', '-24 hours');
  ```

### 3.2 Shema tabel (SQLite):

```sql
-- 1. SOBE / PIVSKE KLAPE
CREATE TABLE IF NOT EXISTS rooms (
    id TEXT PRIMARY KEY,           -- UUID sobe
    code TEXT UNIQUE NOT NULL,     -- 4-mestna koda za vstop (npr. 'PANK')
    name TEXT NOT NULL,           -- Ime skupine (npr. 'Ljubljana Night')
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 2. ČLANI SOBE
CREATE TABLE IF NOT EXISTS members (
    id TEXT PRIMARY KEY,           -- UUID uporabnika
    room_id TEXT NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
    name TEXT NOT NULL,           -- Ime člana (npr. 'Luka')
    lat REAL,                     -- Zadnja znana GPS širina
    lon REAL,                     -- Zadnja znana GPS dolžina
    drinks_count INTEGER DEFAULT 0, -- Število popitih pijač
    last_seen DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 3. CHAT SPOROČILA & DOGODKI
CREATE TABLE IF NOT EXISTS messages (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    room_id TEXT NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
    sender_name TEXT NOT NULL,
    message_type TEXT DEFAULT 'text', -- 'text', 'location_ping', 'round_call', 'eta'
    content TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

---

## 4. Navodila za postavitev na strežniku (Korak za korakom)

V korenski mapi projekta je pripravljena mapa `server/` s celotno kodo za zagon v Dockerju.

### 4.1 Prenos in zagon na Linux strežniku:
Na tvojem strežniku (kjer že teče OSRM):

```bash
# 1. Ustvari mapo za squad server
mkdir -p ~/sankfinder-squad && cd ~/sankfinder-squad

# 2. Kopiraj datoteke iz mape /server v repozitoriju (ali jih prenesi s scp/git)
# V mapi se nahajajo:
# - package.json
# - index.js
# - Dockerfile
# - docker-compose.yml

# 3. Zagon Docker kontejnerja:
docker compose up -d --build
```
Kontejner bo poslušal na vratih `8080`.

### 4.2 Nastavitev Caddy ali Nginx obratnega proxyja:

#### Če uporabljaš Caddy (`/etc/caddy/Caddyfile`):
Dodaj blok za vrata 8080 ob OSRM:
```caddyfile
sankfinder.sluga.me {
    # 1. OSRM navigacija
    handle /route/* {
        reverse_proxy localhost:5000
    }

    # 2. Squad REST API
    handle /api/* {
        reverse_proxy localhost:8080
    }

    # 3. WebSocket v živo za chat in radar prijateljev
    handle /ws* {
        reverse_proxy localhost:8080
    }
}
```
Uveljavi spremembo: `sudo systemctl reload caddy`.

#### Če uporabljaš Nginx:
```nginx
# V obstoječem server bloku za sankfinder.sluga.me dodaj:
location /api/ {
    proxy_pass http://localhost:8080;
    proxy_set_header Host $host;
}

location /ws {
    proxy_pass http://localhost:8080;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
}
```
Uveljavi spremembo: `sudo systemctl reload nginx`.

---

## 5. Protokol komunikacije (WebSocket JSON)

Povezava: `wss://sankfinder.sluga.me/ws?code=PANK&name=Anže&userId=user_123`

### A. Posodobitev lokacije (telefon pošlje vsakih 5-10 s):
```json
{
  "type": "location_update",
  "lat": 46.0468,
  "lon": 14.5015
}
```
Strežnik takoj pošlje vsem v sobi:
```json
{
  "type": "peer_location",
  "userId": "user_123",
  "name": "Anže",
  "lat": 46.0468,
  "lon": 14.5015
}
```

### B. Chat sporočilo ali hitra akcija:
```json
{
  "type": "chat_message",
  "content": "Jaz sem v Krakovcu, kje ste vi?"
}
```
Vsi v sobi prejmejo:
```json
{
  "type": "new_message",
  "senderName": "Anže",
  "content": "Jaz sem v Krakovcu, kje ste vi?",
  "timestamp": "22:15"
}
```

### C. Števec popitih rund ("Runda Tracker"):
```json
{
  "type": "drink_count_update",
  "delta": 1
}
```
Vsi v sobi prejmejo:
```json
{
  "type": "drinks_updated",
  "userId": "user_123",
  "name": "Anže",
  "drinksCount": 3
}
```

---

## 6. Načrt implementacije v Android aplikaciji

1. **Nov modul / Repozitorij:** `SquadRepository.kt` z `OkHttp` WebSocket odjemalcem.
2. **Nov ViewModel:** `SquadViewModel.kt` za upravljanje aktivne seje, seznama članov, koordinat in sporočil.
3. **Zaslon:**
   - Zavihek v Orodjih: *"Pivska klapa"*.
   - Pogled zemljevida: Izris dodatnih markerjev (ikonice piva/prijateljev) na [MapMainPage.kt](file:///c:/Android/SankFinder/app/src/main/java/com/example/sankfinder/ui/pages/MapMainPage.kt) poleg tvoje modre pike.
   - Spodnji plavajoči mini chat ali posvečena podstran s hitrimi gumbi (*"Naročil rundo"*, *"Pridem čez X min"*, *"Izgubil sem se"*).
