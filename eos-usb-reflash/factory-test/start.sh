#!/bin/bash
# This is a factory test script that places a barebones system in
# /run/intramfs. This fs will mount the USB disk and flash its 
# image to internal storage.

set -e
mydir=$(dirname $(readlink -f $0))

# If this script is running from an exFAT filesystem we need to manually load
# the exfat kernel module, as on EOS prior to 4.0 the USB device has been
# mounted using the FUSE exFAT driver, and the initramfs we are going to pivot
# to does not contain an exFAT driver (neither in-kernel nor via FUSE).
FSTYPES=$(lsblk --noheadings --output FSTYPE)
if [[ "$FSTYPES" =~ "exfat" ]] ; then
    echo "Detected an exFAT filesystem attached to this machine;"
    echo "Trying to load the 'exfat' kernel module..."
    if ! modprobe exfat ; then
        echo "This version of EOS does not have in-kernel exFAT support!"
        echo "If you are trying to reflash this computer from a USB device "
        echo "formatted as exFAT, please try again with a device formatted "
        echo "with a compatible filesystem (ext2 / ext4)."
        echo "Removing testsuite directory and powering off in 30 seconds..."
        sleep 30
        rm -rf $mydir
        poweroff
    fi
fi

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
