#!/bin/sh

MINION=false
MASTER=false

# Detect presence of Salt Minion or Master
[ -f /etc/salt/minion ] && MINION=true
[ -f /etc/salt/master ] && MASTER=true

if [ "$MINION" = false ] && [ "$MASTER" = false ]; then
    echo "SaltStack is not installed."
    exit 1
fi

# Helper function to print uncommented config lines
print_config() {
    [ -f "$1" ] && grep -E '^\s*[^#]' "$1"
}

if [ "$MINION" = true ]; then
    echo "[+] Salt Minion is installed."
    echo "[*] Checking minion configuration..."
    print_config /etc/salt/minion
    print_config /etc/salt/minion.d/master.conf
    [ -f /etc/salt/minion_id ] && cat /etc/salt/minion_id

    echo "[*] Salt DNS (salt):"
    nslookup salt 2>/dev/null || dig salt 2>/dev/null

    echo "[*] Salt DNS (salt.salt):"
    nslookup salt.salt 2>/dev/null || dig salt.salt 2>/dev/null
fi

if [ "$MASTER" = true ]; then
    echo "[+] Salt Master is installed."

    echo "[*] Accepted Keys:"
    salt-key -L

    echo "[*] Master configuration:"
    print_config /etc/salt/master
    print_config /etc/salt/master.d/master.conf

    echo "[*] Existing Salt files:"
    ls -alR /srv/salt 2>/dev/null

    echo "[*] Minion status:"
    salt-run manage.status
    salt '*' test.ping
fi