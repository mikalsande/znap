#!/bin/sh
#
# ----------------------------------------------------------------------------
# "THE BEER-WARE LICENSE" (Revision 42):
# <mikal.sande@gmail.com> wrote this file. As long as you retain this notice you
# can do whatever you want with this stuff. If we meet some day, and you think
# this stuff is worth it, you can buy me a beer in return. Mikal Sande 
# ----------------------------------------------------------------------------
#
# znap.sh - a zfs pool snapshot management script
# usage: znap.sh <pool>
#
# znap.sh is a simple zfs snapshot management script. It performs daily, 
# weekly and monthly snapshots for a whole pool recursively and keeps the 
# snapshots for a configurable amount of days.
#
# This script only performs one snapshot of a pool per day, # if it is time 
# for a weekly snapshot then a weekly snapshot will be created instead of a 
# daily one. The same goes for monthly snapshots, which take precedence over 
# both daily and weekly snapshots.
#
# All date related functions are performed by date(1), this script only 
# performs integer comparisons to determine when a snapshot is to too old.
#
# Add this line to /etc/crontab to run the script daily
# 1   2   *   *   *   _znap	/bin/sh /usr/local/sbin/znap.sh <poolname>
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
DAILY_LIFETIME=${DAILY_LIFETIME:='7'}
WEEKLY_LIFETIME=${WEEKLY_LIFETIME:='28'}
MONTHLY_LIFETIME=${MONTHLY_LIFETIME:='84'}

# monday = 1, sunday = 7
WEEKLY_DAY=${WEEKLY_DAY:='7'}
MONTHLY_DAY=${MONTHLY_DAY:='1'}

# name that will be used and grepped for in snapshots
SNAPSHOT_NAME=${SNAPSHOT_NAME:='znap'}

# ratelimit destroyal of old snapshots to make
# sure that we don't delete all snapshots,
# theis determines the maximum number of snapshots
# the script destroys each time it is executed.
DESTROY_LIMIT=${DESTROY_LIMIT:='2'}


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

# Are weekly and monthly snapshots on different days?
if [ "$WEEKLY_DAY" -eq "$MONTHLY_DAY"  ]
then
	echo "$0 - Weekly and monthly snapshots should be on different weekdays, exiting"
	exit 2
fi


#########################
# Runtime configuration #
#########################

# find the threshold date for destroying snapshots
DAILY_DESTROY_DATE="$(date -v -${DAILY_LIFETIME}d '+%Y%m%d%H%M')"
WEEKLY_DESTROY_DATE="$(date -v -${WEEKLY_LIFETIME}d '+%Y%m%d%H%M')"
MONTHLY_DESTROY_DATE="$(date -v -${MONTHLY_LIFETIME}d '+%Y%m%d%H%M')"

# todays date, day of week and day of month
TODAY_DATE="$(date '+%Y%m%d%H%M')"
TODAY_DAY_OF_WEEK="$(date '+%u')"
TODAY_DAY_OF_MONTH="$(date '+%d')"


#############
# Functions #
#############

# destory old snapshots
destroy_old ()
{
	case "$1" in
	daily)
		DESTROY_DATE="$DAILY_DESTROY_DATE"
		TYPE='daily'
		;;
	weekly)
		DESTROY_DATE="$WEEKLY_DESTROY_DATE"
		TYPE='weekly'
		;;
	monthly)
		DESTROY_DATE="$MONTHLY_DESTROY_DATE"
		TYPE='monthly'
		;;
	*)
		return
		;;	
	esac

	for snapshot in $( zfs list -H -t snapshot -o name \
		| grep "^${POOL}" | grep "_${SNAPSHOT_NAME}_${TYPE}" \
		| grep --only-matching '@.*' | sort | uniq )
	do
		# exit if we have already destroyed enough snapshots
		if [ "$destroyed" -eq "$DESTROY_LIMIT" ]
		then
			exit 0
		fi

		snapshot_date="${snapshot#@}"
		snapshot_date="${snapshot_date%%_*}"
		
		if [ "$snapshot_date" -lt "$DESTROY_DATE" ]
		then
			zfs destroy -d -r "${POOL}${snapshot}"
			destroyed=$(( $destroyed + 1 ))
		fi
	done
}


######################
# Make new snapshots #
######################

# decide which type the snapshots will be created
# the default is daily
SNAPSHOT_TYPE='daily'

# Is it time for a weekly snapshot?
if [ "$TODAY_DAY_OF_WEEK" = "$WEEKLY_DAY" ]
then
	SNAPSHOT_TYPE='weekly'
fi

# Is it time for a monthly snapshot?
if [ "$TODAY_DAY_OF_MONTH" -le '7' -a "$TODAY_DAY_OF_WEEK" -eq "$MONTHLY_DAY" ]
then
	SNAPSHOT_TYPE='monthly'
fi

SNAPSHOT="${TODAY_DATE}_${SNAPSHOT_NAME}_${SNAPSHOT_TYPE}"

# make the snapshot
zfs snapshot -r "${POOL}@${SNAPSHOT}"


########################
# Delete old snapshots #
########################

# destroyed snapshot count
destroyed='0'

# destroy old daily snapshots
destroy_old 'daily'

# destroy old weekly snapshots
destroy_old 'weekly'

# destroy old monthly snapshots
destroy_old 'monthly'


exit 0
