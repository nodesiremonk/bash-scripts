#!/bin/bash

SCRIPT_DIR="/root/backup/rclone"
REMOTE_NAME="rclone-remote-name"
REMOTE_DIR="/pat/to/remote/folder"
BACKUP_SRC="/path/to/backup"
BACKUP_DST="/tmp"
MYSQL_USER="root"
MYSQL_PASS="rootpassword"
MYSQL_DB="--all-databases"
MYSQL_CONTAINER="mysql"
KEEP_COPY=10

NOW=$(($(date +"%j") % $KEEP_COPY))
DESTFILE="$BACKUP_DST/$NOW.tar.gz"

/usr/bin/docker exec $MYSQL_CONTAINER /usr/bin/mysqldump --no-tablespaces -u $MYSQL_USER -p$MYSQL_PASS $MYSQL_DB > "$NOW-Databases.sql"
tar --exclude-vcs --exclude "node_modules" --exclude "tmp" --exclude "_static" -zcf "$DESTFILE" $BACKUP_SRC "$NOW-Databases.sql"

$SCRIPT_DIR/rclone copyto --onedrive-no-versions "$DESTFILE" "$REMOTE_NAME:$REMOTE_DIR/$NOW.tar.gz"

rm -f "$NOW-Databases.sql" "$DESTFILE"
