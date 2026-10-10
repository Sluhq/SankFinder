# Navodila za postavitev OSRM strežnika na Linuxu z Dockerjem (Peš navigacija za ŠankFinder)

Ta navodila te po korakih vodijo skozi vzpostavitev lastnega **OSRM (Open Source Routing Machine)** strežnika na Linuxu (Ubuntu, Debian, Fedora, domači strežnik, VPS ali namenskem strežniku) za računanje pešpoti v aplikaciji **ŠankFinder**.

---

## 0. Pogosto vprašanje: Ali rabim Virtualko (VM) ali zadostuje Kontejner (Docker)?

### **Kratek odgovor: Docker kontejner je popolnoma dovolj!**

- **Virtualka (Virtual Machine / VM)**: NI potrebna, razen če sploh nimaš Linuxa in želiš zagnati Linux znotraj Windows/macOS (vendar lahko na Windows uporabiš kar **WSL2 + Docker Desktop**). Polna virtualka porabi več virov, ker poganja celoten operacijski sistem in kernel od začetka.
- **Docker kontejner**: Je priporočljiv in standarden način. Kontejner teče neposredno na jedru operacijskega sistema, porabi minimalno sistemskih sredstev in omogoča takojšnje posodobitve brez zapletov.

### ⚠️ Pomembno opozorilo glede strojnih zahtev (Slovenija vs. Cela Evropa)

Čeprav kontejner zadostuje, je razlika med Slovenijo in celo Evropo **ogromna**:

| Kriterij | Slovenija (`slovenia-latest`) | Regija (SLO + HR + AT + IT) | **Celotna Evropa (`europe-latest`)** |
|---|---|---|---|
| **Velikost PBF datoteke** | ~65 MB | ~3.5 GB | **~28 do 30 GB** |
| **RAM med obdelavo** | < 1 GB | ~8 do 16 GB | **64 do 128 GB RAM** (ali 32 GB + 64 GB NVMe SWAP) |
| **Potreben SSD prostor** | ~500 MB | ~20 GB | **150 do 250 GB hitrega SSD** |
| **Čas priprave** | ~30 do 60 sekund | ~10 do 25 minut | **4 do 12 ur** (odvisno od CPU) |
| **RAM med tekom (Routing)** | ~300 MB | ~2 do 4 GB | **~35 do 50 GB** (ali z `--mmap` manj) |

> [!WARNING]
> Če želiš procesirati **celotno Evropo**, tvoj računalnik/strežnik **MORA** imeti vsaj **64 GB RAM-a** (ali močan NVMe SSD s 64 GB SWAP-om) ter 200+ GB prostega prostora! V nasprotnem primeru bo proces zrušil Linux z napako `Out of memory (OOM Killed)` ali `std::bad_alloc`.
> 
> Če nimaš tako močnega strežnika, je **najboljša izbira REGIONALNA karta** (SLO + sosednje države) – navodila so spodaj v razdelku 3!

---

## 1. Kaj potrebuješ na Linuxu (Osnovna priprava)

1. **Linux distribucija**: Ubuntu (20.04, 22.04, 24.04), Debian 11/12 ali katerikoli drug sodoben Linux (ali WSL2 na Windows).
2. **Nameščen Docker in Docker Compose**:
   ```bash
   sudo apt update
   sudo apt install -y docker.io docker-compose-v2 curl wget osmium-tool
   # Dovoljenje za poganjanje Dockerja brez sudo:
   sudo usermod -aG docker $USER
   newgrp docker
   ```
3. **Odprta vrata v požarnem zidu (Port 5000)**:
   ```bash
   sudo ufw allow 5000/tcp
   ```

---

## 2. Postavitev za CELOTNO EVROPO (`europe-latest`)

Uporabi ta postopek, če imaš strežnik z vsaj **64 GB RAM-a** (npr. Hetzner Dedicated strežnik ali močno delovno postajo) in **200+ GB prostora na hitrem SSD-ju**.

### Korak 1: Priprava delovne mape in SWAP spomina (če imaš 32–64 GB RAM)
```bash
mkdir -p ~/osrm-europe
cd ~/osrm-europe

# Če nimaš 128 GB RAM-a, obvezno ustvari 64 GB swap datoteko na hitrem SSD-ju:
sudo fallocate -l 64G /swapfile_osrm
sudo chmod 600 /swapfile_osrm
sudo mkswap /swapfile_osrm
sudo swapon /swapfile_osrm
```

### Korak 2: Prenos zemljevida celotne Evrope (~30 GB)
Prenos traja nekaj minut ali ur glede na tvojo internetno povezavo:
```bash
wget --show-progress -O europe-latest.osm.pbf https://download.geofabrik.de/europe-latest.osm.pbf
```

### Korak 3: Ekstrakcija grafa za pešce (`foot.lua`)
Ker je zemljevid ogromen, uporabimo profil za pešce:
```bash
docker run --rm -t -v "${PWD}:/data" ghcr.io/project-osrm/osrm-backend \
  osrm-extract -p /opt/foot.lua /data/europe-latest.osm.pbf
```
*(Ta korak lahko traja od 2 do 6 ur, odvisno od števila jeder procesorja in hitrosti diska!)*

### Korak 4: Particioniranje grafa
```bash
docker run --rm -t -v "${PWD}:/data" ghcr.io/project-osrm/osrm-backend \
  osrm-partition /data/europe-latest.osrm
```

### Korak 5: Prilagoditev MLD uteži
```bash
docker run --rm -t -v "${PWD}:/data" ghcr.io/project-osrm/osrm-backend \
  osrm-customize /data/europe-latest.osrm
```

### Korak 6: Trajni zagon z Docker Compose (z zastavico `--mmap`)
Pri celotni Evropi je ključno uporabiti zastavico `--mmap`, da operacijski sistem preslika datoteke iz SSD diska po potrebi in ne preobremeni RAM-a na silo:

Ustvari `docker-compose.yml`:
```yaml
services:
  osrm-europe:
    image: ghcr.io/project-osrm/osrm-backend
    container_name: osrm-europe
    restart: unless-stopped
    ports:
      - "5000:5000"
    volumes:
      - ./:/data
    command: osrm-routed --algorithm mld --mmap /data/europe-latest.osrm
```

Zagon:
```bash
docker compose up -d
```

---

## 3. PAMETNA ALTERNATIVA: Regijska karta (Slovenija + sosednje države)

Če imaš običajen domači strežnik ali cenejši VPS (npr. **8 do 16 GB RAM-a**), je celotna Evropa pretežka. Za aplikacijo ŠankFinder pa običajno zadoščajo Slovenija, Hrvaška, Avstrija in Italija!

Te države preprosto združiš z enim ukazom orodja `osmium`:

### Korak 1: Priprava mape
```bash
mkdir -p ~/osrm-region
cd ~/osrm-region
```

### Korak 2: Prenos želenih držav (Geofabrik)
```bash
wget -q --show-progress -O slovenia.osm.pbf https://download.geofabrik.de/europe/slovenia-latest.osm.pbf
wget -q --show-progress -O croatia.osm.pbf https://download.geofabrik.de/europe/croatia-latest.osm.pbf
wget -q --show-progress -O austria.osm.pbf https://download.geofabrik.de/europe/austria-latest.osm.pbf
# Če želiš še Italijo (~2 GB) ali Madžarsko (~150 MB):
# wget -q --show-progress -O hungary.osm.pbf https://download.geofabrik.de/europe/hungary-latest.osm.pbf
```

### Korak 3: Združitev v eno regijsko karto
```bash
osmium merge slovenia.osm.pbf croatia.osm.pbf austria.osm.pbf -o region-latest.osm.pbf
# Po združitvi lahko posamezne datoteke pobrišeš, da prihraniš prostor:
rm slovenia.osm.pbf croatia.osm.pbf austria.osm.pbf
```

### Korak 4: Obdelava z OSRM Dockerjem
```bash
# 1. Ekstrakcija za pešce
docker run --rm -t -v "${PWD}:/data" ghcr.io/project-osrm/osrm-backend osrm-extract -p /opt/foot.lua /data/region-latest.osm.pbf

# 2. Particioniranje
docker run --rm -t -v "${PWD}:/data" ghcr.io/project-osrm/osrm-backend osrm-partition /data/region-latest.osrm

# 3. Prilagajanje uteži
docker run --rm -t -v "${PWD}:/data" ghcr.io/project-osrm/osrm-backend osrm-customize /data/region-latest.osrm
```

### Korak 5: Zagon storitve
Ustvari `docker-compose.yml`:
```yaml
services:
  osrm-region:
    image: ghcr.io/project-osrm/osrm-backend
    container_name: osrm-region
    restart: unless-stopped
    ports:
      - "5000:5000"
    volumes:
      - ./:/data
    command: osrm-routed --algorithm mld /data/region-latest.osrm
```

Zagon:
```bash
docker compose up -d
```

---

## 4. Postavitev samo za Slovenijo (Najhitrejša možnost, < 1 min)

Če rabiš strežnik takoj in le za Slovenijo, je to narejeno v 60 sekundah:

```bash
mkdir -p ~/osrm-slovenia && cd ~/osrm-slovenia
wget -q --show-progress -O slovenia-latest.osm.pbf https://download.geofabrik.de/europe/slovenia-latest.osm.pbf
docker run --rm -t -v "${PWD}:/data" ghcr.io/project-osrm/osrm-backend osrm-extract -p /opt/foot.lua /data/slovenia-latest.osm.pbf
docker run --rm -t -v "${PWD}:/data" ghcr.io/project-osrm/osrm-backend osrm-partition /data/slovenia-latest.osrm
docker run --rm -t -v "${PWD}:/data" ghcr.io/project-osrm/osrm-backend osrm-customize /data/slovenia-latest.osrm

cat << 'COMPOSE' > docker-compose.yml
services:
  osrm-sankfinder:
    image: ghcr.io/project-osrm/osrm-backend
    container_name: osrm-sankfinder
    restart: unless-stopped
    ports:
      - "5000:5000"
    volumes:
      - ./:/data
    command: osrm-routed --algorithm mld /data/slovenia-latest.osrm
COMPOSE

docker compose up -d
```

---

## 5. Preverjanje delovanja (Test s cURL)

Preveri, da strežnik odgovarja na peš navigacijo:

```bash
# Test v Ljubljani:
curl "http://localhost:5000/route/v1/foot/14.5058,46.0569;14.5033,46.0483?overview=full&geometries=geojson"
```

Odgovor bo vseboval točne koordinate poti (`LineString`), čas hoje v sekundah in razdaljo v metrih.

---

## 6. Kako povezati ŠankFinder (Android aplikacijo)

V aplikaciji ŠankFinder je v `AndroidManifest.xml` že vklopljena podpora `android:usesCleartextTraffic="true"`, kar omogoča HTTP povezave.

1. **Če je strežnik v lokalnem WiFi omrežju**:
   - Izpiši IP na Linuxu: `hostname -I | awk '{print $1}'` (npr. `192.168.1.150`)
   - URL: `http://192.168.1.150:5000`
2. **Če je strežnik na zunanjem VPS (Hetzner, AWS...)**:
   - URL: `http://<JAVNI_IP>:5000` ali z Nginx domeno `https://osrm.tvojadomena.com`
3. **Če poganjaš Android Emulator na istem PC-ju**:
   - URL: `http://10.0.2.2:5000`

---

## 7. Hitri ukazi za upravljanje

| Namen | Ukaz |
|---|---|
| Pregled logov v živo | `docker compose logs -f` |
| Zaustavitev strežnika | `docker compose down` |
| Ponovni zagon | `docker compose restart` |
| Poraba pomnilnika in procesorja | `docker stats` |
