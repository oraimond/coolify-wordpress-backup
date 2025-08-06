# Dockerfile for coolify-wordpress-backup
FROM alpine:latest

# Install dependencies
RUN apk update && \
    apk add --no-cache bash openrc docker-cli gzip tar

WORKDIR /app
COPY scripts/backup.sh /app/backup.sh
RUN chmod +x /app/backup.sh

# Set DRY_RUN=1 by default, can be overridden in Coolify
ENV DRY_RUN=1
# Set CRON_SCHEDULE to daily at 2am by default, can be overridden in Coolify
ENV CRON_SCHEDULE="0 2 * * *"

# Create backup directory
RUN mkdir -p /backups/wordpress

# Copy entrypoint script for dynamic cron setup
COPY scripts/entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

CMD ["/app/entrypoint.sh"]