 #!/bin/sh


ipt=$(command -v iptables || command -v /sbin/iptables || command -v /usr/sbin/iptables)

ALLOW() {
    
    $ipt -P INPUT ACCEPT; $ipt -P OUTPUT ACCEPT ; $ipt -P FORWARD ACCEPT ; $ipt -F; $ipt -X
    
}

CHECKERR() {
    if [ ! $? -eq 0 ]; then
        echo "ERROR, EXITTING TO PREVENT LOCKOUT"
        ALLOW
        exit 1
    fi
}

if [ -z "$DISPATCHER" ]; then
    echo "DISPATCHER not defined."
    exit 1
fi

if [ -z "$LOCALNETWORK" ]; then
    echo "LOCALNETWORK not defined."
    exit 1
fi

#Setup backup dir
if [ -z "$BCK" ]; then
    BCK="/root/.cache"
else 
    mkdir -p $BCK 2>/dev/null
fi

#disable pre-existing rules
if [ -f /etc/ufw/ufw.conf ]; then
    ufw disable
fi

if [ -f /etc/firewalld/firewalld.conf ]; then
    systemctl stop firewalld
    systemctl disable firewalld
fi


if [ -n "$ipt" ]; then
    #Backup iptables
    iptables-save > /opt/rules.v4
    iptables-save > $BCK/rules.v4.old

    ALLOW

    #Allow scoring
    if [ -n "$CCSHOST" ]; then
        $ipt -A OUTPUT -d $CCSHOST -j ACCEPT
        CHECKERR
        $ipt -A INPUT -s $CCSHOST -j ACCEPT
        CHECKERR
    fi

    # Allow local network
    $ipt -A INPUT -s $LOCALNETWORK -j ACCEPT
    CHECKERR
    $ipt -A OUTPUT -d $LOCALNETWORK -j ACCEPT
    CHECKERR

    # Allow loopback
    $ipt -A INPUT -i lo -j ACCEPT
    CHECKERR
    $ipt -A OUTPUT -o lo -j ACCEPT
    CHECKERR

    # Allow in SSH from dispatcher
    $ipt -A INPUT -s $DISPATCHER -p tcp --dport 22 -j ACCEPT
    CHECKERR
    $ipt -A OUTPUT -d $DISPATCHER -p tcp --sport 22 -j ACCEPT
    CHECKERR

    # Allow 80 template
    $ipt -A INPUT -p tcp --dport 80 -j ACCEPT
    CHECKERR
    $ipt -A OUTPUT -p tcp --sport 80 -j ACCEPT
    CHECKERR

    # Block everything else
    $ipt -P INPUT DROP
    CHECKERR
    $ipt -P OUTPUT DROP
    CHECKERR
    $ipt -P FORWARD DROP
    CHECKERR

    # Save rules
    iptables-save > /opt/rules.v4
    iptables-save > $BCK/rules.v4
    iptables-save

fi