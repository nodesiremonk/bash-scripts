#!/bin/bash

function getJsonVal () { 
    python3 -c "import json,sys;sys.stdout.write(json.load(sys.stdin)$1)";
}

BOX_ACCESS_TOKEN="box_token"
BOX_FOLDER_ID="123456789"
BACKUP_SRC="/path/to/backup/"
BACKUP_DST="/tmp"
MYSQL_USER="root"
MYSQL_PASS="rootpassword"
MYSQL_DB="--all-databases"
MYSQL_CONTAINER="mysql"

TODAY=$(date +"%A")
FILE_NAME="$TODAY.tar.gz"
DEST_FILE="$BACKUP_DST/$FILE_NAME"

/usr/bin/docker exec $MYSQL_CONTAINER /usr/bin/mysqldump -u $MYSQL_USER -p$MYSQL_PASS $MYSQL_DB > "$TODAY-DB.sql"
tar --exclude-vcs -zcf "$DEST_FILE" $BACKUP_SRC "$TODAY-DB.sql"

PARM="{\"name\":\"$FILE_NAME\",\"parent\":{\"id\":\"$BOX_FOLDER_ID\"}}"
AUTH="Authorization: Bearer $BOX_ACCESS_TOKEN"

CHECK_FILE=$(curl -X OPTIONS "https://api.box.com/2.0/files/content" \
    -H "$AUTH" \
    -H "Content-Type: application/json" \
    -d $PARM
)

CODE=$(echo $CHECK_FILE | getJsonVal "['code']")

if [ $CODE == "item_name_in_use" ]
then
    # file exists, update version
    FILE_ID=$(echo $CHECK_FILE | getJsonVal "['context_info']['conflicts']['id']")
    URL="https://upload.box.com/api/2.0/files/$FILE_ID/content"
else
    # upload file
    URL="https://upload.box.com/api/2.0/files/content"
fi

curl -i -X POST "$URL" \
    -H "$AUTH" \
    -H "Content-Type: multipart/form-data" \
    -F attributes="$PARM" \
    -F file=@$DEST_FILE

rm -f "$TODAY-DB.sql" "$DEST_FILE"
