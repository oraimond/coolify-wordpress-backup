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

# Add a symlink so 'cleanup' can be used as a command
RUN ln -s /app/cleanup.sh /usr/local/bin/cleanup

# Add a symlink so 'restore' can be used as a command
RUN ln -s /app/restore.sh /usr/local/bin/restore

# On startup, do a single dry run, then sleep for scheduled tasks
CMD ["/bin/sh", "-c", "DRY_RUN=1 backup && sleep infinity"]