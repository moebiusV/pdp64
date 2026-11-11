# encopt -- the optimal prefix-encoding search of pdp64.  GNU conventions: all install uninstall clean distclean check dist; DESTDIR and prefix.
# ./configure writes config.mk (prefix, bindir, mandir, CC, CFLAGS); without it the defaults below apply.
PACKAGE = encopt
VERSION = 1.1
-include config.mk
prefix ?= /usr/local
bindir ?= $(prefix)/bin
mandir ?= $(prefix)/share/man
CC ?= cc
CFLAGS ?= -O2
WARN = -std=c99 -Wall -Wextra
INSTALL ?= install
LIBS = -lm

SRCS = main.c encopt.c
HDRS = encopt.h
DISTFILES = AUTHORS COPYING ChangeLog INSTALL Makefile NEWS README configure encopt.1 encopt-tools.1 encopt.5 check.sh export.py corpusfix.py weightsfile.py profile.py leave-one-out.py $(SRCS) $(HDRS) \
	tests/test_random.c tests/test_reader.py tests/current.encopt tests/current.committed tests/current.optimum tests/current.fetch tests/current.exec \
	tests/profile.weights tests/profile.summary tests/small.encopt tests/small.expected tests/small2.encopt tests/small2.static.expected tests/small2.fetch.expected tests/small2.exec.expected \
	tests/corpus/words.s programs/lz4main.c programs/zlibmain.c programs/bearmain.c programs/ecmain.c programs/libc.c programs/make-profile.sh

all: encopt

encopt: $(SRCS) $(HDRS)
	$(CC) $(WARN) $(CFLAGS) -DENCOPT_VERSION='"$(VERSION)"' -o $@ $(SRCS) $(LIBS)

tests/test_random: tests/test_random.c encopt.c $(HDRS)
	$(CC) $(WARN) $(CFLAGS) -o $@ tests/test_random.c encopt.c $(LIBS)

check: encopt tests/test_random
	sh ./check.sh

install: encopt
	$(INSTALL) -d $(DESTDIR)$(bindir) $(DESTDIR)$(mandir)/man1 $(DESTDIR)$(mandir)/man5
	$(INSTALL) -m 755 encopt $(DESTDIR)$(bindir)/encopt
	$(INSTALL) -m 644 encopt.1 $(DESTDIR)$(mandir)/man1/encopt.1
	$(INSTALL) -m 644 encopt-tools.1 $(DESTDIR)$(mandir)/man1/encopt-tools.1
	$(INSTALL) -m 644 encopt.5 $(DESTDIR)$(mandir)/man5/encopt.5

uninstall:
	rm -f $(DESTDIR)$(bindir)/encopt $(DESTDIR)$(mandir)/man1/encopt.1 $(DESTDIR)$(mandir)/man1/encopt-tools.1 $(DESTDIR)$(mandir)/man5/encopt.5

clean:
	rm -f encopt tests/test_random *.o

distclean: clean
	rm -f config.mk $(PACKAGE)-$(VERSION).tar.gz

dist: $(DISTFILES)
	rm -rf $(PACKAGE)-$(VERSION)
	mkdir -p $(PACKAGE)-$(VERSION)/tests/corpus $(PACKAGE)-$(VERSION)/programs
	for f in $(DISTFILES); do cp -p $$f $(PACKAGE)-$(VERSION)/$$f; done
	tar chf - $(PACKAGE)-$(VERSION) | gzip -9 > $(PACKAGE)-$(VERSION).tar.gz
	rm -rf $(PACKAGE)-$(VERSION)

.PHONY: all check install uninstall clean distclean dist
