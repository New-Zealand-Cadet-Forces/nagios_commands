#!/bin/bash

/usr/lib/nagios/plugins/check_file_age -f /media/backup_usb/backups/weekly/`date "+%a"`/dreamhost/updated_timestamp -w $1 -c $2 -W $3 -C $4
