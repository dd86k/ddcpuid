PREFIX=/usr/local
DC=dmd

ifeq ($(DC),dmd)
	DFLAGS=-betterC
	DEBUGFLAGS=-debug
endif

ifeq ($(DC),gdc)
	DEBUGFLAGS=-g
endif

ifeq ($(DC),ldc)
	DEBUGFLAGS=-g
endif

.PHONY: clean install uninstall debug release

default: debug

debug:
	$(MAKE) ddcpuid DFLAGS="$(DFLAGS) $(DEBUGFLAGS)"

release:
	$(MAKE) ddcpuid DFLAGS="$(DFLAGS)"

clean:
	rm -fv ddcpuid.o
	rm -fv ddcpuid

install: ddcpuid
	cp ddcpuid $(PREFIX)/bin
	cp ddcpuid.1 $(PREFIX)/share/man/man1

uninstall: 
	rm -fv $(PREFIX)/bin/ddcpuid
	rm -fv $(PREFIX)/share/man/man1/ddcpuid.1

ddcpuid: ddcpuid.d
	$(DC) $(DFLAGS) ddcpuid.d

