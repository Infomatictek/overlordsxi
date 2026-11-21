FROM python:3.11-slim

WORKDIR /app
COPY combat_analytics /app/combat_analytics

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    OVERLORDS_ANALYTICS_HOST=0.0.0.0 \
    OVERLORDS_ANALYTICS_PORT=8765 \
    OVERLORDS_ANALYTICS_DB=/data/analytics.db \
    OVERLORDS_PG_LOG_DIR=/pg_logs \
    OVERLORDS_POLL_INTERVAL_SEC=15 \
    OVERLORDS_COOKIE_SECURE=1 \
    OVERLORDS_TRUST_PROXY_HEADERS=1

RUN useradd --system --uid 10001 --no-create-home analytics && \
    mkdir -p /data /pg_logs && \
    chown -R analytics:analytics /data

USER analytics
EXPOSE 8765

CMD ["python", "-m", "combat_analytics.cli", "serve"]
