#!/bin/bash
# This is a factory test script that places a barebones system in
# /run/intramfs. This fs will mount the USB disk and flash its 
# image to internal storage.

set -e
mydir=$(dirname $(readlink -f $0))

echo "Unpacking initramfs in /run/initramfs"

if [ ! -d /run/initramfs ] ; then
    mkdir /run/initramfs
fi
cd /run/initramfs

INITRAMFS_PATH=$mydir/initramfs.img

if [ -f $INITRAMFS_PATH ] ; then
    zcat $INITRAMFS_PATH | cpio -id >/dev/null || exit 1
    echo "Successfully unpacked initramfs."
else
    echo "${INITRAMFS_PATH} could not be found. Use backup flashing method."
    sleep 10
    exit 1
fi
sleep 2

systemctl mask plymouth-poweroff.service plymouth-shutdown.service plymouth-halt.service
echo "Removing testsuite directory and powering off."
sleep 2
rm -rf $mydir
poweroff
