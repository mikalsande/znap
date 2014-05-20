#!/bin/sh
#
# ----------------------------------------------------------------------------
# "THE BEER-WARE LICENSE" (Revision 42):
# <mikal.sande@gmail.com> wrote this file. As long as you retain this notice you
# can do whatever you want with this stuff. If we meet some day, and you think
# this stuff is worth it, you can buy me a beer in return. Mikal Sande 
# ----------------------------------------------------------------------------
#
# znap-hourly.sh - a zfs pool hourly snapshot management script
# usage: znap-hourly.sh <pool>
#
# znap-hourly.sh is a simple zfs snapshot management script. It performs 
# hourly snapshots for a whole pool recursively and keeps the snapshots 
# for a configurable amount of hours.
#
# This script is ment to take a snapshot of a whole pool eveyr hour. 
# Although it can also be scheduled every two hours, or any other hourly 
# interval. The snapshots will live for the configured amount of hours 
# either way.
#
# All date related functions are performed by date(1), this script only 
# performs integer comparisons to determine when a snapshot is to too old.
#
# This script should be scheduled a after znap.sh.
#
# Add this line to /etc/crontab to run the script daily
# 7   *   *   *   *   _znap	/bin/sh /usr/local/sbin/znap-hourly.sh <poolname>
#

set -u

PATH=/sbin:/bin:/usr/sbin:/usr/bin

# Configuration files
CONFIG='./'
CONFIG_FILE="${CONFIG}/znap.conf"
CONFIG_DIR="${CONFIG}/znap.d"
FOUND_CONFIG='no'


########################
# Script Configuration #
########################

# set standard config just in case something is commented out in the 
# config file the lines below are configurables that can be set in a 
# per pool config. 
HOURLY_LIFETIME=${HOURLY_LIFETIME:='24'}

# name that will be used and grepped for in snapshots
SNAPSHOT_NAME=${SNAPSHOT_NAME:='znap'}

# ratelimit destroyal of old snapshots to make
# sure that we don't delete all snapshots,
# theis determines the maximum number of snapshots
# the script destroys each time it is executed.
DESTROY_LIMIT=${DESTROY_LIMIT:='2'}


#########################
# Runtime configuration #
#########################

# find the threshold date for destroying snapshots
HOURLY_DESTROY_TIME="$(date -v -${HOURLY_LIFETIME}H '+%Y%m%d%H%M')"

# the date and hour when the script is run
TIME_NOW="$(date '+%Y%m%d%H%M')"


#################
# Runtime tests #
#################

# Is a poolname given?
if [ "$#" -eq '0' ]
then
	echo "$0 - Please enter a poolname"
	exit 2
fi
POOL="$1"

# Does the pool exist?
zpool list "$POOL" > /dev/null 2>&1
if [ "$?" -ne '0' ]
then
	echo "$0 - No such pool: $POOL"
	exit 2
fi

# Is the pool in the FAULTED state?
zpool status "$POOL" | grep 'state: FAULTED' > /dev/null
if [ "$?" -eq '0' ]
then
	echo "$0 - Pool is in the FAULTED state, exiting"
	echo
	zfs status "$POOL"
	exit 1
fi

# Skip snapshot if znap.sh has taken a snapshot this hour
zfs list -t snapshot | grep "^$POOL" | grep "${TIME_NOW}_${SNAPSHOT_NAME}_" > /dev/null
if [ "$?" -eq '0' ]
then
	exit 0
fi

# Is there a general config?
if [ -r "$CONFIG_FILE" ]
then
	. $CONFIG_FILE
	FOUND_CONFIG='yes'
fi

# Is there a specific config for this pool?
POOL_CONFIG="${CONFIG_DIR}/${POOL}.conf"
if [ -f "$POOL_CONFIG" ]
then
	. $POOL_CONFIG
	FOUND_CONFIG='yes'
fi

# Exit if no configs were found
if [ "$FOUND_CONFIG" != 'yes' ]
then
	echo "$0 - No config found at $CONFIG_FILE or $POOL_CONFIG, exiting"
	exit 2
fi


######################
# Make new snapshots #
######################

# snapshot name
SNAPSHOT="${TIME_NOW}_${SNAPSHOT_NAME}_hourly"

# make the snapshot
zfs snapshot -r "${POOL}@${SNAPSHOT}"


########################
# Delete old snapshots #
########################

# destroyed snapshot count
destroyed='0'

# destroy old hourly snapshots
for snapshot in $( zfs list -H -t snapshot -o name \
	| grep "^${POOL}" | grep "_${SNAPSHOT_NAME}_hourly" \
	| grep --only-matching '@.*' | sort | uniq )
do
	# exit if we have already destroyed enough snapshots
	if [ "$destroyed" -eq "$DESTROY_LIMIT" ]
	then
		exit 0
	fi

	snapshot_date="${snapshot#@}"
	snapshot_date="${snapshot_date%%_*}"

	if [ "$snapshot_date" -lt "$HOURLY_DESTROY_TIME" ]
	then
		zfs destroy -d -r "${POOL}${snapshot}"
		destroyed=$(( $destroyed + 1 ))
	fi
done


exit 0
