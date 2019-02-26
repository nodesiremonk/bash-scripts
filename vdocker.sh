#!/bin/bash

############################################################
# core functions
############################################################
function check_install {
	if [ -z "`which "$1" 2>/dev/null`" ]
	then
		executable=$1
		shift
		while [ -n "$1" ]
		do
			DEBIAN_FRONTEND=noninteractive apt-get -q -y install "$1"
			apt-get clean
			print_info "$1 installed for $executable"
			shift
		done
	else
		print_warn "$2 already installed"
	fi
}

function check_remove {
	if [ -n "`which "$1" 2>/dev/null`" ]
	then
		DEBIAN_FRONTEND=noninteractive apt-get -q -y remove --purge "$2"
		apt-get clean
		print_info "$2 removed"
	else
		print_warn "$2 is not installed"
	fi
}

function check_sanity {
	# Do some sanity checking.
	if [ $(/usr/bin/id -u) != "0" ]
	then
		die 'Must be run by root user'
	fi

	if [ ! -f /etc/debian_version ]
	then
		die "Distribution is not supported"
	fi
}

function die {
	echo "ERROR: $1" > /dev/null 1>&2
	exit 1
}

function get_domain_name() {
	# Getting rid of the lowest part.
	domain=${1%.*}
	lowest=`expr "$domain" : '.*\.\([a-z][a-z]*\)'`
	case "$lowest" in
	com|net|org|gov|edu|co|me|info|name)
		domain=${domain%.*}
		;;
	esac
	lowest=`expr "$domain" : '.*\.\([a-z][a-z]*\)'`
	[ -z "$lowest" ] && echo "$domain" || echo "$lowest"
}

function get_password() {
	# Check whether our local salt is present.
	SALT=/var/lib/radom_salt
	if [ ! -f "$SALT" ]
	then
		head -c 512 /dev/urandom > "$SALT"
		chmod 400 "$SALT"
	fi
	password=`(cat "$SALT"; echo $1) | md5sum | base64`
	echo ${password:0:13}
}

function print_info {
	echo -n -e '\e[1;36m'
	echo -n $1
	echo -e '\e[0m'
}

function print_warn {
	echo -n -e '\e[1;33m'
	echo -n $1
	echo -e '\e[0m'
}

function show_os_arch_version {
	# Thanks for Mikel (http://unix.stackexchange.com/users/3169/mikel) for the code sample which was later modified a bit
	# http://unix.stackexchange.com/questions/6345/how-can-i-get-distribution-name-and-version-number-in-a-simple-shell-script
	ARCH=$(uname -m | sed 's/x86_//;s/i[3-6]86/32/')

	if [ -f /etc/lsb-release ]; then
		. /etc/lsb-release
		OS=$DISTRIB_ID
		VERSION=$DISTRIB_RELEASE
	elif [ -f /etc/debian_version ]; then
		# Work on Debian and Ubuntu alike
		OS=$(lsb_release -si)
		VERSION=$(lsb_release -sr)
	elif [ -f /etc/redhat-release ]; then
		# Add code for Red Hat and CentOS here
		OS=Redhat
		VERSION=$(uname -r)
	else
		# Pretty old OS? fallback to compatibility mode
		OS=$(uname -s)
		VERSION=$(uname -r)
	fi

	OS_SUMMARY=$OS
	OS_SUMMARY+=" "
	OS_SUMMARY+=$VERSION
	OS_SUMMARY+=" "
	OS_SUMMARY+=$ARCH
	OS_SUMMARY+="bit"

	print_info "$OS_SUMMARY"
}

############################################################
# applications
############################################################
function install_nano {
	check_install nano nano
}

function install_lsb_release {
	check_install lsb_release lsb_release
}

function install_fail2ban {
	check_install fail2ban fail2ban
}

function install_htop {
	check_install htop htop
}

function install_iotop {
	check_install iotop iotop
}

function install_iftop {
	check_install iftop iftop
	print_warn "Run IFCONFIG to find your net. device name"
	print_warn "Example usage: iftop -i venet0"
}

function install_sslcert {
	if [ -z "$1" ]
	then
		die "Usage: `basename $0` site [domain] [email]"
	fi
	if [ -z "$2" ]
	then
		die "Usage: `basename $0` site [domain] [email]"
	fi
    
	mkdir -p /var/www/letsencrypt
	mkdir -p /etc/letsencrypt/configs
	cat > "/etc/letsencrypt/configs/$1.conf" <<END
# the domain we want to get the cert for;
# technically it's possible to have multiple of this lines, but it only worked
# with one domain for me, another one only got one cert, so I would recommend
# separate config files per domain.
domains = $1

# increase key size
rsa-key-size = 4096

# the current closed beta (as of 2015-Nov-07) is using this server
server = https://acme-v01.api.letsencrypt.org/directory

# this address will receive renewal reminders
email = $2

# turn off the ncurses UI, we want this to be run as a cronjob
text = True

# authenticate by placing a file in the webroot (under .well-known/acme-challenge/)
# and then letting LE fetch it
authenticator = webroot
webroot-path = /var/www/letsencrypt/	
END

#	renew_sslcert $1
}

function install_site {

	if [ -z "$1" ]
	then
		die "Usage: `basename $0` site [domain]"
	fi

	# Setup folder
	mkdir /var/www/$1
	mkdir /var/www/$1/public

	# Setup default index.html file
	cat > "/var/www/$1/public/index.html" <<END
Hello World
END

	# Setting up Nginx mapping
	cat > "/etc/nginx/sites-available/$1.conf" <<END
server {
	listen 80;
	server_name $1;
	root /var/www/$1/public;
	index index.html index.php;
	client_max_body_size 32m;

	access_log  /var/log/nginx/$1.access.log;
	error_log  /var/log/nginx/$1.error.log;
	#error_page 404 /error/404/index.html;
	
	add_header X-Frame-Options DENY;
	add_header X-Content-Type-Options nosniff;
	
	#=========== Https start ===========
	#listen 443 ssl;  # ssl only
	#listen 443 ssl spdy;  # ssl with spdy
	#listen 443 ssl http2; # ssl with http2, supported by v1.9.5
        #ssl_certificate /etc/letsencrypt/live/$1/fullchain.pem;
        #ssl_certificate_key /etc/letsencrypt/live/$1/privkey.pem;
        
        #ssl_session_cache shared:SSL:20m;
        #ssl_session_timeout 60m;

        #ssl_prefer_server_ciphers on;
        #ssl_ciphers ECDH+AESGCM:ECDH+AES256:ECDH+AES128:DH+3DES:!ADH:!AECDH:!MD5;
        
        # Need to create DH parameters file by: openssl dhparam 2048 -out /etc/nginx/cert/dhparam.pem
        #ssl_dhparam /etc/nginx/cert/dhparam.pem;

        #ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
        
        # Enable OCSP stapling, need to generate .crt first
        #ssl_stapling on;
        #ssl_stapling_verify on;
        #ssl_trusted_certificate /etc/nginx/cert/trustchain.crt;
        #resolver 8.8.8.8 8.8.4.4;
        
        # enable STS
        #add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
        #add_header Strict-Transport-Security "max-age=31536000" always;
        
	#=========== Https End ===========
	
	# Directives to send expires headers and turn off 404 error logging.
	location ~* \.(js|css|png|jpg|jpeg|gif|svg|mp3|mp4|ico)$ {
		expires max;
		log_not_found off;
		access_log off;
		
		# prevent hotlink
		# valid_referers none blocked ~.google. ~.bing. ~.yahoo. server_names ~($host);
		# if (\$invalid_referer) {
		#    rewrite (.*) /static/images/hotlink-denied.jpg redirect;
		#    # or use "return 403;" if don't want to redirect
		#    # drop the 'redirect' flag for redirect without URL change (internal rewrite)
		#    # need to add another line for: location = /static/images/hotlink-denied.jpg { }
		#}
		
	}

	location = /favicon.ico {
		log_not_found off;
		access_log off;
	}

	location = /robots.txt {
		allow all;
		log_not_found off;
		access_log off;
	}

	## Disable viewing .htaccess & .htpassword
	location ~ /\.ht {
		deny  all;
	}
	
	## To allow Let's Encrypt to access the temporary file
	location /.well-known/acme-challenge {
        	root /var/www/letsencrypt;
	}

	include /etc/nginx/php.conf;
}

# redirect www to non-www
#server {
#        server_name www.$1;
#        return 301 \$scheme://$1\$request_uri;
#}

# force https. need to remove listen 80 and just leave listen 443 and ssl config there
#server {
#       listen         80;
#       server_name    $1;
#       return         301 https://$1\$request_uri;
#}
END
	# Create the link so nginx can find it
	ln -s /etc/nginx/sites-available/$1.conf /etc/nginx/sites-enabled/$1.conf

	# PHP/Nginx needs permission to access this
	chown www-data:www-data -R "/var/www/$1"

	invoke-rc.d nginx restart

	print_warn "New site successfully installed."
}

function install_iptables {

	check_install iptables iptables

	if [ -z "$1" ]
	then
		die "Usage: `basename $0` iptables [ssh-port-#]"
	fi

	# Create startup rules
	cat > /etc/iptables.up.rules <<END
*filter

# http://articles.slicehost.com/2010/4/30/ubuntu-lucid-setup-part-1

#  Allows all loopback (lo0) traffic and drop all traffic to 127/8 that doesn't use lo0
-A INPUT -i lo -j ACCEPT
-A INPUT ! -i lo -d 127.0.0.0/8 -j REJECT

#  Accepts all established inbound connections
-A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

#  Allows all outbound traffic
#  You can modify this to only allow certain traffic
-A OUTPUT -j ACCEPT

# Allows HTTP and HTTPS connections from anywhere (the normal ports for websites)
-A INPUT -p tcp --dport 80 -j ACCEPT
-A INPUT -p tcp --dport 443 -j ACCEPT

# UN-COMMENT THESE IF YOU USE INCOMING MAIL!

# Allows POP (and SSL-POP)
#-A INPUT -p tcp --dport 110 -j ACCEPT
#-A INPUT -p tcp --dport 995 -j ACCEPT

# SMTP (and SSMTP)
#-A INPUT -p tcp --dport 25 -j ACCEPT
#-A INPUT -p tcp --dport 465 -j ACCEPT

# IMAP (and IMAPS)
#-A INPUT -p tcp --dport 143 -j ACCEPT
#-A INPUT -p tcp --dport 993 -j ACCEPT

#  Allows SSH connections (only 3 attempts by an IP every minute, drop the rest to prevent SSH attacks)
-A INPUT -p tcp -m tcp --dport $1 -m state --state NEW -m recent --set --name DEFAULT --rsource
-A INPUT -p tcp -m tcp --dport $1 -m state --state NEW -m recent --update --seconds 60 --hitcount 3 --name DEFAULT --rsource -j DROP
-A INPUT -p tcp -m state --state NEW --dport $1 -j ACCEPT

# Allow ping
-A INPUT -p icmp -m icmp --icmp-type 8 -j ACCEPT

# log iptables denied calls (Can grow log files fast!)
#-A INPUT -m limit --limit 5/min -j LOG --log-prefix "iptables denied: " --log-level 7

# Misc

# Reject all other inbound - default deny unless explicitly allowed policy
#-A INPUT -j REJECT
#-A FORWARD -j REJECT

# It's safer to just DROP the packet
-A INPUT -j DROP
-A FORWARD -j DROP

COMMIT
END

	# Set these rules to load on startup
	cat > /etc/network/if-pre-up.d/iptables <<END
#!/bin/sh
/sbin/iptables-restore < /etc/iptables.up.rules
END

	# Make it executable
	chmod +x /etc/network/if-pre-up.d/iptables

	# Load the rules
	iptables-restore < /etc/iptables.up.rules

	# You can flush the current rules with /sbin/iptables -F
	echo 'Created /etc/iptables.up.rules and startup script /etc/network/if-pre-up.d/iptables'
	echo 'If you make changes you can restore the rules with';
	echo '/sbin/iptables -F'
	echo 'iptables-restore < /etc/iptables.up.rules'
	echo ' '
}

function remove_unneeded {
	# Some Debian have portmap installed. We don't need that.
	check_remove /sbin/portmap portmap

	# Remove rsyslogd, which allocates ~30MB privvmpages on an OpenVZ system,
	# which might make some low-end VPS inoperatable. We will do this even
	# before running apt-get update.
#check_remove /usr/sbin/rsyslogd rsyslog

	# Other packages that are quite common in standard OpenVZ templates.
	check_remove /usr/sbin/apache2 'apache2*'
	check_remove /usr/sbin/named 'bind9*'
	check_remove /usr/sbin/smbd 'samba*'
	check_remove /usr/sbin/nscd nscd

	# Need to stop sendmail as removing the package does not seem to stop it.
	if [ -f /usr/lib/sm.bin/smtpd ]
	then
		invoke-rc.d sendmail stop
		check_remove /usr/lib/sm.bin/smtpd 'sendmail*'
	fi
}

############################################################
# Classic Disk I/O and Network speed tests
############################################################
function runtests {
	print_info "Classic I/O test"
	print_info "dd if=/dev/zero of=iotest bs=64k count=16k conv=fdatasync && rm -fr iotest"
	dd if=/dev/zero of=iotest bs=64k count=16k conv=fdatasync && rm -fr iotest

	print_info "Network test"
	print_info "wget cachefly.cachefly.net/100mb.test -O 100mb.test && rm -fr 100mb.test"
	wget cachefly.cachefly.net/100mb.test -O 100mb.test && rm -fr 100mb.test
}

function apt_clean {
	apt-get -q -y autoclean
	apt-get -q -y clean
}

function update_upgrade {
	# Run through the apt-get update/upgrade first.
	# This should be done before we try to install any package
	apt-get -q -y update
	apt-get -q -y upgrade

	# also remove the orphaned stuff
	apt-get -q -y autoremove
}

function install_certbot {
	apt-get -y install certbot -t $(lsb_release -cs)-backports
	print_warn "Certbot has been installed."
}

function install_docker {
	apt update && apt -y install apt-transport-https ca-certificates curl gnupg2 software-properties-common
	curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
	add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"
	apt update && apt -y install docker-ce docker-ce-cli containerd.io
	# might need to reboot here
	# change 1.23.2 to latest version
	curl -L "https://github.com/docker/compose/releases/download/1.23.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
	chmod +x /usr/local/bin/docker-compose
}

function install_backport {
	echo "deb http://deb.debian.org/debian $(lsb_release -cs)-backports main\n > /etc/apt/sources.list.d/backports.list"
	apt update
	print_warn "backport has been installed."
}

######################################################################## 
# START OF PROGRAM
########################################################################
export PATH=/bin:/usr/bin:/sbin:/usr/sbin

check_sanity
case "$1" in
docker)
	install_docker
	;;
backport)
	install_backport
	;;    
sslcert)
	install_sslcert $2 $3
	;;
site)
	install_site $2
	;;
iptables)
	install_iptables $2
	;;
test)
	runtests
	;;
certbot)
	install_certbot
	;;	
system)
	update_timezone
	remove_unneeded
	update_upgrade
	install_lsb_release
	install_nano
	install_htop
	install_fail2ban
	install_iotop
	install_iftop
	apt_clean
	;;
*)
	show_os_arch_version
	echo '  '
	echo 'Usage:' `basename $0` '[option] [argument]'
	echo 'Available options (in recomended order):'
	echo '  - system                         (remove unneeded, upgrade system, install software)'
	echo '  - iptables  [port]               (setup basic firewall with HTTP(S) open)'
	echo '  - backport                       (install backport repo, required for certbot)'
    echo '  - docker                         (install docker)'
	echo '  - certbot                        (install Certbot from backports)'
	echo '  - site      [domain.tld]         (create nginx vhost and /var/www/$site/public)'
	echo '  - sslcert   [domain.tld] [email] (get ssl cert for site, run letsencrypt first)'
	echo '  - test                           (Run the classic disk IO and classic cachefly network test)'
	echo '  '
	;;
esac
