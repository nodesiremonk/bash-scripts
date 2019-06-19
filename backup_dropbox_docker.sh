#!/bin/bash

SCRIPT_DIR="/root/backup"
DROPBOX_DIR="/"
BACKUP_SRC="/var/www/"
BACKUP_DST="/tmp"
MYSQL_USER="root"
MYSQL_PASS="rootpassword"
MYSQL_DB="--all-databases"
MYSQL_CONTAINER="mysql"

NOW=$(date +"%A")
DESTFILE="$BACKUP_DST/$NOW.tar.gz"

/usr/bin/docker exec $MYSQL_CONTAINER /usr/bin/mysqldump -u $MYSQL_USER -p$MYSQL_PASS $MYSQL_DB > "$NOW-Databases.sql"
tar --exclude-vcs -zcvf "$DESTFILE" $BACKUP_SRC "$NOW-Databases.sql"

$SCRIPT_DIR/dropbox_uploader.sh upload "$DESTFILE" "$DROPBOX_DIR/$NOW.tar.gz"

rm -f "$NOW-Databases.sql" "$DESTFILE"
