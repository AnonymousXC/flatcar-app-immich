#!/bin/bash
# =============================================================================
# Immich Health Check
# =============================================================================

set -euo pipefail

echo "=== Immich Health Check ==="
echo ""

# Check containers
all_ok=true
for container in immich-postgres immich-redis immich-server immich-ml immich-proxy; do
    if docker ps --format "{{.Names}}" | grep -q "^${container}$"; then
        echo "  ✓ ${container} is running"
    else
        echo "  ✗ ${container} is NOT running"
        all_ok=false
    fi
done

echo ""
echo "=== Disk Usage ==="
df -h /var/lib/immich

echo ""
echo "=== Memory Usage ==="
free -h

echo ""
echo "=== Immich API Status ==="
if curl -sf http://localhost:2283/api/server-info/ping > /dev/null 2>&1; then
    echo "  ✓ API is responding"
else
    echo "  ✗ API is not responding"
    all_ok=false
fi

echo ""
if $all_ok; then
    echo "All checks passed ✓"
    exit 0
else
    echo "Some checks failed ✗"
    exit 1
fi
