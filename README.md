# Observability Stack Demo

Демонстрационный проект современного стека observability с использованием Prometheus, Loki, Grafana и Python backend.

## Архитектура проекта

### Основные компоненты

1. **Backend Application** (Python + Litestar)
   - REST API с эндпоинтами для тестирования
   - Встроенные Prometheus метрики
   - OpenAPI документация через Scalar
   - Поддержка различных HTTP статусов и задержек

2. **Мониторинг (Prometheus)**
   - Сбор метрик с backend каждые 3 секунды
   - Scraping метрик с `/metrics` эндпоинта
   - Хранение временных рядов метрик

3. **Логирование (Loki + Promtail)**
   - Loki для хранения и индексирования логов
   - Promtail для сбора логов из Docker containers
   - Настройка retention на 7 дней
   - Структурированные логи с метаданными

4. **Визуализация (Grafana)**
   - Предконфигурированные datasources (Prometheus + Loki)
   - Готовый example dashboard
   - Единый интерфейс для метрик и логов
   - Админ доступ: `admin/admin`

### API Endpoints

- `GET /` - корневой эндпоинт
- `GET /status/{status_code}` - возвращает указанный HTTP статус
- `GET /status/{status_code}?seconds_sleep=N` - добавляет задержку N секунд
- `GET /docs` - OpenAPI документация (Scalar UI)
- `GET /metrics` - Prometheus метрики (Litestar application)
- `GET /passenger_metrics` - Phusion Passenger метрики (mock для демонстрации)

### Технологический стек

- **Backend**: Python 3.11, Litestar, Uvicorn
- **Metrics**: Prometheus + prometheus_client
- **Logs**: Loki + Promtail
- **Visualization**: Grafana
- **Orchestration**: Docker Compose

## 🚀 Краткий старт

Теперь всё запускается одной командой:

```bash
# Полное развёртывание с нуля
make dev && make build && make up
```

**Результат:**
- ✅ Все 5 сервисов запущены
- ✅ Grafana настроена автоматически
- ✅ Все dashboard импортированы и работают
- ✅ Метрики собираются

**Доступ через браузер:**
- **Backend API**: http://localhost:8080
- **API документация**: http://localhost:8080/docs  
- **Grafana**: http://localhost:3000 (admin/admin)
- **Prometheus**: http://localhost:9090

## Развёртывание

### Development Environment

#### Быстрый старт для разработки:
```bash
# 1. Клонировать репозиторий
git clone <repository-url>
cd grafana-deploy

# 2. Переключиться на нужную ветку
git checkout passenger-metrics

# 3. Настроить среду разработки
make dev
# или вручную:
# cd backend && python -m env env && source env/bin/activate && pip install -r req.txt

# 4. Запустить все сервисы (автоматически настроит Grafana)
make up

# 5. Проверить здоровье сервисов
make health
```

#### Доступ к сервисам (Development):
- **Backend API**: http://localhost:8080
- **API документация**: http://localhost:8080/docs
- **Passenger metrics**: http://localhost:8080/passenger_metrics
- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3000 (admin/admin)
- **Promtail**: http://localhost:9080

#### Команды для разработки:
```bash
make test              # Запустить все тесты
make test-unit         # Unit тесты
make start-backend     # Запустить только backend локально
make logs              # Посмотреть логи всех сервисов
make clean             # Очистить временные файлы и контейнеры
```

### Production Environment

#### Требования для production:
- Docker Engine 20.10+
- Docker Compose v2.0+
- Минимум 2GB RAM
- Минимум 5GB свободного места на диске

#### Production deployment:
```bash
# 1. Подготовить production окружение
# Создать отдельную директорию для production
mkdir -p /opt/monitoring && cd /opt/monitoring

# 2. Скопировать конфигурационные файлы
scp docker-compose.yml user@server:/opt/monitoring/
scp -r grafana/ user@server:/opt/monitoring/
scp prometheus.yml user@server:/opt/monitoring/
scp loki-config.yaml user@server:/opt/monitoring/
scp promtail-config.yaml user@server:/opt/monitoring/

# 3. Создать production override файл
cat > docker-compose.prod.yml << EOF
version: '3.8'
services:
  backend:
    restart: unless-stopped
    environment:
      - PYTHONUNBUFFERED=1
      - ENV=production
    deploy:
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 256M
  
  prometheus:
    restart: unless-stopped
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=30d'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--web.enable-lifecycle'
    deploy:
      resources:
        limits:
          memory: 1G
        reservations:
          memory: 512M
  
  grafana:
    restart: unless-stopped
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=\${GRAFANA_PASSWORD}
      - GF_INSTALL_PLUGINS=grafana-piechart-panel
      - GF_SERVER_DOMAIN=\${GRAFANA_DOMAIN:-localhost}
      - GF_SERVER_ROOT_URL=http://\${GRAFANA_DOMAIN:-localhost}:3000
    deploy:
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 256M
  
  loki:
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 256M
  
  promtail:
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 128M
        reservations:
          memory: 64M
EOF

# 4. Создать .env файл для production
cat > .env << EOF
GRAFANA_PASSWORD=your_secure_password_here
GRAFANA_DOMAIN=monitoring.yourdomain.com
EOF

# 5. Запустить в production режиме
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# 6. Проверить статус
docker-compose ps
```

#### Production мониторинг:
```bash
# Проверка здоровья сервисов
curl -f http://localhost:8080/
curl -f http://localhost:9090/-/ready
curl -f http://localhost:3000/api/health

# Мониторинг логов
docker-compose logs -f --tail=100

# Мониторинг ресурсов
docker stats
```

#### Backup и восстановление:
```bash
# Backup Grafana данных
docker-compose exec grafana tar czf - /var/lib/grafana > grafana-backup-$(date +%Y%m%d).tar.gz

# Backup Prometheus данных
docker-compose exec prometheus tar czf - /prometheus > prometheus-backup-$(date +%Y%m%d).tar.gz

# Восстановление (остановить сервисы перед восстановлением)
docker-compose down
docker volume rm grafana-deploy_grafanadata grafana-deploy_prometheusdata
docker-compose up -d grafana prometheus
# Затем восстановить из backup файлов
```

### Доступные дашборды в Grafana:
- **Docker Observability Stack** - основной мониторинг системы (работает сразу)
- **Phusion Passenger Monitoring** - мониторинг Passenger процессов (работает с mock данными)
- **Passenger Monitoring (Working)** - упрощенный passenger dashboard (гарантированно работает)
- **Monitoring Dashboard** - дополнительный системный мониторинг

Все дашборды автоматически импортируются при выполнении `make up`.

#### Быстрая проверка dashboard:
```bash
# Проверить что passenger метрики доступны
curl -s http://localhost:8080/passenger_metrics | head -5

# Проверить через Prometheus
curl -s -u admin:admin "http://localhost:3000/api/datasources/proxy/uid/PBFA97CFB590B2093/api/v1/query?query=passenger_process_count"

# Открыть рабочий passenger dashboard:
# http://localhost:3000/d/working-passenger/passenger-monitoring-working
```

> 🎉 **Никаких дополнительных команд setup-grafana больше не нужно!**  
> Всё настраивается автоматически при `make up`. 🚀

### Безопасность Production:

#### Обязательные настройки:
```bash
# 1. Изменить пароли по умолчанию
# Обновить GRAFANA_PASSWORD в .env

# 2. Настроить firewall
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 3000/tcp  # Grafana (можно ограничить по IP)
sudo ufw enable

# 3. Настроить SSL/TLS (рекомендуется через reverse proxy)
# Пример с nginx:
sudo apt install nginx certbot python3-certbot-nginx
sudo certbot --nginx -d monitoring.yourdomain.com

# 4. Ограничить доступ к внутренним портам
# Закрыть прямой доступ к Prometheus (9090) и другим сервисам
# Оставить только Grafana (3000) через nginx
```

#### Nginx reverse proxy config:
```nginx
server {
    listen 80;
    server_name monitoring.yourdomain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name monitoring.yourdomain.com;
    
    ssl_certificate /etc/letsencrypt/live/monitoring.yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/monitoring.yourdomain.com/privkey.pem;
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## Видео
https://youtu.be/LyocQr7cN-0

## Нагрузочное тестирование с ab

```bash
ab -k -c 5 -n 20000 'http://localhost:8080/' & \
ab -k -c 5 -n 2000 'http://localhost:8080/status/400' & \
ab -k -c 5 -n 3000 'http://localhost:8080/status/409' & \
ab -k -c 5 -n 5000 'http://localhost:8080/status/500' & \
ab -k -c 50 -n 5000 'http://localhost:8080/status/200?seconds_sleep=1' & \
ab -k -c 50 -n 2000 'http://localhost:8080/status/200?seconds_sleep=2'
```

### Сценарии тестирования:
- **Обычная нагрузка**: 20000 запросов к корневому эндпоинту
- **Ошибки клиента**: 400, 409 статусы
- **Ошибки сервера**: 500 статус
- **Задержки**: запросы с искусственными задержками 1-2 секунды

## Мониторинг и алерты

### Ключевые метрики для отслеживания:

**Litestar Application:**
- HTTP request rate и latency
- Error rate по статусам
- Resource utilization (CPU, Memory)
- Log error patterns

**Phusion Passenger:**
- Количество процессов по приложениям
- Использование мощности (capacity)
- CPU и Memory usage по процессам
- Request rate и общее количество обработанных запросов
- Размер очереди ожидания
- Активные сессии

## Интеграция с реальным Phusion Passenger

Для замены mock endpoint на реальные Passenger метрики:

### 1. Установка Passenger Status Service

```bash
# На сервере с Passenger
# Установить passenger-status-service или passenger_exporter
gem install passenger-status-service
# или
wget https://github.com/passenger/passenger_exporter/releases/latest/download/passenger_exporter
chmod +x passenger_exporter

# Запустить exporter
./passenger_exporter --passenger.command="passenger-status" --web.listen-address=":9149"
```

### 2. Обновить Prometheus конфигурацию

```yaml
# В prometheus.yml заменить mock job:
scrape_configs:
  - job_name: "passenger"
    static_configs:
      - targets: ["your-passenger-server:9149"]
    scrape_interval: 15s
    metrics_path: /metrics  # вместо /passenger_metrics
```

### 3. Настроить сетевой доступ

```bash
# Открыть порт 9149 на Passenger сервере
sudo ufw allow from PROMETHEUS_SERVER_IP to any port 9149

# Или через SSH tunnel для безопасности
ssh -L 9149:localhost:9149 user@passenger-server
```

### 4. Отключить mock endpoint (опционально)

```python
# В backend/main.py закомментировать или удалить:
# @get("/passenger_metrics")
# async def passenger_metrics() -> str:
#     ...

# Обновить route_handlers:
app = Litestar(
    route_handlers=[root, return_status, PrometheusController],  # убрать passenger_metrics
    ...
)
```

### 5. Проверить интеграцию

```bash
# Проверить что метрики поступают в Prometheus
curl http://prometheus-server:9090/api/v1/query?query=passenger_process_count

# Проверить дашборд в Grafana
# Passenger Monitoring dashboard должен показывать реальные данные
```

### Пример systemd service для passenger_exporter:

```ini
# /etc/systemd/system/passenger-exporter.service
[Unit]
Description=Passenger Exporter
After=network.target

[Service]
Type=simple
User=nobody
ExecStart=/usr/local/bin/passenger_exporter --passenger.command="passenger-status" --web.listen-address=":9149"
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable passenger-exporter
sudo systemctl start passenger-exporter
```

### Retention policies:
- **Prometheus**: по умолчанию 15 дней (production: 30 дней)
- **Loki**: 7 дней (настраивается в `loki-config.yaml`)

### Примеры alerting rules для Passenger:

```yaml
# alerts.yml
groups:
- name: passenger
  rules:
  - alert: PassengerHighWaitQueue
    expr: passenger_get_wait_list_size > 5
    for: 2m
    labels:
      severity: warning
    annotations:
      summary: "High wait queue size detected"
      description: "Passenger wait queue size is {{ $value }} for instance {{ $labels.instance }}"
  
  - alert: PassengerHighMemoryUsage
    expr: sum by (supergroup) (passenger_process_memory) > 2000000000  # 2GB
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High memory usage in {{ $labels.supergroup }}"
      description: "Memory usage is {{ $value | humanize1024 }}B"
  
  - alert: PassengerProcessDown
    expr: passenger_process_count < 2
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "Low process count detected"
      description: "Only {{ $value }} passenger processes running"
```

## Структура проекта

```
.
├── backend/                 # Python backend приложение
│   ├── Dockerfile          # Docker образ для backend
│   ├── main.py            # Основной код приложения
│   └── req.txt            # Python зависимости
├── grafana/               # Grafana конфигурация
│   ├── datasources.yaml  # Предконфигурированные источники данных
│   └── example-dashboard.json # Пример дашборда
├── docker-compose.yml     # Оркестрация всех сервисов
├── loki-config.yaml      # Конфигурация Loki
├── prometheus.yml        # Конфигурация Prometheus
└── promtail-config.yaml  # Конфигурация Promtail
```

## CI/CD и разработка

### Доступные команды (Makefile)

```bash
make help          # Показать все доступные команды
make dev           # Настроить среду разработки
make test          # Запустить все тесты
make test-unit     # Запустить unit тесты
make ci-test       # Запустить тесты для CI
make up            # Запустить все сервисы + настроить Grafana
make down          # Остановить все сервисы
make health        # Проверить здоровье сервисов
make clean         # Очистить временные файлы
```

### GitHub Actions CI/CD

Проект включает полноценный CI/CD pipeline:
- **Unit Testing**: тестирование Python кода
- **Integration Testing**: тестирование API и Docker containers
- **Security Scanning**: проверка безопасности с Trivy
- **Load Testing**: нагрузочное тестирование с Apache Bench

Pipeline запускается автоматически при push в ветки `main`, `ci-cd-addon`, `sketch-wip`.

### Pre-commit hooks

Для обеспечения качества кода:
```bash
pip install pre-commit
pre-commit install
```

Hooks включают:
- Code formatting (Black, isort)
- Linting (flake8)
- YAML/JSON validation
- Unit tests

### Структура тестов

```
backend/tests/
├── __init__.py
└── test_main.py    # Comprehensive API tests
```

Тесты покрывают:
- Все API endpoints (включая `/passenger_metrics`)
- Error handling
- Metrics collection (Litestar и Passenger)
- Concurrent requests
- OpenAPI documentation
- Validation Prometheus format метрик

## Масштабирование и расширение

### High Availability Setup:

```yaml
# docker-compose.ha.yml
version: '3.8'
services:
  prometheus:
    deploy:
      replicas: 2
    volumes:
      - prometheus1:/prometheus
      - ./prometheus-ha.yml:/etc/prometheus/prometheus.yml
  
  grafana:
    environment:
      - GF_DATABASE_TYPE=postgres
      - GF_DATABASE_HOST=postgres:5432
      - GF_DATABASE_NAME=grafana
      - GF_DATABASE_USER=grafana
      - GF_DATABASE_PASSWORD=grafana_password
  
  postgres:
    image: postgres:13
    environment:
      POSTGRES_DB: grafana
      POSTGRES_USER: grafana
      POSTGRES_PASSWORD: grafana_password
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  prometheus1:
  postgres_data:
```

### Мониторинг нескольких Passenger серверов:

```yaml
# prometheus.yml
scrape_configs:
  - job_name: "passenger-prod"
    static_configs:
      - targets: ["prod-server1:9149", "prod-server2:9149"]
    labels:
      environment: "production"
  
  - job_name: "passenger-staging"
    static_configs:
      - targets: ["staging-server:9149"]
    labels:
      environment: "staging"
```

### Интеграция с системами оповещений:

```yaml
# alertmanager.yml
global:
  smtp_smarthost: 'smtp.gmail.com:587'
  smtp_from: 'monitoring@yourdomain.com'

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'web.hook'

receivers:
- name: 'web.hook'
  email_configs:
  - to: 'admin@yourdomain.com'
    subject: 'Alert: {{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'
    body: |
      {{ range .Alerts }}
      Alert: {{ .Annotations.summary }}
      Description: {{ .Annotations.description }}
      Instance: {{ .Labels.instance }}
      {{ end }}
  
  slack_configs:
  - api_url: 'YOUR_SLACK_WEBHOOK_URL'
    channel: '#monitoring'
    title: 'Passenger Alert'
    text: '{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'
```

### Данный проект является отличной основой для:
- Изучения observability практик
- Настройки мониторинга микросервисов
- Создания alerting rules
- Изучения современных CI/CD практик
- Мониторинга Ruby on Rails / Sinatra / Padrino приложений
- Добавления трейсинга (Jaeger/Tempo)
- Production-ready deployment опыта

## Полезные команды

```bash
# Быстрая диагностика
make info                    # Информация о проекте
make check-deps              # Проверка зависимостей
make health                  # Проверка здоровья сервисов
make metrics                 # Показать текущие метрики

# Тестирование и CI/CD
make test-load               # Нагрузочное тестирование
make ci-test                 # Тесты для CI окружения
make ci-build                # Сборка и тестирование Docker образа

# Обслуживание
make clean                   # Очистить все временные файлы
make down                    # Остановить все сервисы
make logs                    # Посмотреть логи
```

## Пример дашборда
Находится в папке `/grafana/example-dashboard.json`

---
*Обновлено в рамках работы над CI/CD интеграцией*

## Troubleshooting

### Распространенные проблемы и решения:

#### 1. Сервисы не запускаются
```bash
# Проверить логи
docker-compose logs

# Проверить статус контейнеров
docker-compose ps

# Перезапустить с полной очисткой
make clean && make up
```

#### 2. Grafana не показывает данные
```bash
# Проверить что Prometheus собирает метрики
curl http://localhost:9090/api/v1/query?query=up

# Проверить targets в Prometheus
# Открыть http://localhost:9090/targets

# Проверить подключение datasource в Grafana
# Grafana → Configuration → Data Sources → Prometheus → Test
```

#### 3. Passenger метрики не работают
```bash
# Проверить endpoint
curl http://localhost:8080/passenger_metrics

# Проверить что Prometheus scraping настроен
curl http://localhost:9090/api/v1/query?query=passenger_process_count

# Если используете реальный Passenger exporter:
curl http://passenger-server:9149/metrics
```

#### 4. Проблемы с памятью
```bash
# Ограничить память для сервисов
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# Мониторить использование ресурсов
docker stats

# Очистить неиспользуемые данные
docker system prune -f
```

#### 5. SSL/TLS проблемы в production
```bash
# Проверить сертификаты
sudo certbot certificates

# Обновить сертификаты
sudo certbot renew

# Проверить nginx конфигурацию
sudo nginx -t
sudo systemctl reload nginx
```

### Мониторинг производительности:

```bash
# CPU и память хоста
top
htop
free -h
df -h

# Docker контейнеры
docker stats
docker system df

# Сетевая активность
ss -tulpn
netstat -tulpn
```

### Логирование и отладка:

```bash
# Детальные логи всех сервисов
docker-compose logs -f --tail=100

# Логи конкретного сервиса
docker-compose logs -f grafana
docker-compose logs -f prometheus

# Войти в контейнер для отладки
docker-compose exec backend /bin/bash
docker-compose exec grafana /bin/bash

# Проверить конфигурационные файлы
docker-compose exec prometheus cat /etc/prometheus/prometheus.yml
docker-compose exec grafana cat /etc/grafana/grafana.ini
```

### Полезные метрики для отладки:

```promql
# Доступность сервисов
up

# Использование ресурсов
rate(container_cpu_usage_seconds_total[5m])
container_memory_usage_bytes

# Passenger метрики
passenger_process_count
passenger_capacity_used
passenger_get_wait_list_size > 0

# HTTP ошибки
rate(litestar_requests_total{status_code=~"4..|5.."}[5m])
```

---

**Поддержка:** Если возникли проблемы, проверьте логи, статус сервисов и сетевую связность. Большинство проблем решается перезапуском сервисов или проверкой конфигурации.