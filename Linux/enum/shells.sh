#!/bin/sh


# Get hashes of all shells listed in /etc/passwd

echo "Checking for hashes of all shells in /etc/passwd"
echo "======="

cut -d':' -f7 /etc/passwd | sort -u | while read -r shell; do
    if [ -f "$shell" ]; then
        echo "[+] $shell hash: $(sha256sum "$shell")"
    fi
done

echo "======="

# Get hashes of all shells listed in /etc/shells and check for other files with the same hash

echo "Checking for hashes of all shells in /etc/shells"
echo "======="

while read -r shell; do
    if [ -f "$shell" ]; then
        echo "[+] $shell hash: $(sha256sum "$shell")"

        # Try GNU stat first
        filesize=$(stat -c%s "$shell" 2>/dev/null)

        # Fallback for BSD/macOS
        if [ $? -ne 0 ]; then
            filesize=$(stat -f%z "$shell" 2>/dev/null)
            if [ $? -ne 0 ]; then
                echo "Error getting filesize for $shell"
                continue
            fi
        fi

        shellhash=$(sha256sum "$shell" | cut -d' ' -f1)

        matches=$(find / -type f -size "${filesize}c" -exec sha256sum {} \; 2>/dev/null | \
                  grep "$shellhash" | grep -v "$shell")

        if [ -n "$matches" ]; then
            echo "Other files with same hash:"
            echo "$matches"
        fi
    fi
done < /etc/shells

echo "======="
