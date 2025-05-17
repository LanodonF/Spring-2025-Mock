#!/bin/bash

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Detect OS and install dependencies
install_dependencies() {
    local db_type=$1
    if [ -f /etc/redhat-release ]; then
        sudo dnf install -y gnupg ${db_type}-client
    elif [ -f /etc/debian_version ]; then
        sudo apt update && sudo apt install -y gnupg ${db_type}-client
    else
        echo "Unsupported OS. Please install gnupg and ${db_type}-client manually."
        exit 1
    fi
}

# Validate arguments
if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <mysql|postgres> <DB_USER> <BACKUP_PATH> <BACKUP_NAME>"
    exit 1
fi

DB_TYPE="$1"
DB_USER="$2"
BACKUP_PATH="$3"
BACKUP_NAME="$4"
TIMESTAMP=$(date +%Y%m%d%H%M%S)
TEMP_FILE="/tmp/${BACKUP_NAME}_${TIMESTAMP}.sql"

# Check dependencies
if ! command_exists gpg; then
    install_dependencies "gnupg"
fi

case $DB_TYPE in
    mysql)
        if ! command_exists mysqldump; then
            install_dependencies "mysql"
        fi
        ;;
    postgres)
        if ! command_exists pg_dump; then
            install_dependencies "postgresql"
        fi
        ;;
    *)
        echo "Invalid database type. Use 'mysql' or 'postgres'"
        exit 1
        ;;
esac

# Create backup directory
mkdir -p "$BACKUP_PATH"

# Create backup
case $DB_TYPE in
    mysql)
        echo -n "Enter MySQL password: "
        read -s DB_PASSWORD
        echo
        mysqldump -u "$DB_USER" --password="$DB_PASSWORD" --all-databases > "$TEMP_FILE"
        ;;
    postgres)
        echo -n "Enter PostgreSQL password: "
        read -s DB_PASSWORD
        echo
        PGPASSWORD="$DB_PASSWORD" pg_dump -U "$DB_USER" --format=c --blobs > "$TEMP_FILE"
        ;;
esac

if [ $? -ne 0 ]; then
    echo "Backup failed!"
    rm -f "$TEMP_FILE"
    exit 2
fi

# Encrypt with GPG
echo "Encrypting backup (GPG will prompt for password)..."
ENCRYPTED_FILE="${BACKUP_PATH}/${BACKUP_NAME}_${TIMESTAMP}.gpg"
gpg -c -o "$ENCRYPTED_FILE" "$TEMP_FILE"

if [ $? -ne 0 ]; then
    echo "Encryption failed!"
    rm -f "$TEMP_FILE"
    exit 3
fi

# Cleanup
rm -f "$TEMP_FILE"
echo "Backup successful: $ENCRYPTED_FILE"