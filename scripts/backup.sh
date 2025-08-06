#!/bin/bash

set -e

# DRY_RUN option: set to 1 to only print actions
DRY_RUN=${DRY_RUN:-0}

BACKUP_DIR="/backups/wordpress"
DATE=$(date +"%Y-%m-%d_%H-%M")
mkdir -p "$BACKUP_DIR"

# Discover all wordpress and mariadb containers
WP_CONTAINERS=($(docker ps --filter "name=wordpress" --format "{{.Names}}"))
DB_CONTAINERS=($(docker ps --filter "name=mariadb" --format "{{.Names}}"))

# Build associative arrays for suffix matching
declare -A WP_SUFFIXES
declare -A DB_SUFFIXES

for WP in "${WP_CONTAINERS[@]}"; do
    # Extract suffix after last dash
    SUFFIX="${WP##*-}"
    WP_SUFFIXES[$SUFFIX]="$WP"
done

for DB in "${DB_CONTAINERS[@]}"; do
    SUFFIX="${DB##*-}"
    DB_SUFFIXES[$SUFFIX]="$DB"
done

# Only backup pairs with matching suffixes
for SUFFIX in "${!WP_SUFFIXES[@]}"; do
    if [[ -n "${DB_SUFFIXES[$SUFFIX]}" ]]; then
        WP_CONTAINER="${WP_SUFFIXES[$SUFFIX]}"
        MARIADB_CONTAINER="${DB_SUFFIXES[$SUFFIX]}"
        TMP_DIR="/tmp/${SUFFIX}-backup-$DATE"
        mkdir -p "$TMP_DIR"

        # Get Coolify resource name from WordPress container (if available)
        RESOURCE_NAME=$(docker inspect --format '{{ index .Config.Labels "coolify.resourceName" }}' "$WP_CONTAINER")
        if [[ -z "$RESOURCE_NAME" ]]; then
            RESOURCE_NAME="$SUFFIX"
        fi

        # Get DB credentials from container ENV
        log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

        if [[ "$DRY_RUN" -eq 1 ]]; then
            log "[DRY RUN] Would get DB credentials from $MARIADB_CONTAINER"
            DB_NAME="<db_name>"
            DB_USER="<db_user>"
            DB_PASS="<db_pass>"
        else
            DB_NAME=$(docker exec "$MARIADB_CONTAINER" printenv MYSQL_DATABASE)
            DB_USER=$(docker exec "$MARIADB_CONTAINER" printenv MYSQL_USER)
            DB_PASS=$(docker exec "$MARIADB_CONTAINER" printenv MYSQL_PASSWORD)
        fi

        # Dump MariaDB database
        if [[ "$DRY_RUN" -eq 1 ]]; then
            log "[DRY RUN] Would dump DB for $RESOURCE_NAME to $TMP_DIR/db.sql using mariadb-dump -u$DB_USER -p$DB_PASS $DB_NAME"
        else
            log "💾 Dumping DB for $RESOURCE_NAME to $TMP_DIR/db.sql"
            docker exec "$MARIADB_CONTAINER" mariadb-dump -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" > "$TMP_DIR/db.sql"
        fi

        # Copy WordPress files
        if [[ "$DRY_RUN" -eq 1 ]]; then
            log "[DRY RUN] Would copy WordPress files for $RESOURCE_NAME from $WP_CONTAINER:/var/www/html to $TMP_DIR/html"
        else
            log "📦 Copying WordPress files for $RESOURCE_NAME to $TMP_DIR/html"
            docker cp "$WP_CONTAINER":/var/www/html "$TMP_DIR/html"
        fi

        # Compress everything
        ARCHIVE="$BACKUP_DIR/${RESOURCE_NAME}-backup-$DATE.tar.gz"
        if [[ "$DRY_RUN" -eq 1 ]]; then
            log "[DRY RUN] Would create archive $ARCHIVE from $TMP_DIR"
        else
            log "🗜️  Creating archive $ARCHIVE"
            tar -czf "$ARCHIVE" -C "$TMP_DIR" .
        fi

        # Cleanup
        if [[ "$DRY_RUN" -eq 1 ]]; then
            log "[DRY RUN] Would remove $TMP_DIR"
        else
            rm -rf "$TMP_DIR"
        fi

        log "✅ Backup complete: $ARCHIVE"
    fi
done

# Run cleanup script at the end
DRY_RUN=$DRY_RUN cleanup