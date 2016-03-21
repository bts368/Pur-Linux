#!/bin/bash

env -i HOME=${HOME} TERM=${TERM} PS1='\u:\w\$ ' > /dev/null 2>&1
set +h
umask 022 
echo
set +h

set -e
if [ "${PS4}" == 'Line ${LINENO}: ' ];
then
        set -x
fi

PUR="/"
PSRC="/sources"
PTLS="/tools"
PCNTRB="/contrib"
export PUR PSRC PCNTRB PTLS

if [ "${USER}" == 'bts' ];
then
        export MAKEFLAGS="-j $(($(egrep '^processor[[:space:]]*:' /proc/cpuinfo | wc -l)+1))"
fi
ulimit -n 512

PLOGS=/var/log/pur_install
rm -rf ${PLOGS}
mkdir -p ${PLOGS}

contsrc_prep () {
        pkg=${1}
        if [ -z "${pkg}" ];
        then
                echo "WARNING: coresrc_prep called with no packagename!"
                exit 1
        fi
        rm -rf ${PSRC}/${pkg}
        cp -a ${PSRC}/pur_src/contrib/${pkg} ${PSRC}
        cd ${PSRC}/${pkg}
}

contsrc_prep2 () {
        pkg=${1}
        if [ -z "${pkg}" ];
        then
                echo "WARNING: coresrc_prep2 called with no packagename!"
                exit 1
        fi
        rm -rf ${PSRC}/${pkg}
        cp -a ${PSRC}/pur_src/contrib/${pkg} ${PSRC}
        mkdir ${PSRC}/${pkg}/${pkg}-build
        cd ${PSRC}/${pkg}/${pkg}-build
}

contsrc_clean () {
        pkg=${1}
        if [ -z "${pkg}" ];
        then
                echo "WARNING: coresrc_clean called with no packagename!"
                exit 1
        fi
        cd ${PSRC}
        rm -rf ${PSRC}/${pkg}
}

rm -rf /tools
rm -f /usr/lib/lib{bfd,opcodes}.a
rm -f /usr/lib/libbz2.a
rm -f /usr/lib/lib{com_err,e2p,ext2fs,ss}.a
rm -f /usr/lib/libltdl.a
rm -f /usr/lib/libfl.a
rm -f /usr/lib/libfl_pic.a
rm -f /usr/lib/libz.a
rm -rf /tmp/*


# NTPsec
echo "[NTPsec] Configuring..."
contsrc_prep ntpsec
# configure here
# > ${PLOGS}/ntpsec_configure.1 2>&1
echo "[NTPsec] Building..."
# compile here
# > ${PLOGS}/ntpsec_make.1 2>&1
contsrc_clean ntpsec

# LibreSSL
echo "[LibreSSL] Configuring..."
contsrc_prep libressl
# configure here
# > ${PLOGS}/libressl_configure.1 2>&1
echo "[LibreSSL] Building..."
# compile here
# > ${PLOGS}/libressl_make.1 2>&1
contsrc_clean libressl

# Net-Tools
echo "[Net-Tools] Configuring..."
contsrc_prep net-tools
# configure here
# > ${PLOGS}/net-tools_configure.1 2>&1
echo "[Net-Tools] Building..."
# compile here
# > ${PLOGS}/net-tools_make.1 2>&1
contsrc_clean net-tools
