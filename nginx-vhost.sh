#!/bin/bash
echo '[quick-lemp] Add new NGINX vhost'
echo
if [[ $EUID -ne 0 ]]; then
   echo 'This script must be run with root privileges.' 1>&2
   exit 1
fi

# Nginx
echo -e '\n[Nginx]'
echo
read -e -p 'VHOST name (only alphanum) ' VHOSTNAME
echo

echo
read -p 'Do you want to create a self-signed SSL cert and configure HTTPS? [y/N] ' -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
  conf1="  listen 443 ssl;\n"
  conf2="  include h5bp/directive-only/ssl.conf;\n  ssl_certificate /etc/ssl/certs/$VHOSTNAME.crt;\n  ssl_certificate_key /etc/ssl/private/$VHOSTNAME.key;"
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/$VHOSTNAME.key -out /etc/ssl/certs/$VHOSTNAME.crt
  chmod 400 /etc/ssl/private/$VHOSTNAME.key
else
  conf1=
  conf2=
  conf3=
fi

echo -e "server {
  listen 80;
$conf1
  server_name $VHOSTNAME;

$conf2
  root /var/www/$VHOSTNAME/public;

  charset utf-8;
  error_page 404 /404.html;
  location = /favicon.ico { log_not_found off; access_log off; }
  location = /robots.txt { allow all; log_not_found off; access_log off; }
  client_max_body_size 20M;

  location ^~ /static/ {
    alias /var/www/$VHOSTNAME/static;
  }

  location ~ \\.php\$ {
    try_files \$uri =404;
    fastcgi_pass unix:/var/run/php/php7.0-fpm.sock;
    fastcgi_read_timeout 300;
    fastcgi_param SCRIPT_FILENAME \$request_filename;
    fastcgi_index index.php;
    include fastcgi_params;
  }

}" > /etc/nginx/sites-available/$VHOSTNAME

mkdir -p /var/www/$VHOSTNAME/public
mkdir -p /var/www/$VHOSTNAME/static
ln -s /etc/nginx/sites-available/$VHOSTNAME /etc/nginx/sites-enabled/$VHOSTNAME

echo
service nginx restart
echo
exit 0
