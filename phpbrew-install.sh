#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

export PHP_VERSION="7.0.14"
phpbrew init
source "$HOME/.phpbrew/bashrc"

phpbrew --quiet --no-progress install --production -j $(nproc) "${PHP_VERSION}" +default+fpm+gettext+mysql+intl+xml_all+xmlrpc+iconv+curl+soap+exif+pgsql

phpbrew switch php-${PHP_VERSION}
phpbrew --no-progress -v ext install gd -- --with-freetype-dir=/usr/include
phpbrew --no-progress -v ext install opcache -- --enable-opcache
