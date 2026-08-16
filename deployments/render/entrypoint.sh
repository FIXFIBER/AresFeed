#!/bin/sh
set -eu

# ---------------------------------------------------------------------------
# 1. Run database migrations against DATABASE_URL before starting services.
#    golang-migrate needs the `postgres://` scheme and (for Neon/Supabase)
#    `sslmode=require`. Normalize the app's DATABASE_URL for the CLI.
# ---------------------------------------------------------------------------
MIG_URL="${DATABASE_URL:-}"

if [ -z "$MIG_URL" ]; then
  echo "ERROR: DATABASE_URL is not set. Cannot run migrations." >&2
  exit 1
fi

# postgres:// is what golang-migrate expects (not postgresql://)
MIG_URL=$(printf '%s' "$MIG_URL" | sed -E 's#^postgresql:#postgres:#')

# Ensure TLS is requested when talking to a managed Postgres (Neon/Supabase)
case "$MIG_URL" in
  *sslmode=*) ;;
  *'?'*)      MIG_URL="${MIG_URL}&sslmode=require" ;;
  *)          MIG_URL="${MIG_URL}?sslmode=require" ;;
esac

# Neon's *pooler* connection strings carry channel_binding=require, which
# golang-migrate's lib/pq driver does not need and can reject. Drop it.
MIG_URL=$(printf '%s' "$MIG_URL" | sed -E 's/[?&]channel_binding=[^&]*//; s/\?$//')

echo "==> Applying database migrations (may take a moment)…"
if migrate -path /app/migrations -database "$MIG_URL" up; then
  echo "==> Migrations applied."
else
  echo "ERROR: migrations failed. Check DATABASE_URL / network." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# 2. Hand off to supervisord (redis + api + gateway + web).
# ---------------------------------------------------------------------------
echo "==> Starting services via supervisord…"
exec supervisord -n -c /etc/supervisor/conf.d/supervisord.conf
