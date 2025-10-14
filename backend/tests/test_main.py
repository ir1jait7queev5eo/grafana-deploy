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
