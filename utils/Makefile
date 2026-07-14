CFLAGS ?= -O2 -g -Wall
LIBS_UDEV = $(shell pkg-config --libs libudev)
PROGS = fll_blockdev_detect

.PHONY: all clean

all: $(PROGS)

fll_blockdev_cmdline.c: fll_blockdev_detect.ggo
	gengetopt --input=$< --file-name=fll_blockdev_cmdline \
		  --unamed-opts=ARGS

fll_blockdev_cmdline.o: fll_blockdev_cmdline.c
	$(CC) $(CFLAGS) $(CPPFLAGS) -c -o $@ $<

fll_blockdev_detect: fll_blockdev_cmdline.o
	$(CC) $(CFLAGS) $(CPPFLAGS) $(LDFLAGS) $< -o $@ $@.c $(LIBS_UDEV)

clean:
	$(RM) $(PROGS) *_cmdline.*
