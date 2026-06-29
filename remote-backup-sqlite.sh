#!/bin/bash
set -euo pipefail

RCLONE="/path/to/rclone"
DOCKER="/usr/bin/docker"
REMOTE_NAME="dropbox"
REMOTE_DIR="/backup"

DB_FILE="database.sqlite"
DB_DIR="/path/to/sqlite/database/"
BACKUP_DIR="/tmp"
BACKUP_PASSPHRASE_FILE="/path/to/.backup_passphrase"

# KEEP_COPY=10

DAY=$(date +"%A")
BACKUP_FILE="db_${DAY}.sqlite"
# DEL=$(date --date="$KEEP_COPY day ago" +"%Y-%m-%d")

# Create consistent backup
$DOCKER run --rm -t --user root -v "$DB_DIR":/workspace -v "$BACKUP_DIR":/backup -w /workspace keinos/sqlite3:latest sqlite3  "$DB_FILE" "VACUUM INTO '/backup/${BACKUP_FILE}'"

# Compress
gzip "${BACKUP_DIR}/${BACKUP_FILE}"

gpg --batch --yes --passphrase-file "$BACKUP_PASSPHRASE_FILE" --cipher-algo AES256 --symmetric --output "${BACKUP_DIR}/${BACKUP_FILE}.gz.gpg" "${BACKUP_DIR}/${BACKUP_FILE}.gz"

# $RCLONE copyto --onedrive-no-versions "${BACKUP_DIR}/${BACKUP_FILE}.gz.gpg" "${REMOTE_NAME}:${REMOTE_DIR}/${DAY}.sqlite.gz.gpg"
# $RCLONE deletefile "${REMOTE_NAME}:${REMOTE_DIR}/${DEL}.sqlite.gz.gpg"

$RCLONE copyto "${BACKUP_DIR}/${BACKUP_FILE}.gz.gpg" "${REMOTE_NAME}:${REMOTE_DIR}/${DAY}.sqlite.gz.gpg"

rm -f "${BACKUP_DIR}/${BACKUP_FILE}.gz" "${BACKUP_DIR}/${BACKUP_FILE}.gz.gpg"
