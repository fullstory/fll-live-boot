DIRS := utils
LINT := $(wildcard initscripts/share/fll-live-initscripts/fll_*) utils/fll_login

all: $(DIRS:%=all-%)
all-%:
	$(MAKE) -C $* all

clean: $(DIRS:%=clean-%)
clean-%:
	$(MAKE) -C $* clean

distclean: clean

test:
	@for f in $(LINT); do \
		echo "checking $$f ..."; \
		dash -n "$$f" || exit 1; \
		checkbashisms -p "$$f" || exit 1; \
	done
