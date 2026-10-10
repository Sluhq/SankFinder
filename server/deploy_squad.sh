#!/bin/bash
set -e

echo "=========================================================="
echo "  🍻 ŠankFinder: Zagon Squad Chat & Live Location Server  "
echo "=========================================================="

mkdir -p data
docker compose up -d --build

echo ""
echo "Storitev uspešno zagnana v ozadju na vratih 8080!"
echo "Preverjanje statusa:"
curl -s http://localhost:8080/api/health || true
echo ""
echo "Za pregled logov zaženi: docker compose logs -f"
