#!/bin/bash

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Validate arguments
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <mysql|postgres> <DB_USER> <ENCRYPTED_FILE>"
    exit 1
fi

DB_TYPE="$1"
DB_USER="$2"
ENCRYPTED_FILE="$3"
DECRYPTED_FILE="/tmp/$(basename "${ENCRYPTED_FILE%.gpg}")"

# Check dependencies
if ! command_exists gpg; then
    echo "Please install gnupg first"
    exit 1
fi

case $DB_TYPE in
    mysql)
        if ! command_exists mysql; then
            echo "Please install mysql-client first"
            exit 1
        fi
        ;;
    postgres)
        if ! command_exists pg_restore; then
            echo "Please install postgresql-client first"
            exit 1
        fi
        ;;
    *)
        echo "Invalid database type. Use 'mysql' or 'postgres'"
        exit 1
        ;;
esac

# Decrypt file
echo "Decrypting backup (GPG will prompt for password)..."
gpg -o "$DECRYPTED_FILE" -d "$ENCRYPTED_FILE"

if [ $? -ne 0 ]; then
    echo "Decryption failed!"
    exit 2
fi

# Restore backup
echo -n "Enter database password: "
read -s DB_PASSWORD
echo

case $DB_TYPE in
    mysql)
        mysql -u "$DB_USER" --password="$DB_PASSWORD" < "$DECRYPTED_FILE"
        ;;
    postgres)
        PGPASSWORD="$DB_PASSWORD" pg_restore -U "$DB_USER" --clean --create "$DECRYPTED_FILE"
        ;;
esac

if [ $? -ne 0 ]; then
    echo "Restore failed!"
    rm -f "$DECRYPTED_FILE"
    exit 3
fi

# Cleanup
rm -f "$DECRYPTED_FILE"
echo "Restore successful!"