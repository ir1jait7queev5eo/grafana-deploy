import asyncio
import logging
import random
import time

from litestar import Litestar, get
from litestar.plugins.prometheus import PrometheusConfig, PrometheusController
from litestar.openapi.config import OpenAPIConfig
from litestar.openapi.plugins import ScalarRenderPlugin
from litestar.exceptions import HTTPException
import uvicorn

# Настройка логирования
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
)

logger = logging.getLogger(__name__)

@get("/")
async def root() -> str:
    return "root"

@get("/status/{status_code:int}")
async def return_status(
    status_code: int,
    seconds_sleep: int | None = None,
) -> dict:
    logger.info(f"Hello from Litestar! {status_code=}, {seconds_sleep=}")
    if seconds_sleep:
        await asyncio.sleep(seconds_sleep)
    if status_code and status_code != 200:
        logger.error("Shit happens")
        raise HTTPException(detail="an error occurred", status_code=status_code)
    return {"data": "Hello"}

@get("/passenger_metrics")
async def passenger_metrics() -> str:
    """
    Mock Phusion Passenger metrics endpoint for testing.
    Returns Prometheus format metrics similar to real Passenger data.
    """
    instance_id = "ChsBkRTF"
    
    # Simulate some realistic variation in metrics
    base_time = int(time.time())
    production_load = random.randint(4, 8)
    development_load = random.randint(0, 2)
    
    # Generate mock processes with realistic PIDs and stats
    production_processes = [
        {
            'pid': str(1769484 + i * 20),
            'cpu': random.randint(0, 50),
            'memory': random.randint(250000, 350000),
            'sessions': random.randint(0, 3),
            'processed': random.randint(50000, 150000)
        }
        for i in range(production_load)
    ]
    
    development_processes = [
        {
            'pid': str(1876242 + i * 10),
            'cpu': random.randint(0, 10),
            'memory': random.randint(200000, 250000),
            'sessions': random.randint(0, 1),
            'processed': random.randint(1, 100)
        }
        for i in range(development_load)
    ]
    
    exporter_process = {
        'pid': '1877624',
        'cpu': random.randint(0, 5),
        'memory': random.randint(35000, 45000),
        'sessions': 0,
        'processed': random.randint(10, 50)
    }
    
    total_processes = production_load + development_load + 1
    total_capacity_used = production_load + development_load + 1
    
    metrics = []
    
    # Instance level metrics
    metrics.extend([
        "# HELP passenger_process_count Total number of processes in instance",
        "# TYPE passenger_process_count gauge",
        f'passenger_process_count{{instance="{instance_id}"}} {total_processes}',
        "# HELP passenger_capacity_used Capacity used by instance",
        "# TYPE passenger_capacity_used gauge",
        f'passenger_capacity_used{{instance="{instance_id}"}} {total_capacity_used}',
        "# HELP passenger_get_wait_list_size Size of get wait list in instance",
        "# TYPE passenger_get_wait_list_size gauge",
        f'passenger_get_wait_list_size{{instance="{instance_id}"}} {random.randint(0, 2)}',
    ])
    
    # Development supergroup metrics
    if development_load > 0:
        metrics.extend([
            "# HELP passenger_supergroup_capacity_used Capacity used by supergroup",
            "# TYPE passenger_supergroup_capacity_used gauge",
            f'passenger_supergroup_capacity_used{{instance="{instance_id}",supergroup="/srv/development_rozarioflowers.ru (development)"}} {development_load}',
            "# HELP passenger_supergroup_get_wait_list_size Size of get wait list in supergroup",
            "# TYPE passenger_supergroup_get_wait_list_size gauge",
            f'passenger_supergroup_get_wait_list_size{{instance="{instance_id}",supergroup="/srv/development_rozarioflowers.ru (development)"}} {random.randint(0, 1)}',
        ])
        
        # Development process metrics
        for proc in development_processes:
            metrics.extend([
                "# HELP passenger_process_cpu CPU usage by process",
                "# TYPE passenger_process_cpu gauge",
                f'passenger_process_cpu{{instance="{instance_id}",supergroup="/srv/development_rozarioflowers.ru (development)",pid="{proc["pid"]}"}} {proc["cpu"]}',
                "# HELP passenger_process_memory Memory usage by process (rss)",
                "# TYPE passenger_process_memory gauge",
                f'passenger_process_memory{{instance="{instance_id}",supergroup="/srv/development_rozarioflowers.ru (development)",pid="{proc["pid"]}"}} {proc["memory"]}',
                "# HELP passenger_process_sessions Active sessions by process",
                "# TYPE passenger_process_sessions gauge",
                f'passenger_process_sessions{{instance="{instance_id}",supergroup="/srv/development_rozarioflowers.ru (development)",pid="{proc["pid"]}"}} {proc["sessions"]}',
                "# HELP passenger_process_processed Total requests processed by process",
                "# TYPE passenger_process_processed counter",
                f'passenger_process_processed{{instance="{instance_id}",supergroup="/srv/development_rozarioflowers.ru (development)",pid="{proc["pid"]}"}} {proc["processed"]}',
            ])
    
    # Prometheus exporter supergroup
    metrics.extend([
        "# HELP passenger_supergroup_capacity_used Capacity used by supergroup",
        "# TYPE passenger_supergroup_capacity_used gauge",
        f'passenger_supergroup_capacity_used{{instance="{instance_id}",supergroup="Prometheus exporter"}} 1',
        "# HELP passenger_supergroup_get_wait_list_size Size of get wait list in supergroup",
        "# TYPE passenger_supergroup_get_wait_list_size gauge",
        f'passenger_supergroup_get_wait_list_size{{instance="{instance_id}",supergroup="Prometheus exporter"}} 0',
    ])
    
    # Prometheus exporter process
    metrics.extend([
        "# HELP passenger_process_cpu CPU usage by process",
        "# TYPE passenger_process_cpu gauge",
        f'passenger_process_cpu{{instance="{instance_id}",supergroup="Prometheus exporter",pid="{exporter_process["pid"]}"}} {exporter_process["cpu"]}',
        "# HELP passenger_process_memory Memory usage by process (rss)",
        "# TYPE passenger_process_memory gauge",
        f'passenger_process_memory{{instance="{instance_id}",supergroup="Prometheus exporter",pid="{exporter_process["pid"]}"}} {exporter_process["memory"]}',
        "# HELP passenger_process_sessions Active sessions by process",
        "# TYPE passenger_process_sessions gauge",
        f'passenger_process_sessions{{instance="{instance_id}",supergroup="Prometheus exporter",pid="{exporter_process["pid"]}"}} {exporter_process["sessions"]}',
        "# HELP passenger_process_processed Total requests processed by process",
        "# TYPE passenger_process_processed counter",
        f'passenger_process_processed{{instance="{instance_id}",supergroup="Prometheus exporter",pid="{exporter_process["pid"]}"}} {exporter_process["processed"]}',
    ])
    
    # Production supergroup metrics
    metrics.extend([
        "# HELP passenger_supergroup_capacity_used Capacity used by supergroup",
        "# TYPE passenger_supergroup_capacity_used gauge",
        f'passenger_supergroup_capacity_used{{instance="{instance_id}",supergroup="/srv/rozarioflowers.ru (production)"}} {production_load}',
        "# HELP passenger_supergroup_get_wait_list_size Size of get wait list in supergroup",
        "# TYPE passenger_supergroup_get_wait_list_size gauge",
        f'passenger_supergroup_get_wait_list_size{{instance="{instance_id}",supergroup="/srv/rozarioflowers.ru (production)"}} {random.randint(0, 1)}',
    ])
    
    # Production process metrics
    for proc in production_processes:
        metrics.extend([
            "# HELP passenger_process_cpu CPU usage by process",
            "# TYPE passenger_process_cpu gauge",
            f'passenger_process_cpu{{instance="{instance_id}",supergroup="/srv/rozarioflowers.ru (production)",pid="{proc["pid"]}"}} {proc["cpu"]}',
            "# HELP passenger_process_memory Memory usage by process (rss)",
            "# TYPE passenger_process_memory gauge",
            f'passenger_process_memory{{instance="{instance_id}",supergroup="/srv/rozarioflowers.ru (production)",pid="{proc["pid"]}"}} {proc["memory"]}',
            "# HELP passenger_process_sessions Active sessions by process",
            "# TYPE passenger_process_sessions gauge",
            f'passenger_process_sessions{{instance="{instance_id}",supergroup="/srv/rozarioflowers.ru (production)",pid="{proc["pid"]}"}} {proc["sessions"]}',
            "# HELP passenger_process_processed Total requests processed by process",
            "# TYPE passenger_process_processed counter",
            f'passenger_process_processed{{instance="{instance_id}",supergroup="/srv/rozarioflowers.ru (production)",pid="{proc["pid"]}"}} {proc["processed"]}',
        ])
    
    return "\n".join(metrics) + "\n"

prometheus_config = PrometheusConfig()

app = Litestar(
    route_handlers=[root, return_status, passenger_metrics, PrometheusController],
    middleware=[prometheus_config.middleware],
    openapi_config=OpenAPIConfig(
        title="Тестовый Бэкенд",
        description="Пример OpenAPI документации",
        version="0.0.1",
        render_plugins=[ScalarRenderPlugin()],
        path="/docs",
    ),
)

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8080, reload=False, workers=1)
