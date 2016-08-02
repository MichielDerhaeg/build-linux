#!/bin/sh

if [[ $(id -u) -ne 0 ]]; then
  echo "run as root"
  exit 1
fi

rm -f mdos.img
fallocate -l 100M mdos.img
echo -e "o\nn\n\n\n\n\nw\n" | fdisk mdos.img
loopdevice="$(losetup -P --show -f mdos.img)"
looppart=${loopdevice}p1
mkfs.ext4 $looppart

mkdir -p mountdir
mount $looppart mountdir
cd mountdir
tar --xattrs -xpf ../fs.tar
grub-install --target=i386-pc --boot-directory="$PWD/boot/grub" $loopdevice
cd ..
umount mountdir
sync
rm -rf mountdir
losetup -d $loopdevice
