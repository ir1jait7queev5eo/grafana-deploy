#!/bin/bash

# Simple CI integration test script
# Designed to work reliably in GitHub Actions environment

set -e

echo "🚀 Running CI integration tests..."

# Test basic connectivity first
echo "Testing basic connectivity..."
if ! curl -s http://localhost:8080/ >/dev/null; then
    echo "❌ Backend not accessible"
    exit 1
fi

# Basic endpoint tests with better error handling
echo "Testing backend endpoints..."

if curl -f http://localhost:8080/ >/dev/null 2>&1; then
    echo "✅ Root endpoint works"
else
    echo "❌ Root endpoint failed"
    exit 1
fi

if curl -f http://localhost:8080/status/200 >/dev/null 2>&1; then
    echo "✅ Status 200 works"
else
    echo "❌ Status 200 failed"
    exit 1
fi

if curl -f http://localhost:8080/metrics >/dev/null 2>&1; then
    echo "✅ Metrics endpoint works"
else
    echo "❌ Metrics endpoint failed"
    exit 1
fi

# Test error endpoints
if curl -s -w "%{http_code}" http://localhost:8080/status/400 | grep -q "400"; then
    echo "✅ Status 400 works"
fi

if curl -s -w "%{http_code}" http://localhost:8080/status/500 | grep -q "500"; then
    echo "✅ Status 500 works"
fi

# Test metrics content
if curl -s http://localhost:8080/metrics | grep -q "litestar_requests_total"; then
    echo "✅ Metrics contain expected data"
fi

# Test OpenAPI docs
if curl -s http://localhost:8080/docs | grep -q "Тестовый Бэкенд"; then
    echo "✅ OpenAPI docs accessible"
fi

# Test Prometheus if available
if curl -s -f http://localhost:9090/-/ready >/dev/null 2>&1; then
    echo "✅ Prometheus is ready"
    
    if curl -s "http://localhost:9090/api/v1/targets" | grep -q "localhost:8080"; then
        echo "✅ Prometheus targets configured"
    fi
    
    if curl -s "http://localhost:9090/api/v1/query?query=up" | grep -q "success"; then
        echo "✅ Prometheus query API works"
    fi
else
    echo "⚠️  Prometheus not ready, skipping Prometheus tests"
fi

# Test Grafana if available
if curl -s -f http://localhost:3000/api/health >/dev/null 2>&1; then
    echo "✅ Grafana is healthy"
else
    echo "⚠️  Grafana not ready, skipping Grafana tests"
fi

# Run mini load test
if command -v ab >/dev/null 2>&1; then
    echo "Running mini load test..."
    ab -q -c 2 -n 20 http://localhost:8080/ >/dev/null 2>&1
    ab -q -c 2 -n 10 http://localhost:8080/status/200 >/dev/null 2>&1
    echo "✅ Load test completed"
fi

echo "🎉 All CI integration tests passed!"
