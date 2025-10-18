#!/bin/bash

# Script to set up Grafana with proper datasources and dashboards for Docker environment

set -e

GRAFANA_URL="http://localhost:3000"
GRAFANA_USER="admin"
GRAFANA_PASS="admin"
PROMETHEUS_URL="http://prometheus:9090"  # Docker internal URL

echo "🔧 Setting up Grafana for Docker environment..."

# Wait for Grafana to be ready
echo "⏳ Waiting for Grafana to be ready..."
for i in {1..30}; do
    if curl -s "$GRAFANA_URL/api/health" >/dev/null 2>&1; then
        echo "✅ Grafana is ready"
        break
    fi
    echo "Waiting for Grafana... ($i/30)"
    sleep 2
done

# Delete existing datasource if it exists
echo "🗑️  Removing existing Prometheus datasource (if any)..."
curl -u "$GRAFANA_USER:$GRAFANA_PASS" -X DELETE "$GRAFANA_URL/api/datasources/uid/PBFA97CFB590B2093" 2>/dev/null || true

# Create Prometheus datasource with correct Docker URL
echo "🔌 Creating Prometheus datasource..."
curl -u "$GRAFANA_USER:$GRAFANA_PASS" -X POST \
    -H "Content-Type: application/json" \
    -d "{
        \"uid\": \"PBFA97CFB590B2093\",
        \"name\": \"Prometheus\",
        \"type\": \"prometheus\",
        \"url\": \"$PROMETHEUS_URL\",
        \"access\": \"proxy\",
        \"isDefault\": true
    }" \
    "$GRAFANA_URL/api/datasources"

echo
echo "🧪 Testing datasource connectivity..."
DATASOURCE_TEST=$(curl -u "$GRAFANA_USER:$GRAFANA_PASS" -s "$GRAFANA_URL/api/datasources/proxy/uid/PBFA97CFB590B2093/api/v1/query?query=up")
if echo "$DATASOURCE_TEST" | grep -q '"status":"success"'; then
    echo "✅ Datasource connectivity test passed"
else
    echo "❌ Datasource connectivity test failed:"
    echo "$DATASOURCE_TEST"
fi

# Import dashboard
echo "📊 Importing dashboard..."
if [ -f "grafana/docker-dashboard.json" ]; then
    DASHBOARD_RESPONSE=$(curl -u "$GRAFANA_USER:$GRAFANA_PASS" -X POST \
        -H "Content-Type: application/json" \
        -d @grafana/docker-dashboard.json \
        "$GRAFANA_URL/api/dashboards/db")
    
    if echo "$DASHBOARD_RESPONSE" | grep -q '"status":"success"'; then
        DASHBOARD_URL=$(echo "$DASHBOARD_RESPONSE" | jq -r '.url')
        echo "✅ Dashboard imported successfully"
        echo "🌐 Dashboard URL: $GRAFANA_URL$DASHBOARD_URL"
    else
        echo "❌ Dashboard import failed:"
        echo "$DASHBOARD_RESPONSE"
    fi
else
    echo "❌ Dashboard file not found: grafana/docker-dashboard.json"
fi

echo
echo "🎉 Grafana setup completed!"
echo "📝 Access Grafana at: $GRAFANA_URL"
echo "👤 Username: $GRAFANA_USER"
echo "🔒 Password: $GRAFANA_PASS"
echo
echo "🔍 To verify metrics are working:"
echo "   curl -u $GRAFANA_USER:$GRAFANA_PASS \"$GRAFANA_URL/api/datasources/proxy/uid/PBFA97CFB590B2093/api/v1/query?query=up\""
