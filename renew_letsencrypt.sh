#!/bin/sh

if [[ $1 ]]
then
    CONF=/etc/letsencrypt/configs/$1.conf
    if [[ -f $CONF ]]
    then
        cd /opt/letsencrypt/
        ./letsencrypt-auto --config $CONF certonly
        if [ $? -ne 0 ]
        then
            ERRORLOG=`tail /var/log/letsencrypt/letsencrypt.log`
            echo -e "The Let's Encrypt cert has not been renewed! \n \n" \
                $ERRORLOG
        else
            /usr/sbin/nginx -s reload
            echo -e "The Let's Encrypt cert has been successfully renewed! \n \n"
        fi
    else
        die "config file is not found"
    fi
else
    echo ' '
    echo 'Usage:' `basename $0` '[site]'
    echo 'Please specify the site name'
fi

exit 0
