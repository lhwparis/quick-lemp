#!/bin/bash
echo '[quick-lemp] LEMP Stack Installation'
echo 'Configured for Ubuntu 14.04.'
echo 'Installs Nginx, PHP7-FPM, MariaDB.'
echo
read -p 'Do you want to continue? [y/N] ' -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo 'Exiting...'
  exit 1
fi
if [[ $EUID -ne 0 ]]; then
   echo 'This script must be run with root privileges.' 1>&2
   exit 1
fi



# Update packages and add MariaDB repository
echo -e '\n[Package Updates]'
apt-get install software-properties-common
apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xcbcb082a1bb943db
add-apt-repository 'deb http://mirrors.syringanetworks.net/mariadb/repo/10.1/ubuntu trusty main'
add-apt-repository ppa:nginx/stable
apt-get install -y language-pack-en-base
LC_ALL=en_US.UTF-8 add-apt-repository ppa:ondrej/php-7.0
apt-get update

# Depencies and pip
echo -e '\n[Dependencies]'
sudo update-rc.d apache2 disable
apt-get -y remove apache2 mysql php5 php5-fpm
apt-get -y install build-essential debconf-utils libpcre3-dev libssl-dev curl

apt-get update
apt-get -y upgrade

# Nginx
echo -e '\n[Nginx]'
# remove apache2
apt-get -y install nginx
service nginx stop
mv /etc/nginx /etc/nginx-previous
curl -L https://github.com/h5bp/server-configs-nginx/archive/1.0.0.tar.gz | tar -xz
# Newer: https://github.com/h5bp/server-configs-nginx/archive/master.zip
mv server-configs-nginx-1.0.0 /etc/nginx
cp /etc/nginx-previous/uwsgi_params /etc/nginx-previous/fastcgi_params /etc/nginx
sed -i.bak -e
sed -i.bak -e "s/www www/www-data www-data/" \
  -e "s/logs\/error.log/\/var\/log\/nginx\/error.log/" \
  -e "s/logs\/access.log/\/var\/log\/nginx\/access.log/" /etc/nginx/nginx.conf
sed -i.bak -e "s/logs\/static.log/\/var\/log\/nginx\/static.log/" /etc/nginx/h5bp/location/expires.conf

echo
read -p 'Do you want to create a self-signed SSL cert and configure HTTPS? [y/N] ' -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
  conf1="  listen 443 ssl default_server;\n"
  conf2="  include h5bp/directive-only/ssl.conf;\n  ssl_certificate /etc/ssl/certs/nginx.crt;\n  ssl_certificate_key /etc/ssl/private/nginx.key;"
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/nginx.key -out /etc/ssl/certs/nginx.crt
  chmod 400 /etc/ssl/private/nginx.key
else
  conf1=
  conf2=
  conf3=
fi

echo -e "server {
  listen 80 default_server;
$conf1
  server_name _;

$conf2
  root /var/www/vhost1/public;

  charset utf-8;
  error_page 404 /404.html;
  location = /favicon.ico { log_not_found off; access_log off; }
  location = /robots.txt { allow all; log_not_found off; access_log off; }

  location ^~ /static/ {
    alias /var/www/vhost1/static;
  }

  location ~ \\.php\$ {
    try_files \$uri =404;
    fastcgi_pass unix:/var/run/php/php7.0-fpm.sock;
    fastcgi_param SCRIPT_FILENAME \$request_filename;
    fastcgi_index index.php;
    include fastcgi_params;
  }

}" > /etc/nginx/sites-available/vhost1

mkdir -p /var/www/vhost1/public
mkdir -p /var/www/vhost1/static
ln -s /etc/nginx/sites-available/vhost1 /etc/nginx/sites-enabled/vhost1

# PHP
echo -e '\n[PHP-FPM]'
apt-get -q -y install php7.0-fpm php7.0-common php7.0-curl php7.0-gd php7.0-cli php-pear php7.0-imap php7.0-mcrypt php7.0-opcache php7.0-json
echo '<?php phpinfo(); ?>' > /var/www/vhost1/public/checkinfo.php

# Permissions
echo -e '\n[Adjusting Permissions]'
chgrp -R www-data /var/www/*
chmod -R g+rw /var/www/*
sh -c 'find /var/www/* -type d -print0 | sudo xargs -0 chmod g+s'

# MariaDB

echo
read -p 'Do you want to install MariaDb? [y/N] ' -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo -e '\n[MariaDB]'
  export DEBIAN_FRONTEND=noninteractive
  apt-get -q -y install mariadb-server php7.0-mysql
  
  mkdir -p /usr/share/adminer
  chown -R www-data:www-data /usr/share/adminer
  wget http://www.adminer.org/latest.php -O /usr/share/adminer/index.php
  
echo -e "server {
  listen localhost:8005;
  server_name  localhost;
  server_name adminer;
  root   /usr/share/adminer;
  charset utf-8;
  location / {
    index index.php;
    try_files $uri $uri/ /index.php?$args;
    fastcgi_pass unix:/var/run/php/php7.0-fpm.sock;
    fastcgi_param SCRIPT_FILENAME \$request_filename;
    fastcgi_index index.php;
    include fastcgi_params;
  }
}" > /etc/nginx/sites-available/adminer
ln -s /etc/nginx/sites-available/adminer /etc/nginx/sites-enabled/adminer
  
fi
echo
service nginx restart
echo
exit 0
