#!/bin/bash
set -euo pipefail

DB_FILE="database.sqlite"
DB_DIR="/path/to/sqlite/database/"
BACKUP_DIR="/path/to/backup"

mkdir -p "$BACKUP_DIR"

TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_FILE="database_${TIMESTAMP}.sqlite"

# Create consistent backup
/usr/bin/docker run --rm -t --user root -v "$DB_DIR":/workspace -v "$BACKUP_DIR":/backup -w /workspace keinos/sqlite3:latest sqlite3  "$DB_FILE" "VACUUM INTO '/backup/${BACKUP_FILE}'"

# Compress
gzip "${BACKUP_DIR}/${BACKUP_FILE}"

# Keep at most 30 backups
ls -1t "$BACKUP_DIR"/database_*.sqlite.gz 2>/dev/null \
    | tail -n +31 \
    | xargs -r rm -f

# Remove anything older than 24 hours
find "$BACKUP_DIR" \
    -name "database_*.sqlite.gz" \
    -type f \
    -mmin +1440 \
    -delete
