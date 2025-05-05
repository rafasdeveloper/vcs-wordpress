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
    setup_ssh

    info "Syncing changes from VPS to repository" 1
    sync_changes

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

    local ssh_dir="/root/.ssh"
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
        ssh-keyscan -H github.com >> ~/.ssh/known_hosts 2>/dev/null
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

# Function for syncing changes from vps to repository
sync_changes() {
    local repo_url="$GIT_SSH_REPO_URL"
    local tmp_dir="/tmp/repo_sync"
    local target_dir="/var/www/html"

    # Dele flag files if they exist
    local flag_sync_completed="/var/www/html/.git-sync-complete"
    if [ -f "${flag_sync_completed}" ]; then
        rm -f "${flag_sync_completed}"
    fi
    local flag_sync_notneeded="/var/www/html/.git-sync-not-needed"
    if [ -f "${flag_sync_notneeded}" ]; then
        rm -f "${flag_sync_notneeded}"
    fi

    # Config git email and name
    git config --global user.email vps@rafaeldeveloper.co
    git config --global user.name "VPS ${COOLIFY_UUID}"
    git config --global core.sshCommand "ssh -i ~/.ssh/id_coolify_local_repo -o IdentitiesOnly=yes"

    # Clone the repository
    git clone "${repo_url}" "${tmp_dir}"

    # Set a name for the new branch
    local branch_name="syncing-changes"

    # Create a new branch (if not exist) for the changes with the branch name
    if git -C "${tmp_dir}" show-ref --verify --quiet "refs/heads/${branch_name}"; then
        echo "Branch ${branch_name} already exists. Checking out the branch."
        git -C "${tmp_dir}" fetch origin
        git -C "${tmp_dir}" checkout "${branch_name}"
    else
        echo "Creating new branch ${branch_name}."
        git -C "${tmp_dir}" checkout -b "${branch_name}"
    fi

    # Sync changes from the target directory to the temporary director
    # Sync target /var/www/html/wp-content/themes to the temporary directory
    rsync -av --delete "${target_dir}/wp-content/themes" "${tmp_dir}/"
    
    # Sync target /var/www/html/wp-content/plugins to the temporary directory
    rsync -av --delete "${target_dir}/wp-content/plugins" "${tmp_dir}/"

    # Sync target /var/www/html/wp-config.php to the temporary directory
    rsync -av --delete "${target_dir}/wp-config.php" "${tmp_dir}/wp-config.php"

    # Check if there are any changes to commit
    if [ -z "$(git -C "${tmp_dir}" status --porcelain)" ]; then
        echo "No changes to commit."
        # Clean up
        rm -rf "${tmp_dir}"
        # Create flag file to indicate that the sync is not needed
        touch "${flag_sync_notneeded}"
        chown www-data:www-data "${flag_sync_notneeded}"
        chmod 600 "${flag_sync_notneeded}"
        echo "Sync not needed. Flag file created at ${flag_sync_notneeded}."
        return
    fi

    # Add and commit changes
    git -C "${tmp_dir}" add .

    # Commit the changes with a message including the COOLIFY_UUID, COOLIFY_FQDN and the date
    git -C "${tmp_dir}" commit -m "VPS SYNC - ${COOLIFY_UUID} - ${COOLIFY_FQDN} - $(date +%Y-%m-%d)"    
    
    # Push changes to the repository
    git -C "${tmp_dir}" push origin "${branch_name}"
    
    # Clean up
    rm -rf "${tmp_dir}"

    # Create flag file to indicate that the sync is complete
    touch "${flag_sync_completed}"
    chown www-data:www-data "${flag_sync_completed}"
    chmod 600 "${flag_sync_completed}"
    echo "Sync complete. Flag file created at ${flag_sync_completed}."
}

# Execute the main function
main "$@"