#!/bin/bash
env -i HOME=${HOME} TERM=${TERM} PS1='\u:\w\$ ' > /dev/null 2>&1
set +h
umask 022 
echo

set -e
set -x

# Are we using curl or wget?
if ! type curl > /dev/null 2>&1; then
        fetch_cmd="$(which wget) -c --progress=bar --tries=5 --waitretry 3 -a /tmp/fetch.log"
else
        fetch_cmd="$(which curl) --progress-bar -LSOf --retry 5 --retry-delay 3 -C -"
fi


PUR=${HOME}/purroot
PLOGS=${PUR}/logs
if [ -z "${PUR}" ];
then
	echo "PUR VARIABLE IS UNSET! Further process will cause host system damage."
fi
set +e
sudo umount -l ${PUR}/{run,sys,proc,dev} > /dev/null 2>&1
sudo rm -rf ${PUR}/{run,sys,proc,dev,bin,boot,etc,home,lib,mnt,opt} > /dev/null 2>&1
set -e

PSRC=${PUR}/sources
PCNTRB=${PUR}/contrib

PUR_TGT="$(uname -m)-pur-linux-gnu"
PTLS=${PUR}/tools

############################################
# PREPPING CHROOT                          #
############################################

#Device Nodes
sudo mkdir -p ${PUR}/{dev,proc,sys,run}
sudo mknod -m 600 ${PUR}/dev/console c 5 1
sudo mknod -m 666 ${PUR}/dev/null c 1 3
sudo mount --bind /dev ${PUR}/dev
sudo mount -t devpts devpts ${PUR}/dev/pts -o gid=5,mode=620
sudo mount -t proc proc ${PUR}/proc
sudo mount -t sysfs sysfs ${PUR}/sys
sudo mount -t tmpfs tmpfs ${PUR}/run
if [ -h ${PUR}/dev/shm ];
then
	sudo mkdir -p ${PUR}/$(readlink ${PUR}/dev/shm)
fi
# Entering chroot 
cd ${PUR}
rm -f chrootboot.sh

if [ "${USER}" == 'bts' ];
then
	# used in development
	${fetch_cmd} http://10.1.1.1/pur/chrootboot.sh
else
	${fetch_cmd} https://raw.githubusercontent.com/PurLinux/Base/CURRENT/chrootboot.sh
fi

chmod +x chrootboot.sh
echo "ENTERING CHROOT"
sudo chroot "${PUR}" /tools/bin/env -i					\
			HOME=/root					\
			TERM="${TERM}"					\
			PS1='\u:\w (chroot) \$ '			\
			PATH=/bin:/usr/bin:/sbin:/usr/sbin:/tools/bin	\
			PS4="${PS4}"					\
			/tools/bin/bash /chrootboot.sh

sudo umount -l ${PUR}/{run,sys,proc,dev} > /dev/null 2>&1

