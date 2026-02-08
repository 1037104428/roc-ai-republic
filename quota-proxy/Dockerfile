FROM node:22-bookworm-slim
WORKDIR /app

# better-sqlite3 may need native build tools if no prebuild is available.
RUN apt-get update \
  && apt-get install -y --no-install-recommends python3 make g++ \
  && rm -rf /var/lib/apt/lists/*

COPY package.json package-lock.json* ./
RUN npm ci --omit=dev
COPY server.js ./
EXPOSE 8787
CMD ["node","/app/server.js"]
