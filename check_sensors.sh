#!/usr/bin/env bash
# $Id$
# check_sensors - get temperature, fan speed, and voltages from lm-sensors
#   by Matthew Wall
#   based on check_sensors by Mikael Lammentausta
#
# Copyright (c) 2010 Matthew Wall, all rights reserved
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
#
# Revision History
#  0.3 - testing on openbsd
#  0.2 - make return codes consistent
#  0.1 - fix parsing of temperatures when output contains degree symbol
#      - consolidate code
#      - fix parsing of motherboard temperature
#      - handle multiple cpus
#
#
# Prerequisites
#
# This plugin depends on lm-sensors.  Ensure that lm-sensors is installed.
#   apt-get install lm-sensors
# Ensure that sensors are configured.
#   sensors-detect
# Beware that detecting sensors can hang your system!
#
#
# How to use this plugin
# 
# In a single query you can retrieve temperature, fan speed, or voltage 
# information, but not all three.  The warning and critical levels apply 
# only to temperature and fan speeds.
#
#
# Examples
# 
# check_sensors
# OK - sensors ok
#
# check_sensors -T temperature
# OK - MOTHERBOARD = 28.0C, CPU0 = 42.0C, CPU1 = 42.5C | MOTHERBOARD=28.0;; CPU0=42.0;; CPU1=42.5;;
#
# check_sensors -T temperature -w 45 -c 50
# OK - MOTHERBOARD = 28.0C, CPU0 = 42.5C, CPU1 = 42.5C | MOTHERBOARD=28.0;45;50 CPU0=42.5;45;50 CPU1=42.5;45;50
#
# check_sensors -T fan
# OK - fan1 = 4787 RPM, fan2 = 4530 RPM, fan3 = 3426 RPM | fan1=4787;; fan2=4530;; fan3=3426;;
#
# check_sensors -T fan -w 4000 -c 1000
# WARNING - fan1 = 4720 RPM, fan2 = 4560 RPM, fan3 = 3391 RPM | fan1=4720;4000;1000 fan2=4560;4000;1000 fan3=3391;4000;1000
#
# check_sensors -T voltages
# OK - VCore1 = +1.73V,VCore2 = +1.73V,+3.3V = +3.30V,+5V = +4.95V,+12V = +11.98V,-12V = -3.56V,-5V = -5.39V,cpu0_vid = +1.750V,



PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

PROGNAME=`basename $0`
PROGPATH=`echo $0 | sed -e 's,[\\/][^\\/][^\\/]*$,,'`
REVISION='0.3'

# load the nagios utils
utilsfn=
for d in $PROGPATH /usr/lib/nagios/plugins /usr/lib64/nagios/plugins /usr/local/nagios/libexec /opt/nagios-plugins/libexec . ; do
  if [ -f $d/utils.sh ]; then
    utilsfn=$d/utils.sh;
  fi
done
if [ "$utilsfn" = "" ]; then
  echo "UNKNOWN - cannot find utils.sh (part of nagios plugins)";
  exit 3;
fi
. $utilsfn;

print_usage() {
    echo "Usage: $PROGNAME [--version] [--help] [--verbose]"
    echo "       [-T (temperature | voltages | fan)]"
    echo "       [-w value] [-c value]"
    echo
    echo -e "\t --help | -h          print help"
    echo -e "\t --version | -V       print version"
    echo -e "\t --verbose | -v       be verbose"
    echo -e "\t --type | -T [type]   "
    echo -e "\t    temperature       check and print temperature data"
    echo -e "\t    voltages          check and print voltage data"
    echo -e "\t    fan               check and print fan data"
    echo -e "\t -w [value]           specify warning value"
    echo -e "\t -c [value]           specify critical value"
    echo
    echo "If no options are given, only status will be printed.  Only one"
    echo "sensor type can be specified at a time.  Values for warning and"
    echo "critical have the same units as the sensor type for which they"
    echo "are specified."
}

print_help() {
    print_revision $PROGNAME $REVISION
    echo 
    echo "This plugin checks hardware status using lm-sensors."
    echo 
    print_usage
    echo 
    support
}

# set defaults
check_temp=1
check_voltages=0
check_fan=0
isverbose=0
maxcpu=16

# parse cmd arguments
if [ "$#" -gt 0 ]; then
    while [ "$#" -gt 0 ]; do
	case "$1" in
	    '--help'|'-h')
		print_help
		exit $STATE_OK
		;;
	    '--version'|'-V')
		print_revision $PROGNAME $REVISION
		exit $STATE_OK
		;;
	    '--verbose'|'-v')
		isverbose=1
		shift 1
		;;
	    '-T'|'--type')
		case $2 in
		    'temp'|'temperature')
			check_temp=1
			;;
		    'voltages')
			check_voltages=1
			;;
		    'fan')
			check_fan=1
			;;
		    *)
			echo "UNKNOWN - unrecognized type $2"
			exit $STATE_UNKNOWN
			;;
		esac
		shift 2
		;;
	    '-c')
		critical="$2"
		shift 2
		;;
	    '-w')
		warning="$2"
		shift 2
		;;
	    *)
		echo "UNKNOWN - unrecognized option $1"
		print_usage
		exit $STATE_UNKNOWN
		;;
	esac
    done
fi

# test dependencies
if [ ! "$(type -p sensors)" ]; then
    echo "UNKNOWN - sensors command not found"
    exit $STATE_UNKNOWN
fi

# get the data
sensordata=$(sensors 2>&1)
status=$?

# check the status code
if [ ${status} -ne 0 ]; then
    echo "UNKNOWN - sensors returned $status"
    exit $STATE_UNKNOWN
fi

# all is ok
if [ $isverbose -eq 1 ]; then
    echo -e "${sensordata}"
fi

# check temperatures
check_temp() {
    cpu_temp="$(grep -i 'coretemp-isa-000' <<< "${sensordata}" | \
		grep -Eo '[0-9\.]+[[:punct:]]?[ ]?[CF]+' | head -n 1 | \
                sed 's/.\([CF]\)/\1/' )" 

    for cpu in $(seq 0 1 $maxcpu); do
      cpun_temp[${#cpun_temp[@]}]="$(grep -i "Core $cpu:" <<< "${sensordata}" | \
        grep -Eo '[0-9\.]+[[:punct:]]?[ ]?[CF]+' | head -n 1 | \
          sed 's/.\([CF]\)/\1/' )" 
    done

    mobo_temp="$(grep -i 'M/B temp' <<< "${sensordata}" | \
		 grep -Eo '[0-9\.]*[[:punct:]]?[ ]?[CF]+' | head -n 1 | \
                 sed 's/.\([CF]\)/\1/' )"
}

# check fan speed
check_fan() {
    fans="$(grep -i 'fan' <<< "${sensordata}" | cut -d'(' -f 1 )"
}

# check voltages
check_voltages() {
    sensors | grep -E '[0-9]{2}\ V' | cut -d'(' -f 1 | \
        sed 's/\ *//g ; s/:/\ =\ /' | tr '\n' ',' 
}






if [ $check_temp -eq 1 ]; then
    check_temp
    cpu_status=$STATE_OK

    t=$(grep -Eo '[0-9.]+' <<< ${cpu_temp})
    if [ "$t" != "" ]; then temps="$t "; fi
    t=$(grep -Eo '[0-9.]+' <<< ${mobo_temp})
    if [ "$t" != "" ]; then temps="$t "; fi
    for cpu in $(seq 0 1 $maxcpu); do
        t=$(grep -Eo '[0-9.]+' <<< ${cpun_temp[$cpu]})
        if [ "$t" != "" ]; then temps="$t "; fi
    done

    for t in $temps; do
        [ "$critical" ] && \
            if [ $(echo "$t > $critical" | bc) -eq 1 ]; then
            cpu_status=$STATE_CRITICAL
        fi

        [ "$warning" -a $cpu_status -eq 0 ] && \
            if [ $(echo "$t > $warning" | bc) -eq 1 ]; then
            cpu_status=$STATE_WARNING
        fi
    done

    if [ "${mobo_temp}" != "" ]; then
        if [ "$MSG" != "" ]; then MSG="$MSG, "; fi
        MSG="${MSG}MOTHERBOARD = ${mobo_temp}"
        if [ "$PARAM" != "" ]; then PARAM="$PARAM "; fi
        t=$(grep -Eo '[0-9.]+' <<< ${mobo_temp})
        PARAM="${PARAM}MOTHERBOARD=$t;$warning;$critical"
    fi
    if [ "${cpu_temp}" != "" ]; then
        if [ "$MSG" != "" ]; then MSG="$MSG, "; fi
        MSG="${MSG}CPU = ${cpu_temp}"
        if [ "$PARAM" != "" ]; then PARAM="$PARAM "; fi
        t=$(grep -Eo '[0-9.]+' <<< ${cpu_temp})
        PARAM="${PARAM}CPU=$t;$warning;$critical"
    fi
    for cpu in $(seq 0 1 $maxcpu); do
        if [ "${cpun_temp[$cpu]}" != "" ]; then
            if [ "$MSG" != "" ]; then MSG="$MSG, "; fi
            MSG="${MSG}CPU$cpu = ${cpun_temp[$cpu]}"
            if [ "$PARAM" != "" ]; then PARAM="$PARAM "; fi
            t=$(grep -Eo '[0-9.]+' <<< ${cpun_temp[$cpu]})
            PARAM="${PARAM}CPU$cpu=$t;$warning;$critical"
        fi
    done

    CODE=$cpu_status
    

    # fan
elif [ $check_fan -eq 1 ]; then
    check_fan
    fan_status=$STATE_OK
    worst_state=$STATE_OK
    first=1
    IFS_bak="$IFS"
    IFS=$'\n'

    for fan in $fans; do
	fan_status=0
	fan_name="$(awk -F':' {'print $1'} <<< $fan )"
	speed="$(awk /[0-9]+/{'print $2'} <<< $fan)"

	[ "$critical" ] && \
	    if [ $speed -le $critical ]; then
	    fan_status=$STATE_CRITICAL
	fi

	[ "$warning" -a $fan_status -eq 0 ] && \
	    if [ $speed -le $warning ]; then
	    fan_status=$STATE_WARNING
	fi
	
        if [ $first -eq 1 ]; then 
            first=0
        else
            MSG="$MSG, "
            PARAM="$PARAM "
        fi
	MSG="${MSG}${fan_name} = ${speed} RPM"
        PARAM="${PARAM}${fan_name}=${speed};$warning;$critical"

	[ $fan_status -gt $worst_state ] && worst_state=$fan_status
    done

    CODE=$worst_state


# voltages
elif [ $check_voltages -eq 1 ]; then
    # no critical/warning for voltages!
    MSG="$(check_voltages)"
    CODE=$STATE_OK


# default operation
else
    if echo ${sensordata} | egrep ALARM > /dev/null; then
	MSG="alarm detected!"
        CODE=$STATE_CRITICAL
    else
	MSG="sensors ok"
        CODE=$STATE_OK
    fi
fi




case $CODE in
0)
    STATUS=OK
    ;;
1)
    STATUS=WARNING
    ;;
2)
    STATUS=CRITICAL
    ;;
3)
    STATUS=UNKNOWN
    ;;
esac

echo -n "$STATUS - $MSG"
if [ "$PARAM" != "" ]; then echo -n " | $PARAM"; fi
echo

exit $CODE

