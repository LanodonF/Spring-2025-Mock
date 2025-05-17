#!/bin/sh

# Set default value for N if not already set
: "${N:=150}"

# List of log files to check
log_files="/var/log/secure /var/log/auth.log /var/log/messages"

#check each log file
for file in $log_files; do
    if [ -f "$file" ]; then
        echo "=========="
        echo "$file"
        tail -n "$N" "$file"
        if [ -n "$SESSION" ]; then
            grep "$SESSION" "$file"
        fi
        echo "=========="
    fi
done