#!/bin/sh
#
# ----------------------------------------------------------------------------
# "THE BEER-WARE LICENSE" (Revision 42):
# <mikal.sande@gmail.com> wrote this file. As long as you retain this notice you
# can do whatever you want with this stuff. If we meet some day, and you think
# this stuff is worth it, you can buy me a beer in return. Mikal Sande 
# ----------------------------------------------------------------------------
#
# znap-util.sh - utility script for znap
# usage: znap.sh <pool> <actip>
#

set -u


########################
# Script Configuration #
########################

# Configuration files
CONFIG='./'
CONFIG_FILE="${CONFIG}/znap.conf"
CONFIG_DIR="${CONFIG}/znap.d"
FOUND_CONFIG='no'


#############
# Functions #
#############

# List all toplevel znap snapshots
list ()
{
	zfs list -H -t snapshot -o name | grep "^${POOL}" \
		| grep "_${SNAPSHOT_NAME}_" \
		| grep --only-matching '@.*' \
		| sort | uniq
}


# List all snapshots with unique data
list_unique ()
{
	zfs list -t snapshot -S used -o name,refer,used \
		| grep "^${POOL}" | grep -v '0$'
}


# List datasets by snapshot usage
list_dataset ()
{
	zfs list -o space -S usedsnap -o name,used,usedsnap \
		| grep "^${POOL}" | grep -v '0$'
}


# Show config
show_config ()
{
	cat << EOF

Config
  Poolname:		$POOL
  Config file:		$CONFIG_FILE
  Config directory:	$CONFIG_DIR

Lifetimes
  Hourly snapshot:	$HOURLY_LIFETIME hours
  Daily snapshot:	$DAILY_LIFETIME days
  Weekly snapshot:	$WEEKLY_LIFETIME days
  Monthly snapshot:	$MONTHLY_LIFETIME days

Destroy times
  Hourly snapshots:	$HOURLY_DESTROY_TIME
  Daily snapshots:	$DAILY_DESTROY_DATE
  Weekly snapshots:	$WEEKLY_DESTROY_DATE
  Monthly snapshots:	$MONTHLY_DESTROY_DATE

Weekdays (1 = monday, 7 = sunday)
  Weekly snapshots:	$WEEKLY_DAY
  Monthly snapshots:	$MONTHLY_DAY

Name included in all snapshots: $SNAPSHOT_NAME

Snapshots destroyed per run: $DESTROY_LIMIT

ssh replication config
  Username:		$REMOTE_USER
  Host:			$REMOTE_HOST
  Pool:			$REMOTE_POOL

EOF
}


# Print help
print_help ()
{
	cat << EOF

Usage: $(basename $0) <pool> <action>

Actions:
  config	Show znap config
  dataset	List datasets where snapshots contain data
		Shows the fields name,used,usedsnap
  list		List all toplevel snapshots
  uniq		List all snapshots that have unique data
		Shows the fields name,refer,used

EOF

	exit
}


#################
# Runtime tests #
#################

# Is a poolname given?
if [ "$#" -eq '0' ]
then
	echo "$0 - Please enter a poolname"
	print_help
fi
POOL="$1"

# Is an action given?
if [ "$#" -eq '2' ]
then
	ACTION="$2"	
else 
	print_help
fi

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


#########################
# Runtime configuration #
#########################

# find the threshold date for destroying snapshots
HOURLY_DESTROY_TIME="$(date -v -${HOURLY_LIFETIME}H '+%Y%m%d%H')"
DAILY_DESTROY_DATE="$(date -v -${DAILY_LIFETIME}d '+%Y%m%d%H')"
WEEKLY_DESTROY_DATE="$(date -v -${WEEKLY_LIFETIME}d '+%Y%m%d%H')"
MONTHLY_DESTROY_DATE="$(date -v -${MONTHLY_LIFETIME}d '+%Y%m%d%H')"

# todays date, day of week and day of month
TODAY_DATE="$(date '+%Y%m%d%H')"
TODAY_DAY_OF_WEEK="$(date '+%u')"
TODAY_DAY_OF_MONTH="$(date '+%d')"


########
# Main #
########

case "$ACTION" in
config)
	show_config
	;;
dataset)
	list_dataset
	;;
list)
	list
	;;
uniq)
	list_unique
	;;
*)
	echo "Unrecognized action."
	print_help
esac
