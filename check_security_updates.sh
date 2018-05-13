#!/bin/sh
# https://superuser.com/a/199874
# Standard Nagios plugin return codes.
STATUS_OK=0
STATUS_WARNING=1
STATUS_CRITICAL=2
STATUS_UNKNOWN=3

# Query pending updates.
updates=$(/usr/lib/update-notifier/apt-check 2>&1)
if [ $? -ne 0 ]; then
    echo "Querying pending updates failed."
    exit $STATUS_UNKNOWN
fi

# Check for the case where there are no updates.
if [ "$updates" = "0;0" ]; then
    echo "All packages are up-to-date."
    exit $STATUS_OK
fi

# Check for pending security updates.
pending=$(echo "${updates}" | cut -d ";" -f 2)
if [ "$pending" != "0" ]; then
    echo "${pending} security update(s) pending."
    exit $STATUS_CRITICAL
fi

# Check for pending non-security updates.
pending=$(echo "${updates}" | cut -d ";" -f 1)
if [ "$pending" != "0" ]; then
    echo "${pending} non-security update(s) pending."
    exit $STATUS_WARNING
fi

# If we've gotten here, we did something wrong since our "0;0" check should have
# matched at the very least.
echo "Script failed, manual intervention required."
exit $STATUS_UNKNOWN
