#!/bin/sh
#
# About
# -----
# This script sends simple system-metrics to a remote graphite server.
#
#
# Metrics
# -------
# The metrics currently include the obvious things such as:
#
#   * System uptime.
#   * Percentages of disk fullness for all mount-points.
#   * Swap In/Out status.
#   * Process-count and fork-count.
#   * NTP-skew.
#
# The metrics can easily be updated on a per-host basis via the inclusion
# of local scripts.
#
#
# Extensions
# ----------
# Any file matching the pattern /etc/graphite_send.d/*.sh will be executed
# and the output will be used to add additional metrics to be sent.
#
# The shell-scripts will be assumed to output values such as:
#    metric.name1  33
#    metric.name2  value
#
# The hostname and the time-period will be added to the  data before it
# is sent to the graphite host.
#
#
# Usage
# -----
# Configure the host/port of the graphite server in the file
# via /etc/default/graphite.conf:
#
#   echo HOST=1.2.3.4 >  /etc/default/graphite.conf
#   echo PORT=2004    >> /etc/default/graphite.conf
#
# Then merely run `graphite_send`, as root, and the metrics will be sent.
#
# If you wish to see what is being sent run:
#
#    VERBOSE=1 graphite_send
#
#
# License
# -------
# Copyright (c) 2014 by Steve Kemp.  All rights reserved.
#
# This script is free software; you can redistribute it and/or modify it under
# the same terms as Perl itself.
#
# The LICENSE file contains the full text of the license.
#

## Setup some defaults
config_location=/mnt/WD_NAS/Monitoring/config/graphite/graphite.conf

#
# Setup a sane path
#
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
export PATH

#
# Get the current hostname
#
host=$(hostname -s)

#
# The current time - we want all metrics to be reported at the
# same time.
#
time=$(date +%s)

#
#  If we have a configuration file then load it, if not then abort.
#
if [ -e "$config_location" ]; then
    . "$config_location" 
else
    echo "You must configure the remote host:port to send data to"
    echo "Please try:"
    echo " "
    echo "  echo HOST=1.2.3.4 > "$config_location"
    echo "  echo PORT=2003    >> "$config_location"
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
    #
    if ( which nc >/dev/null 2>/dev/null ); then
        echo $1 | nc -w1 -t $HOST $PORT
    else
        echo "nc (netcat) is not present.  Aborting"
    fi

}

### Send some smart data
for i in $(/usr/local/sbin/smartctl --scan | awk '{for (i=NF; i!=0 ; i--) if(match($i, '/pass[0-9]/')) print $i }'| sed 's/\/dev\///' | grep -v ',$' ); do
  # Sanity check that the drive will return a temperature (we don't want to include non-SMART usb devices)
  current_temp=`/usr/local/sbin/smartctl -d scsi -a /dev/$i | awk '/Current Drive Temperature/{print $0}' | awk '{print $4}'`;
  send "$host.$i.temp $current_temp $time"
done
### End smart data
