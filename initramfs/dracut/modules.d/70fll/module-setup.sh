#!/bin/bash

###
# F.U.L.L.S.T.O.R.Y dracut module setup script
#
# Copyright: (C) 2025, Kel Modderman <kelvmod@gmail.com>
# License:   GPLv2
#
# F.U.L.L.S.T.O.R.Y Project Homepage:
# https://github.com/fullstory
###

check() {
    # live environment only
    [[ $hostonly ]] && return 1
    return 255
}

depends() {
    echo base fs-lib initqueue shutdown
}

installkernel() {
    hostonly='' instmods iso9660 erofs loop squashfs overlay \
        ext4 btrfs jfs f2fs xfs ntfs vfat exfat udf \
        of_pmem nd_pmem nfit dm-crypt
}

install() {
    inst_multiple blkid cat chmod cryptsetup dd echo eject env grep \
        ln mkdir mount readlink rmdir sed systemd-detect-virt udevadm umount
    inst_simple /etc/default/distro
    inst_rules "$moddir/99-fll.rules"
    inst_hook initqueue/finished 50 "$moddir/fll-finished.sh"
    inst_hook emergency 50 "$moddir/fll-emergency.sh"
    inst_script "/usr/share/fll-live-initramfs/fll.initramfs" "/sbin/fll"
    inst_hook shutdown 50 "/usr/share/fll-live-initramfs/fll.shutdown"
}
