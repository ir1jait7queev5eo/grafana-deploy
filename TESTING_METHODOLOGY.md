# Методология тестирования системы мониторинга (Observability Stack)

## Цель документа
Этот документ описывает пошаговую методологию диагностики и решения проблем с системой мониторинга, основанной на Prometheus, Grafana и backend приложении. Документ создан для воспроизведения процесса отладки в будущем.

## Проблема
**Симптом:** В панели Grafana везде отображается "No data", несмотря на то что места для метрик предусмотрены.

## Методология диагностики

### 1. Проверка статуса сервисов

#### 1.1 Проверка Docker-окружения
```bash
# Проверить статус Docker демона
docker ps

# Если ошибка "cannot connect" - запустить Docker
dockerd --host=unix:///var/run/docker.sock &

# Проверить статус контейнеров
docker-compose ps
```

**Ожидаемый результат:** Все сервисы должны быть в статусе "Up"

#### 1.2 Диагностика сетевых проблем
```bash
# Включить IPv4 forwarding если нужно
echo 1 > /proc/sys/net/ipv4/ip_forward

# Проверить Docker сети
docker network ls
```

### 2. Проверка доступности endpoints

#### 2.1 Проверка backend приложения
```bash
# Основной endpoint
curl -s http://localhost:8080/

# Метрики Litestar
curl -s http://localhost:8080/metrics | head -10

# Метрики Passenger (если есть)
curl -s http://localhost:8080/passenger_metrics | head -10
```

**Ожидаемый результат:** 
- `/` возвращает "root"
- `/metrics` возвращает Prometheus метрики
- `/passenger_metrics` возвращает mock метрики

#### 2.2 Если backend недоступен - локальный запуск
```bash
# Установить зависимости в env
cd backend
python3 -m env env
source env/bin/activate
pip install -r req.txt

# Запустить backend
python main.py &
```

### 3. Проверка сбора метрик Prometheus

#### 3.1 Проверка targets
```bash
# Статус целевых endpoint'ов
curl -s http://localhost:9090/api/v1/targets | jq .
```

**Ожидаемый результат:**
- `health: "up"` для всех targets
- `lastError: ""` (пустая строка)

#### 3.2 Проверка доступности метрик
```bash
# Базовая метрика up
curl -s "http://localhost:9090/api/v1/query?query=up" | jq '.data.result'

# Метрики приложения
curl -s "http://localhost:9090/api/v1/query?query=litestar_requests_total" | jq '.data.result[0:3]'

# Passenger метрики
curl -s "http://localhost:9090/api/v1/query?query=passenger_process_count" | jq '.data.result'

# Список всех доступных метрик
curl -s "http://localhost:9090/api/v1/label/__name__/values" | jq '.data[0:10]'
```

### 4. Генерация тестовых данных

#### 4.1 Создание нагрузки для метрик
```bash
# Успешные запросы
for i in {1..50}; do curl -s http://localhost:8080/status/200 > /dev/null; sleep 0.1; done &

# Запросы с ошибками
for i in {1..20}; do curl -s http://localhost:8080/status/500 > /dev/null; sleep 0.2; done &
for i in {1..10}; do curl -s http://localhost:8080/status/400 > /dev/null; sleep 0.3; done &

# Медленные запросы
for i in {1..5}; do curl -s http://localhost:8080/status/200?seconds_sleep=1 > /dev/null; done &
```

#### 4.2 Проверка что данные появились
```bash
# Подождать 30 секунд и проверить
sleep 30
curl -s "http://localhost:9090/api/v1/query?query=litestar_requests_total" | jq '.data.result'
```

### 5. Проверка Grafana

#### 5.1 Проверка доступности интерфейса
```bash
# Проверить что Grafana отвечает
curl -s http://localhost:3000/login | head -5
```

#### 5.2 Настройка через API
```bash
# Добавить Prometheus datasource
curl -X POST -u admin:admin -H "Content-Type: application/json" \
  -d '{"name":"Prometheus","type":"prometheus","url":"http://localhost:9090","access":"proxy","isDefault":true}' \
  http://localhost:3000/api/datasources

# Проверить что datasource работает
curl -u admin:admin "http://localhost:3000/api/datasources/proxy/1/api/v1/query?query=up" | jq '.data.result[0]'
```

#### 5.3 Создание простого dashboard
```json
{
  "dashboard": {
    "title": "Backend Observability",
    "panels": [
      {
        "id": 1,
        "title": "Total Requests",
        "type": "stat",
        "targets": [{"expr": "litestar_requests_total"}]
      },
      {
        "id": 2,
        "title": "Request Rate",
        "type": "graph", 
        "targets": [{"expr": "rate(litestar_requests_total[1m])"}]
      }
    ]
  },
  "overwrite": true
}
```

```bash
# Создать dashboard
curl -X POST -u admin:admin -H "Content-Type: application/json" \
  -d @dashboard.json http://localhost:3000/api/dashboards/db
```

### 6. Использование браузера для проверки UI

#### 6.1 Навигация и скриншоты
```python
# В Sketch environment
browser_navigate("http://localhost:3000")
browser_take_screenshot()  # Сохранить текущее состояние
```

#### 6.2 Интерпретация результатов скриншотов
- **Нормальное состояние:** Видна форма логина или dashboard
- **Проблема с загрузкой:** Сообщение "Grafana has failed to load its application files"
- **Проблема с данными:** Панели показывают "No data"

### 7. Альтернативные стратегии при проблемах

#### 7.1 Проблемы с Docker networking
```bash
# Запуск с host networking
docker run --net=host -e GF_SECURITY_ADMIN_PASSWORD=admin grafana/grafana:latest

# Обновление конфигурации для localhost
# В prometheus.yml изменить "backend:8080" на "localhost:8080"
# В datasources.yaml изменить "prometheus:9090" на "localhost:9090"
```

#### 7.2 Локальная установка вместо Docker
```bash
# Скачать и запустить Prometheus локально
wget https://github.com/prometheus/prometheus/releases/download/v3.0.0/prometheus-3.0.0.linux-amd64.tar.gz
tar -xf prometheus-3.0.0.linux-amd64.tar.gz
./prometheus-3.0.0.linux-amd64/prometheus --config.file=./prometheus.yml &

# Скачать и запустить Grafana локально  
wget https://dl.grafana.com/oss/release/grafana-11.3.0.linux-amd64.tar.gz
tar -xf grafana-11.3.0.linux-amd64.tar.gz
cd grafana-v11.3.0 && GF_SECURITY_ADMIN_PASSWORD=admin ./bin/grafana server &
```

## Критерии успешного решения

### ✅ Чек-лист проверок
1. **Backend доступен:** `curl localhost:8080/` возвращает "root"
2. **Метрики генерируются:** `curl localhost:8080/metrics` возвращает данные
3. **Prometheus собирает:** API targets показывает `health: "up"`
4. **Данные в Prometheus:** Query API возвращает метрики
5. **Grafana подключена:** Datasource API возвращает данные
6. **Dashboard создан:** Search API показывает dashboard

### 🔍 Ключевые команды для быстрой проверки
```bash
# Одной командой проверить всю цепочку
curl -s localhost:8080/ && \
curl -s localhost:9090/api/v1/targets | jq -r '.data.activeTargets[0].health' && \
curl -s -u admin:admin localhost:3000/api/datasources/proxy/1/api/v1/query?query=up | jq '.data.result | length'
```

**Ожидаемый результат:** `root`, `up`, `2` (или больше)

## Часто встречающиеся проблемы

### 1. Docker networking
- **Симптом:** Prometheus не может достучаться до backend
- **Решение:** Использовать `localhost` вместо container names или `--net=host`

### 2. Порты заблокированы
- **Симптом:** Connection refused
- **Решение:** Проверить `netstat -tlnp` и освободить порты

### 3. Права доступа
- **Симптом:** Permission denied
- **Решение:** Запустить с правильными правами или через `sudo`

### 4. Конфигурация metrics path
- **Симптом:** 404 Not Found в Prometheus targets
- **Решение:** Проверить `metrics_path` в `prometheus.yml`

### 5. Grafana UI не загружается
- **Симптом:** "Failed to load application files"
- **Решение:** Проверить через API, UI может работать некорректно но данные доступны

## Итоговая валидация

После выполнения всех шагов должны быть доступны:
- **Backend:** http://localhost:8080
- **Prometheus:** http://localhost:9090  
- **Grafana:** http://localhost:3000

И все метрики должны показывать реальные данные вместо "No data".
