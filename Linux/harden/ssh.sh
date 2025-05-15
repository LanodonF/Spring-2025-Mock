#!/bin/sh

sys=$(command -v service || command -v systemctl)
FILE="/etc/ssh/sshd_config"
RC="/etc/rc.d/rc.sshd"

if [ -f "$FILE" ]; then
    # Detect appropriate sed syntax (GNU vs BSD)
    SED="sed -i''"
    if sed --version >/dev/null 2>&1; then
        SED="sed -i"
    fi

    echo "[+] Locking down SSH settings in $FILE"

    # Disable AllowTcpForwarding
    $SED 's/^AllowTcpForwarding.*/# AllowTcpForwarding/' "$FILE"
    echo "AllowTcpForwarding no" >> "$FILE"

    # Disable X11Forwarding
    $SED 's/^X11Forwarding.*/# X11Forwarding/' "$FILE"
    echo "X11Forwarding no" >> "$FILE"

    # Disable PubkeyAuthentication if NOPUB is set
    if [ -n "$NOPUB" ]; then
        $SED 's/^PubkeyAuthentication.*/# PubkeyAuthentication/' "$FILE"
        echo "PubkeyAuthentication no" >> "$FILE"
    fi

    # Override AuthorizedKeysFile if AUTHKEY is set
    if [ -n "$AUTHKEY" ]; then
        $SED 's/^AuthorizedKeysFile.*/# AuthorizedKeysFile/' "$FILE"
        echo "AuthorizedKeysFile $AUTHKEY" >> "$FILE"
    fi

    # Restrict SSH to specific users if PERMITUSERS is set
    if [ -n "$PERMITUSERS" ]; then
        $SED 's/^AllowUsers.*/# AllowUsers/' "$FILE"
        echo "AllowUsers $PERMITUSERS" >> "$FILE"
    fi

    # Special handling for root pubkey auth if ROOTPUB is set
    if [ -n "$ROOTPUB" ]; then
        $SED 's/^PubkeyAuthentication.*/# PubkeyAuthentication/' "$FILE"
        echo "PubkeyAuthentication no" >> "$FILE"
        echo "Match User root" >> "$FILE"
        echo "    PubkeyAuthentication yes" >> "$FILE"
    fi

else
    echo "[-] Could not find sshd config at $FILE"
    exit 1
fi

# Restart SSH service using available init system
if [ -z "$sys" ]; then
    if [ -f "/etc/rc.d/sshd" ]; then
        RC="/etc/rc.d/sshd"
    fi
    echo "[*] Restarting SSH with $RC"
    "$RC" restart
else
    echo "[*] Restarting SSH with $sys"
    "$sys" restart ssh 2>/dev/null || \
    "$sys" ssh restart 2>/dev/null || \
    "$sys" restart sshd 2>/dev/null || \
    "$sys" sshd restart
fi