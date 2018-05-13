#!/bin/bash
# BASH version > 3 needed
#
# This Nagios plugin verifies a specific hop in traceroute command for expected hop
# You can define a PRIMARY EXPECTED ROUTE (OK) and a SECONDARY FAILOVER ROUTE (WARNING)
#
# Requirements :
# Traceroute command
#
# Version 1.0 : 27/03/2014
# Initial release.
#
# Davide Del Grande
################################################################################
NAGIOS_OK=0
NAGIOS_WARNING=1
NAGIOS_CRITICAL=2
NAGIOS_UNKNOWN=3


PROGNAME="check_traceroute"
AUTHOR="Davide Del Grande"
VERSION="1.0"




print_usage() {
	echo $PROGNAME $VERSION by $AUTHOR
	echo "Usage:"
	echo "check_traceroute TARGET NHOP ROUTE1 ROUTE2"
	echo " "
	echo "Example:"
	echo "check_traceroute 8.8.8.8 3 192.168.1.254 192.168.2.254"
}


if [ "$#" -lt 4 ]; then
	print_usage
	exit $NAGIOS_UNKNOWN
fi



TARGET=$1
NHOP=$2
ROUTE1=$3
ROUTE2=$4
ERRCODE=3

TR_OPTS="-n"
[[ $DEFAULT_SOCKET_TIMEOUT =~ ^[0-9]+$ ]] && TR_OPTS+=" -w$DEFAULT_SOCKET_TIMEOUT"

if  ! [[ $NHOP =~ ^[0-9]+$ ]]; then
	print_usage
	exit $NAGIOS_UNKNOWN
fi


TR_OPTS+=" -f$NHOP -m$NHOP $TARGET"

TR_OUTPUT=`traceroute $TR_OPTS 2>/dev/null`
if [ $? -ne 0 ]; then
	echo ERROR in traceroute command.
	exit $NAGIOS_UNKNOWN
fi

TR_HOP=`echo "$TR_OUTPUT" | tail -n1 | sed 's/^ *//' | cut -f 3 -d " "`

case "$TR_HOP" in
        $ROUTE1)
				echo "OK: Primary path in place: HOP $NHOP to $TARGET via $TR_HOP"
                exit $NAGIOS_OK
                ;;
        $ROUTE2)
				echo "WARNING: Failover path in place: HOP $NHOP to $TARGET via $TR_HOP"
                exit $NAGIOS_WARNING
                ;;
        *)
				echo "CRITICAL: Unexpected path in place: HOP $NHOP to $TARGET via $TR_HOP"
                exit $NAGIOS_CRITICAL
                ;;
esac
