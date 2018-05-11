default:

prove:
	prove --jobs 1 --shuffle --lib --recurse t/

export KERNEL_VERSION=4.16.8
export KERNEL=linux-$(KERNEL_VERSION)
export KERNEL_ARCHIVE=$(KERNEL).tar.xz
export MODULE_TO_TEST=fs/fat
export MODULE=$(KERNEL)/$(MODULE_TO_TEST)

$(KERNEL_ARCHIVE):
	wget https://cdn.kernel.org/pub/linux/kernel/v4.x/$@

prepare_kernel:
	cd $(KERNEL) \
	&& make defconfig \
	&& make modules_prepare

$(KERNEL): $(KERNEL_ARCHIVE)
	tar xf $(KERNEL).tar.xz

kernel: $(KERNEL) prepare_kernel
	PERL5OPT="$(PERL5OPT) -MDevel::Cover" bin/dismember    \
		--full --single --cache=0                           \
		--plugin=testcompile                                \
		--all --kernel $(KERNEL) --module $(MODULE)

test: prove kernel

clean:
	-rm -fr $(KERNEL) $(KERNEL_ARCHIVE) result/

.PHONY: default test prove kernel prepare_kernel
