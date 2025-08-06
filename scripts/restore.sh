#!/bin/bash

set -e
BACKUP_DIR="/backups/wordpress"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

# 1. List available WordPress services
log "Discovering WordPress services..."
services=( $(docker ps --filter "name=wordpress" --format "{{.Names}}") )
if [[ ${#services[@]} -eq 0 ]]; then
    log "No WordPress services found."
    exit 1
fi
log "Available WordPress services:"
for i in "${!services[@]}"; do
    echo "$((i+1)). ${services[$i]}"
    # Try to get resource name
    resource=$(docker inspect --format '{{ index .Config.Labels "coolify.resourceName" }}' "${services[$i]}")
    if [[ -n "$resource" ]]; then
        echo "    (Coolify resource: $resource)"
    fi
    resources[$i]="$resource"
done

# 2. Prompt user to select a service
read -p "Enter the number of the service to restore: " svc_idx
svc_idx=$((svc_idx-1))
WP_CONTAINER="${services[$svc_idx]}"
RESOURCE_NAME="${resources[$svc_idx]}"
if [[ -z "$RESOURCE_NAME" ]]; then
    RESOURCE_NAME=$(echo "$WP_CONTAINER" | sed 's/^wordpress-//')
fi

# 3. List available backups for that service
log "Listing backups for $RESOURCE_NAME..."
backups=( $(ls -1t $BACKUP_DIR/${RESOURCE_NAME}-backup-*.tar.gz 2>/dev/null) )
if [[ ${#backups[@]} -eq 0 ]]; then
    log "No backups found for $RESOURCE_NAME."
    exit 1
fi
for i in "${!backups[@]}"; do
    echo "$((i+1)). ${backups[$i]}"
done

# 4. Prompt user to select a backup
read -p "Enter the number of the backup to restore: " bkp_idx
bkp_idx=$((bkp_idx-1))
BACKUP_FILE="${backups[$bkp_idx]}"

# 5. Ask if user wants to backup current state
read -p "Do you want to backup the current state before restoring? (y/n): " backup_first
if [[ "$backup_first" =~ ^[Yy]$ ]]; then
    log "Backing up current state..."
    backup
fi

# 6. Find the corresponding MariaDB container
SUFFIX="${WP_CONTAINER##*-}"
MARIADB_CONTAINER="mariadb-$SUFFIX"

# 7. Extract backup
TMP_DIR="/tmp/restore-$RESOURCE_NAME-$$"
mkdir -p "$TMP_DIR"
log "Extracting $BACKUP_FILE to $TMP_DIR..."
tar -xzf "$BACKUP_FILE" -C "$TMP_DIR"

# 8. Restore WordPress files
log "Restoring WordPress files to $WP_CONTAINER:/var/www/html ..."
docker cp "$TMP_DIR/html/." "$WP_CONTAINER:/var/www/html/"

# 9. Restore MariaDB database
DB_NAME=$(docker exec "$MARIADB_CONTAINER" printenv MYSQL_DATABASE)
DB_USER=$(docker exec "$MARIADB_CONTAINER" printenv MYSQL_USER)
DB_PASS=$(docker exec "$MARIADB_CONTAINER" printenv MYSQL_PASSWORD)
log "Restoring MariaDB database to $MARIADB_CONTAINER..."
docker exec -i "$MARIADB_CONTAINER" mariadb -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" < "$TMP_DIR/db.sql"

# 10. Cleanup
echo "Cleaning up..."
rm -rf "$TMP_DIR"
log "✅ Restore complete."
