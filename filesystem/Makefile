FS_FILES=build.sh crypttab filesystem.install fstab group gshadow host.conf hosts inittab issue ld.so.conf locale.sh modprobe.d.usb-load-ehci-first motd nsswitch.conf os-release passwd profile systemctl resolv.conf securetty shadow shells

../fs.tar: build.sh $(FS_FILES)
	fakeroot ./build.sh
