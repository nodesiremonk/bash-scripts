#!/bin/bash

LOCAL_MYSQL_USER=""
LOCAL_MYSQL_PASSWORD=""
LOCAL_DATABASE=""
REMOTE_MYSQL_SERVER=""
REMOTE_MYSQL_USER=""
REMOTE_MYSQL_PASSWORD=""
REMOTE_DATABASE=""

if [[ $1 = "backup" ]]
then
    mysqldump -u $LOCAL_MYSQL_USER -p$LOCAL_MYSQL_PASSWORD $LOCAL_DATABASE | sed -e 's/DEFINER[ ]*=[ ]*[^*]*\*/\*/' | mysql -u $REMOTE_MYSQL_USER -p$REMOTE_MYSQL_PASSWORD --host=$REMOTE_MYSQL_SERVER -C $REMOTE_DATABASE
elif [[ $1 = "restore" ]]
then
    mysqldump -u $REMOTE_MYSQL_USER -p$REMOTE_MYSQL_PASSWORD --host=$REMOTE_MYSQL_SERVER $REMOTE_DATABASE | sed -e 's/DEFINER[ ]*=[ ]*[^*]*\*/\*/' | mysql -u $LOCAL_MYSQL_USER -p$LOCAL_MYSQL_PASSWORD -C $LOCAL_DATABASE
else
    echo ' '
    echo 'Usage:' `basename $0` '[action]'
    echo 'Available actions:'
    echo ' backup  :  backup local db to remote server'
    echo ' retore  :  restore remote backup db to local server'
fi
