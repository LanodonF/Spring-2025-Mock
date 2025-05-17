#!/bin/sh

# Set search path
if [ -n "$1" ]; then
    find_path="$1"
elif [ -n "$PATH" ]; then
    find_path="$PATH"
fi

# Define search functions
grep_for_phone_numbers() {
    grep -RPo '(\([0-9]{3}\) |[0-9]{3}-)[0-9]{3}-[0-9]{4}' "$1" 2>/dev/null
}

grep_for_email_addresses() {
    grep -RPo '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,6}' "$1" 2>/dev/null
}

grep_for_social_security_numbers() {
    grep -RPo '[0-9]{3}-[0-9]{2}-[0-9]{4}' "$1" 2>/dev/null
}

grep_for_credit_card_numbers() {
    grep -RPo '(?:\d{4}[-\s]?){3}\d{4}' "$1" 2>/dev/null
}

find_interesting_files_by_extension() {
    find "$1" -type f \( \
        -iname '*.doc' -o -iname '*.docx' -o -iname '*.xls' -o -iname '*.xlsx' \
        -o -iname '*.pdf' -o -iname '*.ppt' -o -iname '*.pptx' -o -iname '*.txt' \
        -o -iname '*.rtf' -o -iname '*.csv' -o -iname '*.odt' -o -iname '*.ods' \
        -o -iname '*.odp' -o -iname '*.odg' -o -iname '*.odf' -o -iname '*.odc' \
        -o -iname '*.odb' -o -iname '*.odm' -o -iname '*.docm' -o -iname '*.dotx' \
        -o -iname '*.dotm' -o -iname '*.dot' -o -iname '*.wbk' -o -iname '*.xltx' \
        -o -iname '*.xltm' -o -iname '*.xlt' -o -iname '*.xlam' -o -iname '*.xlsb' \
        -o -iname '*.xla' -o -iname '*.xll' -o -iname '*.pptm' -o -iname '*.potx' \
        -o -iname '*.potm' -o -iname '*.pot' -o -iname '*.ppsx' -o -iname '*.ppsm' \
        -o -iname '*.pps' -o -iname '*.ppam' \
    \) 2>/dev/null
}

search() {
    grep_for_phone_numbers "$1"
    grep_for_email_addresses "$1"
    grep_for_social_security_numbers "$1"
    grep_for_credit_card_numbers "$1"
    find_interesting_files_by_extension "$1"
}

scan_directory() {
    echo "[+] Searching $1 for PII."
    search "$1"
}

check_vsftpd_config() {
    conf="$1"
    if [ -f "$conf" ]; then
        echo "[+] VSFTPD config file found at $conf. Checking for anon_root and local_root."
        anon_root=$(grep -E '^\s*anon_root' "$conf" | awk '{print $2}')
        local_root=$(grep -E '^\s*local_root' "$conf" | awk '{print $2}')

        [ -n "$anon_root" ] && scan_directory "$anon_root"
        [ -n "$local_root" ] && scan_directory "$local_root"
    fi
}

scan_mysql() {
    echo "[+] Checking MySQL databases for PII."
    databases=$(mysql -u "$USER" -p"$PASS" -e "SHOW DATABASES;" 2>/dev/null | grep -v "Database")

    for db in $databases; do
        case "$db" in
            information_schema|performance_schema|mysql|test|sys) continue ;;
        esac

        echo "[+] Checking $db for PII."
        tables=$(mysql -u "$USER" -p"$PASS" -e "SHOW TABLES FROM $db;" 2>/dev/null | grep -v "Tables")

        for table in $tables; do
            mysql -u "$USER" -p"$PASS" -e "SELECT * FROM $db.$table;" 2>/dev/null | grep -v Field >> /tmp/pii.txt
        done

        search /tmp/pii.txt
        rm -f /tmp/pii.txt
    done
}

# Main scan targets
[ -n "$find_path" ] && scan_directory "$find_path"
scan_directory "/home"
scan_directory "/var/www"

# VSFTPD config checks
check_vsftpd_config /etc/vsftpd.conf
check_vsftpd_config /etc/vsftpd/vsftpd.conf
check_vsftpd_config /usr/local/etc/vsftpd.conf
check_vsftpd_config /usr/local/vsftpd/vsftpd.conf

# ProFTPD config check
if [ -f /etc/proftpd/proftpd.conf ]; then
    echo "[+] ProFTPD config found. Checking for DefaultRoot."
    default_root=$(grep -E '^\s*DefaultRoot' /etc/proftpd/proftpd.conf | awk '{print $2}')
    [ -n "$default_root" ] && scan_directory "$default_root"
fi

# Samba config check
if [ -f /etc/samba/smb.conf ]; then
    echo "[+] Samba config found. Checking shares."
    shares=$(grep -E '^\s*path' /etc/samba/smb.conf | awk '{print $3}' | sed 's/"//g')
    for share in $shares; do
        scan_directory "$share"
    done
fi

# MySQL PII check if credentials are available
if [ -n "$USER" ] && [ -n "$PASS" ]; then
    scan_mysql
fi