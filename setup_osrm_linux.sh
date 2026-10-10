#!/bin/bash
set -e

echo "=================================================="
echo "  ŠankFinder: Postavitev OSRM za pešce na Linuxu  "
echo "=================================================="

# 1. Priprava delovne mape
mkdir -p ~/osrm-sankfinder
cd ~/osrm-sankfinder

# 2. Prenos uradne karte Slovenije
echo "[1/5] Prenašam karto Slovenije (Geofabrik)..."
wget -q --show-progress -O slovenia-latest.osm.pbf https://download.geofabrik.de/europe/slovenia-latest.osm.pbf

# 3. Ekstrakcija s profilom za pešce
echo "[2/5] Ekstrakcija z OSRM profilom za pešce (foot.lua)..."
docker run --rm -t -v "${PWD}:/data" ghcr.io/project-osrm/osrm-backend osrm-extract -p /opt/foot.lua /data/slovenia-latest.osm.pbf

# 4. Particioniranje
echo "[3/5] Particioniranje grafa..."
docker run --rm -t -v "${PWD}:/data" ghcr.io/project-osrm/osrm-backend osrm-partition /data/slovenia-latest.osrm

# 5. Prilagajanje MLD uteži
echo "[4/5] Prilagajanje MLD uteži..."
docker run --rm -t -v "${PWD}:/data" ghcr.io/project-osrm/osrm-backend osrm-customize /data/slovenia-latest.osrm

# 6. Zapis docker-compose konfiguracije
echo "[5/5] Zagon trajnega servisa z Docker Compose..."
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

# Preverjanje IP naslova
IP=$(hostname -I | awk '{print $1}')

echo ""
echo "=================================================="
echo "  OSRM strežnik uspešno deluje na vratih 5000!   "
echo "  URL za testiranje v brskalniku ali telefonu:    "
echo "  http://${IP}:5000                              "
echo "=================================================="
