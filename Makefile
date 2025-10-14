.PHONY: help test test-unit test-integration test-load build up down logs clean install dev

# Default target
help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Development setup
install: ## Install backend dependencies
	@echo "Installing backend dependencies..."
	cd backend && python -m venv venv && source venv/bin/activate && pip install -r req.txt
	@echo "Installing test dependencies..."
	cd backend && source venv/bin/activate && pip install pytest pytest-asyncio httpx pytest-cov

dev: ## Set up development environment
	@echo "Setting up development environment..."
	@$(MAKE) install
	@echo "Development environment ready!"
	@echo "To activate: cd backend && source venv/bin/activate"

# Docker operations
build: ## Build all Docker images
	@echo "Building Docker images..."
	docker-compose build

up: ## Start all services with Docker Compose
	@echo "Starting services..."
	docker-compose up -d
	@echo "Services started. Waiting for health checks..."
	@sleep 30
	@docker-compose ps

down: ## Stop all services
	@echo "Stopping services..."
	docker-compose down -v

logs: ## Show logs from all services
	docker-compose logs -f

status: ## Show status of all services
	docker-compose ps

# Testing
test: ## Run all tests
	@echo "Running comprehensive test suite..."
	@$(MAKE) test-unit
	@$(MAKE) test-integration

test-unit: ## Run unit tests
	@echo "Running unit tests..."
	cd backend && source venv/bin/activate && python -m pytest tests/ -v --cov=. --cov-report=html --cov-report=term

test-integration: ## Run integration tests
	@echo "Running integration tests..."
	@chmod +x test_system.sh
	@./test_system.sh

test-load: ## Run load tests
	@echo "Running load tests..."
	@if ! command -v ab &> /dev/null; then \
		echo "Installing Apache Bench..."; \
		sudo apt-get update && sudo apt-get install -y apache2-utils; \
	fi
	@echo "Running load test with Apache Bench..."
	ab -c 10 -n 1000 http://localhost:8080/ > load_test_results.txt 2>&1
	ab -c 5 -n 500 http://localhost:8080/status/200 >> load_test_results.txt 2>&1
	ab -c 5 -n 200 'http://localhost:8080/status/200?seconds_sleep=1' >> load_test_results.txt 2>&1
	@echo "Load test results saved to load_test_results.txt"

# Backend operations
start-backend: ## Start backend locally
	@echo "Starting backend locally..."
	cd backend && source venv/bin/activate && python main.py &
	@echo "Backend started on http://localhost:8080"

stop-backend: ## Stop local backend
	@echo "Stopping backend..."
	@pkill -f "python main.py" || true

# Monitoring operations
start-monitoring: ## Start monitoring stack (Prometheus, Grafana)
	@echo "Starting monitoring stack..."
	@if [ ! -d "/tmp/prometheus-2.54.1.linux-amd64" ]; then \
		echo "Downloading Prometheus..."; \
		cd /tmp && wget -q https://github.com/prometheus/prometheus/releases/download/v2.54.1/prometheus-2.54.1.linux-amd64.tar.gz; \
		cd /tmp && tar xzf prometheus-2.54.1.linux-amd64.tar.gz; \
		cp prometheus.yml /tmp/prometheus-2.54.1.linux-amd64/; \
		sed -i 's/backend:8080/localhost:8080/g' /tmp/prometheus-2.54.1.linux-amd64/prometheus.yml; \
	fi
	@echo "Starting Prometheus..."
	@cd /tmp/prometheus-2.54.1.linux-amd64 && ./prometheus --config.file=prometheus.yml > prometheus.log 2>&1 &
	@echo "Prometheus started on http://localhost:9090"

stop-monitoring: ## Stop monitoring stack
	@echo "Stopping monitoring stack..."
	@pkill -f "prometheus --config.file" || true
	@pkill -f "grafana" || true

# Utility operations
clean: ## Clean up containers, volumes, and temporary files
	@echo "Cleaning up..."
	docker-compose down -v --remove-orphans
	docker system prune -f
	rm -f backend/*.pid
	rm -f *.log
	rm -f load_test_results.txt
	rm -rf backend/htmlcov/
	rm -f backend/.coverage

check-deps: ## Check if required tools are installed
	@echo "Checking dependencies..."
	@command -v docker >/dev/null 2>&1 || { echo "Docker not found. Please install Docker."; exit 1; }
	@command -v docker-compose >/dev/null 2>&1 || { echo "Docker Compose not found. Please install Docker Compose."; exit 1; }
	@command -v python3 >/dev/null 2>&1 || { echo "Python 3 not found. Please install Python 3."; exit 1; }
	@echo "All dependencies are installed."

health: ## Check health of all services
	@echo "Checking service health..."
	@echo "Backend:"
	@curl -s -f http://localhost:8080/ && echo " ✓ Backend is healthy" || echo " ✗ Backend is not responding"
	@echo "Prometheus:"
	@curl -s -f http://localhost:9090/-/ready && echo " ✓ Prometheus is ready" || echo " ✗ Prometheus is not ready"
	@echo "Grafana:"
	@curl -s -f http://localhost:3000/api/health && echo " ✓ Grafana is healthy" || echo " ✗ Grafana is not responding"

metrics: ## Show current metrics from backend
	@echo "Current backend metrics:"
	@curl -s http://localhost:8080/metrics | grep -E "^litestar_" || echo "No metrics available"

# CI/CD helpers
ci-test: ## Run tests suitable for CI environment
	@echo "Running CI tests..."
	cd backend && python -m pytest tests/ -v --cov=. --cov-report=xml --cov-report=term-missing

ci-build: ## Build and test Docker image for CI
	@echo "Building and testing Docker image..."
	cd backend && docker build -t backend:ci .
	docker run -d -p 8080:8080 --name backend-ci backend:ci
	sleep 10
	curl -f http://localhost:8080/ || exit 1
	docker stop backend-ci
	docker rm backend-ci
	@echo "Docker image test passed"

# Documentation
docs: ## Generate documentation
	@echo "Generating documentation..."
	@echo "OpenAPI docs available at: http://localhost:8080/docs"
	@echo "Coverage report: backend/htmlcov/index.html"

info: ## Show project information
	@echo "=== Monitoring System Project ==="
	@echo "Backend: Python + Litestar (port 8080)"
	@echo "Prometheus: Metrics collection (port 9090)"
	@echo "Grafana: Visualization (port 3000, admin/admin)"
	@echo "Loki: Log aggregation (port 3100)"
	@echo "Promtail: Log collection (port 9080)"
	@echo ""
	@echo "Useful commands:"
	@echo "  make up        - Start all services"
	@echo "  make test      - Run all tests"
	@echo "  make health    - Check service health"
	@echo "  make logs      - Show service logs"
	@echo "  make down      - Stop all services"
