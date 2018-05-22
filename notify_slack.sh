#!/bin/bash

# This script is used by Nagios to post alerts into a Slack channel
# using the Incoming WebHooks integration. Create the channel, botname
# and integration first and then add this notification script in your
# Nagios configuration.
#
# All variables that start with NAGIOS_ are provided by Nagios as 
# environment variables when an notification is generated.
# A list of the env variables is available here: 
#   http://nagios.sourceforge.net/docs/3_0/macrolist.html
#
# More info on Slack
# Website: https://slack.com/
# Twitter: @slackhq, @slackapi
#
# My info
# Website: http://matthewcmcmillan.blogspot.com/
# Twitter: @matthewmcmillan

# Based heavily from here: https://gist.github.com/matt448/8200821

#Set the message icon based on Nagios service state
if [ "$NAGIOS_SERVICESTATE" = "CRITICAL" ]
then
    ICON=":exclamation:"
elif [ "$NAGIOS_SERVICESTATE" = "WARNING" ]
then
    ICON=":warning:"
elif [ "$NAGIOS_SERVICESTATE" = "OK" ]
then
    ICON=":ballot_box_with_check:"
elif [ "$NAGIOS_SERVICESTATE" = "UNKNOWN" ]
then
    ICON=":question:"
else
    ICON=":speech_ballon:"
fi

#Send message to Slack
#curl -X POST --data "payload={\"channel\": \"${SLACK_CHANNEL}\", \"username\": \"${SLACK_USERNAME}\", \"text\": \"${ICON} HOST: ${NAGIOS_HOSTNAME}   SERVICE: ${NAGIOS_SERVICEDISPLAYNAME}     MESSAGE: ${NAGIOS_SERVICEOUTPUT} <https://${MY_NAGIOS_HOSTNAME}/cgi-bin/nagios3/status.cgi?host=${NAGIOS_HOSTNAME}|See Nagios>\"}" https://${SLACK_HOSTNAME}/services/hooks/incoming-webhook?token=${SLACK_TOKEN}

# Call by passing 2 arguments - first being slack incoming webhook for your app, 
# second being message you want to send to that channel (note trap for unwary:
# Make sure 2nd argument is JSON safe - ie no quote marks etc!)
curl -X POST -H 'Content-type: application/json' --data "{\"text\": \"${ICON} $2\"}" $1
