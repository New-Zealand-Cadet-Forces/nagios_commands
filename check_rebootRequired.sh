#!/bin/bash
if [ -f /var/run/reboot-required ]; then
  echo 'CRITICAL - Reboot required'
  exit 2
fi
echo 'OK - No reboot required'
exit 0
