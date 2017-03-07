FS_FILES=be-latin1.bmap build.sh crypttab filesystem.install fstab group gshadow host.conf hosts inittab issue klogd.run ld.so.conf locale.sh modprobe.d.usb-load-ehci-first motd nsswitch.conf os-release passwd profile rcS resolv.conf securetty shadow shells simple.script syslogd.run udhcpc.run ../bzImage ../busybox

../fs.tar: build.sh $(FS_FILES)
	fakeroot ./build.sh

