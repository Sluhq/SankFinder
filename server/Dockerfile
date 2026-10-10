FROM node:20-slim

# Namestitev osnovnih orodij za prevajanje sqlite3
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    make \
    g++ \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY package*.json ./
RUN npm install --omit=dev

COPY index.js ./

# Mapa za hrambo SQLite baze
RUN mkdir -p /app/data
ENV DATA_DIR=/app/data
ENV PORT=8080

EXPOSE 8080

CMD ["node", "index.js"]
