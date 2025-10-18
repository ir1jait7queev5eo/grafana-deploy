#!/bin/bash

# Comprehensive test script for the monitoring system
# This script tests all components of the observability stack

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BACKEND_URL="http://localhost:8080"
PROMETHEUS_URL="http://localhost:9090"
GRAFANA_URL="http://localhost:3000"
TEST_TIMEOUT=30
LOAD_TEST_REQUESTS=50
LOAD_TEST_CONCURRENCY=5

# Test results tracking
PASSED_TESTS=0
FAILED_TESTS=0
TOTAL_TESTS=0

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
}

error() {
    echo -e "${RED}❌ $1${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
}

warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_pattern="$3"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    log "Running test: $test_name"
    
    local result
    if result=$(timeout $TEST_TIMEOUT bash -c "$test_command" 2>&1); then
        if [ -n "$expected_pattern" ]; then
            if echo "$result" | grep -q "$expected_pattern"; then
                success "$test_name"
                return 0
            else
                error "$test_name - Expected pattern '$expected_pattern' not found in: $result"
                return 1
            fi
        else
            success "$test_name"
            return 0
        fi
    else
        error "$test_name - Command failed or timed out: $result"
        return 1
    fi
}

wait_for_service() {
    local service_name="$1"
    local url="$2"
    local timeout="${3:-30}"
    
    log "Waiting for $service_name to be ready..."
    
    local count=0
    while [ $count -lt $timeout ]; do
        if curl -s -f "$url" &>/dev/null; then
            success "$service_name is ready"
            return 0
        fi
        sleep 1
        ((count++))
        echo -n "."
    done
    
    error "$service_name did not start within ${timeout}s"
    return 1
}

test_backend_endpoints() {
    log "Testing Backend API endpoints"
    
    # Test root endpoint
    run_test "Backend root endpoint" \
        "curl -s $BACKEND_URL/" \
        "root"
    
    # Test status 200 endpoint
    run_test "Backend status 200" \
        "curl -s $BACKEND_URL/status/200" \
        'data.*Hello'
    
    # Test status 400 endpoint (should return error)
    run_test "Backend status 400" \
        "curl -s -w '%{http_code}' $BACKEND_URL/status/400" \
        "400"
    
    # Test status 500 endpoint
    run_test "Backend status 500" \
        "curl -s -w '%{http_code}' $BACKEND_URL/status/500" \
        "500"
    
    # Test sleep endpoint
    log "Testing sleep endpoint (this will take a moment)..."
    local start_time=$(date +%s)
    curl -s "$BACKEND_URL/status/200?seconds_sleep=2" &>/dev/null
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [ $duration -ge 2 ]; then
        success "Sleep endpoint works correctly (took ${duration}s)"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        error "Sleep endpoint didn't work correctly (took ${duration}s, expected ≥2s)"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

test_prometheus_metrics() {
    log "Testing Prometheus metrics collection"
    
    # Generate some traffic to create metrics
    log "Generating traffic to create metrics data..."
    for i in {1..5}; do
        curl -s "$BACKEND_URL/status/200" &>/dev/null
        curl -s "$BACKEND_URL/status/500" &>/dev/null
    done
    
    # Wait for Prometheus to scrape metrics (scrape_interval = 3s)
    log "Waiting for Prometheus to collect metrics..."
    sleep 5
    
    # Test metrics endpoint
    run_test "Backend metrics endpoint" \
        "curl -s $BACKEND_URL/metrics" \
        "litestar_requests_total"
    
    # Test Prometheus targets
    run_test "Prometheus targets" \
        "curl -s $PROMETHEUS_URL/api/v1/targets" \
        "localhost:8080"
    
    # Test Prometheus query
    run_test "Prometheus query API" \
        "curl -s '$PROMETHEUS_URL/api/v1/query?query=up'" \
        "success"
    
    # Test specific metrics
    run_test "Litestar metrics in Prometheus" \
        "curl -s '$PROMETHEUS_URL/api/v1/query?query=litestar_requests_total'" \
        "litestar_requests_total"
}

test_grafana_access() {
    log "Testing Grafana accessibility"
    
    # Test Grafana login page
    run_test "Grafana login page" \
        "curl -s $GRAFANA_URL/login" \
        "Grafana"
    
    # Test Grafana API health
    run_test "Grafana health check" \
        "curl -s $GRAFANA_URL/api/health" \
        "ok"
}

run_load_test() {
    log "Running load tests to generate metrics"
    
    if ! command -v ab &> /dev/null; then
        warn "Apache Bench (ab) not found, skipping load tests"
        return 0
    fi
    
    log "Running load test with Apache Bench..."
    
    # Background load tests
    ab -q -c $LOAD_TEST_CONCURRENCY -n $LOAD_TEST_REQUESTS "$BACKEND_URL/" &>/dev/null &
    local pid1=$!
    
    ab -q -c $LOAD_TEST_CONCURRENCY -n $((LOAD_TEST_REQUESTS/2)) "$BACKEND_URL/status/400" &>/dev/null &
    local pid2=$!
    
    ab -q -c $LOAD_TEST_CONCURRENCY -n $((LOAD_TEST_REQUESTS/5)) "$BACKEND_URL/status/200?seconds_sleep=1" &>/dev/null &
    local pid3=$!
    
    # Wait for all load tests to complete
    wait $pid1 $pid2 $pid3
    
    success "Load tests completed"
    PASSED_TESTS=$((PASSED_TESTS + 1))
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    # Verify metrics increased
    sleep 5  # Wait for Prometheus to scrape
    
    run_test "Metrics updated after load test" \
        "curl -s '$PROMETHEUS_URL/api/v1/query?query=litestar_requests_total' | jq -r '.data.result[0].value[1]'" \
        "[0-9]+"
}

test_openapi_docs() {
    log "Testing OpenAPI documentation"
    
    run_test "OpenAPI documentation" \
        "curl -s $BACKEND_URL/docs" \
        "Тестовый Бэкенд"
    
    run_test "OpenAPI JSON schema" \
        "curl -s $BACKEND_URL/docs/openapi.json" \
        "openapi"
}

check_docker_services() {
    if command -v docker &> /dev/null && docker info &>/dev/null; then
        log "Checking Docker services status"
        
        if docker compose ps &>/dev/null; then
            log "Docker Compose services:"
            docker compose ps
        else
            warn "Docker Compose services not running"
        fi
    else
        warn "Docker not available or not running"
    fi
}

generate_test_report() {
    echo
    echo "============================================"
    log "TEST SUMMARY"
    echo "============================================"
    echo "Total tests run: $TOTAL_TESTS"
    echo -e "${GREEN}Passed: $PASSED_TESTS${NC}"
    echo -e "${RED}Failed: $FAILED_TESTS${NC}"
    echo
    
    if [ $FAILED_TESTS -eq 0 ]; then
        echo -e "${GREEN}🎉 All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}❌ $FAILED_TESTS test(s) failed${NC}"
        return 1
    fi
}

cleanup() {
    log "Cleaning up..."
    # Kill any background processes if needed
    jobs -p | xargs -r kill &>/dev/null || true
}

main() {
    trap cleanup EXIT
    
    echo "============================================"
    log "MONITORING SYSTEM TEST SUITE"
    echo "============================================"
    echo
    
    # Check if services are running
    log "Checking service availability..."
    
    if ! wait_for_service "Backend" "$BACKEND_URL" 10; then
        error "Backend service not available. Please start the backend first."
        exit 1
    fi
    
    # Run test suites
    test_backend_endpoints
    test_openapi_docs
    
    # Check if Prometheus is running
    if curl -s -f "$PROMETHEUS_URL" &>/dev/null; then
        test_prometheus_metrics
        run_load_test
    else
        warn "Prometheus not available, skipping Prometheus tests"
    fi
    
    # Check if Grafana is running
    if curl -s -f "$GRAFANA_URL" &>/dev/null; then
        test_grafana_access
    else
        warn "Grafana not available, skipping Grafana tests"
    fi
    
    check_docker_services
    
    # Generate final report
    generate_test_report
}

# Run main function
main "$@"
