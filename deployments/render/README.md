# AresFeed — Docker + Render deployment

This folder contains a **single combined Docker image** that bundles everything
AresFeed needs to run on Render as one Web Service:

| Process      | Port | Notes                                                |
|--------------|------|------------------------------------------------------|
| Next.js web  | 3000 | Public port (Render sets `$PORT`). Proxies API calls server-side. |
| Go API       | 8080 | Internal. Serves `/healthz`, `/readyz`, `/metrics`.   |
| Go Gateway   | 8081 | Internal.                                            |
| Redis        | 6379 | Internal, in-container. **Optional** — the app degrades gracefully if it is unreachable. |

Only **port 3000** is published. The web server calls the Go API at
`http://localhost:8080` (server-side), so the browser only ever talks to the
web origin — no CORS / extra public ports required.

## Why a combined image?

- Render does **not** run `docker-compose.yml`.
- AresFeed needs **PostgreSQL + the `vector` extension** (its migrations run
  `CREATE EXTENSION vector`). Render's managed Postgres does **not** ship
  pgvector, so the database is provided externally (Neon — see below).
- Redis is optional, so running it inside the container avoids a second managed
  service and keeps the deploy to a single Web Service.

---

## 1. Local verification (no cloud needed)

```bash
# From repo root
docker build -f deployments/render/Dockerfile -t AresFeed:local .

# Postgres with pgvector (separate container)
docker run -d --name lf-pg \
  -e POSTGRES_USER=AresFeed -e POSTGRES_PASSWORD=AresFeed -e POSTGRES_DB=AresFeed \
  -p 5432:5432 pgvector/pgvector:pg16

# Wait ~5s for Postgres to accept connections, then run the app:
docker run -d --name lf-app -p 3000:3000 -p 8080:8080 \
  --add-host host.docker.internal:host-gateway \
  -e DATABASE_URL='postgres://AresFeed:AresFeed@host.docker.internal:5432/AresFeed?sslmode=disable' \
  -e REDIS_URL='redis://localhost:6379' \
  -e API_URL='http://localhost:8080' \
  -e SITE_URL='http://localhost:3000' \
  -e ALLOWED_ORIGINS='http://localhost:3000' \
  -e JWT_SECRET='dev-secret-change-me' \
  -e ENVIRONMENT=production -e LOG_LEVEL=info \
  -e API_PORT=8080 -e GATEWAY_PORT=8081 \
  AresFeed:local

# Health checks
curl -sS http://localhost:8080/healthz      # {"status":"ok"}
curl -sS -o /dev/null -w '%{http_code}\n' http://localhost:3000/   # 200
```

The entrypoint runs `migrate up` against `DATABASE_URL` on every start, so the
schema is always current.

---

## 2. Database: Neon (pgvector) — setup steps

1. Go to **https://neon.tech** and create a free project.
2. In the dashboard, open **Connection Details** and copy the
   **Connection string** (looks like
   `postgresql://<user>:<pass>@<project>.neon.tech/neondb?sslmode=require`).
3. That string is your `DATABASE_URL`. The container's entrypoint rewrites
   `postgresql://` → `postgres://` and forces `sslmode=require` automatically,
   and the migrations enable the `vector` extension on first run. No manual
   `CREATE EXTENSION` needed.
4. (Optional) Add the Neon project to your Render workspace's environment so
   `DATABASE_URL` stays in sync — but a plain pasted string works fine.

> Supabase is also fine (it ships pgvector). Use its **direct** host (not the
> pooler) and append `?sslmode=require`.

---

## 3. Deploy to Render

Two options. Both assume you have the image built (step 1) and a Neon
`DATABASE_URL`.

### Option A — push to a registry, deploy the image (recommended)

```bash
# Tag + push to GitHub Container Registry (or Docker Hub)
docker tag AresFeed:local ghcr.io/<you>/AresFeed:latest
docker push ghcr.io/<you>/AresFeed:latest
```

Then in the Render dashboard: **New → Web Service → Deploy an existing image**,
enter the image URL, and set the environment variables below. Or use
`deploy-render.sh` (fills them in via the CLI).

### Option B — let Render build from your fork's Dockerfile

Fork the repo, add these files (`deployments/render/*`, the updated
`.dockerignore`), push, then **New → Web Service → connect the repo**, choose
**Docker** as the runtime and `deployments/render/Dockerfile` as the
Dockerfile path.

### Required environment variables (Render)

| Key                | Example / notes                                                      |
|--------------------|----------------------------------------------------------------------|
| `DATABASE_URL`     | Neon connection string (with `sslmode=require`). **Required.**       |
| `JWT_SECRET`       | Strong random value, e.g. `openssl rand -base64 48`. **Required.**   |
| `REDIS_URL`        | `redis://localhost:6379` (in-container).                             |
| `API_URL`          | `http://localhost:8080`                                             |
| `SITE_URL`         | `https://<your-service>.onrender.com`                              |
| `ALLOWED_ORIGINS`  | `https://<your-service>.onrender.com`                              |
| `ENVIRONMENT`      | `production`                                                         |
| `LOG_LEVEL`        | `info`                                                              |
| `API_PORT`         | `8080`                                                              |
| `GATEWAY_PORT`     | `8081`                                                              |
| `FEDERATION_ENABLED` | `false` (default)                                                 |

Set **Health check path** to `/` (the web server). The free plan spins down
when idle and will show a TLS error until woken; use the **Starter** plan for
an always-on instance.

> Note: `NODE_ENV=production` and `PORT` are set automatically by the image /
> Render. Do **not** add `NODE_ENV=production` as a Render env var — it would
> prune dev dependencies during the build (not relevant for this image, but
> worth knowing).

---

## Files

- `Dockerfile` — multi-stage: Go builder → Next.js standalone builder →
  debian runtime with redis-server + supervisord + golang-migrate.
- `supervisord.conf` — runs redis, api, gateway, web.
- `entrypoint.sh` — normalizes `DATABASE_URL`, runs `migrate up`, then execs
  supervisord.
- `deploy-render.sh` — headless Render service creation via the `render` CLI.
