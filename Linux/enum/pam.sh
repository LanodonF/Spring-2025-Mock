#!/bin/sh

echo_section() {
    echo ""
    echo "======="
    echo "$1"
    echo "======="
}

search_pam_config() {
    local pattern="$1"
    grep -ER "^[^#]*$pattern" /etc/pam.d/
}

check_so_integrity() {
    local so_file="$1"
    MOD=$(find /lib/ /lib64/ /lib32/ /usr/lib/ /usr/lib64/ /usr/lib32/ -name "$so_file" 2>/dev/null)

    if [ -z "$MOD" ]; then
        echo "[-] $so_file not found"
    else
        for i in $MOD; do
            echo "[+] $so_file found at $i"
            if grep -qr "$so_file" "$i"; then 
                echo "[+] $i is correctly configured"
            else
                echo "[-] $i is TAMPERED WITH | [INVESTIGATE!]"
            fi
        done
    fi
}

verify_auth_order() {
    echo_section "Verifying pam authentication properly denies and permits"
    files=$(find /etc/pam.d/ -name "*-auth")

    for file in $files; do
        [ -f "$file" ] || { echo "File not found: $file"; continue; }

        deny_line=$(grep -n 'pam_deny.so' "$file" | cut -d: -f1 | head -n 1)
        permit_line=$(grep -n 'pam_permit.so' "$file" | cut -d: -f1 | head -n 1)

        [ -z "$permit_line" ] && echo "pam_permit.so not found in $file. [INVESTIGATE!]" && continue
        [ -z "$deny_line" ] && echo "pam_deny.so not found in $file. [INVESTIGATE!]" && continue

        if [ "$deny_line" -ge "$permit_line" ]; then
            echo "pam_permit.so comes before pam_deny.so in $file | [INVESTIGATE!]"
        fi
    done
}

verify_unix_hash() {
    echo_section "Verifying pam_unix.so hash"
    BACKUPBINARYDIR="$BCK/pam_libraries"
    BCKUNIX=$(find "$BACKUPBINARYDIR" -type f -name "pam_unix.so" 2>/dev/null)

    if [ -z "$BCKUNIX" ]; then
        echo "[-] No backup of pam_unix.so found at $BACKUPBINARYDIR"
    else
        for i in $BCKUNIX; do
            echo "[+] Backup of pam_unix.so found at $i"
            l=$(echo "$i" | sed "s|$BACKUPBINARYDIR||g")
            if [ -f "$l" ]; then
                hash_current=$(sha256sum "$i" | cut -d' ' -f1)
                hash_backup=$(sha256sum "$l" | cut -d' ' -f1)
                if [ "$hash_current" = "$hash_backup" ]; then
                    echo "[+] $i hash matches $l"
                else
                    echo "[-] $i hash does not match | [INVESTIGATE!]"
                    echo "Hashes:"
                    echo "Current: $hash_current"
                    echo "Backup:  $hash_backup"
                fi
            else
                echo "[-] Current file $l not found for comparison"
            fi
        done
    fi
}

dump_unix_strings() {
    echo_section "Dumping strings from pam_unix.so"
    MOD=$(find /lib/ /lib64/ /lib32/ /usr/lib/ /usr/lib64/ /usr/lib32/ -name "pam_unix.so" 2>/dev/null)
    if [ -z "$MOD" ]; then
        echo "[-] pam_unix.so not found"
    else
        for i in $MOD; do
            echo "[+] pam_unix.so found at $i"
            echo "[+] Strings:"
            strings "$i"
        done
    fi
}

list_unowned_files() {
    echo_section "Checking for unowned PAM-related files"
    for i in $(find /{lib*,usr/lib*} -name pam_unix.so 2>/dev/null); do 
        d=$(dirname "$i")
        for f in "$d"/*; do
            [ -f "$f" ] || continue
            if command -v dpkg >/dev/null; then
                dpkg -S "$f" >/dev/null 2>&1 || echo "$f unowned"
            else
                rpm -qf "$f" >/dev/null 2>&1 || echo "$f unowned"
            fi
        done
    done
}

# === Begin Checks ===

echo_section "Checking for execution of arbitrary commands in PAM configuration"
search_pam_config "pam_exec.so"

echo_section "Checking for pam_succeed_if in PAM configuration"
search_pam_config "pam_succeed_if.so"

echo_section "Checking for nullok in PAM configuration"
search_pam_config "nullok"

echo_section "Checking that pam_deny.so has not been tampered with"
check_so_integrity "pam_deny.so"

echo_section "Checking that pam_permit.so has not been tampered with"
check_so_integrity "pam_permit.so"

verify_auth_order

if [ -z "$BCK" ]; then
    echo "[-] \$BCK not set. Skipping pam_unix.so hash verification"
else
    verify_unix_hash
fi

if [ -n "$ENSTR" ] && command -v strings >/dev/null; then
    dump_unix_strings
elif [ -n "$ENSTR" ]; then
    echo "[-] strings not found. Skipping strings of pam_unix.so"
fi

if [ -n "$PRINTAUTH" ]; then
    echo_section "Printing pam authentication configuration"
    grep -ER "^\s*[^#]" /etc/pam.d/*-auth
fi

list_unowned_files
