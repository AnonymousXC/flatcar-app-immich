#!/bin/bash
# =============================================================================
# Immich Restore Script
# Restores Immich from a backup snapshot
# Usage: sudo ./restore.sh <backup_name>
# =============================================================================

set -euo pipefail

BACKUP_NAME="${1:-}"
BACKUP_DIR="/var/lib/immich/backups"

if [[ -z "$BACKUP_NAME" ]]; then
    echo "Usage: $0 <backup_name>"
    echo "Available backups:"
    ls -1 "${BACKUP_DIR}" | grep "immich_backup_" || echo "  (none)"
    exit 1
fi

echo "WARNING: This will STOP Immich and restore from ${BACKUP_NAME}"
read -p "Are you sure? (yes/no): " confirm
if [[ "$confirm" != "yes" ]]; then
    echo "Aborted."
    exit 0
fi

echo "Stopping Immich services..."
systemctl stop immich-server immich-ml immich-proxy

# Restore upload data
if [[ -d "${BACKUP_DIR}/${BACKUP_NAME}_upload" ]]; then
    echo "Restoring upload data..."
    rm -rf /var/lib/immich/upload/*
    cp -a "${BACKUP_DIR}/${BACKUP_NAME}_upload"/* /var/lib/immich/upload/
fi

# Restore postgres data
if [[ -d "${BACKUP_DIR}/${BACKUP_NAME}_postgres" ]]; then
    echo "Restoring postgres data..."
    systemctl stop immich-postgres
    rm -rf /var/lib/immich/postgres/*
    cp -a "${BACKUP_DIR}/${BACKUP_NAME}_postgres"/* /var/lib/immich/postgres/
    systemctl start immich-postgres
fi

# Restore database dump (if snapshots aren't available)
if [[ -f "${BACKUP_DIR}/${BACKUP_NAME}_db.sql" ]]; then
    echo "Restoring database from SQL dump..."
    sleep 5  # Wait for postgres to start
    docker exec -i immich-postgres psql -U postgres -d immich < "${BACKUP_DIR}/${BACKUP_NAME}_db.sql"
fi

echo "Starting Immich services..."
systemctl start immich-server immich-ml immich-proxy

echo "Restore complete!"
