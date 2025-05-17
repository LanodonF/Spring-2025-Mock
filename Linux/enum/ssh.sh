#!/bin/sh

# Find and display all authorized_keys files in /home and /root
find /home /root -name "authorized_keys*" -exec ls -al {} \; -exec cat {} \; 2>/dev/null

# Print non-comment, non-empty lines from /etc/ssh/sshd_config
if [ -f /etc/ssh/sshd_config ]; then
    echo "=========="
    echo "/etc/ssh/sshd_config"
    grep "^\s*[^#]" /etc/ssh/sshd_config
    echo "=========="
fi

# Print non-comment, non-empty lines from each file in /etc/ssh/sshd_config.d/
if [ -d /etc/ssh/sshd_config.d ]; then
    for file in /etc/ssh/sshd_config.d/*; do
        if [ -f "$file" ]; then
            echo "=========="
            echo "$file"
            grep "^\s*[^#]" "$file"
            echo "=========="
        fi
    done
fi
