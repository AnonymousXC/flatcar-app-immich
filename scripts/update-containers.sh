#!/bin/bash
# =============================================================================
# Update Immich Containers
# Pulls latest images and restarts services
# =============================================================================

set -euo pipefail

echo "Pulling latest Immich images..."

for image in     "ghcr.io/immich-app/immich-server:release"     "ghcr.io/immich-app/immich-machine-learning:release"     "tensorchord/pgvecto-rs:pg14-v0.2.0"     "redis:6.2-alpine"     "nginx:alpine"; do
    echo "Pulling ${image}..."
    docker pull "${image}"
done

echo ""
echo "Restarting services to use new images..."
systemctl restart immich-proxy immich-server immich-ml immich-postgres immich-redis

echo ""
echo "Update complete! Check status with: systemctl status immich-server"
