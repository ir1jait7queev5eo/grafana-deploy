#!/bin/bash

# Universal test runner for the monitoring system
# Supports multiple test modes: unit, integration, ci, full

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅${NC} $1"
}

error() {
    echo -e "${RED}❌${NC} $1"
}

warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

show_help() {
    echo "Usage: $0 [test_type]"
    echo ""
    echo "Test types:"
    echo "  unit        - Run unit tests only"
    echo "  integration - Run integration tests only"  
    echo "  ci          - Run CI-suitable tests"
    echo "  full        - Run all tests (default)"
    echo "  help        - Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 unit"
    echo "  $0 integration"
    echo "  $0"
}

run_unit_tests() {
    log "Running unit tests..."
    cd backend
    source env/bin/activate 2>/dev/null || { error "Virtual environment not found. Run 'make dev' first."; exit 1; }
    python -m pytest tests/ -v --cov=. --cov-report=term
    cd ..
    success "Unit tests completed"
}

run_integration_tests() {
    log "Running integration tests..."
    
    # Check if services are running
    if ! docker compose ps | grep -q "Up"; then
        error "Docker services not running. Run 'make up' first."
        exit 1
    fi
    
    # Wait for services
    log "Waiting for services to be ready..."
    sleep 10
    
    # Test basic endpoints
    if curl -f http://localhost:8080/ >/dev/null 2>&1; then
        success "Backend is responding"
    else
        error "Backend is not responding"
        return 1
    fi
    
    # Test metrics
    if curl -f http://localhost:8080/metrics >/dev/null 2>&1; then
        success "Metrics endpoint is working"
    else
        error "Metrics endpoint is not working"
        return 1
    fi
    
    success "Integration tests completed"
}

run_ci_tests() {
    log "Running CI tests..."
    
    # For CI environment, start fresh
    if [ "$CI" = "true" ]; then
        log "CI environment detected"
        make dev >/dev/null 2>&1 || true
    fi
    
    run_unit_tests
    
    # In CI, we might not have full Docker setup
    if docker compose ps >/dev/null 2>&1; then
        run_integration_tests
    else
        warning "Docker services not available, skipping integration tests"
    fi
}

# Main logic
TEST_TYPE=${1:-full}

case $TEST_TYPE in
    unit)
        run_unit_tests
        ;;
    integration)
        run_integration_tests
        ;;
    ci)
        run_ci_tests
        ;;
    full)
        log "Running full test suite..."
        run_unit_tests
        run_integration_tests
        success "All tests completed successfully!"
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        error "Unknown test type: $TEST_TYPE"
        show_help
        exit 1
        ;;
esac
