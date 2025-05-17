#!/bin/sh

# OS flags
IS_RHEL=false
IS_DEBIAN=false
IS_ALPINE=false
IS_SLACK=false
IS_SUSE=false
IS_ARCH=false

# Color variables
ORAG=''
GREEN=''
YELLOW=''
BLUE=''
RED=''
NC=''

# Determine if echo supports -e
if echo -e "test" | grep -qE '\-e'; then
    ECHO='echo'
else
    ECHO='echo -e'
fi

# Debug print function
if [ -z "$DEBUG" ]; then
    DPRINT() { "$@" 2>/dev/null; }
else
    DPRINT() { "$@"; }
fi

# OS detection functions
RHEL()   { IS_RHEL=true; }
SUSE()   { IS_SUSE=true; }
DEBIAN() { IS_DEBIAN=true; }
UBUNTU() { DEBIAN; }
ALPINE() { IS_ALPINE=true; }
SLACK()  { IS_SLACK=true; }
ARCH()   { IS_ARCH=true; }

# OS Detection
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

# Enable colors if set
if [ -n "$COLOR" ]; then
    ORAG='\033[0;33m'
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;36m'
    NC='\033[0m'
fi

echo ""
${ECHO} "${GREEN}#############SERVICE INFORMATION############${NC}"

# Get running services based on detected OS
if [ "$IS_ALPINE" = true ]; then
    SERVICES=$(rc-status -s | grep started | awk '{print $1}')
elif [ "$IS_SLACK" = true ]; then
    SERVICES=$(ls -la /etc/rc.d | grep rwx | awk '{print $9}')
else
    SERVICES=$(DPRINT systemctl --type=service | grep active | awk '{print $1}' || service --status-all | grep -E '(+|is running)')
fi

# Service check function
checkService() {
    serviceList=$1
    serviceToCheckExists=$2
    serviceAlias=$3

    serviceGrep="$serviceToCheckExists"
    [ -n "$serviceAlias" ] && serviceGrep="$serviceAlias\|$serviceToCheckExists"

    if echo "$serviceList" | grep -qi "$serviceGrep"; then
        ${ECHO} "\n${BLUE}[+] $serviceToCheckExists is on this machine${NC}\n"

        if netstat -tulpn 2>/dev/null | grep -i "$serviceGrep" >/dev/null; then
            ${ECHO} "Active on port(s) ${YELLOW}$(netstat -tulpn | grep -i "$serviceGrep" | awk 'BEGIN {ORS=" and "} {print $1, $4}' | sed 's/\(.*\)and /\1\n/')${NC}\n"
        elif ss -blunt -p 2>/dev/null | grep -i "$serviceGrep" >/dev/null; then
            ${ECHO} "Active on port(s) ${YELLOW}$(ss -blunt -p | grep -i "$serviceGrep" | awk 'BEGIN {ORS=" and "} {print $1,$5}' | sed 's/\(.*\)and /\1\n/')${NC}\n"
        fi
    fi
}

# Docker
if checkService "$SERVICES" 'docker' | grep -qi "is on this machine"; then
    checkService "$SERVICES" 'docker'

    ACTIVECONTAINERS=$(docker ps)
    [ -n "$ACTIVECONTAINERS" ] && echo "Current Active Containers" && ${ECHO} "${ORAG}$ACTIVECONTAINERS${NC}\n"

    ANONMOUNTS=$(docker ps -q | DPRINT xargs -n 1 docker inspect --format '{{if .Mounts}}{{.Name}}: {{range .Mounts}}{{.Source}} -> {{.Destination}}{{end}}{{end}}' | grep -vE '^$' | sed 's/^\///g')
    [ -n "$ANONMOUNTS" ] && echo "Anonymous Container Mounts (host -> container)" && ${ECHO} "${ORAG}$ANONMOUNTS${NC}\n"

    VOLUMES=$(DPRINT docker volume ls --format "{{.Name}}")
    if [ -n "$VOLUMES" ]; then
        echo "Volumes"
        for v in $VOLUMES; do
            container=$(DPRINT docker ps -a --filter volume=$v --format '{{.Names}}' | tr '\n' ',' | sed 's/,$//')
            if [ -n "$container" ]; then
                mountpoint=$(DPRINT docker volume inspect --format '{{.Name}}: {{.Mountpoint}}' "$v" | awk -F ': ' '{print $2}')
                ${ECHO} "${ORAG}$v -> $mountpoint used by $container${NC}"
            fi
        done
        echo ""
    fi
fi

# Apache2
if checkService "$SERVICES" 'apache2' 'httpd' | grep -qi "is on this machine"; then
    checkService "$SERVICES" 'apache2' 'httpd'
    APACHE2=true

    if [ -d "/etc/httpd" ]; then
        APACHE2VHOSTS=$(tail -n +1 /etc/httpd/conf.d/* /etc/httpd/conf/httpd.conf 2>/dev/null | grep -v '#' | grep -E '==>|VirtualHost|ServerName|DocumentRoot|ServerAlias|Proxy')
    else
        APACHE2VHOSTS=$(tail -n +1 /etc/apache2/sites-enabled/* /etc/apache2/apache2.conf 2>/dev/null | grep -v '#' | grep -E '==>|VirtualHost|ServerName|DocumentRoot|ServerAlias|Proxy')
    fi

    ${ECHO} "\n[!] Configuration Details\n"
    ${ECHO} "${ORAG}$APACHE2VHOSTS${NC}"
fi

# Nginx
if checkService "$SERVICES" 'nginx' | grep -qi "is on this machine"; then
    checkService "$SERVICES" 'nginx'
    NGINX=true
    NGINXCONFIG=$(tail -n +1 /etc/nginx/sites-enabled/* /etc/nginx/nginx.conf 2>/dev/null | grep -v '#' | grep -E '==>|server|listen|root|server_name|proxy_')
    ${ECHO} "\n[!] Configuration Details\n"
    ${ECHO} "${ORAG}$NGINXCONFIG${NC}"
fi

