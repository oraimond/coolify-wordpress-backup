#!/bin/sh

# Set up cron job using CRON_SCHEDULE env var
echo "$CRON_SCHEDULE root /app/backup.sh >> /var/log/backup.log 2>&1" > /etc/crontabs/root

# Start cron in foreground
crond -f
