default:

prove:
	prove --jobs 1 --shuffle --lib --recurse t/

export KERNEL_VERSION?=6.12.64
export KERNEL=linux-$(KERNEL_VERSION)
export KERNEL_ARCHIVE=$(KERNEL).tar.xz

KM=$(shell echo $(KERNEL) | grep -o '[[:digit:]]*' | head -1)
KMVER=v$(KM).x

export MODULE_TO_TEST?=fs/ramfs
export MODULE=$(KERNEL)/$(MODULE_TO_TEST)

export MODULE_FUNCTIONS?=--all

$(KERNEL_ARCHIVE):
	wget --quiet https://cdn.kernel.org/pub/linux/kernel/$(KMVER)/$@
	touch --date=@0 $@

$(MODULE): $(KERNEL_ARCHIVE)
	tar xf $(KERNEL).tar.xz

prepare_kernel: $(MODULE)
	cd $(KERNEL)      \
	&& make defconfig \
	&& make modules_prepare

kernel: $(MODULE) prepare_kernel
	PERL5OPT="$(PERL5OPT) -MDevel::Cover" bin/extricate \
		--full --single --cache=0                   \
		--plugin=testcompile                        \
		$(MODULE_FUNCTIONS)                         \
		--kernel $(KERNEL) --module $(MODULE)

kernel_no_cover: $(MODULE) prepare_kernel
	bin/extricate                                       \
		--full --single --cache=0                   \
		--plugin=testcompile                        \
		$(MODULE_FUNCTIONS)                         \
		--kernel $(KERNEL) --module $(MODULE)

test: prove kernel

clean:
	-rm -fr $(KERNEL) $(KERNEL_ARCHIVE) result/

.PHONY: default test prove kernel kernel_no_cover prepare_kernel
