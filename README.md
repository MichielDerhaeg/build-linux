Build yourself a Linux
======================

Introduction
------------

*This started out as a personal project to build a very small Linux based
operating system that has very few moving parts but is still very complete and
useful. Along the way of figuring out how to get the damn thing to boot and
making it do something useful I learned quite a lot. Too much time has been
spent reading very old and hard to find documentation. Or when there was none,
the source code of how other people were doing it. So I thought, why not share
what I have learned.*

[This git repo](https://github.com/MichielDerhaeg/build-linux) contains a
Makefile and scripts that automate everything that will be explained in this
document. But it doesn't necessarily do everything in the same order as it's
explained. You can also use that as reference if you'd like.

The Linux Kernel
----------------

The kernel is the core component of our operating system. It manages the
processes and talks to the hardware on our behalf. You can retrieve a copy of
the source code easily from [kernel.org](https://www.kernel.org/). There are
multiple versions to choose from, choosing one is usually a tradeoff between
stability and wanting newer features. If you look at the
[Releases](https://www.kernel.org/category/releases.html) tab, you can see how
long each version will be supported and keeps receiving updates. So you can
usually just apply the update or use the updated version without changing
anything else or having something break.

So just pick a version and download the tar.xz file and extract it with ``tar
-xf linux-version.tar.xz``. To build the kernel we obviously need a compiler and
some build tools. Installing ``build-essential`` on Ubuntu (or ``base-devel`` on
Arch Linux) will almost give you everything you need. You'll also need to
install ``bc`` for some reason.

The next step is configuring your build, inside the untarred directory you do
``make defconfig``. This will generate a default config for your current cpu
architecture and put it in ``.config``. You can edit it directly with a text
editor but it's much better to do it with an interface by doing ``make nconfig``
(this needs ``libncurses5-dev`` on Ubuntu) because it also deals with
dependencies of enabled features. Here you can enable/disable features
and device drivers with the spacebar. ``*`` means that it will be compiled in
your kernel image. ``M`` means it will be compiled inside a separate kernel
module. This is a part of the kernel that will be put in a separate file and can
be loaded in or out dynamically in the kernel when they are required. The default
config will do just fine for basic stuff like running in a virtual machine. But
in our case, we don't really want to deal with kernel modules so we'll just do
this: ``sed "s/=m/=y/" -i .config``. And we're done, so we can simply do ``make`` to
build our kernel. Don't forget to add ``-jN`` with `N` the number of cores
because this might take a while. When it's done, it should tell you where your
finished kernel is placed. This is usually ``arch/x86/boot/bzImage`` in the
linux source directory for Intel computers.

Other useful/interesting ways to configure the kernel are:

  * ``make localmodconfig`` will look at the modules that are currently
      loaded in the running kernel and change the config so that only those are
      enabled as module. Useful for when you only want to build the things you
      need without having to figure out what that is. So you can install
      something like Ubuntu on the machine first, copy the config to your build
      machine, usually located in /boot, Arch Linux has it in gzipped at
      /proc/config.gz). Do ``lsmod > /tmp/lsmodfile``, transfer this file to you
      build machine and run ``LSMOD=lsmodfile make localmodconfig`` there
      after you created ``.config``. And you end up with a kernel that is
      perfectly tailored to your machine. But this has a huge disadvantage, your
      kernel only supports what you were using at the time. If you insert a
      usb drive it might not work because you weren't using the kernel module
      for fat32 support at the time.

  * ``make localyesconfig``is the same as above but everything gets compiled in
      the kernel instead as a kernel module.

  * ``make allmodconfig`` generates a new config where all options are enabled
      and as much as possible as module.

  * ``make allyesconfig``is same as above but with everything compiled in the
      kernel.

  * ``make randconfig`` generates a random config...

You can check out ``make help`` for more info.

Busybox Userspace
-----------------

All these tools you know and love like ``ls``, ``echo``, ``cat`` ``mv``, and
``rm`` and so on are commonly referred to as the 'coreutils'. Busybox has that
and a lot more, like utilities from ``util-linux`` so we can do stuff like
``mount`` and even a complete init system. Basically, it contains most tools
you expect to be present on a Linux system, except they are a slightly
simplified version of the regular ones.

You can get the source from [busybox.net](https://busybox.net/). They also
provide prebuilt binaries which will do just fine for most use-cases. But just
to be sure we will build our own version.

Configuring busybox is very similar to configuring the kernel. It also uses a
``.config`` file and you can do ``make defconfig`` to generate one and ``make
menuconfig`` to configure it with a GUI. But we are going to use the one I
provided (which I stole from Arch Linux). You can find the config in the git
repo with the name ``bb-config``. Like the ``defconfig`` version, this has most
utilities enabled but with a few differences like statically linking all
libraries.  Building busybox is again done by simply doing ``make``, but before
we do this, let's look into ``musl`` first.

The C Standard Library
----------------------

The C standard library is more important to the operating system than you might
think. It provides some useful functions and an interface to the kernel. But it
also handles DNS requests and provides a dynamic linker. We don't really have to
pay attention to any of this, we can just statically link the one we are using
right now which is probably 'glibc'. This means the following part is optional.
But I thought this would make it more interesting and it also makes us able to
build smaller binaries.

That's because we are going to use [musl](https://www.musl-libc.org/), which is
a lightweight libc implementation. You can get it by installing ``musl-tools``
on Ubuntu or simply ``musl`` on Arch Linux. Now we can link binaries to musl
instead of glibc by using ``musl-gcc`` instead of ``gcc``.

Before we can build busybox with musl, we need sanitized kernel headers for use
with musl. You get that from [this github
repo](https://github.com/sabotage-linux/kernel-headers). And set
``CONFIG_EXTRA_CFLAGS`` in your busybox config to
``CONFIG_EXTRA_CFLAGS="-I/path/to/kernel-headers/x86_64/include"`` to use them.
Obviously change ``/path/to`` to the location where you put the headers repo,
which can be relative from within the busybox source directory.

If you run ``make CC=musl-gcc`` now, the busybox executable will be
significantly smaller because we are statically linking a much smaller libc.

Be aware that even though there is a libc standard, musl is not always a
drop-in replacement for glibc if the application you're compiling uses glibc
specific things.

Building the Disk Image
-----------------------

Installing an OS on a file instead of a real disk complicates things but this
makes development and testing easier.

So let's start by allocating a new file of size 100M by doing ``fallocate -l100M
image``(some distros don't have ``fallocate`` so you can do ``dd if=/dev/zero
of=image bs=1M count=100`` instead). And then we format it like we would format
a disk with ``fdisk image``. It automatically creates an MBR partition table for
us and we'll create just one partition filling the whole image by pressing 'n' and
afterwards just use the default options for everything and keep spamming 'enter'
until you're done. Finally press 'w' exit and to write the changes to the
image.
```bash
$ fdisk image

Welcome to fdisk (util-linux 2.29.2).
Changes will remain in memory only, until you decide to write them.
Be careful before using the write command.

Device does not contain a recognized partition table.
Created a new DOS disklabel with disk identifier 0x319d111f.

Command (m for help): n
Partition type
   p   primary (0 primary, 0 extended, 4 free)
   e   extended (container for logical partitions)
Select (default p):

Using default response p.
Partition number (1-4, default 1):
First sector (2048-204799, default 2048):
Last sector, +sectors or +size{K,M,G,T,P} (2048-204799, default 204799):

Created a new partition 1 of type 'Linux' and of size 99 MiB.

Command (m for help): w
The partition table has been altered.
Syncing disks.
```

In order to interact with our new partition we'll create a loop device for our
image. Loop devices are block devices (like actual disks) that in our case
point to a file instead of real hardware. For this we need root so sudo up
with ``sudo su`` or however you prefer to gain root privileges and afterwards
run:
```bash
$ losetup -P -f --show image
/dev/loop0
```
The loop device probably ends with a 0 but it could be different in your case.
The ``-P`` makes sure the partition also gets a loop device, ``/dev/loop0p1`` in
my case. Let's make a filesystem on it.
```bash
$ mkfs.ext4 /dev/loop0p1
```
If you want to use something other than ext4, be sure to enable it when
configuring your kernel. Now that we have done that, we can mount it and start
putting everything in place.
```bash
$ mkdir image_root
$ mount /dev/loop0p1 image_root
$ cd image_root # it's assumed you do the following commands from this location
$ mkdir -p usr/{sbin,bin} bin sbin boot
```
And while we're at it, we can create the rest of the file system hierarchy. This
is actually standardized and applications often assume this is the way you're
doing it, but you can often do what you want. You can find more info
[here](http://www.pathname.com/fhs/).
```bash
$ mkdir -p {dev,etc,home,lib}
$ mkdir -p {mnt,opt,proc,srv,sys}
$ mkdir -p var/{lib,lock,log,run,spool}
$ install -d -m 0750 root
$ install -d -m 1777 tmp
$ mkdir -p usr/{include,lib,share,src}
```
We'll copy our binaries over.
```bash
$ cp /path/to/busybox usr/bin/busybox
$ cp /path/to/bzImage boot/bzImage
```
You can call every busybox utility by supplying the utility as an argument, like
so: ``busybox ls --help``. But busybox also detects by what name it is called
and then executes that utility. So you can put symlinks for each utility and
busybox can figure out which utility you want by the symlink's name.

```bash
for util in $(./usr/bin/busybox --list-full); do
  ln -s /usr/bin/busybox $util
done
```
These symlinks might be incorrect from outside the system because of the
absolute path, but they work just fine from within the booted system.

Lastly, we'll copy some files from ``../filesystem`` to the image that will be
of some use to us later.
```bash
$ cp ../filesystem/{passwd,shadow,group,issue,profile,locale.sh,hosts,fstab} etc
$ install -Dm755 ../filesystem/simple.script usr/share/udhcpc/default.script
# optional
$ install -Dm644 ../filesystem/be-latin1.bmap usr/share/keymaps/be-latin1.bmap
```
These are the basic configuration files for a UNIX system. The .script file is
required for running a dhcp client, which we'll get to later. The keymap file is
a binary keymap file I use for belgian azerty.

The Boot Loader
---------------

The next step is to install the bootloader - the program that loads our kernel in
memory and starts it. For this we use GRUB, one of the most widely used
bootloaders. It has a ton of features but we are going to keep it very simple.
Installing it is very simple, we just do this:
```bash
grub-install --modules=part_msdos \ 
             --target=i386-pc \
             --boot-directory="$PWD/boot" \
             /dev/loop0
```
Ubuntu users might need to install ``grub-pc-bin`` first if they are on an EFI
system.

The ``--target=i386-pc`` tells grub to use the simple msdos MBR bootloader. This
is often the default, but this can vary from machine to machine so you better
specify it here. The ``--boot-directory`` options tells grub to install the grub
files in /boot inside the image instead of the /boot of your current system.
``--modules=part_msdos`` is a workaround for a bug in Ubuntu's grub. When you
use ``losetup -P``, grub doesn't detect the root device correctly and doesn't
think it needs to support msdos partition tables and won't be able to find the
root partition.

Now we just have to configure grub and then our system should be able to boot.
This basically means telling grub how to load the kernel. This config is located
at ``boot/grub/grub.cfg`` (some distro's use ``/boot/grub2``). This file needs
to be created first, but before we do that, we need to figure something out
first. If you look at ``/proc/cmdline`` on your own machine you might see
something like this:
```bash
$ cat /proc/cmdline
BOOT_IMAGE=/boot/vmlinuz-4.4.0-71-generic root=UUID=83066fa6-cf94-4de3-9803-ace841e5066c ro
```
These are the arguments passed to your kernel when it's booted. The 'root'
option tells our kernel which device holds the root filesystem that needs to be
mounted at '/'. The kernel needs to know this or it won't be able to boot. There
are different ways of identifying your root filesystem. Using a UUID is a
good way because it is a unique identifier for the filesystem generated when you
do ``mkfs``. The issue with using this is that the kernel doesn't really
support it because it depends on the implementation of the filesystem. This
works on your system because it uses an initramfs, but we can't use it now. We
could do ``root=/dev/sda1``, this will probably work but it has some other problems.
The 'a' in 'sda' depends on the order the bios will load the disk and this
can change when you add a new disk, or for a variety of other reasons.
Or when you use a different type of interface/disk it can be something entirely
different. So we need something more robust. I suggest we use the PARTUUID. It's
a unique id for the partition (and not the filesystem like UUID) and this is a
somewhat recent addition to the kernel for msdos partition tables (it's actually
a GPT thing). We'll find the id like this:
```bash
$ fdisk -l ../image | grep "Disk identifier"
Disk identifier: 0x4f4abda5
```
Then we drop the 0x and append the partition number as two digit hexidecimal. An
MBR only has 4 partitions max so that it's hexidecimal or decimal doesn't really
matter, but that's what the standard says. So the grub.cfg should look like this:
```
linux /boot/bzImage quiet init=/bin/sh root=PARTUUID=4f4abda5-01
boot
```
The ``defconfig`` kernel is actually a debug build so it's very verbose, so to
make it shut up you can add the ``quiet`` option. This stops it from being
printed to the console. You can still read it with the ``dmesg`` utility.

``init`` specifies the first process that will be started when the kernel is
booted. For now we just start a shell, we'll configure a real init while it's
running.

So now we should be able to boot the system. You can umount the image, exit root
and start a VM to test it out. The simplest way of doing this is using QEMU.
The Ubuntu package is ``qemu-kvm``, and just ``qemu`` on Arch Linux.
```bash
$ cd ../
$ umount image_root
$ exit # we shouldn't need root anymore
$ qemu-system-x86_64 -enable-kvm image
```
And if everything went right you should now be dropped in a shell in our
homemade operating system.

**Side note:** When using QEMU, you don't actually need a bootloader. You can
tell QEMU to load the kernel for you.
```bash
$ qemu-system-x86_64 -enable-kvm \
                     -kernel bzImage \
                     -append "quiet init=/bin/sh root=/dev/sda1" \
                     image

```
Where ``bzImage`` points to the kernel you built on your system, not the image.
and ``-append`` specifies the kernel arguments (don't forget the quotes). This
could be useful when you would like to try different kernel parameters without
changing ``grub.cfg`` every time.

PID 1: /sbin/init
---------------

The first process started by the kernel (now ``/bin/sh``) has process id 1. This
is not just a number and has some special implications for this process. The
most important thing to note is that when this process ends, you'll end up with
a kernel panic. PID 1 can never ever die or exit during the entire runtime of
your system. A second and less important consequence of being PID 1 is when
another process 'reparents', e.g. when a process forks to the background, PID 1
will become the parent process.

This implies that PID 1 has a special role to fill in our operating system.
Namely that of starting everything, keeping everything running, and shutting
everything down because it's the first and last process to live.

This also makes this ``init`` process very suitable to start and manage services
as is the case with the very common ``sysvinit`` and the more modern
``systemd``. But this isn't strictly necessary and some other process can carry
the burden of service supervision, which is the case with the
[runit](http://smarden.org/runit/)-like ``init`` that is included with
``busybox``.

Unless you passed the ``rw`` kernel parameter the root filesystem is mounted as
read-only. So before we can make changes to our running system we have to
remount it as read-write first. Before we can do any mounting at all we have
to mount the ``proc`` pseudo filesystem that serves as an interface to kernel.
```bash
$ mount -t proc proc /proc
$ mount / -o remount,rw
```

``busybox`` provides only two ways of editing files: ``vi`` and ``ed``. If you
are not confortable using either of those you could always shutdown the VM,
mount the image again, and use your favorite text editor on your host machine.

If you don't use a qwerty keyboard, you might have noticed that the VM uses a
qwerty layout as this is the default. You might want to change it to azerty with
``loadkmap < /usr/share/keymaps/be-latin1.bmap``. You can dump the layout you
are using on your host machine with ``busybox dumpkmap > keymap.bmap`` in a
virtual console (not in X) and put this on your image instead.

First, we'll create a script that handles the initialisation of the system
itself (like mounting filesystems and configuring devices, etc). You could call it
``startup`` and put it in the ``/etc/init.d`` directory (create this first).
Don't forget to ``chmod +x`` this file when you're done.
```bash
#!/bin/sh
# /etc/init.d/startup

# mount the special pseudo filesytems /proc and /sys
mount -t proc proc /proc -o nosuid,noexec,nodev
mount -t sysfs sys /sys -o nosuid,noexec,nodev
# /dev isn't required if we boot without initramfs because the kernel
# will have done this for us but it doesn't hurt
mount -t devtmpfs dev /dev -o mode=0755,nosuid
mkdir -p /dev/pts /dev/shm
# /dev/pts contains pseudo-terminals, gid 5 should be the
# tty user group
mount -t devpts devpts /dev/pts -o mode=0620,gid=5,nosuid,noexec
# /run contains runtime files like pid files and domain sockets
# they don't need to be stored on the disk, we'll store them in RAM
mount -t tmpfs run /run -o mode=0755,nosuid,nodev
mount -t tmpfs shm /dev/shm -o mode=1777,nosuid,nodev
# the nosuid,noexec,nodev options are for security reasons and are not
# strictly necessary, you can read about them in the 'mount'
# man page

# the kernel does not read /etc/hostname on it's own
# you need to write it in /proc/sys/kernel/hostname to set it
# don't forget to create this file if you want to give your system a name
if [[ -f /etc/hostname ]]; then
  cat /etc/hostname > /proc/sys/kernel/hostname
fi

# mdev is a mini-udev implementation that
# populates /dev with devices by scanning /sys
# see the util-linux/mdev.c file in the busybox source
# for more information
mdev -s
echo /sbin/mdev > /proc/sys/kernel/hotplug

# the "localhost" loopback network interface is
# down at boot, we have to set it 'up' or we won't be able to
# make local network connections
ip link set up dev lo

# you could add the following to change the keyboard layout at boot
loadkmap < /usr/share/keymaps/be-latin1.bmap

# mounts all filesystems in /etc/fstab
mount -a
# make the root writable if this hasn't been done already
mount -o remount,rw /
# end of /etc/init.d/startup
```

The next file is the init configuration ``/etc/inittab``. The syntax of this
file is very similar to that of ``sysvinit``'s ``inittab`` but has several
differences. For more information you can look at the ``examples/inittab`` file
in the busybox source.
```inittab
# /etc/inittab
::sysinit:/bin/echo STARTING SYSTEM
::sysinit:/etc/init.d/startup
tty1::respawn:/sbin/getty 38400 tty1
tty2::respawn:/sbin/getty 38400 tty2
tty3::respawn:/sbin/getty 38400 tty3
::ctrlaltdel:/bin/umount -a -r
::shutdown:/bin/echo SHUTTING DOWN
::shutdown:/bin/umount -a -r
# end of /etc/inittab
```
The ``sysinit`` entry is the first command ``init`` will execute. We'll put our
``startup`` script here. You can specify multiple entries of this kind and they
will be executed sequentially. The same goes for the ``shutdown`` entry, which
will obviously be executed at shutdown. The ``respawn`` entries will be executed
after ``sysinit`` and will be restarted when they exit. We'll put some
``getty``'s on the specified tty's. These will ask for your username and execute
``/bin/login`` which will ask for your password and starts a shell for you when
it's correct. If you don't care for user login and passwords, you could instead
of the ``getty``'s do ``::askfirst:-/bin/sh``. ``askfirst`` does the same as
``respawn`` but asks you to press enter first. If no tty is specified it will
figure out what the console is. The ``-`` infront of ``-/bin/sh`` means that
the shell is started as a login shell. ``/bin/login`` usually does this for us
but we have to specify it here. Starting the shell as a login shell means that
it configures certain things it otherwise assumes already to be configured. E.g.
it sources ``/etc/profile``.

We can now start our system with ``init``. You can remove the ``init=/bin/sh``
entry in ``/boot/grub/grub.cfg`` because it defaults to ``/sbin/init``. If
you reboot the system you should see a login screen. But if you run ``reboot``,
you'll notice it won't do anything. This happens because normally ``reboot``
tells the running ``init`` to reboot. You know - the ``init`` that isn't running
right now. So we have two options, we could run ``reboot -f`` which skips the
``init``, or we could do this:
```bash
$ exec init
```
Because the shell we are currently using is PID 1 and you could just replace the
shell process with ``init`` and our system should be properly booted now
presenting you a login prompt.

The root password should be empty so it should only ask for a username.

Service Supervision
-------------------

In the last part of our OS building adventure we'll look into setting up some
services. An important thing to note is that we are using
[runit](http://smarden.org/runit/) for service supervision, which is quite different
from how the more common ``sysvinit`` does things but it'll give you a
feel for which problems it's supposed to solve and how.

A basic service consists of a directory containing a ``run`` executable, usually
a script. This ``run`` script usually starts the daemon and doesn't exit until
the daemon does. If ``run`` exits ``runit`` will think the service itself has
stopped and if it wasn't supposed to stop, ``runit`` will try to restart it. So
be careful with forking daemons. Starting the service is done with ``runsv``.
This is the process that actually monitors the service and restarts it if
necessary. Usually you won't run it manually but doing so is useful for testing
services.

The first service we are going to create is a logging service that collects
messages from other processes and stores them in files.

```bash
$ mkdir -p /etc/init.d/syslogd
$ vi /etc/init.d/syslogd/run
$ cat /etc/init.d/syslog/run
#!/bin/sh
exec syslogd -n
$ chmod +x /etc/init.d/syslog/run
$ runsv /etc/init.d/syslogd & # asynchronous
$ sv status /etc/init.d/syslogd
run: /etc/init.d/syslogd: (pid 991) 1170s
```
It's that simple, but we have to make sure ``syslogd`` doesn't fork or else
``runsv`` will keep trying to start it even though it is already running. That's
what the ``-n`` option is for. The ``sv`` command can be used to control the
service.

To make sure that our new service is started at boot we could create a new
``inittab`` entry for it but this isn't very flexible. A better solution is to
use ``runsvdir``. This runs ``runsv`` for every service in a directory. So
running ``runsvdir /etc/init.d`` would do the trick but this way we can't
disable services at boot. To solve this issue we'll create a separate directory
and symlink the enabled services in there.
```bash
$ mkdir -p /etc/rc.d
$ ln -s /etc/init.d/syslogd /etc/rc.d
$ runsvdir /etc/rc.d & # asynchronous
```
If we add ``::respawn:/usr/bin/runsvdir /etc/rc.d`` to ``/etc/inittab`` all the
services symlinked in ``/etc/rc.d`` will be started at boot. Enabling and
disabling a service now consists of creating and removing a symlink in ``/etc/rc.d``.
Note that ``runsvdir`` monitors this directory and starts the service when the
symlink appears and not just at boot.

### Syslog

``syslogd`` implements the well known ``syslog`` protocol for logging. This
means that it creates a UNIX domain socket at ``/dev/log`` for daemons to
connect and send their logs to. Usually it puts all of the collected logs in
``/var/log/messages`` unless told otherwise. You can specify filters in
``/etc/syslog.conf`` to put certain logs in different files.
```bash
$ vi /etc/syslog.conf
$ cat /etc/syslog.conf
kern.* /var/log/kernel.log
$ sv down /etc/init.d/syslogd # restart
$ sv up /etc/init.d/syslogd
```
This will put everything the kernel has to say in a separate log file
``/var/log/kernel.log``. But ``syslogd`` doesn't read the kernel logs like
``rsyslog`` does. We need a different service for that.
```bash
$ mkdir -p /etc/init.d/klogd
$ vi /etc/init.d/klogd/run
$ cat /etc/init.d/klogd/run
#!/bin/sh
sv up /etc/init.d/syslogd || exit 1
exec klogd -n
$ chmod +x /etc/init.d/klogd/run
$ ln -s /etc/init.d/klogd /etc/rc.d
```
Now we should see kernel logs appearing in ``/var/log/kernel.log``.
The ``sv up /etc/init.d/syslogd || exit 1`` line makes sure ``syslogd`` is
started before ``klogd``. This is how we add dependencies in ``runit``. If
``syslogd`` hasn't been started yet ``sv`` will fail and ``run`` will exit.
``runsv`` will attempt to restart ``klogd`` after a while and will only
succeed when ``syslogd`` has been started. Believe it or not, this is what the
runit documentation says about making dependencies.

### DHCP

The very last thing we will do is provide our system with a network connection.
```bash
$ mkdir -p /etc/init.d/udhcpc
$ vi /etc/init.d/udhcpc/run
$ cat /etc/init.d/udhcpc/run
#!/bin/sh
exec udhcpc -f -S
$ chmod +x /etc/init.d/udhcpc/run
$ ln -s /etc/init.d/udhcpc /etc/rc.d
```
Now we're done. Yes - it's that simple. Note that udhcpc just asks for a lease
from the DHCP server and that's it. When it has a lease it executes
``/usr/share/udhcpc/default.script`` to configure the system. We already copied
this script to this location. This script is included with the busybox source.
These scripts usually use ``ip``, ``route``, and write to ``/etc/resolv.conf``.
If you would like a static ip, you'll have to write a script that does these
things.

Epilogue
--------

That's it! We're done for now. Thanks for reading. I hope you learned something
useful. I certainly did while making this.
