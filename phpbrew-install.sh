#!/bin/bash
export PHP_VERSION="7.0.14"

export DEBIAN_FRONTEND=noninteractive

sudo apt install build-essential \
    libcurl4-openssl-dev \
    libssl-dev \
    libsslcommon2-dev \
    libgd-dev \
    libjpeg-dev \
    libpng-dev \
    libxslt1-dev \
    re2c \
    libxml2-dev \
    libbz2-dev \
    libreadline-dev \
    libfreetype6-dev \
    libltdl-dev \
    gettext \
    libgettextpo-dev \
    libicu-dev \
    libmhash-dev \
    libmcrypt-dev \
    libmysqlclient-dev \
    libpq-dev \
    libfreetype6 \
    libc-client2007e-dev \
    libkrb5-dev

if [ ! -d ~/.phpbrew ]; then
    phpbrew init
    source "$HOME/.phpbrew/bashrc"
fi

phpbrew install -j "$(nproc)" "${PHP_VERSION}" +default +curl +gmp +imap +json +xml +mbstring +mcrypt +xml_all +zlib +fpm +gettext +mysql +intl +xmlrpc +iconv +soap +exif +pgsql -- --with-libdir=lib/x86_64-linux-gnu
phpbrew switch "php-${PHP_VERSION}"
phpbrew ext install gd -- --with-freetype-dir=/usr/include
phpbrew ext install opcache -- --enable-opcache
phpbrew ext install imap -- --with-kerberos --with-imap-ssl
phpbrew ext install mailparse
