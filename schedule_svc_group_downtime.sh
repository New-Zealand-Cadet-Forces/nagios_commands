#!/bin/bash

#
# Write a command to the Nagios command file to cause
# it to schedule service downtime.
#
# Author: Sam Tilders sam@jovianprojects.com.au
#
# Based on the example event handler scripts and cmd.c/.cgi
#
# Requires:
#  GNU Date (for date formatting options)
#  Bash > 2.x (for inline variable regex substitution on the comment_data)

# Notes: 
# 1) In order for Nagios to process any commands that
#    are written to the command file, you must enable
#    the check_external_commands option in the main
#    configuration file.

# Caveats:
#  Using "date" to validate the command line date format doesn't always pick
# up all mistakes in the date format. Sometimes "date" seems to invent something
# that might have been what you intented.
#  Makes no attempt to verify the hostname or service desc before passing them to
# the command pipe. Nagios seems to ignore the command if it doesn't match.
# Write a command to the Nagios command file to cause
# it to schedule host downtime

# Example:
# A cron entry to schedule downtime for the nntp service every day at 0400 while 
# other cron jobs (locate database update) slow the machine down.
# 30 0 * * * schedule_svc_downtime news NNTP "`date --iso-8601` 04:00:00" "`date --iso-8601` 05:00:00" 1 3600 auto "while cron does things"
# There are utilities such as "shellsupport" that will do date manipulation allowing shell scripts
# to wrap around this command to schedule for days in advance instead of same date.

usage()
{
	echo "Usage: $0 <hostname> <service desc> <start time> <end time> <fixed> <duration> <user> <comment>"
	echo "   Times must be in the form \"CCYY-MM-DD HH:mm:ss\" and will probably need to be quoted."
	echo "   fixed is either 1 or 0 and indicates that the time period is fixed and duration should be ignored"
	echo "   length of the downtime in seconds, only used if not fixed downtime"
	echo "   user who is requesting the downtime"
	echo "   comment to place on the downtime, probably will need to be quoted."
}

if [ $# -lt 7 ]; then
	echo "$0: Too few parameters"
	usage
	exit 1
fi
if [ $# -gt 7 ]; then
	echo "$0: Too many parameters"
	usage
	exit 1
fi

#hostname=$1
servicedesc=$1
raw_start=$2
raw_end=$3
fixed=$4
duration=$5
comment_author=$6
# command is comment with ; replaced for space
#comment_data=${8/;/ }
comment_data=$7
triggered_by=0


echocmd="/bin/echo"

CommandFile="/var/lib/nagios3/rw/nagios.cmd"

# get the current date/time in seconds since UNIX epoch
datetime=`date +%s`


start_time=`date -d "$raw_start" +%s`
if [ $? != 0 ]; then
	echo "Bad format for start time."
	usage
	exit 1
fi
end_time=`date -d "$raw_end" +%s`
if [ $? != 0 ]; then
	echo "Bad format for end time."
	usage
	exit 1
fi
if [ $fixed != 1 -a $fixed != 0 ]; then
	echo "Fixed must be 1 or 0"
	usage
	exit 1
fi

# create the command line to add to the command file
cmdline=$datetime"] SCHEDULE_SERVICEGROUP_SVC_DOWNTIME;$servicedesc;$start_time;$end_time;$fixed;$triggered_by;$duration;$comment_author;$comment_data"

# append the command to the end of the command file
`$echocmd "["$cmdline >> $CommandFile`

