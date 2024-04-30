#!/bin/bash

DB_HOST="postgresql.host.name"
DB_PORT="5432"
DB_NAME="postgres"
DB_USER="user"
DB_PASSWORD="password"
DB_CONTAINER="psql-client"
DB_SCHEMA="public"

SCRIPT_DIR="/root/backup"
DROPBOX_DIR="/postgresql"
BACKUP_DST="/tmp"

NOW=$(date +"%A")
DESTFILE="$BACKUP_DST/$NOW.tar.gz"

/usr/bin/docker run --rm $DB_CONTAINER pg_dump postgresql://$DB_USER:$DB_PASSWORD@$DB_HOST:$DB_PORT/$DB_NAME -n $DB_SCHEMA > "$NOW-Databases.sql"
tar -zcvf "$DESTFILE" "$NOW-Databases.sql"

$SCRIPT_DIR/dropbox_uploader.sh upload "$DESTFILE" "$DROPBOX_DIR/$NOW.tar.gz"

rm -f "$NOW-Databases.sql" "$DESTFILE"
