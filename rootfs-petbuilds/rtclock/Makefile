CFLAGS ?= -O2 -Wall -pedantic
CLANG ?= clang
LLVM_STRIP ?= llvm-strip
LIBS = $(shell pkg-config --libs libbpf)
PREFIX = /usr/local

rtclock: rtclock.c rtclock.skel.h
	$(CC) $(CFLAGS) -o $@ $< $(LIBS)

rtclock.skel.h: rtclock.bpf.o
	bpftool gen skeleton $< > $@

rtclock.bpf.o: rtclock.bpf.c
	$(CLANG) -g -O2 -Wall -target bpf -D__KERNEL__ -c $< -o $@
	$(LLVM_STRIP) -g $@

install: rtclock
	install -D -m 755 $< $(DESTDIR)$(PREFIX)/bin/$<

clean:
	rm -f rtclock rtclock.skel.h rtclock.bpf.o
