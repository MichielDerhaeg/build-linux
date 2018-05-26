#!/bin/bash

rm -rf root
mkdir root
pkgdir=$PWD/root
srcdir=$PWD
# --- original

cd "$pkgdir"

#
# setup root filesystem
#
for d in boot dev etc home mnt usr var opt srv/http run; do
  install -d -m755 $d
done
install -d -m555 proc
install -d -m555 sys
install -d -m0750 root
install -d -m1777 tmp
# vsftpd won't run with write perms on /srv/ftp
#install -d -m555 -g ftp srv/ftp

# setup /etc
install -d etc/{ld.so.conf.d,skel,profile.d}
for f in fstab group hosts issue passwd profile; do
  install -m644 "$srcdir"/$f etc/
done
ln -s /proc/self/mounts etc/mtab
for f in shadow; do
  install -m600 "$srcdir"/$f etc/
done
#install -m755 "$srcdir"/locale.sh etc/profile.d/locale.sh

# setup /var
for d in cache local opt log/old lib/misc empty; do
  install -d -m755 var/$d
done
install -d -m1777 var/{tmp,spool/mail}

ln -s spool/mail var/mail
ln -s ../run var/run
ln -s ../run/lock var/lock

#
# setup /usr hierarchy
#
for d in bin include lib share/misc src; do
  install -d -m755 usr/$d
done
for d in $(seq 8); do
  install -d -m755 usr/share/man/man$d
done

#
# add lib symlinks
#
ln -s usr/lib "$pkgdir"/lib
[[ $CARCH = 'x86_64' ]] && (
ln -s usr/lib "$pkgdir"/lib64
ln -s lib "$pkgdir"/usr/lib64
)

#
# add bin symlinks
#
ln -s usr/bin "$pkgdir"/bin
ln -s usr/bin "$pkgdir"/sbin
ln -s bin "$pkgdir"/usr/sbin

#
# setup /usr/local hierarchy
#
for d in bin etc games include lib man sbin share src; do
  install -d -m755 usr/local/$d
done
ln -s ../man usr/local/share/man

### --- custom

install -m755 ../../busybox usr/bin/busybox
install -m755 ../../bzImage boot/bzImage
for bin in $(../../busybox --list); do
  ln -s /usr/bin/busybox usr/bin/$bin
done

install -m644 "$srcdir/inittab" etc/inittab
install -d -m755 etc/init.d
install -d -m755 etc/rc.d
install -m755 "$srcdir/rcS" etc/init.d

install -Dm755 "$srcdir/udhcpc.run" etc/init.d/udhcpc/run
ln -s /etc/init.d/udhcpc etc/rc.d
install -Dm755 "$srcdir/syslogd.run" etc/init.d/syslogd/run
ln -s /etc/init.d/syslogd etc/rc.d
install -Dm755 "$srcdir/klogd.run" etc/init.d/klogd/run
ln -s /etc/init.d/klogd etc/rc.d

install -Dm755 "$srcdir/simple.script" usr/share/udhcpc/default.script #script is busybox example
install -Dm644 "$srcdir/be-latin1.bmap" usr/share/keymaps/be-latin1.bmap

echo hostname > etc/hostname

tar --xattrs -cpf ../../fs.tar *
