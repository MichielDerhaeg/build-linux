KERNEL_VERSION=4.5.3
KERNEL_URL=https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-$(KERNEL_VERSION).tar.xz
BUSYBOX_VERSION=1.24.2
BUSYBOX_URL=https://www.busybox.net/downloads/busybox-$(BUSYBOX_VERSION).tar.bz2

all: bzImage

linux-$(KERNEL_VERSION).tar.xz:
	wget $(KERNEL_URL)

linux-$(KERNEL_VERSION): linux-$(KERNEL_VERSION).tar.xz
	tar -xf linux-$(KERNEL_VERSION).tar.xz

bzImage: linux-$(KERNEL_VERSION) .config
	cp .config linux-$(KERNEL_VERSION)
	$(MAKE) -C linux-$(KERNEL_VERSION)
	cp linux-4.5.3/arch/x86/boot/bzImage .

busybox-$(BUSYBOX_VERSION).tar.bz2:
	wget $(BUSYBOX_URL)

busybox-$(BUSYBOX_VERSION): busybox-$(BUSYBOX_VERSION).tar.bz2
	tar -xf busybox-$(BUSYBOX_VERSION).tar.bz2

busybox: busybox-$(BUSYBOX_VERSION)
	$(MAKE) -C busybox-$(BUSYBOX_VERSION)
	cp busybox-$(BUSYBOX_VERSION)/busybox .
