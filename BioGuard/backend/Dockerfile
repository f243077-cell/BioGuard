# BioGuard Backend — FastAPI + MQTT subscriber
FROM python:3.12-slim

WORKDIR /app

# Installed before the app code so `docker build` reuses this (slow) layer
# whenever only application code changes.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY alembic.ini .
COPY alembic ./alembic
COPY app ./app

# /data is where DATABASE_URL points in docker-compose.yml — mounting a
# volume there (rather than at /app) keeps the SQLite file out of the image
# and off of anything `docker build` copies in, while still shipping the
# code baked into the image as usual.
RUN mkdir -p /data \
    && useradd --create-home --uid 1000 appuser \
    && chown -R appuser:appuser /app /data
USER appuser

EXPOSE 8000

# Uses urllib (stdlib) instead of curl/wget so the image doesn't need an
# extra apt-get layer just for the healthcheck.
HEALTHCHECK --interval=10s --timeout=3s --start-period=10s --retries=5 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/', timeout=2)"

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
