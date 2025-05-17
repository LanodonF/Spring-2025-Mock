#!/bin/bash

# Function to securely get password
get_password() {
    if [ -n "$DECRYPTION_PASSWORD" ]; then
        echo "$DECRYPTION_PASSWORD"
    else
        echo -n "Enter decryption password: "
        read -s password
        echo
        echo "$password"
    fi
}

# Check arguments
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <encrypted_file_path> <target_directory>"
    echo "Note: Password can be provided via DECRYPTION_PASSWORD environment variable"
    exit 1
fi

# Assign arguments
encrypted_file="$1"
target_directory="$2"

# Validate inputs
if [ ! -f "$encrypted_file" ]; then
    echo "Error: Encrypted file '$encrypted_file' does not exist."
    exit 1
fi

if [ ! -d "$target_directory" ]; then
    echo "Error: Target directory '$target_directory' does not exist."
    exit 1
fi

# Get password securely
password=$(get_password)
if [ -z "$password" ]; then
    echo "Error: No password provided"
    exit 1
fi

# Create temporary working files
temp_dir=$(mktemp -d -t decrypt.XXXXXXXXXX)
decrypted_file="${temp_dir}/$(basename "${encrypted_file%.gpg}")"

# Decrypt the file
echo "Decrypting file '$encrypted_file'..."
if ! gpg --batch --yes --passphrase-fd 3 \
          -o "$decrypted_file" -d "$encrypted_file" 3<<<"$password"; then
    echo "Error: Failed to decrypt the file"
    rm -rf "$temp_dir"
    exit 1
fi

# Verify decrypted file exists
if [ ! -f "$decrypted_file" ]; then
    echo "Error: Decrypted file not created"
    rm -rf "$temp_dir"
    exit 1
fi

# Create temporary extraction directory
extract_dir="${temp_dir}/content"
mkdir -p "$extract_dir"

# Extract the decrypted tar file
echo "Extracting archive..."
if ! tar -xf "$decrypted_file" -C "$extract_dir"; then
    echo "Error: Failed to extract the archive"
    rm -rf "$temp_dir"
    exit 1
fi

# Replace target directory
echo "Replacing '$target_directory' with decrypted content..."
if ! mv "$extract_dir" "$target_directory"; then
    echo "Error: Failed to replace target directory"
    rm -rf "$temp_dir" "$extract_dir"
    exit 1
fi

# Cleanup
rm -rf "$temp_dir"
unset password

echo "Success: '$target_directory' has been replaced with decrypted content."