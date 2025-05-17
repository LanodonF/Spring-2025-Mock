#!/bin/bash

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Detect OS type and install necessary packages if missing
install_packages() {
    if [ -f /etc/redhat-release ]; then
        echo "Detected Red Hat-based system. Installing missing packages..."
        sudo dnf install -y gnupg tar
    elif [ -f /etc/debian_version ]; then
        echo "Detected Debian-based system. Installing missing packages..."
        sudo apt update && sudo apt install -y gnupg tar
    else
        echo "Unsupported OS. Please install 'gnupg' and 'tar' manually."
        exit 1
    fi
}

# Check and install missing dependencies
if ! command_exists tar || ! command_exists gpg; then
    install_packages
fi

# Argument parsing and environment variable fallback
if [ "$#" -ne 3 ]; then
    if [ -n "$AAA" ] && [ -n "$BBB" ] && [ -n "$DDD" ]; then
        source_path="$AAA"
        destination_path="$BBB"
        backup_name="$DDD"
    else
        echo "Usage: $0 <source_path> <destination_path> <backup_name>"
        echo "Alternatively, set environment variables:"
        echo "  AAA=source_path BBB=destination_path DDD=backup_name"
        exit 1
    fi
else
    source_path="$1"
    destination_path="$2"
    backup_name="$3"
fi

# Validate paths
if [ ! -d "$source_path" ]; then
    echo "Error: Source path '$source_path' does not exist or is not a directory."
    exit 1
fi

if [ ! -d "$destination_path" ]; then
    echo "Destination path '$destination_path' does not exist, creating it."
    mkdir -p "$destination_path"
fi

# Create a timestamped backup
timestamp=$(date +%Y%m%d%H%M%S)
temp_archive="/tmp/${backup_name}_${timestamp}.tar"

if ! tar -cf "$temp_archive" -C "$source_path" .; then
    echo "Error: Failed to create the tar archive."
    exit 1
fi

# Encrypt the archive with GPG interactive prompt
echo "Please enter encryption password when prompted by GPG:"
if ! gpg -c -o "${temp_archive}.gpg" "$temp_archive"; then
    echo "Error: Failed to encrypt the tar archive with GPG."
    rm -f "$temp_archive"
    exit 1
fi

# Move encrypted file to the destination
destination_file="$destination_path/${backup_name}_${timestamp}.tar.gpg"
if ! mv "${temp_archive}.gpg" "$destination_file"; then
    echo "Error: Failed to move the encrypted file to the destination path."
    rm -f "$temp_archive" "${temp_archive}.gpg"
    exit 1
fi

# Cleanup and set permissions
rm -f "$temp_archive"
chmod 600 "$destination_file"

echo "Backup completed successfully and saved to $destination_file"