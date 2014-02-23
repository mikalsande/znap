#!/bin/sh

set -u

TEMPORARY_FILE='./znap.sh_install'

znap_configure()
{
	case "$(uname -s)" in
		FreeBSD)
			INSTALL_PATH='/usr/local/sbin'
			CONFIG_PATH='/usr/local/etc'
			;;
		*)
			echo "$(uname -s) is not implemented."
			exit 1
			;;
	esac

	SCRIPT="${INSTALL_PATH}/znap.sh"
	CONFIG="${CONFIG_PATH}/znap.conf"

	sed "s|^CONFIG_FILE=.*|CONFIG_FILE='/usr/local/etc/znap.conf'|g" ./znap.sh > "$TEMPORARY_FILE"
}

znap_install()
{
	# Install
	sed "s|^CONFIG_FILE=.*|CONFIG_FILE='${CONFIG}'|g" znap.sh > ./znap.sh_install
	cp ./znap.sh_install "$SCRIPT"
	chmod 555 "$SCRIPT"

	cp ./znap.conf "$CONFIG_PATH"
	chmod 644 "$CONFIG"

	echo 
	echo "Without delegation"
	echo "Add this line to /etc/crontab to run the script daily"
	echo "1   2   *   *   *   root   /bin/sh /usr/local/sbin/znap.sh <poolname>"
	echo
	echo
	echo "With delegation (remeber to add the user)"
	echo "Add this line to /etc/crontab to run the script daily"
	echo "1   2   *   *   *   _znap  /bin/sh /usr/local/sbin/znap.sh <poolname>"
}

znap_remove()
{
	rm -f "$SCRIPT"
	rm -f "$CONFIG"

	echo
	echo "Remember to remove the line from /etc/crontab"
}

znap_clean()
{
	rm -f "$TEMPORARY_FILE"
}


if [ "$#" -eq '0' ]
then
	echo "Available actions"
	echo "  configure - configure the script"
	echo "  install - configure and install script and config"
	echo "  remove - remove script and config"
	echo "  clean - clean temporary files"
	exit 0
fi

case "$1" in 
	install)
		znap_configure
		znap_install
		;;
	remove)
		znap_remove
		;;
	configure)
		znap_configure
		;;
	clean)
		znap_clean
		;;
esac
