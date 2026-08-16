#!/usr/bin/env bash
#
# Deploy AresFeed to Render as a single Web Service running the combined image.
# Uses the `render` CLI (already authenticated in this environment).
#
# Usage:
#   DATABASE_URL='postgres://...' JWT_SECRET='...' SITE_URL='https://xxx.onrender.com' \
#     ./deploy-render.sh
#
# The image must already be pushed to a registry Render can pull:
#   docker tag AresFeed:local ghcr.io/<you>/AresFeed:latest
#   docker push ghcr.io/<you>/AresFeed:latest
# Make the repo PUBLIC, or pass REGISTRY_CREDENTIAL below.

set -euo pipefail

# ---- Configuration (override via env) -------------------------------------
IMAGE="${IMAGE:-ghcr.io/fixfiber/AresFeed:latest}"
SERVICE_NAME="${SERVICE_NAME:-AresFeed}"
PLAN="${PLAN:-free}"                 # 'starter' for always-on (needs card on file)
REGION="${REGION:-oregon}"
HEALTH_PATH="${HEALTH_PATH:-/}"

# ---- Required secrets ------------------------------------------------------
DATABASE_URL="${DATABASE_URL:?Set DATABASE_URL to your Neon/Supabase pgvector connection string}"
JWT_SECRET="${JWT_SECRET:?Set JWT_SECRET to a strong random value (openssl rand -base64 48)}"
SITE_URL="${SITE_URL:?Set SITE_URL to the public Render URL, e.g. https://AresFeed.onrender.com}"

# Public origin the browser uses (same as SITE_URL for a single-origin deploy)
ALLOWED_ORIGINS="${ALLOWED_ORIGINS:-$SITE_URL}"

# Optional: name of a Render registry credential if the image is private
REGISTRY_CREDENTIAL="${REGISTRY_CREDENTIAL:-}"

# ---- Build env var flags ---------------------------------------------------
ENV_VARS=(
  "DATABASE_URL=$DATABASE_URL"
  "JWT_SECRET=$JWT_SECRET"
  "REDIS_URL=redis://localhost:6379"
  "API_URL=http://localhost:8080"
  "SITE_URL=$SITE_URL"
  "ALLOWED_ORIGINS=$ALLOWED_ORIGINS"
  "ENVIRONMENT=production"
  "LOG_LEVEL=info"
  "API_PORT=8080"
  "GATEWAY_PORT=8081"
  "FEDERATION_ENABLED=false"
)

FLAGS=(--type web_service --runtime docker --image "$IMAGE" --name "$SERVICE_NAME"
       --plan "$PLAN" --region "$REGION" --health-check-path "$HEALTH_PATH" --auto-deploy --confirm)
for v in "${ENV_VARS[@]}"; do FLAGS+=(--env-var "$v"); done
if [ -n "$REGISTRY_CREDENTIAL" ]; then FLAGS+=(--registry-credential "$REGISTRY_CREDENTIAL"); fi

echo "==> Creating Render service '$SERVICE_NAME' from $IMAGE"
render services create "${FLAGS[@]}" -o json
echo ""
echo "==> Done. Watch the build & runtime logs in the Render dashboard."
echo "    Health check: $SITE_URL/  (HTTP 200 expected)"
