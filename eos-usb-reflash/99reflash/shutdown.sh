#!/bin/sh
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh
#
# Licensed under the GPLv2
#
# Copyright 2011, Red Hat, Inc.
# Harald Hoyer <harald@redhat.com>
export TERM=linux
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
. /lib/dracut-lib.sh

# Redirecting output so that it is visible to the user.
exec >/dev/tty
exec 2>&1

# Zero-ing out the first MB first, so that the device is only bootable
# if the dd succeeds.
flash_device () {
    dd bs=1M if=/dev/zero of=$1 count=1 conv=fsync || return 1
    gzip -cd $2 | pv | dd bs=1M of=$1 iflag=fullblock conv=sparse seek=1 skip=1 || return 1
    # when dd exits it causes a broken pipe on gzip's end, so we ignore that err
    gzip -cd $2 2>/dev/null | dd bs=1M of=$1 count=1 iflag=fullblock conv=fsync || return 1

    # Ensures that nothing is written to the disk before shutdown.
    blockdev --setro $1
    return 0
}

printf "Beginning reflashing process.\n"
printf "Searching for device to flash to...\n"

# Since the partition might map to any parent disk, we use udevadm
# to get the path of the /oldroot partition and then use its parent
# directory to find the parent disk.
OLDROOT_PART=$(findmnt -rvnf -o SOURCE /oldroot)
OLDROOT_PATH=$(udevadm info -q path -n ${OLDROOT_PART})
OLDROOT_DEV="/dev/$(basename $(dirname $OLDROOT_PATH))"
if [ ! -z $OLDROOT_DEV ] ; then
    printf "Found root device at ${OLDROOT_DEV}.\n"
else
    printf "Could not find root device. Exiting.\n"
    sleep 5
    exit 1
fi

# Creating mountpoint for USB
if [ ! -d /mnt ]; then
    mkdir /mnt
fi

printf "Searching for USB disk...\n"
BLKS=$(lsblk -nlo Name)
for BLK in ${BLKS}; do
    # Skips the /oldroot device and any device that has /oldroot as a parent.
    [ "/dev/$BLK" != "$OLDROOT_DEV" ] || continue
    BLK_PATH=$(udevadm info -q path -n $BLK)
    [ "/dev/$(basename $(dirname $BLK_PATH))" != "$OLDROOT_DEV" ] || continue

    mount /dev/$BLK /mnt 2>/dev/null || continue
    printf "Mounted /dev/${BLK}.\n" 

    if [ -f /mnt/*.gz ] ; then
	for IMG in /mnt/*.gz ; do
            printf "Found ${IMG} at /dev/${BLK}.\n"
            IMG_PATH=$IMG
            break
        done
        break
    else
        umount /mnt
        printf "Did not find img in /dev/${BLK}.\n"
    fi
done

# Check to see that an image was found.
if [ -z $IMG_PATH ] ; then
    printf "Failed to find image. Exiting.\n"
    sleep 5
    exit 1 
fi

killall_proc_mountpoint /oldroot
# Plymouthd is not killed by killall_proc_mountpoint, preventing /oldroot
# from being umounted properly. So we kill it manually.
pkill -f plymouthd

umount_a() {
    local _did_umount="n"
    while read a mp a; do
        if strstr "$mp" oldroot; then
            if umount "$mp"; then
                _did_umount="y"
                # warn "Unmounted $mp."
            fi
        fi
    done </proc/mounts
    losetup -D
    [ "$_did_umount" = "y" ] && return 0
    return 1
}

_cnt=0
while [ $_cnt -le 40 ]; do
    umount_a 2>/dev/null || break
    _cnt=$(($_cnt+1))
done

[ $_cnt -ge 40 ] && umount_a

if strstr "$(cat /proc/mounts)" "/oldroot"; then
    warn "Cannot umount /oldroot"
    for _pid in /proc/*; do
        _pid=${_pid##/proc/}
        case $_pid in
            *[!0-9]*) continue;;
        esac
        [ -e /proc/$_pid/exe ] || continue
        [ -e /proc/$_pid/root ] || continue
        if strstr "$(ls -l /proc/$_pid /proc/$_pid/fd 2>/dev/null)" "oldroot"; then
            warn "Blocking umount of /oldroot [$_pid] $(cat /proc/$_pid/cmdline)"
        elif [ $_pid -ne $$ ]; then
            warn "Still running [$_pid] $(cat /proc/$_pid/cmdline)"
        fi
        ls -l /proc/$_pid/fd 2>&1 | vwarn
    done
fi

# Checking if /oldroot or any of its children are still mounted.
for dev in ${OLDROOT_DEV}*; do
    if findmnt $dev; then
        printf "NO! ${dev} is already mounted! Exiting."
        sleep 5
        exit 1
    fi
done


if [ -f $IMG_PATH ] ; then
    printf "Flashing ${IMG_PATH} to ${OLDROOT_DEV}. This will take a few minutes...\n"
    dmesg -n info
    if ! flash_device ${OLDROOT_DEV} ${IMG_PATH} ; then
        printf "Flashing failed. Machine must now be flashed from backup USB.\n"
        sleep 5
    fi
else
    printf "Image was not accessible.\n"
    sleep 5
fi

umount /mnt

printf "Flashing is complete!\n"
printf "Powering off. Remove the USB before restarting the computer.\n"
sleep 5
poweroff -f

