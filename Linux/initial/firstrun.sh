#!/bin/sh


# Setup backup directory
if [ -z "$BCK" ]; then
    BCK="/root/.cache"
fi

BCK="$BCK/initial"
mkdir -p "$BCK"

# Disable SELinux
sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config 2>/dev/null
setenforce 0 2>/dev/null

# OS-specific installation functions
RHEL() {
    yum check-update -y >/dev/null
    for i in sudo net-tools iptables iproute sed curl wget bash gcc gzip make procps socat tar auditd rsyslog tcpdump unhide strace; do
        yum install -y "$i"
    done
}

SUSE() {
    for i in sudo net-tools iptables iproute2 sed curl wget bash gcc gzip make procps socat tar auditd rsyslog; do
        zypper -n install -y "$i"
    done
}

DEBIAN() {
    apt-get -qq update >/dev/null
    for i in sudo net-tools iptables iproute2 sed curl wget bash gcc gzip make procps socat tar auditd rsyslog tcpdump unhide strace debsums; do
        apt-get -qq install -y "$i"
    done
}

UBUNTU() {
    DEBIAN
}

ALPINE() {
    echo "http://mirrors.ocf.berkeley.edu/alpine/v3.16/community" >> /etc/apk/repositories
    apk update >/dev/null
    for i in sudo iproute2 net-tools curl wget bash iptables util-linux-misc gcc gzip make procps socat tar tcpdump audit rsyslog; do
        apk add "$i"
    done
}

SLACK() {
    slapt-get --update
    for i in net-tools iptables iproute2 sed curl wget bash gcc gzip make procps socat tar tcpdump auditd rsyslog; do
        slapt-get --install "$i"
    done
}

ARCH() {
    pacman -Syu --noconfirm >/dev/null
    for i in sudo net-tools iptables iproute2 sed curl wget bash gcc gzip make procps socat tar tcpdump auditd rsyslog; do
        pacman -S --noconfirm "$i"
    done
}

# Detect OS and install required packages
if command -v yum >/dev/null; then
    RHEL
elif command -v zypper >/dev/null; then
    SUSE
elif command -v apt-get >/dev/null; then
    if grep -qi Ubuntu /etc/os-release; then
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

# Backup user and group data
cp /etc/passwd "$BCK/users"
cp /etc/group "$BCK/groups"

# Determine network connection listing tools
if command -v netstat >/dev/null; then
    LIST_CMD="netstat -tulpn"
    ESTB_CMD="netstat -tupwn"
elif command -v ss >/dev/null; then
    LIST_CMD="ss -blunt -p"
    ESTB_CMD="ss -buntp"
else
    echo "No netstat or ss found"
    LIST_CMD="echo 'No netstat or ss found'"
    ESTB_CMD="echo 'No netstat or ss found'"
fi

# Save network connection info
$LIST_CMD > "$BCK/listen"
$ESTB_CMD > "$BCK/estab"

# Backup PAM configuration and libraries
mkdir -p "$BCK/pam/conf"
mkdir -p "$BCK/pam/pam_libraries"
cp -R /etc/pam.d/ "$BCK/pam/conf/" 2>/dev/null

MOD=$(find /lib/ /lib64/ /lib32/ /usr/lib/ /usr/lib64/ /usr/lib32/ -name "pam_unix.so" 2>/dev/null)
for m in $MOD; do
    moddir=$(dirname "$m")
    mkdir -p "$BCK/pam/pam_libraries/$moddir"
    cp "$moddir"/pam*.so "$BCK/pam/pam_libraries/$moddir" 2>/dev/null
done

# Harden PHP configuration
sys=$(command -v service || command -v systemctl || command -v rc-service)

for file in $(find / -name 'php.ini' 2>/dev/null); do
    {
        echo "disable_functions = 1e, exec, system, shell_exec, passthru, popen, curl_exec, curl_multi_exec, parse_file_file, show_source, proc_open, pcntl_exec/"
        echo "track_errors = off"
        echo "html_errors = off"
        echo "max_execution_time = 3"
        echo "display_errors = off"
        echo "short_open_tag = off"
        echo "session.cookie_httponly = 1"
        echo "session.use_only_cookies = 1"
        echo "session.cookie_secure = 1"
        echo "expose_php = off"
        echo "magic_quotes_gpc = off"
        echo "allow_url_fopen = off"
        echo "allow_url_include = off"
        echo "register_globals = off"
        echo "file_uploads = off"
    } >> "$file"

    echo "$file changed"
done

# Restart common web services
if [ -d /etc/nginx ]; then
    $sys nginx restart || $sys restart nginx
    echo "nginx restarted"
fi

if [ -d /etc/apache2 ]; then
    $sys apache2 restart || $sys restart apache2
    echo "apache2 restarted"
fi

if [ -d /etc/httpd ]; then
    $sys httpd restart || $sys restart httpd
    echo "httpd restarted"
fi

if [ -d /etc/lighttpd ]; then
    $sys lighttpd restart || $sys restart lighttpd
    echo "lighttpd restarted"
fi

if [ -d /etc/ssh ]; then
    $sys ssh restart || $sys restart ssh || $sys restart sshd || $sys sshd restart
    echo "ssh restarted"
fi

# Restart PHP-FPM if installed
file=$(find /etc -maxdepth 2 -type f -name 'php-fpm*' -print -quit)
if [ -d /etc/php/*/fpm ] || [ -n "$file" ]; then
    $sys '*php*' restart || $sys restart '*php*'
    echo "php-fpm restarted"
fi
