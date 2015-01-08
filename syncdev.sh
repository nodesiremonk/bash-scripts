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
  echo 'Usage:' `basename $0` '[action] [folder]'
  echo 'Available actions:'
  echo ' go  :  dry-run'
  echo ' do  :  sync'
else
  if [[ -z $2 ]]
  then
    echo 'please choose project folder'
  else
    if [[ ! -d $PDT_DIR/$2 ]]
    then
      mkdir -p $PDT_DIR/$2
    fi  
    if [[ ! -f $PDT_DIR/$2/rsync_ignore ]]
    then
      cat > $PDT_DIR/$2/rsync_ignore <<END
.git
.gitignore
rsync_ignore
public/tmp
END
    fi
    rsync -$OPT --exclude-from="$PDT_DIR/$2/rsync_ignore" --delete $DEV_DIR/$2/ $PDT_DIR/$2/
  fi
fi
