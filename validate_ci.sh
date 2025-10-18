#!/bin/bash

# Local CI validation script
# This script mimics what happens in GitHub Actions

set -e

echo "🔍 Validating CI pipeline locally..."
echo

# Step 1: Unit tests
echo "📋 Step 1: Running unit tests..."
cd backend
if [ ! -d "env" ]; then
    python -m env env
    source env/bin/activate
    pip install -r req.txt
    pip install pytest pytest-asyncio httpx pytest-cov
else
    source env/bin/activate
fi

python -m pytest tests/ -v --cov=. || {
    echo "❌ Unit tests failed"
    exit 1
}
echo "✅ Unit tests passed"
cd ..

# Step 2: Docker build test
echo "📦 Step 2: Testing Docker build..."
cd backend
docker build -t monitoring-backend:ci-test . || {
    echo "❌ Docker build failed"
    exit 1
}
echo "✅ Docker build succeeded"
cd ..

# Step 3: Integration test
echo "🔗 Step 3: Running integration tests..."

# Start backend locally for testing
cd backend
source env/bin/activate
python main.py &
BACKEND_PID=$!
cd ..

# Wait for backend to start
echo "Waiting for backend to start..."
sleep 10

# Test endpoints
if curl -f http://localhost:8080/ >/dev/null 2>&1; then
    echo "✅ Root endpoint works"
else
    echo "❌ Root endpoint failed"
    kill $BACKEND_PID 2>/dev/null || true
    exit 1
fi

if curl -f http://localhost:8080/status/200 >/dev/null 2>&1; then
    echo "✅ Status endpoint works"
else
    echo "❌ Status endpoint failed"
    kill $BACKEND_PID 2>/dev/null || true
    exit 1
fi

if curl -f http://localhost:8080/metrics >/dev/null 2>&1; then
    echo "✅ Metrics endpoint works"
else
    echo "❌ Metrics endpoint failed"
    kill $BACKEND_PID 2>/dev/null || true
    exit 1
fi

# Check metrics content
if curl -s http://localhost:8080/metrics | grep -q "litestar_requests_total"; then
    echo "✅ Metrics contain expected data"
else
    echo "❌ Metrics missing expected data"
    kill $BACKEND_PID 2>/dev/null || true
    exit 1
fi

# Cleanup
kill $BACKEND_PID 2>/dev/null || true

echo
echo "🎉 All CI validation tests passed!"
echo "📊 Summary:"
echo "  ✅ Unit tests: PASSED"
echo "  ✅ Docker build: PASSED"
echo "  ✅ API endpoints: PASSED"
echo "  ✅ Metrics: PASSED"
echo
echo "🚀 CI pipeline is ready for GitHub Actions!"
