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

    info "Setting up WP-CLI" 1
    setup_wp_cli

    info "Setting up WordPress" 1
    setup_wordpress

    info "Installing WordPress plugins" 1
    install_wp_plugins

    info "Creating log directories" 1
    create_log_dirs

    info "Finalizing the deployment" 1
    cleanup
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
        xz-utils
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

# Function to set up WordPress
setup_wordpress() {
    local wordpress_dir="/var/www/html"
    local wordpress_url="https://wordpress.org/latest.tar.gz"
    local wp_config_docker="/tmp/wp-config-docker.php"
    local wp_config_target="${wordpress_dir}/wp-config.php"

    # Check if the WordPress directory is empty
    if [ ! "$(ls -A ${wordpress_dir})" ]; then
        echo "WordPress directory is empty. Downloading and installing the latest WordPress version..."
        
        # Download and extract WordPress
        curl -o /tmp/latest.tar.gz -SL ${wordpress_url}
        tar -xzf /tmp/latest.tar.gz -C /tmp
        cp -r /tmp/wordpress/* ${wordpress_dir}
        rm -rf /tmp/latest.tar.gz /tmp/wordpress

        # Remove all themes except the default theme
        echo "Removing all themes except the default theme..."
        find ${wordpress_dir}/wp-content/themes/* -type d ! -name "twentytwentythree" -exec rm -rf {} +

        # Set proper permissions
        echo "Setting permissions for WordPress files..."
        chown -R www-data:www-data ${wordpress_dir}
        chmod -R 755 ${wordpress_dir}
    else
        echo "WordPress directory is not empty. Skipping setup."

        # Create wp-config.php from wp-config-docker.php
        if [ -f "${wp_config_docker}" ]; then
            echo "Creating wp-config.php from wp-config-docker.php..."
            cp ${wp_config_docker} ${wp_config_target}

            # Replace Authentication unique keys and salts
            echo "Replacing Authentication unique keys and salts..."
            curl -s https://api.wordpress.org/secret-key/1.1/salt/ > /tmp/wp-salts
            sed -i '/AUTH_KEY/d;/SECURE_AUTH_KEY/d;/LOGGED_IN_KEY/d;/NONCE_KEY/d;/AUTH_SALT/d;/SECURE_AUTH_SALT/d;/LOGGED_IN_SALT/d;/NONCE_SALT/d' ${wp_config_target}
            cat /tmp/wp-salts >> ${wp_config_target}
            rm -f /tmp/wp-salts
        else
            echo "Error: wp-config-docker.php not found in ${wp_config_docker}."
            exit 1
        fi
    fi
}

setup_wp_cli() {
    local wp_cli_bin="/usr/local/bin/wp"

    echo "Setting up WP-CLI..."

    # Download WP-CLI
    curl -o /tmp/wp-cli.phar -SL https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar

    # Make it executable and move to the appropriate directory
    chmod +x /tmp/wp-cli.phar
    mv /tmp/wp-cli.phar ${wp_cli_bin}

    # Verify installation
    if ${wp_cli_bin} --info > /dev/null 2>&1; then
        echo "WP-CLI installed successfully."
    else
        echo "Error: WP-CLI installation failed."
        exit 1
    fi
}

install_wp_plugins() {
    local plugins_env_var="WORDPRESS_PLUGINS" # Environment variable containing plugin names
    local plugins_list=$(printenv ${plugins_env_var})

    if [ -z "${plugins_list}" ]; then
        echo "No plugins specified in the ${plugins_env_var} environment variable. Skipping plugin installation."
        return
    fi

    echo "Installing WordPress plugins: ${plugins_list}"

    # Loop through each plugin in the list and install it
    for plugin in ${plugins_list}; do
        echo "Installing plugin: ${plugin}..."
        wp plugin install ${plugin} --activate --allow-root
        if [ $? -ne 0 ]; then
            echo "Error: Failed to install plugin: ${plugin}"
        else
            echo "Successfully installed plugin: ${plugin}"
        fi
    done
}

# Execute the main function
main "$@"