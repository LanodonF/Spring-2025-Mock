#!/bin/bash

# Secure decryption script using GPG's native password prompt
# Usage: ./decrypt_script.sh <encrypted_file.gpg> <target_directory>

# Check arguments
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <encrypted_file.gpg> <target_directory>"
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

# Create temporary working directory
temp_dir=$(mktemp -d -t gpg_decrypt.XXXXXXXXXX)
trap 'rm -rf "$temp_dir"' EXIT ERR

# Generate decrypted file path
decrypted_file="${temp_dir}/$(basename "${encrypted_file%.gpg}")"

# Decrypt the file using GPG's interactive prompt
echo "Decrypting file (GPG will prompt for password)..."
if ! gpg -o "$decrypted_file" -d "$encrypted_file"; then
    echo "Error: Decryption failed"
    exit 1
fi

# Create extraction directory
extract_dir="${temp_dir}/content"
mkdir -p "$extract_dir"

# Extract the decrypted tar archive
echo "Extracting contents..."
if ! tar -xf "$decrypted_file" -C "$extract_dir"; then
    echo "Error: Failed to extract archive"
    exit 1
fi

# Replace target directory
echo "Replacing target directory..."
rm -rf "$target_directory"
mv "$extract_dir" "$target_directory"

echo "Success: '$target_directory' has been replaced with decrypted content."