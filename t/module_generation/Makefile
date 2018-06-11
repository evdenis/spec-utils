KERNEL_RELEASE := $(shell uname -r)
KERNEL_BUILD   := /lib/modules/$(KERNEL_RELEASE)/build
EXTRA_CFLAGS += -w

obj-m := minix.o debugfs.o sysfs.o ramfs.o 9p.o yama.o apparmor.o selinux.o vfat.o fat.o msdos.o isofs.o

all:
	@$(MAKE) -C $(KERNEL_BUILD) M=$(CURDIR) modules

clean:
	@$(MAKE) -C $(KERNEL_BUILD) M=$(CURDIR) clean

.PHONY: all clean 

