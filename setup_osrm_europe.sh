#!/bin/bash
set -e

echo "=========================================================="
echo "  ŠankFinder: Postavitev OSRM za celotno EVROPO v Dockerju"
echo "=========================================================="
echo "POZOR: Zahteva vsaj 64 GB RAM-a (ali 32 GB RAM + 64 GB SWAP) in 200 GB SSD!"
read -p "Ali želiš nadaljevati? (y/N): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Prekinjeno."
    exit 1
fi

mkdir -p ~/osrm-europe
cd ~/osrm-europe

# 1. Prenos karte celotne Evrope
echo "[1/4] Prenašam karto Evrope (~30 GB) iz Geofabrika..."
wget --show-progress -O europe-latest.osm.pbf https://download.geofabrik.de/europe-latest.osm.pbf

# 2. Ekstrakcija s profilom za pešce
echo "[2/4] Ekstrakcija grafa za pešce (foot.lua) - to lahko traja več ur..."
docker run --rm -t -v "${PWD}:/data" ghcr.io/project-osrm/osrm-backend \
  osrm-extract -p /opt/foot.lua /data/europe-latest.osm.pbf

# 3. Particioniranje
echo "[3/4] Particioniranje grafa..."
docker run --rm -t -v "${PWD}:/data" ghcr.io/project-osrm/osrm-backend \
  osrm-partition /data/europe-latest.osrm

# 4. Prilagajanje uteži
echo "[4/4] Prilagajanje uteži z MLD..."
docker run --rm -t -v "${PWD}:/data" ghcr.io/project-osrm/osrm-backend \
  osrm-customize /data/europe-latest.osrm

# 5. Ustvarjanje docker-compose.yml z --mmap
cat << 'COMPOSE' > docker-compose.yml
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
COMPOSE

docker compose up -d

IP=$(hostname -I | awk '{print $1}')
echo ""
echo "=========================================================="
echo "  OSRM EVROPA uspešno teče na vratih 5000!"
echo "  URL za aplikacijo ŠankFinder: http://${IP}:5000"
echo "=========================================================="
