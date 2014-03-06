#!/bin/sh
#
# ----------------------------------------------------------------------------
# "THE BEER-WARE LICENSE" (Revision 42):
# <mikal.sande@gmail.com> wrote this file. As long as you retain this notice you
# can do whatever you want with this stuff. If we meet some day, and you think
# this stuff is worth it, you can buy me a beer in return. Mikal Sande 
# ----------------------------------------------------------------------------
#
# znap.sh - a zfs pool snapshot management and scrubbing script
# usage: znap.sh <pool>
#
# znap.sh is a simple zfs snapshot and scrub management script. It performs 
# daily, weekly and monthly snapshots for a whole pool recursively and keeps 
# the snapshots for a configurable amount of days.
#
# This script only performs one snapshot of a pool per day, # if it is time 
# for a weekly snapshot then a weekly snapshot will be created instead of a 
# daily one. The same goes for monthly snapshots, which take precedence over 
# both daily and weekly snapshots.
#
# All date related functions are performed by date(1), this script only 
# performs integer comparisons to determine when a snapshot is to too old.
#
# Scrubs are performed in the first week of every month. The day in the 
# the week is configurable.
#
# Add this line to /etc/crontab to run the script daily
# 1   2   *   *   *   root   /bin/sh /usr/local/sbin/znap.sh <poolname>
#

set -u

PATH=/sbin:/bin:/usr/sbin:/usr/bin

# Configuration files
CONFIG='./'
CONFIG_FILE="${CONFIG}/znap.conf"
CONFIG_DIR="${CONFIG}/znap.d"
FOUND_CONFIG='no'

# grep strings, used to grep for different pool states
SCRUB_STRING='scrub in progress since'
RESILVER_STRING='resilver in progress since'
ONLINE_STRING='state: ONLINE'


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
SCRUB_DAY=${SCRUB_DAY:='1'}

# name that will be used and grepped for in snapshots
SNAPSHOT_NAME=${SNAPSHOT_NAME:='znap'}


#########################
# Runtime configuration #
#########################

# find the threshold date for destroying snapshots
DAILY_DESTROY_DATE="$(date -v -${DAILY_LIFETIME}d '+%Y%m%d')"
WEEKLY_DESTROY_DATE="$(date -v -${WEEKLY_LIFETIME}d '+%Y%m%d')"
MONTHLY_DESTROY_DATE="$(date -v -${MONTHLY_LIFETIME}d '+%Y%m%d')"

# todays date, day of week and day of month
TODAY_DATE="$(date '+%Y%m%d')"
TODAY_DAY_OF_WEEK="$(date '+%u')"
TODAY_DAY_OF_MONTH="$(date '+%d')"


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

# Is there a scrub going on?
zpool status "$POOL" | grep "$SCRUB_STRING" > /dev/null
if [ "$?" -eq '0' ]
then
	echo "$0 - Scrub in progress, exiting"
	exit 1
fi

# Is there resilver going on?
zpool status "$POOL" | grep "$RESILVER_STRING" > /dev/null
if [ "$?" -eq '0' ]
then
	echo "$0 - Resilver in progress, exiting"
	exit 1
fi

# Is the pool in the ONLINE state?
zpool status "$POOL" | grep "$ONLINE_STRING" > /dev/null
if [ "$?" -ne '0' ]
then
	echo "$0 - Pool isn't in ONLINE state, exiting"
	exit 1
fi


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
		snapshot_date=$( echo "$snapshot" | tr -d '@' | grep -o '^[[:digit:]]*' )

		if [ "$snapshot_date" -lt "$DESTROY_DATE" ]
		then
			zfs destroy -d -r "${POOL}${snapshot}"
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

# Is there already a snapshot for today?
zfs list -t snapshot | grep "$SNAPSHOT" > /dev/null
if [ "$?" -eq '0' ]
then
	echo "$0 - Todays snapshot already exists, exiting"
	echo "This script should only be run once per day"
	exit 1
fi

# make the snapshot
zfs snapshot -r "${POOL}@${SNAPSHOT}"


########################
# Delete old snapshots #
########################

# destroy old daily snapshots
destroy_old 'daily'

# destroy old weekly snapshots
destroy_old 'weekly'

# destroy old monthly snapshots
destroy_old 'monthly'


#################
# Monthly scrub #
#################

# perform scrub, in the first week of the month
if [ "$TODAY_DAY_OF_MONTH" -le '7' -a "$TODAY_DAY_OF_WEEK" -eq "$SCRUB_DAY" ]
then
	zpool scrub "$POOL"
fi


exit 0
