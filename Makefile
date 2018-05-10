default:

prove:
	prove --jobs 1 --shuffle --lib --recurse t/

export CURRENT_KERNEL=linux-4.16.7
export MODULE_TO_TEST=fs/ramfs
export CURRENT_SOURCES=$(CURRENT_KERNEL)/$(MODULE_TO_TEST)

$(CURRENT_KERNEL).tar.xz:
	wget https://cdn.kernel.org/pub/linux/kernel/v4.x/$@

prepare_kernel:
	cd $(CURRENT_KERNEL) \
	&& make defconfig \
	&& make modules_prepare

$(CURRENT_KERNEL): $(CURRENT_KERNEL).tar.xz
	tar xf $(CURRENT_KERNEL).tar.xz

kernel: $(CURRENT_KERNEL) prepare_kernel
	PERL5OPT="$(PERL5OPT) -MDevel::Cover" bin/dismember    \
		--full --single --cache=0                           \
		--plugin=exec --plugin-exec-file=scripts/compile.sh \
		--all --kernel $(CURRENT_KERNEL) --module $(CURRENT_SOURCES)

test: prove kernel

clean:
	-rm -fr $(CURRENT_KERNEL) $(CURRENT_KERNEL).tar.xz result/

.PHONY: default test prove kernel prepare_kernel
