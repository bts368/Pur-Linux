#!/bin/bash

set +h
set -e

if [ "${PS4}" == 'Line ${LINENO}: ' ];
then
        set -x
fi

PUR="/"
PSRC="${PUR}/sources"
PCNTRB="${PUR}/contrib"

rm -rf /tools
rm -f /usr/lib/lib{bfd,opcodes}.a
rm -f /usr/lib/libbz2.a
rm -f /usr/lib/lib{com_err,e2p,ext2fs,ss}.a
rm -f /usr/lib/libltdl.a
rm -f /usr/lib/libfl.a
rm -f /usr/lib/libfl_pic.a
rm -f /usr/lib/libz.a
rm -rf /tmp/*
