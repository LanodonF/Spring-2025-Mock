# Set default backup directory if not defined
if [ -z "$BCK" ]; then
    BCK="/root/.cache"
fi

# Backup paths
BACKUPCONFDIR="$BCK/pam.d"
BACKUPBINARYDIR="$BCK/pam_libraries"

mkdir -p "$BACKUPCONFDIR"
mkdir -p "$BACKUPBINARYDIR"

# Detect iptables command
ipt=$(command -v iptables || command -v /sbin/iptables || command -v /usr/sbin/iptables)

ALLOW() {
    if [ -z "$DISFW" ]; then return; fi
    "$ipt" -P OUTPUT ACCEPT
}

DENY() {
    if [ -z "$DISFW" ]; then return; fi
    "$ipt" -P OUTPUT DROP
}

handle_pam() {
    if [ -n "$REVERT" ]; then
        echo "[+] Reverting PAM binaries from backup..."
        if [ -d "$BACKUPBINARYDIR" ]; then
            find "$BACKUPBINARYDIR" -type f | while read -r file; do
                ORIGINAL_DIR=$(dirname "${file//$BACKUPBINARYDIR/}")
                echo "Restoring $file to $ORIGINAL_DIR"
                mkdir -p "$ORIGINAL_DIR"
                cp "$file" "$ORIGINAL_DIR"
            done
        else
            echo "[-] Backup directory $BACKUPBINARYDIR does not exist. Cannot revert."
            exit 1
        fi

        echo "[+] Reverting PAM configuration files..."
        if [ -d "$BACKUPCONFDIR" ]; then
            cp -R "$BACKUPCONFDIR"/* /etc/pam.d/
        else
            echo "[-] Backup directory $BACKUPCONFDIR does not exist. Cannot revert."
            exit 1
        fi

        echo "[+] Reversion complete."
    else
        echo "[+] Backing up PAM configuration files and binaries..."
        cp -R /etc/pam.d/* "$BACKUPCONFDIR/"

        MOD=$(find /lib/ /lib64/ /lib32/ /usr/lib/ /usr/lib64/ /usr/lib32/ -name "pam_unix.so" 2>/dev/null)
        if [ -z "$MOD" ]; then
            echo "[-] pam_unix.so not found"
        else
            echo "[+] Found the following pam_unix.so files:"
            echo "$MOD"
            for i in $MOD; do
                BINARY_DIR=$(dirname "$i")
                DEST="$BACKUPBINARYDIR$BINARY_DIR"
                echo "Backing up all binaries from $BINARY_DIR to $DEST"
                mkdir -p "$DEST"
                cp "$BINARY_DIR"/pam* "$DEST/"
            done
        fi

        echo "[+] Backup complete."
    fi
}

DEBIAN() {
    if [ -n "$REINSTALL" ]; then
        echo "[+] Reinstalling PAM-related packages..."
        DEBIAN_FRONTEND=noninteractive
        pam-auth-update --package --force
        apt-get -y --reinstall install libpam-runtime libpam-modules
        echo "[+] Reinstallation complete."
    fi
    handle_pam
}

RHEL() {
    if [ -n "$REINSTALL" ]; then
        echo "[+] Reinstalling PAM-related packages..."
        yum -y reinstall pam
        echo "[+] Reinstallation complete."
        if command -v authconfig >/dev/null; then
            authconfig --updateall
        fi
    fi
    handle_pam
}

SUSE() {
    if [ -n "$REINSTALL" ]; then
        echo "[+] Reinstalling PAM-related packages..."
        zypper install -f -y pam
        pam-config --update
        echo "[+] Reinstallation complete."
    fi
    handle_pam
}

UBUNTU() {
    DEBIAN
}

ALPINE() {
    if [ -z "$UNTESTED" ]; then
        echo "[-] Alpine Linux is untested. Please test manually first."
        exit 1
    fi
    if [ -n "$REINSTALL" ]; then
        echo "[+] Reinstalling PAM-related packages for Alpine..."
        apk fix --reinstall --purge linux-pam
        for file in $(find /etc/pam.d -name '*.apk-new'); do
            mv "$file" "${file%.apk-new}"
        done
        echo "[+] Reinstallation complete."
    fi
    handle_pam
}

SLACK() {
    if [ -z "$UNTESTED" ]; then
        echo "[-] Slackware is untested. Please test manually first."
        exit 1
    fi
    if [ -n "$REINSTALL" ]; then
        echo "[+] Slackware does not support automatic reinstallation of packages. Please reinstall PAM manually."
    fi
    handle_pam
}

ARCH() {
    if [ -z "$UNTESTED" ]; then
        echo "[-] Arch Linux is untested. Please test manually first."
        exit 1
    fi
    if [ -n "$REINSTALL" ]; then
        echo "[+] Reinstalling PAM-related packages for Arch..."
        pacman -S --noconfirm pam
        echo "[+] Reinstallation complete."
    fi
    handle_pam
}

# Begin firewall allow and main logic
ALLOW

if command -v yum >/dev/null; then
    RHEL
elif command -v zypper >/dev/null; then
    SUSE
elif command -v apt-get >/dev/null; then
    if grep -qi ubuntu /etc/os-release; then
        UBUNTU
    else
        DEBIAN
    fi
elif command -v apk >/dev/null; then
    ALPINE
elif command -v slapt-get >/dev/null || grep -qi slackware /etc/os-release; then
    SLACK
elif command -v pacman >/dev/null; then
    ARCH
fi

DENY