#!/bin/bash

NAS_DIR="/BackupNAS/"
NAS_PORT=22
NAS_SERVER=192.168.1.1
NAS_USER=nas_user
BACKUP_SRC="/DATA/Backup/"
BACKUP_DST="/tmp"
MYSQL_SERVER="127.0.0.1"
MYSQL_USER="root"
MYSQL_PASS="rootpassword"
MYSQL_DB="--all-databases"

NOW=$(date +"%A")
DESTFILE="$BACKUP_DST/$NOW.tar.gz"

mysqldump -u $MYSQL_USER -h $MYSQL_SERVER -p$MYSQL_PASS $MYSQL_DB > "$NOW-Databases.sql"
tar --exclude-vcs -zcf "$DESTFILE" $BACKUP_SRC "$NOW-Databases.sql"

scp -P $NAS_PORT "$DESTFILE" $NAS_USER@$NAS_SERVER:$NAS_DIR

rm -f "$NOW-Databases.sql" "$DESTFILE"
