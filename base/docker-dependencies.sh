#!/bin/bash
set -e

# Set up a temporary directory for GPG
export GNUPGHOME="$(mktemp -d)"

# Trap to clean up temporary files on exit or error
trap 'rm -rf "${GNUPGHOME}"' EXIT

# Main function to orchestrate the setup
main() {

    # Check if the script is running as root
    if [ "$(id -u)" -ne 0 ]; then
        echo "This script must be run as root. Please use sudo."
        exit 1
    fi

    info "Installing required applications" 1
    install_common_apps

    info "Installing PHP libraries" 1
    install_php_stuff

    info "Creating log directories" 1
    create_log_dirs

    info "Cleanup..." 1
    cleanup
}

# Create necessary log directories
create_log_dirs() {
    mkdir -p /var/log/supervisord/ \
        && mkdir -p /var/log/php/ \
        && chown www-data:www-data /var/log/php/ \
        && mkdir -p /var/run/php
}

# Clean up unnecessary files and packages
cleanup() {
    apt-get clean
    apt-get purge -y --auto-remove xz-utils gnupg gcc make autoconf libc-dev pkg-config
    rm -rf /usr/local/bin/wp.gpg /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*
}

# Print informational messages
info() {
    local message="$1"
    local blink=''
    [ -z "$2" ] || blink=';5'

    echo -e "\e[45;1${blink}m$message\e[0m"
}

# Install common applications and utilities
install_common_apps() {
    apt-get update && apt-get install -y --no-install-recommends \
        apt-transport-https \
        apt-utils \
        ca-certificates \
        cron \
        curl \
        dirmngr \
        git \
        gnupg \
        mysql-client \
        nginx \
        software-properties-common \
        supervisor \
        netcat \
        tar \
        unzip \
        vim \
        wget \
        xz-utils \
        openssh-server \
        rsync 
}

# Install PHP and required extensions
install_php_stuff() {
    echo "Adding PHP repository..."
    apt-get update && apt-get install -y --no-install-recommends \
        software-properties-common \
        && add-apt-repository -y ppa:ondrej/php \
        && apt-get update

    echo "Installing PHP and required extensions..."
    apt-get install -y --no-install-recommends \
        php-pear \
        php-memcache \
        php-memcached \
        php-redis \
        php-imagick \
        php-apcu \
        php-tidy \
        php${PHP_VERSION} \
        php${PHP_VERSION}-dev \
        php${PHP_VERSION}-cli \
        php${PHP_VERSION}-curl \
        php${PHP_VERSION}-mbstring \
        php${PHP_VERSION}-opcache \
        php${PHP_VERSION}-readline \
        php${PHP_VERSION}-xml \
        php${PHP_VERSION}-zip \
        php${PHP_VERSION}-fpm \
        php${PHP_VERSION}-mysql \
        php${PHP_VERSION}-bcmath \
        php${PHP_VERSION}-bz2 \
        php${PHP_VERSION}-gd \
        php${PHP_VERSION}-intl \
        php${PHP_VERSION}-soap \
        php${PHP_VERSION}-exif \
        gcc \
        make \
        autoconf \
        libc-dev \
        pkg-config \
        libmcrypt-dev \
        && printf "\n" | pecl install mcrypt-1.0.7 \
        && printf "\n" | pecl install xdebug \
        && echo "extension=mcrypt.so" > /etc/php/${PHP_VERSION}/fpm/conf.d/mcrypt.ini \
        && echo "extension=mcrypt.so" > /etc/php/${PHP_VERSION}/cli/conf.d/mcrypt.ini

    # Verify PHP installation
    if ! command -v php > /dev/null 2>&1; then
        echo "Error: PHP is not installed or not available in PATH."
        exit 1
    fi
    if ! command -v php${PHP_VERSION} > /dev/null 2>&1; then
        echo "Error: PHP ${PHP_VERSION} is not installed or not available in PATH."
        exit 1
    fi

    # Install Composer
    info "Installing Composer..." 1
    mkdir /composer-setup \
        && wget https://getcomposer.org/installer -P /composer-setup \
        && php /composer-setup/installer --install-dir=/usr/bin \
        && mv /usr/bin/composer{.phar,} \
        && composer clear-cache \
        && rm -Rf /composer-setup ~/.composer
}

# Execute the main function
main "$@"