FROM node:20-bookworm-slim

ENV NODE_ENV=production

# Native deps:
# - ffmpeg: frame grabbing
# - poppler-utils: PDF -> images for pdf-poppler
# - python3/pip: install yt-dlp
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ffmpeg \
    poppler-utils \
    python3 \
    python3-pip \
    ca-certificates \
  && pip3 install --no-cache-dir yt-dlp \
  && ln -sf "$(command -v yt-dlp)" /usr/local/bin/yt-plb \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm ci --omit=dev

COPY src ./src

EXPOSE 3001

CMD ["node", "src/server.js"]
