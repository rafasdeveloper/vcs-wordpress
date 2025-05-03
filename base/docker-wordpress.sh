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

    info "Setting up WordPress" 1
    install_wordpress

    info "Setting up WP-CLI" 1
    install_wp_cli

    info "Installing WordPress plugins" 1
    install_wp_plugins
}

# Print informational messages
info() {
    local message="$1"
    local blink=''
    [ -z "$2" ] || blink=';5'

    echo -e "\e[45;1${blink}m$message\e[0m"
}

# Function to set up WordPress
install_wordpress() {
    local wordpress_dir="/var/www/html"
    local wordpress_url="https://wordpress.org/latest.tar.gz"
    local wp_config_docker="/tmp/wp-config-docker.php"
    local wp_config_target="${wordpress_dir}/wp-config.php"

    # Check if the WordPress directory is empty or wp-config.php does not exist
    if [ ! "$(ls -A ${wordpress_dir})" ] || [ ! -f "${wp_config_target}" ]; then
        if [ "$(ls -A ${wordpress_dir})" ]; then
            echo "WordPress directory is not empty, but wp-config.php does not exist. Emptying the directory..."
            rm -rf ${wordpress_dir}/*
        fi

        echo "Downloading and installing the latest WordPress version..."
        
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
    else
        echo "WordPress directory is not empty and wp-config.php exists. Skipping setup."
    fi
}

install_wp_cli() {
    local wp_cli_bin="/usr/local/bin/wp"

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
    local plugins_list=$VCS_DEV_WORDPRESS_PLUGINS

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