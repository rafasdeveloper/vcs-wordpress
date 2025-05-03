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
        openssh-server
}

# Install PHP and required extensions
install_php_stuff() {
    echo "Adding PHP repository..."
    apt-get update && apt-get install -y --no-install-recommends \
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
        php8.4 \
        php8.4-dev \
        php8.4-cli \
        php8.4-curl \
        php8.4-mbstring \
        php8.4-opcache \
        php8.4-readline \
        php8.4-xml \
        php8.4-zip \
        php8.4-fpm \
        php8.4-mysql \
        php8.4-bcmath \
        php8.4-bz2 \
        php8.4-gd \
        php8.4-intl \
        php8.4-soap \
        php8.4-exif \
        gcc \
        make \
        autoconf \
        libc-dev \
        pkg-config \
        libmcrypt-dev \
        && printf "\n" | pecl install mcrypt-1.0.7 \
        && printf "\n" | pecl install xdebug \
        && echo "extension=mcrypt.so" > /etc/php/8.4/fpm/conf.d/mcrypt.ini \
        && echo "extension=mcrypt.so" > /etc/php/8.4/cli/conf.d/mcrypt.ini

    # Verify PHP installation
    if ! command -v php > /dev/null 2>&1; then
        echo "Error: PHP is not installed or not available in PATH."
        exit 1
    fi
    if ! command -v php8.4 > /dev/null 2>&1; then
        echo "Error: PHP 8.4 is not installed or not available in PATH."
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