#!/bin/bash
set -e

#workspace_path="/var/www/html"

main()
{
		info "Setting up ssh." 1
		setting_ssh

		info "Finally running supervisord." 1
		supervisord -c /etc/supervisord.conf

		info "Running git sync." 1
		docker-git-sync.sh

		info "Running git clone." 1
		docker-git-clone.sh

		info "WP optimizations." 1
		wp cache flush
		wp media regenerate --yes
		wp transient delete --expired
		wp db optimize
}


info()
{
		message="$1"
		blink=''
		[ -z "$2" ] || blink=';5'

		echo -e "\e[45;1${blink}m$message\e[0m"
}

setting_ssh()
{
		# if /var/run/sshd does not exist, create it
		if [ ! -d /var/run/sshd ]; then
				mkdir -p /var/run/sshd
		fi

		echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
		
		# Use the SSH_AUTH_PWD environment variable for the root password
        if [ -z "$SSH_AUTH_PWD" ]; then
                echo "Error: SSH_AUTH_PWD environment variable is not set."
                exit 1
        fi

        echo "root:$SSH_AUTH_PWD" | chpasswd
}

# shellcheck disable=SC2048
# shellcheck disable=SC2086
main $*