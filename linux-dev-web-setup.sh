#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

source /etc/os-release

DEVPATH="$HOME/Dev/host"

cat <<EOF

Local web development environment setup by Matt Spurrier
https://github.com/digitalsparky/dev-tools

This has been written for Linux Mint/Ubuntu/Ubuntu Variants, however feel free to adapt

This does the following:

* Installs latest NginX from the NginX Repository
* Installs Docker from the Docker repository
* Installs phpbrew and required build dependencies
* Installs composer
* Configures NginX with dynamic hosts for your local filesystem
* Sets up dnsmasq to direct all *.local DNS requests to 127.0.0.1

This allows you to address http://<project>.local from
$DEVPATH/<project>

NginX Logs are available in:

$DEVPATH/logs

Public web directory is:

$DEVPATH/<project>/public

Note: We're using docker for the purpose of running databases et al.
We're using phpbrew in order to dynamically change PHP versions as required.

Run php-fpm, listening on 127.0.0.1:9000

This script does not install PHP using phpbrew - use the phpbrew-install script for that.

EOF

read -p "Are you sure you wish to continue? " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi

sudo apt-get install -qy curl linux-image-extra-$(uname -r) linux-image-extra-virtual apt-transport-https ca-certificates software-properties-common > /dev/null 2>&1

sudo add-apt-repository ppa:nginx/stable

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu ${UBUNTU_CODENAME} stable"

sudo apt-get -q update > /dev/null 2>&1
sudo apt-get -q -y upgrade > /dev/null 2>&1
sudo apt-get -q -y dist-upgrade > /dev/null 2>&1

PACKAGES=$(cat <<EOF
    nginx-extras
    php7.0-cli
    php7.0-curl
    libcurl3-openssl-dev
    libxslt1-dev
    re2c
    libxml2
    libxml2-dev
    bison
    libbz2-dev
    libreadline-dev
    libfreetype6
    libfreetype6-dev
    libpng12-0
    libpng12-dev
    libjpeg-dev
    libjpeg8-dev
    libjpeg8
    libgd-dev
    libgd3
    libxpm4
    libltdl7
    libltdl-dev
    libssl-dev
    gettext
    libgettextpo-dev
    libgettextpo0
    libicu-dev
    libmhash-dev
    libmhash2
    libmcrypt-dev
    libmcrypt4
    libmysqlclient-dev
    libpq-dev
    libfreetype6
    libc-client2007e-dev
    libkrb5-dev
    libmemcached-dev
    libldap2-dev
    docker-ce
EOF
)

sudo apt-get install -yq  > /dev/null 2>&1
sudo apt-get install -yq ${PACKAGES} > /dev/null 2>&1

sudo curl -o /usr/local/bin/phpbrew https://raw.githubusercontent.com/phpbrew/phpbrew/master/phpbrew > /dev/null 2>&1
sudo chmod a+x /usr/local/bin/phpbrew

EXPECTED_SIGNATURE=$(wget -q -O - https://composer.github.io/installer.sig)
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
ACTUAL_SIGNATURE=$(php -r "echo hash_file('SHA384', 'composer-setup.php');")

if [ "$EXPECTED_SIGNATURE" != "$ACTUAL_SIGNATURE" ]; then
    >&2 echo 'ERROR: Invalid installer signature'
    rm composer-setup.php
    exit 1
fi

php composer-setup.php --quiet
RESULT=$?
rm composer-setup.php
exit $RESULT

if [ ! -d "$DEVPATH" ]; then
    mkdir -p "$DEVPATH"
fi

if [ ! -d "$DEVPATH/logs" ]; then
    mkdir -p "$DEVPATH/logs"
fi

sudo tee /etc/nginx/nginx.conf <<EOF > /dev/null
include "/etc/nginx/modules-enabled/*.conf";
user                  $USER $USER;
worker_processes      auto;
worker_rlimit_nofile  8192;
events {
    use                 epoll;
    multi_accept        on;
    worker_connections  8000;
}
pid                   /var/run/nginx.pid;
http {
    disable_symlinks            off;
    server_tokens               off;
    types_hash_max_size         2048;
    default_type                application/octet-stream;
    include                     /etc/nginx/mime.types;
    access_log                  $DEVPATH/logs/access.log combined;
    error_log                   $DEVPATH/logs/error.log debug;
    rewrite_log                 on;
    client_max_body_size        32m;
    client_body_buffer_size     32m;
    keepalive_timeout           20;
    sendfile                    on;
    tcp_nopush                  on;
    tcp_nodelay                 on;
    charset_types               text/css text/plain text/vnd.wap.wml application/javascript application/json application/rss+xml application/xml;
    gzip                        on;
    gzip_comp_level             5;
    gzip_min_length             256;
    gzip_proxied                any;
    gzip_vary                   on;
    gzip_http_version           1.1;
    gzip_disable                "MSIE [1-6]\.(?!.*SV1)";
    gzip_buffers                16 8k;
    gzip_types                  application/atom+xml
                                application/javascript
                                application/x-javascript
                                application/json
                                application/ld+json
                                application/manifest+json
                                application/rss+xml
                                application/vnd.geo+json
                                application/vnd.ms-fontobject
                                application/x-font-ttf
                                application/x-web-app-manifest+json
                                application/xhtml+xml
                                application/xml
                                font/opentype
                                image/bmp
                                image/svg+xml
                                image/x-icon
                                text/cache-manifest
                                text/css
                                text/plain
                                text/vcard
                                text/vnd.rim.location.xloc
                                text/vtt
                                text/x-component
                                text/x-cross-domain-policy;
    reset_timedout_connection on;
    map \$http_x_forwarded_proto \$fehttps {
        default off;
        https on;
    }
    server {
        listen                  127.0.0.1:80 default_server;
        server_name             localhost;
    }
    include "/etc/nginx/includes/*.conf";
}
EOF

if [ ! -d /etc/nginx/includes ]; then
    sudo mkdir /etc/nginx/includes
fi

sudo tee /etc/nginx/includes/local.conf <<EOF > /dev/null
upstream php {
    server                   127.0.0.1:9000;
}

server {
    listen                   127.0.0.1:80;
    server_name              ~^(?<site_id>.+)\.local\$;
    root                     $DEVPATH/\$site_id/public;
    location ~ [^/]\.php(/|\$) {
        fastcgi_split_path_info  ^(.+\.php)(/.+)\$;
        fastcgi_pass php;
        fastcgi_index index.php;
        fastcgi_param HTTP_PROXY "";
        fastcgi_param PATH_INFO       \$fastcgi_path_info;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include       fastcgi_params;
    }
    location / {
        index index.php index.html index.htm;
    }
}
EOF

sudo tee /etc/nginx/fastcgi_params <<EOF > /dev/null
fastcgi_param  QUERY_STRING       \$query_string;
fastcgi_param  REQUEST_METHOD     \$request_method;
fastcgi_param  CONTENT_TYPE       \$content_type;
fastcgi_param  CONTENT_LENGTH     \$content_length;
fastcgi_param  SCRIPT_NAME        \$fastcgi_script_name;
fastcgi_param  REQUEST_URI        \$request_uri;
fastcgi_param  DOCUMENT_URI       \$document_uri;
fastcgi_param  DOCUMENT_ROOT      \$document_root;
fastcgi_param  SERVER_PROTOCOL    \$server_protocol;
fastcgi_param  REQUEST_SCHEME     \$scheme;
fastcgi_param  HTTPS              \$https if_not_empty;
fastcgi_param  HTTPS              \$fehttps if_not_empty;
fastcgi_param  GATEWAY_INTERFACE  CGI/1.1;
fastcgi_param  SERVER_SOFTWARE    nginx;
fastcgi_param  REMOTE_ADDR        \$remote_addr;
fastcgi_param  REMOTE_PORT        \$remote_port;
fastcgi_param  SERVER_ADDR        \$server_addr;
fastcgi_param  SERVER_PORT        \$server_port;
fastcgi_param  SERVER_NAME        \$server_name;
fastcgi_param  REDIRECT_STATUS    200;
EOF

sudo tee /etc/NetworkManager/dnsmasq.d/local.conf <<EOF > /dev/null
address=/local/127.0.0.1
EOF

sudo service network-manager restart> /dev/null 2>&1
sudo service nginx restart> /dev/null 2>&1

sudo usermod -aG docker $USER

echo "All setup now"
echo "You can use <project>.local as the hostname for any site"
echo "Using $DEVPATH/<project>/public as the root directory"
echo "PHPBREW has been installed, it's up to you to set it up, make sure php-fpm is configured to listen on 127.0.0.1:9000"
echo ""
echo "IMPORTANT: You've been added to the docker user group, however will not be able to use docker commands until you logout and back in again"
