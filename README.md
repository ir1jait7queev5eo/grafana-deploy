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
- `GET /metrics` - Prometheus метрики

### Технологический стек

- **Backend**: Python 3.11, Litestar, Uvicorn
- **Metrics**: Prometheus + prometheus_client
- **Logs**: Loki + Promtail
- **Visualization**: Grafana
- **Orchestration**: Docker Compose

## Быстрый старт

1. Запуск всех сервисов:
   ```bash
   docker-compose up -d
   ```

2. Доступ к сервисам:
   - Backend API: http://localhost:8080
   - API документация: http://localhost:8080/docs
   - Prometheus: http://localhost:9090
   - Grafana: http://localhost:3000 (admin/admin)
   - Promtail: http://localhost:9080

3. Импорт дашборда:
   - Откройте Grafana
   - Import dashboard из файла `grafana/example-dashboard.json`

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
- HTTP request rate и latency
- Error rate по статусам
- Resource utilization (CPU, Memory)
- Log error patterns

### Retention policies:
- **Prometheus**: по умолчанию 15 дней
- **Loki**: 7 дней (настраивается в `loki-config.yaml`)

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
make up            # Запустить все сервисы
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
- Все API endpoints
- Error handling
- Metrics collection
- Concurrent requests
- OpenAPI documentation

## Расширение проекта

Данный проект является отличной основой для:
- Изучения observability практик
- Настройки мониторинга микросервисов
- Создания alerting rules
- Изучения современных CI/CD практик
- Добавления трейсинга (Jaeger/Tempo)

## Пример дашборда
Находится в папке `/grafana/example-dashboard.json`

---
*Обновлено в рамках работы над CI/CD интеграцией*