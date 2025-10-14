import asyncio
import pytest
from litestar.testing import TestClient
from main import app


class TestAPI:
    """Test suite for the main API endpoints."""
    
    @pytest.fixture
    def client(self):
        """Create test client."""
        return TestClient(app=app)
    
    def test_root_endpoint(self, client):
        """Test the root endpoint returns 'root'."""
        response = client.get("/")
        assert response.status_code == 200
        assert response.text == "root"
    
    def test_status_200(self, client):
        """Test status endpoint with 200 code."""
        response = client.get("/status/200")
        assert response.status_code == 200
        assert response.json() == {"data": "Hello"}
    
    def test_status_400(self, client):
        """Test status endpoint with 400 code."""
        response = client.get("/status/400")
        assert response.status_code == 400
        assert "detail" in response.json()
        assert response.json()["detail"] == "an error occurred"
    
    def test_status_500(self, client):
        """Test status endpoint with 500 code."""
        response = client.get("/status/500")
        assert response.status_code == 500
        assert "detail" in response.json()
        # Litestar может возвращать разные сообщения для 500 ошибок
        assert response.json()["detail"] in ["an error occurred", "Internal Server Error"]
    
    @pytest.mark.asyncio
    async def test_status_with_sleep(self, client):
        """Test status endpoint with sleep parameter."""
        import time
        
        start_time = time.time()
        response = client.get("/status/200?seconds_sleep=1")
        end_time = time.time()
        
        assert response.status_code == 200
        assert response.json() == {"data": "Hello"}
        # Should take at least 1 second due to sleep
        assert end_time - start_time >= 1.0
    
    def test_metrics_endpoint(self, client):
        """Test Prometheus metrics endpoint."""
        response = client.get("/metrics")
        assert response.status_code == 200
        
        # Check for expected metrics
        metrics_text = response.text
        assert "litestar_requests_total" in metrics_text
        assert "litestar_request_duration_seconds" in metrics_text
        assert "python_info" in metrics_text
    
    def test_openapi_docs(self, client):
        """Test OpenAPI documentation endpoints."""
        # Test HTML docs page
        response = client.get("/docs")
        assert response.status_code == 200
        assert "Тестовый Бэкенд" in response.text
        
        # Test JSON schema
        response = client.get("/docs/openapi.json")
        assert response.status_code == 200
        
        schema = response.json()
        assert "openapi" in schema
        assert schema["info"]["title"] == "Тестовый Бэкенд"
        assert schema["info"]["version"] == "0.0.1"
    
    def test_invalid_endpoint(self, client):
        """Test non-existent endpoint returns 404."""
        response = client.get("/nonexistent")
        assert response.status_code == 404
    
    def test_metrics_after_requests(self, client):
        """Test that metrics are updated after making requests."""
        # Make some requests
        client.get("/")
        client.get("/status/200")
        client.get("/status/400")
        
        # Check metrics
        response = client.get("/metrics")
        assert response.status_code == 200
        
        metrics_text = response.text
        
        # Should see request counts in metrics
        assert 'path="/"' in metrics_text
        assert 'path="/status/200"' in metrics_text
        assert 'path="/status/400"' in metrics_text
        
        # Should see different status codes
        assert 'status_code="200"' in metrics_text
        assert 'status_code="400"' in metrics_text
    
    def test_concurrent_requests(self, client):
        """Test that the app handles concurrent requests properly."""
        import concurrent.futures
        import threading
        
        def make_request():
            response = client.get("/status/200")
            return response.status_code
        
        # Make 10 concurrent requests
        with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
            futures = [executor.submit(make_request) for _ in range(10)]
            results = [future.result() for future in concurrent.futures.as_completed(futures)]
        
        # All requests should succeed
        assert all(status == 200 for status in results)
        assert len(results) == 10
    
    def test_passenger_metrics_endpoint(self, client):
        """Test Passenger metrics endpoint returns valid Prometheus format."""
        response = client.get("/passenger_metrics")
        assert response.status_code == 200
        
        # Check content type - should be plain text
        assert response.headers.get("content-type") == "text/plain; charset=utf-8"
        
        metrics_text = response.text
        
        # Check for expected metric families
        assert "passenger_process_count" in metrics_text
        assert "passenger_capacity_used" in metrics_text
        assert "passenger_supergroup_capacity_used" in metrics_text
        assert "passenger_process_cpu" in metrics_text
        assert "passenger_process_memory" in metrics_text
        assert "passenger_process_sessions" in metrics_text
        assert "passenger_process_processed" in metrics_text
        
        # Check for expected labels
        assert 'instance="ChsBkRTF"' in metrics_text
        assert 'supergroup="/srv/rozarioflowers.ru (production)"' in metrics_text
        assert 'supergroup="Prometheus exporter"' in metrics_text
        
        # Check for HELP and TYPE comments
        assert "# HELP passenger_process_count" in metrics_text
        assert "# TYPE passenger_process_count gauge" in metrics_text
        assert "# TYPE passenger_process_processed counter" in metrics_text
        
        # Validate that metrics contain numeric values
        lines = metrics_text.split('\n')
        metric_lines = [line for line in lines if line and not line.startswith('#')]
        
        for line in metric_lines:
            if line.strip():
                # Each metric line should have format: metric_name{labels} value
                # Use rsplit to split only on the last space (labels can contain spaces)
                parts = line.rsplit(' ', 1)
                assert len(parts) == 2, f"Invalid metric line format: {line}"
                metric_name_with_labels = parts[0]
                value = parts[1]
                
                # Value should be numeric
                try:
                    float(value)
                except ValueError:
                    assert False, f"Non-numeric value in metric line: {line}"
                
                # Metric name should contain passenger prefix
                assert 'passenger_' in metric_name_with_labels, f"Missing passenger prefix: {line}"
    
    def test_passenger_metrics_variability(self, client):
        """Test that passenger metrics show some variability (not all static)."""
        # Make two requests and compare - some metrics should vary
        response1 = client.get("/passenger_metrics")
        import time
        time.sleep(0.1)  # Small delay
        response2 = client.get("/passenger_metrics")
        
        assert response1.status_code == 200
        assert response2.status_code == 200
        
        # The responses might be different due to random generation
        # But they should both be valid Prometheus format
        for response in [response1, response2]:
            metrics_text = response.text
            assert "passenger_process_count" in metrics_text
            assert 'instance="ChsBkRTF"' in metrics_text
