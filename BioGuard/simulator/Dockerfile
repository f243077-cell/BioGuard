# BioGuard Simulator — publishes simulated temperature/lock readings over MQTT
FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY config.py main.py ./
COPY utils ./utils

RUN useradd --create-home --uid 1000 simuser
USER simuser

# DEVICE_ID must be overridden per instance — see docker-compose.yml, where
# each simulator-N service sets its own. The config.py default is only
# meant for one ad-hoc `python main.py` run outside Docker.
CMD ["python", "main.py"]
