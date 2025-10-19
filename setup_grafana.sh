#!/bin/bash

# Simplified Grafana setup script

set -e

# Configuration
GRAFANA_URL="http://localhost:3000"
GRAFANA_USER="admin"
GRAFANA_PASS="admin"
PROMETHEUS_URL="http://prometheus:9090"
DATASOURCE_UID="PBFA97CFB590B2093"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}🔧${NC} $1"; }
success() { echo -e "${GREEN}✅${NC} $1"; }
error() { echo -e "${RED}❌${NC} $1"; }

# Helper function for Grafana API calls
grafana_api() {
    local method=$1
    local endpoint=$2
    local data=$3
    
    curl -s -u "$GRAFANA_USER:$GRAFANA_PASS" \
         -X "$method" \
         ${data:+-H "Content-Type: application/json" -d "$data"} \
         "$GRAFANA_URL/api/$endpoint"
}

log "Setting up Grafana..."

# Wait for Grafana
log "⏳ Waiting for Grafana to be ready..."
for i in {1..30}; do
    if grafana_api GET "health" >/dev/null 2>&1; then
        success "Grafana is ready"
        break
    fi
    [ $i -eq 30 ] && { error "Grafana failed to start"; exit 1; }
    echo "Waiting... ($i/30)"
    sleep 2
done

# Setup datasource
log "🔌 Setting up Prometheus datasource..."
grafana_api DELETE "datasources/uid/$DATASOURCE_UID" >/dev/null 2>&1 || true

DATASOURCE_JSON='{
    "uid": "'$DATASOURCE_UID'",
    "name": "Prometheus",
    "type": "prometheus",
    "url": "'$PROMETHEUS_URL'",
    "access": "proxy",
    "isDefault": true
}'

if grafana_api POST "datasources" "$DATASOURCE_JSON" | grep -q "id"; then
    success "Datasource created"
else
    error "Failed to create datasource"
    exit 1
fi

# Test connectivity
if grafana_api GET "datasources/proxy/uid/$DATASOURCE_UID/api/v1/query?query=up" | grep -q "success"; then
    success "Datasource connectivity verified"
else
    error "Datasource connectivity failed"
fi

# Import dashboards
log "📊 Importing dashboards..."
for dashboard_file in grafana/dashboards/*.json; do
    if [ -f "$dashboard_file" ]; then
        dashboard_name=$(basename "$dashboard_file")
        if grafana_api POST "dashboards/db" "@$dashboard_file" | grep -q "id"; then
            success "Imported $dashboard_name"
        else
            error "Failed to import $dashboard_name"
        fi
    fi
done

echo
success "🎉 Grafana setup completed!"
echo "📝 Access: $GRAFANA_URL (admin/admin)"
echo "🔍 Test: curl -u admin:admin \"$GRAFANA_URL/api/datasources/proxy/uid/$DATASOURCE_UID/api/v1/query?query=up\""
