# Dockerfile for coolify-wordpress-backup
FROM alpine:latest

# Install dependencies
RUN apk update && \
    apk add --no-cache bash docker-cli gzip tar

WORKDIR /app
COPY scripts/backup.sh /app/backup.sh
RUN chmod +x /app/backup.sh

# Create backup directory
RUN mkdir -p /backups/wordpress

# Add a symlink so 'backup' can be used as a command
RUN ln -s /app/backup.sh /usr/local/bin/backup

# On startup, do a single dry run, then sleep for scheduled tasks
CMD ["/bin/sh", "-c", "DRY_RUN=1 backup && sleep infinity"]