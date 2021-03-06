#!/bin/sh
#
# sshd        Starts sshd.
#

# Make sure the ssh-keygen progam exists
[ -f /usr/bin/ssh-keygen ] || exit 0

# Check for the SSH1 RSA key
if [ ! -f ./etc/ssh_host_key ] ; then
	echo Generating RSA Key...
	/usr/bin/ssh-keygen -t rsa1 -f ./etc/ssh_host_key -C '' -N ''
fi

# Check for the SSH2 RSA key
if [ ! -f ./etc/ssh_host_rsa_key ] ; then
	echo Generating RSA Key...
	/usr/bin/ssh-keygen -t rsa -f ./etc/ssh_host_rsa_key -C '' -N ''
fi

# Check for the SSH2 DSA key
if [ ! -f ./etc/ssh_host_dsa_key ] ; then
	echo Generating DSA Key...
	echo
	/usr/bin/ssh-keygen -t dsa -f ./etc/ssh_host_dsa_key -C '' -N ''
fi

# Check for the SSH2 ECDSA key
if [ ! -f ./etc/ssh_host_ecdsa_key ]; then
	echo Generating ECDSA Key...
	echo
	/usr/bin/ssh-keygen -t ecdsa -f ./etc/ssh_host_ecdsa_key -C '' -N ''
fi

# Check for the ed25519 key
if [ ! -f ./etc/ssh_host_ed25519_key ]; then
	echo Generating ed25519 Key...
	echo
	/usr/bin/ssh-keygen -t ed25519 -f ./etc/ssh_host_ed25519_key -C '' -N ''
fi

exit $?

