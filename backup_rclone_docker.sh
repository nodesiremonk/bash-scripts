#!/bin/bash

RCLONE="/root/backup/rclone/rclone"
DOCKER="/usr/bin/docker"
REMOTE_NAME="rclone-remote-name"
REMOTE_DIR="/pat/to/remote/folder"
BACKUP_SRC="/path/to/backup"
BACKUP_DST="/tmp"
MYSQL_USER="root"
MYSQL_PASS="rootpassword"
MYSQL_DB="--all-databases"
MYSQL_CONTAINER="mysql"
KEEP_COPY=10

#ADD=$(($(date +"%j") % $KEEP_COPY))
ADD=$(date +"%Y-%m-%d")
DEL=$(date --date="$KEEP_COPY day ago" +"%Y-%m-%d")
DEST_FILE="$BACKUP_DST/$ADD.tar.gz"
DB_FILE="$ADD-Databases.sql"

$DOCKER exec $MYSQL_CONTAINER /usr/bin/mysqldump --no-tablespaces -u $MYSQL_USER -p$MYSQL_PASS $MYSQL_DB > $DB_FILE
tar --exclude-vcs --exclude "node_modules" --exclude "tmp" -zcf $DEST_FILE $BACKUP_SRC $DB_FILE

$RCLONE copyto --onedrive-no-versions $DEST_FILE "$REMOTE_NAME:$REMOTE_DIR/$ADD.tar.gz"
$RCLONE deletefile "$REMOTE_NAME:$REMOTE_DIR/$DEL.tar.gz"

rm -f $DB_FILE $DEST_FILE
