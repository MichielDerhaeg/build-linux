#!/bin/bash

if [[ $(id -u) -ne 0 ]]; then
  echo "run as root"
  exit 1
fi

image=image

rm -f $image
fallocate -l 100M $image
echo -e "o\nn\n\n\n\n\nw\n" | fdisk $image
loopdevice="$(losetup -P --show -f $image)"
looppart=${loopdevice}p1
mkfs.ext4 $looppart

mkdir -p mountdir
mount $looppart mountdir
cd mountdir
tar --xattrs -xpf ../fs.tar
grub-install --modules=part_msdos --locales="" --themes="" --target=i386-pc --boot-directory="$PWD/boot" $loopdevice
cd ..

## generate grub.cfg (since linux 3.8 32-bit MBR "NT disk signatures" are allowed)
uuid=$(fdisk -l $image | grep "Disk identifier" | cut -d " " -f 3 | cut --complement -c 1,2)-01
echo -e "linux /boot/bzImage quiet root=PARTUUID=$uuid\nboot" > "mountdir/boot/grub/grub.cfg"

umount mountdir
sync
rm -rf mountdir
losetup -d $loopdevice

if [[ -n $SUDO_UID ]]; then
  chown $SUDO_UID:$SUDO_GID $image
fi
