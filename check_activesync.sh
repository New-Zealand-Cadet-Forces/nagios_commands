#!/bin/bash
#set -x
################################################################################
#
# check_activesync plugin for Nagios
#
# Originally Written by Kristijan Modric (kmodric_at_gmail.com)
#
# Created: 23 March 2011
#
# Version 1.0 (Kristijan Modric)
#
# Base for this plugin was great article about EAS protocol written by Andreas Helland (Digging Into The Exchange ActiveSync Protocol)
# http://mobilitydojo.net/2010/03/17/digging-into-the-exchange-activesync-protocol/
#
# Command line: check_activesync.sh
#
# Description:
# This plugin will attempt to connect to EAS (Exchange Active Sync) server and get Folder information for specific user
# Scripts is checking existing of some unique Folder in the output
#
# Notes:
# - This plugin requires that the curl program is installed.
# - You need to copy binary file activesync.txt to: /usr/lib/nagios/plugins/
# or change in script to reflect your configuration (--data-binary @/usr/lib/nagios/plugins/activesync.txt)
# (If you are interested in the byte sequence here goes: 03 01 6a 00 00 07 56 52 03 30 00 01 01.)
# - You need to configure Active Sync manually to know DeviceID and DeviceType information
# for that you must use real mobile device or emulator to create partnership
# - You need to create unique folder in user's mailbox (eg. Nagios2759671)
# - MS-ASProtocolVersion: 12.0 (Exchange 2007 RTM)
# 14.0 (Exchange 2010)
# 12.1 (Exchange 2007 SP1)
# 12.0 (Exchange 2007 RTM)
#
# Parameters:
# $1 - domain name
# $2 - username
# $3 - password (Note: avoid using of special character e.g.: escalation mark!)
# $4 - DeviceID - A unique id for the device that is synchronizing (you gen retrieve that information from owa (Outlook web access))
# or using power shell:
# Get-ActiveSyncDevice -Identity "user"
# Get-ActiveSyncDevice -Mailbox "domainuser"
# $5 - DeviceType - An id for the device/model you are using, or the ActiveSync client. (can be anything eg. PocketPC or iPhone)
# $6 - activesyncserver (eg. as.contoso.com)
# $7 - UniqueFolder (eg. Nagios2759671)
#
# Example of command definitions for nagios:
#
# define command {
# command_name check_activesync
# command_line /usr/lib/nagios/plugins/check_activesync.sh $ARG1$ $ARG2$ $ARG3$ $ARG4$ $ARG5$ $ARG6$ $ARG7$
# }
#
##############################################################################


STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_DEPENDENT=4


if [ $# -ne 7 ]; then
echo "Usage: $0 "
echo "Example 1: $0 "
echo "Example 2: $0 "
exit 3
fi


#DEBUG:Verbose mode
#result=`/usr/bin/curl -verbose -k --basic --user $1''$2:$3 -H "Expect: 100-continue" -H "Host: $6" -H "MS-ASProtocolVersion: 12.0" -H "Connection: Keep-Alive" -A "$5" --data-binary @/usr/lib/nagios/plugins/activesync.txt -H "Content-Type: application/vnd.ms-sync.wbxml" "https://$6/Microsoft-Server-ActiveSync?Cmd=FolderSync&User=$2&DeviceId=$4&DeviceType=$5" | strings`

result=`/usr/bin/curl -k --basic --user $1''$2:$3 -H "Expect: 100-continue" -H "Host: $6" -H "MS-ASProtocolVersion: 12.0" -H "Connection: Keep-Alive" -A "$5" --data-binary @/usr/lib/nagios/plugins/activesync.txt -H "Content-Type: application/vnd.ms-sync.wbxml" "https://$6/Microsoft-Server-ActiveSync?Cmd=FolderSync&User=$2&DeviceId=$4&DeviceType=$5" | strings`


if [[ $result == *$7* ]]
then
echo "Active Sync is working OK! | ActiveSyncCheck=1"
exit $STATE_OK
else
echo "Active Sync is NOT working! | ActiveSyncCheck=0"
exit $STATE_CRITICAL
fi
