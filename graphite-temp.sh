#!/bin/sh
#
# About
# -----
# This script sends simple system-metrics to a remote graphite server.
#
#
# Metrics
# -------
# The metrics currently include smart data but would like to add things like:
#
#   * System uptime
#   * NTP-skew
#
#
#
#
# Usage
# -----
# Configure the host/port of the graphite server in the file
# via a configured graphite.conf:
#
#   echo HOST=192.168.1.xxx >  /etc/default/graphite.conf
#   echo PORT=2003    >> /etc/default/graphite.conf
#
# Then merely run `graphite_send`, as root (needed for smartctl data), and the metrics will be sent.
#
# If you wish to see what is being sent run:
#
#    VERBOSE=1 graphite_send
#
#
# License
# -------
# Copyright (c) 2017 by Peter Boguszewski
#
# This script is free software; you can redistribute it and/or modify it freely.
#

## Setup some necessary variables:
config_location=/mnt/WD_NAS/Monitoring/config/graphite/graphite.conf

#
# Setup a sane path for Linux (may need to modify/check for FreeBSD
# when porting to FreeNas jail
#
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
export PATH

#
# Get the current hostname (from a FreeBSD host)
#
host=$(hostname -s)

#
# The current time - we want all metrics to be reported at the
# same time that are colled within this script.
#
time=$(date +%s)

#
# If we have a configuration file then load it, if not then abort
# and give some guidance.
#
if [ -e "$config_location" ]; then
    . "$config_location" 
else
    echo "You must configure the remote host:port to send data to"
    echo "Please try something like this (point to a graphite server of course):"
    echo " "
    echo "  echo HOST=192.168.1.225 > "$config_location"
    echo "  echo PORT=2003 >> "$config_location"
    exit 1
fi

###
##
## A simple function to send data to a remote host:port address.
##
###
send()
{
    if [ ! -z "$VERBOSE"  ]; then
        echo "Sending : $1"
    fi
    #
    # If we have nc then send the data, otherwise alert the user.
    # This is the command for FreeBSD's nc
    #
    if ( which nc >/dev/null 2>/dev/null ); then
        echo $1 | nc -w1 -t $HOST $PORT
    else
        echo "nc (netcat) is not present.  Aborting!"
    fi
}

### Send some smart data; will add some checking as a next step
for i in $(/usr/local/sbin/smartctl --scan | awk '{for (i=NF; i!=0 ; i--) if(match($i, '/pass[0-9]/')) print $i }'| sed 's/\/dev\///' | grep -v ',$' ); do
  # Sanity check that the drive will return a temperature (we don't want to include non-SMART usb devices)
  current_temp=`/usr/local/sbin/smartctl -d scsi -a /dev/$i | awk '/Current Drive Temperature/{print $0}' | awk '{print $4}'`;
  send "$host.$i.temp $current_temp $time"
done
### End smart data
