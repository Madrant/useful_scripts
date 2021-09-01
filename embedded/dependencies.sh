#!/bin/bash

set -e

echo "A packages required to build and run this program will be installed:"
cat "$0" | grep 'sudo apt-get install' | sed '1d;s/sudo apt-get install/    /g'

# Ask for confirmation
echo
echo "Proceed? [y/n]"
read -r ans

if ! [ "$ans" == 'y' ]
then
	echo "Cancelled by user"
	exit 1
fi

# Request super-user rights
if [ "$(id -u)" -ne 0 ]; then
	echo "Requesting super-user rigths..."
	sudo echo "Ok"
fi

# Check OS version
if [ -f /etc/os-release ]
then
	source /etc/os-release
	echo "Current OS: ${PRETTY_NAME}"

	if ! [ "$NAME" == "Debian/GNU Linux" ]
	then
		if ! [ "$VERSION_ID" == "9" ]
		then
			echo "Debian 9 Stretch required"
			exit 1
		fi
	else
		echo "Note: Debian 9 Stretch required"
	fi
else
	echo "Note: Debian 9 Stretch required"
fi

echo "Installing required deb packages..."

sudo apt-get install qt5-default
sudo apt-get install libqt5qml5
sudo apt-get install libqt5quick5
sudo apt-get install libqt53dquickextras5
sudo apt-get install qtdeclarative5-dev
sudo apt-get install qt3d5-dev
sudo apt-get install g++
sudo apt-get install qml-module-qtquick*
sudo apt-get install qml-module-qt3d*
sudo apt-get install qml-module-qt-labs-settings

echo "Done"
echo "Installation successfull"

exit 0
