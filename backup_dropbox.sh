#!/bin/bash

SCRIPT_DIR="/root/backup"
DROPBOX_DIR="/"
BACKUP_SRC="/var/www/"
BACKUP_DST="/tmp"
MYSQL_SERVER="127.0.0.1"
MYSQL_USER="root"
MYSQL_PASS="rootpassword"
MYSQL_DB="--all-databases"

NOW=$(date +"%A")
DESTFILE="$BACKUP_DST/$NOW.tar.gz"

mysqldump -u $MYSQL_USER -h $MYSQL_SERVER -p$MYSQL_PASS $MYSQL_DB > "$NOW-Databases.sql"
tar --exclude-vcs -zcvf "$DESTFILE" $BACKUP_SRC "$NOW-Databases.sql"

$SCRIPT_DIR/dropbox_uploader.sh upload "$DESTFILE" "$DROPBOX_DIR/$NOW.tar.gz"

rm -f "$NOW-Databases.sql" "$DESTFILE"
