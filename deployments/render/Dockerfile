# syntax=docker/dockerfile:1
#
# Single combined image for AresFeed on Render.
# Bundles: Go API (8080) + Go Gateway (8081) + Next.js web (3000) + in-container Redis.
# Only port 3000 is published by Render; the web server proxies API calls
# server-side to http://localhost:8080, so no other port needs to be public.
#
# External dependency: a PostgreSQL database WITH the `vector` extension
# (Neon / Supabase both provide pgvector). Set DATABASE_URL accordingly.
# Redis is OPTIONAL — if REDIS_URL is unreachable the app disables caching
# and rate-limiting gracefully, but we run an in-container redis for full
# functionality without a second managed service.

# ---------- Go builder ----------
FROM golang:1.25-alpine AS go-builder
RUN apk add --no-cache git ca-certificates
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /out/api ./cmd/api
RUN CGO_ENABLED=0 GOOS=linux go build -o /out/gateway ./cmd/gateway

# ---------- Web (Next.js standalone) builder ----------
FROM node:22-alpine AS web-builder
WORKDIR /web
COPY web/package*.json ./
RUN npm ci
COPY web/ ./
ARG API_URL=http://localhost:8080
ARG SITE_URL=http://localhost:3000
ENV API_URL=$API_URL
ENV SITE_URL=$SITE_URL
RUN npm run build

# ---------- Runtime ----------
# node:22-bookworm-slim gives us the Node runtime the Next.js standalone
# server needs, plus a Debian base for redis-server + supervisord.
FROM node:22-bookworm-slim
ENV NODE_ENV=production
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    tzdata \
    redis-server \
    supervisor \
    procps \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Go services
COPY --from=go-builder /out/api /usr/local/bin/api
COPY --from=go-builder /out/gateway /usr/local/bin/gateway

# golang-migrate CLI (postgres + file drivers baked in).
# Pick the architecture matching the build host so the binary actually runs.
RUN ARCH=$(uname -m); \
    case "$ARCH" in \
      x86_64)  M=amd64 ;; \
      aarch64) M=arm64 ;; \
      arm64)   M=arm64 ;; \
      *)       M=amd64 ;; \
    esac; \
    curl -fsSL "https://github.com/golang-migrate/migrate/releases/download/v4.18.1/migrate.linux-${M}.tar.gz" -o /tmp/migrate.tgz \
    && tar -xzf /tmp/migrate.tgz -C /tmp \
    && mv /tmp/migrate /usr/local/bin/migrate \
    && chmod +x /usr/local/bin/migrate \
    && rm -f /tmp/migrate.tgz

# Next.js standalone output
COPY --from=web-builder /web/.next/standalone ./
COPY --from=web-builder /web/.next/static ./.next/static
COPY --from=web-builder /web/public ./public

# Migrations + process manager + entrypoint
COPY migrations ./migrations
COPY deployments/render/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY deployments/render/entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh && mkdir -p /app/uploads

EXPOSE 3000 8080 8081

ENTRYPOINT ["/app/entrypoint.sh"]
