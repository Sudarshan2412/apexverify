FROM node:20-bookworm-slim

ENV NODE_ENV=production

# Native deps:
# - ffmpeg: frame grabbing
# - poppler-utils: PDF -> images for pdf-poppler
# - yt-dlp: resolve YouTube/VOD URLs
RUN set -eux; \
  apt-get update; \
  apt-get install -y --no-install-recommends \
    ffmpeg \
    poppler-utils \
    ca-certificates \
    curl; \
  rm -rf /var/lib/apt/lists/*; \
  curl -L "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux" -o /usr/local/bin/yt-dlp; \
  chmod 0755 /usr/local/bin/yt-dlp; \
  ln -sf /usr/local/bin/yt-dlp /usr/local/bin/yt-plb

WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm ci --omit=dev

COPY src ./src

EXPOSE 3001

CMD ["node", "src/server.js"]
