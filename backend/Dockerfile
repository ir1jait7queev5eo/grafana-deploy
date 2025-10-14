FROM python:3.11-slim

WORKDIR /app

# Install system dependencies including wget for health checks
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    && rm -rf /var/lib/apt/lists/*

COPY req.txt req.txt

RUN pip install -r req.txt

COPY main.py .

EXPOSE 8080

CMD ["python", "main.py"]
