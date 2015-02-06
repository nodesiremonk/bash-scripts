#!/bin/bash

DEV_DIR="/var/www/develop_dir/"
PDT_DIR="/var/www/production_dir/"

if [[ $1 = "go" ]]
then
    OPT="aLnv"
elif [[ $1 = "do" ]]
then
    OPT="aLv"
else
    OPT=""
fi

if [[ -z $OPT ]]
then
    echo ' '
    echo 'Usage:' `basename $0` '[action]'
    echo 'Available actions:'
    echo ' go  :  dry-run'
    echo ' do  :  sync'
else
    if [[ ! -d $PDT_DIR ]]
    then
        mkdir -p $PDT_DIR
    fi
    rsync -$OPT --exclude-from="$DEV_DIR/rsync_ignore" --delete $DEV_DIR/ $PDT_DIR/
fi
