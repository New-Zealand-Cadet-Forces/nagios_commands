#!/bin/bash

# Note - you'll need to have created Nagios user a private key, and stored it in
# /etc/nagios3/id_rsa (or change command below) first.
# Do this with 
# ssh-keygen -f /etc/nagios3/id_rsa
# Make sure this id_rsa file is owned by nagios user!
# Then you need to add the contests of /etc/nagios3/id_rsa.pub to the remote
# users' ~/.ssh/authorized_keys file
# Finally, you'll need to run the follwoing command to accept the key for the host:

# sudo -u nagios /etc/nagios3/commands/check_for_ssh_login.sh <user>@<host>
# The authenticity of host 'ps595593.dreamhost.com (75.119.215.63)' can't be established.
# RSA key fingerprint is SHA256:6ggl87eT0VFtF6rtnKsC8+3bWom5zQ1PqmnI72THAmc.
# Are you sure you want to continue connecting (yes/no)? yes
# Warning: Permanently added '<host>,<ip>' (RSA) to the list of known hosts.

# Then the following will work

uptime=`ssh ${BASH_ARGV[0]} -i /etc/nagios3/id_rsa 'uptime' | grep load`

if  ((${#uptime}>5)) ; then
    echo "OK - Uptime command returned '$uptime'."
    exit 0
else
    echo "CRITICAL - Unable to connect to remote machine."
    exit 2
fi

