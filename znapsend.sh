#!/bin/sh
#
# ----------------------------------------------------------------------------
# "THE BEER-WARE LICENSE" (Revision 42):
# <mikal.sande@gmail.com> wrote this file. As long as you retain this notice you
# can do whatever you want with this stuff. If we meet some day, and you think
# this stuff is worth it, you can buy me a beer in return. Mikal Sande
# ----------------------------------------------------------------------------
#
# znapsend.sh - a zfs snapshot replication script that works together with znap.sh
# usage: znapsend.sh <pool> [initial]
#
# Config for user, host and pool to replicate to is given on a per pool
# basis with configuration files in the znap.d directory.
#
# Using the initial argument is for sending the initial snapshots. After the 
# inital run the script should be run without that argument. The script will 
# figure out which snapshot the local and remote have in common and use that
# as a base for sending incremental zfs streams.
#
# This script does some runtime tests locally, but assumes that the config for
# slave host and slave pool are correct.

PATH=/sbin:/bin:/usr/sbin:/usr/bin

# Configuration files
CONFIG='./'
CONFIG_FILE="${CONFIG}/znap.conf"
CONFIG_DIR="${CONFIG}/znap.d"


#################
# Script Config #
#################

REMOTE_USER=${REMOTE_USER:='znapsend'}
REMOTE_HOST=''
REMOTE_POOL=''

SNAPSHOT_NAME='znap'

TEMP_FILE="/tmp/znapsend$$"

# Set traps to handle the temporary file
trap 'rm -f $TEMP_FILE' 0
trap 'exit 1' 1 2 3 15


#################
# Runtime tests #
#################

# Is a poolname given?
if [ "$#" -eq '0' ]
then
	echo "$0 - Please enter a poolname"
	exit 2
fi
LOCAL_POOL="$1"

# Does the pool exist?
zpool list "$LOCAL_POOL" > /dev/null 2>&1
if [ "$?" -ne '0' ]
then
	echo "$0 - No such pool: $LOCAL_POOL"
	exit 2
fi

# Is the pool in the FAULTED state?
zpool status "$LOCAL_POOL" | grep 'state: FAULTED' > /dev/null
if [ "$?" -eq '0' ]
then
	echo "$0 - Pool is in the FAULTED state, exiting"
	exit 1
fi

# Include the general config, just in case
if [ -r "$CONFIG_FILE" ]
then
	. "$CONFIG_FILE"
fi

# Is there a specific config for this pool?
# Exit if there isn't a config for this pool,
POOL_CONFIG="${CONFIG_DIR}/${LOCAL_POOL}.conf"
if [ -f "$POOL_CONFIG" ]
then
	. "$POOL_CONFIG"
else
	echo "$0 - No config found at $POOL_CONFIG. A per pool configuration is \
		required for the remote host and remote pool configuration."
	exit 2
fi

# Is the config for the remote host complete?
if [ -z "$REMOTE_USER" -o -z "$REMOTE_HOST" -o -z "$REMOTE_POOL" ]
then
	echo "$0 - Config for remote is incomplete"
	exit 2
fi


#############
# Full send #  
#############

# Find the newest local snapshot 
LOCAL_NEWEST="$( zfs list -H -t snapshot -o name \
	| grep "^${LOCAL_POOL}" \
	| grep "_${SNAPSHOT_NAME}_" \
	| grep --only-matching '@.*' \
	| sort -r | uniq \
	| head -1)"

# Test whether there are any local snapshots
if [ -z "$LOCAL_NEWEST" ]
then
	echo "${0} - Couldn't find any local snapshots for ${LOCAL_POOL}"
	exit 1
fi

# Is this a full run?
if [ "$#" -ge '2' -a "$2" = 'initial' ]
then
	echo "${0} - Initial run"
	echo "This could take a while, consider running it in a terminal multiplexer"
	echo

	zfs send -Rvn "${LOCAL_POOL}${LOCAL_NEWEST}"

	echo
	echo "Do you want to proceed? (y/N): "
	read answer
	if [ "$answer" != 'y' ]
	then
		exit 0
	fi

	echo
	zfs send -Rv "${LOCAL_POOL}${LOCAL_NEWEST}" \
		| ssh "$REMOTE_HOST" sudo -n zfs receive -Fduv "$REMOTE_POOL"

	exit 0
fi

# Find the newest remote snapshot
REMOTE_NEWEST=$( ssh "$REMOTE_HOST" zfs list -H -t snapshot -o name \
	| grep "^${REMOTE_POOL}" \
	| grep "_${SNAPSHOT_NAME}_" \
	| grep --only-matching '@.*' \
	| sort -r | uniq \
	| head -1 )

if [ -z "$REMOTE_NEWEST" ]
then
	echo "${0} - Couldn't find any remote snapshots, please perform a full send."
	echo
	echo "/bin/sh ${0} ${LOCAL_POOL} initial"
	exit 1
fi


####################
# Incremental send #
####################

# Find dates for the newest snapshots
local_date=$( echo "$LOCAL_NEWEST" | tr -d '@' | grep -o '^[[:digit:]]*' )
remote_date=$( echo "$REMOTE_NEWEST" | tr -d '@' | grep -o '^[[:digit:]]*' )

# Is the remote pool ahead of the local pool?
if [ "$remote_date" -gt "$local_date" ]
then
	echo "${0} - Remote pool is ahead of the local pool"
	exit 1
fi

# Is the remote in sync already?
if [ "$remote_date" -eq "$local_date" ]
then
	echo "${0} - Remote is already in sync"
	exit 1
fi

# Prepare the temporary file
touch "$TEMP_FILE" > /dev/null 2>&1
if [ "$?" -ne '0' ]
then
	echo "$0 - Couldn't create temp file ${TEMP_FILE}, exiting"
	exit 1
fi


# Generate list of local snapshots
zfs list -H -t snapshot -o name \
	| grep "^${LOCAL_POOL}" \
	| grep "_${SNAPSHOT_NAME}_" \
	| grep --only-matching '@.*' \
	| sort -r | uniq \
	> "$TEMP_FILE"

# Generate list of remote snapshots
ssh "${REMOTE_USER}@${REMOTE_HOST}" zfs list -H -t snapshot -o name \
	| grep "^${REMOTE_POOL}" \
	| grep "_${SNAPSHOT_NAME}_" \
	| grep --only-matching '@.*' \
	| sort -r | uniq \
	>> "$TEMP_FILE"

# Find the newest snapshot the local and remote pools have in common, if any
COMMON_NEWEST="$( sort -r "$TEMP_FILE" | uniq -d | head -1 )"

# Exit if there are no snapshots in common between the local and remote pools
if [ -z "$COMMON_NEWEST" ]
then
	echo "$0 - No common snapshots, please perform an initial full zfs send"
	echo "/bin/sh $0 $LOCAL_POOL initial"
	exit 1
fi

# Send the incremental zfs stream to the remote
zfs send -R -I "${LOCAL_POOL}${COMMON_NEWEST}" "${LOCAL_POOL}${LOCAL_NEWEST}" \
	| ssh "${REMOTE_USER}@${REMOTE_HOST}" sudo -n zfs receive -Fdu "$REMOTE_POOL"
