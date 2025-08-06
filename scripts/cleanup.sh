#!/bin/bash

# cleanup.sh: Retain for each resource:
# - 2 most recent backups
# - 3 most recent Sunday backups
# - Delete the rest

set -e

# DRY_RUN option: set to 1 to only print actions
DRY_RUN=${DRY_RUN:-0}
BACKUP_DIR="/backups/wordpress"
MAX_RECENT=2
MAX_SUNDAYS=3

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

cd "$BACKUP_DIR"

# Find all unique resource names (prefix before -backup-)
for RESOURCE in $(ls *-backup-*.tar.gz 2>/dev/null | sed 's/-backup-.*//g' | sort | uniq); do
    log "Processing $RESOURCE backups..."
    files=( $(ls -1t ${RESOURCE}-backup-*.tar.gz 2>/dev/null) )
    keep=()

    # 1. Keep the 2 most recent
    for ((i=0; i<${#files[@]} && i<$MAX_RECENT; i++)); do
        keep+=("${files[$i]}")
    done


    # 2. Keep the 3 most recent Sunday backups
    sunday_count=0
    for f in "${files[@]}"; do
        # Extract date from filename (assumes format ...-YYYY-MM-DD_HH-MM.tar.gz)
        date_str=$(echo "$f" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}')
        if [[ -n "$date_str" ]]; then
            # Get day of week (0=Sunday)
            day_of_week=$(date -d "$date_str" +%w)
            if [[ "$day_of_week" == "0" ]]; then
                if [[ ! " ${keep[@]} " =~ " $f " ]]; then
                    keep+=("$f")
                    ((sunday_count++))
                fi
            fi
        fi
        if [[ $sunday_count -ge $MAX_SUNDAYS ]]; then
            break
        fi
    done

    # 4. Delete files not in keep[]
    for f in "${files[@]}"; do
        if [[ ! " ${keep[@]} " =~ " $f " ]]; then
            if [[ "$DRY_RUN" -eq 1 ]]; then
                log "[DRY RUN] Would delete $f"
            else
                log "Deleting $f"
                rm -f "$f"
            fi
        fi
    done
    log "Kept: ${keep[*]}"
done
