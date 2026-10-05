LINT := $(wildcard initscripts/share/fll-live-initscripts/fll_*) utils/fll_login \
	initramfs/fll.initramfs initramfs/fll.shutdown \
	initramfs/dracut/modules.d/70fll/fll-finished.sh \
	initramfs/dracut/modules.d/70fll/fll-emergency.sh

all:

test:
	@for f in $(LINT); do \
		echo "checking $$f ..."; \
		dash -n "$$f" || exit 1; \
		checkbashisms -p "$$f" || exit 1; \
	done
