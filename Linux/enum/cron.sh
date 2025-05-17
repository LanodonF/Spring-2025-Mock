#!/bin/sh

echo "=========="
echo "/etc/crontab:"
cat /etc/crontab

echo "=========="
echo "/etc/cron.d/:"
ls -altr /etc/cron.d/

# Only list contents of /etc/cron.d/* if CROND is not set
if [ -z $CROND ]; then
    echo "=========="
    echo "Contents of /etc/cron.d/*:"
    cat /etc/cron.d/*
fi

echo "=========="
echo "/var/spool/cron/:"
ls -altr /var/spool/cron/

echo "=========="
echo "/var/spool/cron/crontabs/:"
ls -altr /var/spool/cron/crontabs/

echo "=========="
echo "Contents of individual crontabs:"
find /var/spool/cron/crontabs/ -type f -exec echo {} \; -exec cat {} \;

echo "=========="
echo "crontab -l:"
crontab -l