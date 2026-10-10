#!/bin/bash
set -e

echo "=========================================================="
echo "  ŠankFinder: Postavitev OSRM za REGIJO (SLO+HR+AT+IT)    "
echo "=========================================================="

mkdir -p ~/osrm-region
cd ~/osrm-region

# 1. Namestitev osmium-tool, če še ni
if ! command -v osmium &> /dev/null; then
    echo "Nameščam osmium-tool..."
    sudo apt update && sudo apt install -y osmium-tool
fi

# 2. Prenos posameznih držav
echo "[1/5] Prenašam karte Slovenije, Hrvaške in Avstrije..."
wget -q --show-progress -O slovenia.osm.pbf https://download.geofabrik.de/europe/slovenia-latest.osm.pbf
wget -q --show-progress -O croatia.osm.pbf https://download.geofabrik.de/europe/croatia-latest.osm.pbf
wget -q --show-progress -O austria.osm.pbf https://download.geofabrik.de/europe/austria-latest.osm.pbf

# 3. Združitev v eno karto
echo "[2/5] Združujem karte v regijsko datoteko (osmium merge)..."
osmium merge slovenia.osm.pbf croatia.osm.pbf austria.osm.pbf -o region-latest.osm.pbf
rm slovenia.osm.pbf croatia.osm.pbf austria.osm.pbf

# 4. Ekstrakcija s profilom za pešce
echo "[3/5] Ekstrakcija grafa za pešce (foot.lua)..."
docker run --rm -t -v "${PWD}:/data" ghcr.io/project-osrm/osrm-backend \
  osrm-extract -p /opt/foot.lua /data/region-latest.osm.pbf

# 5. Particioniranje in prilagoditev uteži
echo "[4/5] Particioniranje in MLD prilagajanje..."
docker run --rm -t -v "${PWD}:/data" ghcr.io/project-osrm/osrm-backend \
  osrm-partition /data/region-latest.osrm

docker run --rm -t -v "${PWD}:/data" ghcr.io/project-osrm/osrm-backend \
  osrm-customize /data/region-latest.osrm

# 6. Docker Compose zagon
echo "[5/5] Ustvarjanje docker-compose.yml in zagon..."
cat << 'COMPOSE' > docker-compose.yml
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
COMPOSE

docker compose up -d

IP=$(hostname -I | awk '{print $1}')
echo ""
echo "=========================================================="
echo "  OSRM regijski strežnik uspešno teče na vratih 5000!     "
echo "  URL za aplikacijo ŠankFinder: http://${IP}:5000          "
echo "=========================================================="
