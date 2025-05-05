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
        info "This script must be run as root. Please use sudo." 1
        exit 1
    fi

    info "Setting up repository access" 1
    setup_ssh();

}

# Print informational messages
info() {
    local message="$1"
    local blink=''
    [ -z "$2" ] || blink=';5'

    echo -e "\e[45;1${blink}m$message\e[0m"
}

# Function to set up SSH access for the repository
setup_ssh() {

    local ssh_dir="~/.ssh"
    local ssh_key="${ssh_dir}/id_coolify_local_repo"

    # Check if the SSH directory exists
    if [ ! -d "${ssh_dir}" ]; then
        mkdir -p "${ssh_dir}"
        chmod 700 "${ssh_dir}"
    fi

    # Check if the SSH key already exists
    if [ -f "${ssh_key}" ]; then
        echo "SSH key already exists. Skipping key generation."
    else
        echo "$GIT_SSH_PRIVATE_KEY" > "${ssh_key}"
        chmod 600 "${ssh_key}"
        ssh-keyscan github.com >> ~/.ssh/known_hosts
    fi

    # Check if the SSH key is added to the SSH agent
    if ! ssh-add -l | grep -q "${ssh_key}"; then
        echo "Adding SSH key to the SSH agent."
        eval "$(ssh-agent -s)"
        ssh-add "${ssh_key}"
    else
        echo "SSH key is already added to the SSH agent."
    fi
}

# Function to clone the repository
clone_repository() {
    local repo_url="$GIT_SSH_REPO_URL"
    local branch_name="$GIT_SSH_REPO_BRANCH"
    local tmp_dir="/tmp/repo"
    local target_dir="/var/www/html"

    # Config git email and name
    git config --global user.email vps@rafaeldeveloper.co
    git config --global user.name "VPS ${COOLIFY_UUID}"
    git config --global core.sshCommand "ssh -i ~/.ssh/id_coolify_local_repo -o IdentitiesOnly=yes"

    # Clone the repository by branch name
    if [ -d "${tmp_dir}" ]; then
        echo "Repository already cloned. Pulling latest changes."
        git -C "${tmp_dir}" pull origin "${branch_name}"
    else
        echo "Cloning repository from ${repo_url} to ${tmp_dir}."
        git clone -b "${branch_name}" "${repo_url}" "${tmp_dir}"
    fi

    # Sync changes from the temporary directory to the target directory
    rsync -av --delete "${tmp_dir}/themes" "${target_dir}/wp-content/themes"
    rsync -av --delete "${tmp_dir}/plugins" "${target_dir}/wp-content/plugins"
    rsync -av --delete "${tmp_dir}/wp-config.php" "${target_dir}/wp-config.php"

}

# Execute the main function
main "$@"