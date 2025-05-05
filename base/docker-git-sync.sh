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

    info "Syncing changes from VPS to repository" 1
    sync_changes();

}

# Print informational messages
info() {
    local message="$1"
    local blink=''
    [ -z "$2" ] || blink=';5'

    echo -e "\e[45;1${blink}m$message\e[0m"
}

# Function for syncing changes from vps to repository
sync_changes() {
    local repo_url="$GIT_SSH_REPO_URL"
    local tmp_dir="/tmp/repo_sync"
    local target_dir="/var/www/html"

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
    rsync -av --delete "${target_dir}/wp-content/themes" "${tmp_dir}/themes"
    
    # Sync target /var/www/html/wp-content/plugins to the temporary directory
    rsync -av --delete "${target_dir}/wp-content/plugins" "${tmp_dir}/plugins"

    # Sync target /var/www/html/wp-config.php to the temporary directory
    rsync -av --delete "${target_dir}/wp-config.php" "${tmp_dir}/wp-config.php"

    # Check if there are any changes to commit
    if [ -z "$(git -C "${tmp_dir}" status --porcelain)" ]; then
        echo "No changes to commit."
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
}

# Execute the main function
main "$@"