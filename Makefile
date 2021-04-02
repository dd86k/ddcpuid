PREFIX=/usr/local
DC=dmd

ifneq ($(findstring gdc,$(DC)),gdc)
	RELEASEFLAGS=-O -release -boundscheck=off
endif

ifeq ($(findstring dmd,$(DC)),dmd)
	DFLAGS=-betterC
	DEBUGFLAGS=-debug
endif

ifeq ($(findstring gdc,$(DC)),gdc)
	DEBUGFLAGS=-g -oddcpuid
	RELEASEFLAGS=-O -frelease -fbounds-check=off -oddcpuid
endif

ifeq ($(findstring ldc,$(DC)),ldc)
	DEBUGFLAGS=-g
endif

.PHONY: clean install uninstall debug release

default: debug

debug:
	$(MAKE) ddcpuid DFLAGS="$(DFLAGS) $(DEBUGFLAGS)"

release:
	$(MAKE) ddcpuid DFLAGS="$(DFLAGS) $(RELEASEFLAGS)"

clean:
	rm -fv ddcpuid.o
	rm -fv ddcpuid

install: ddcpuid
	cp ddcpuid $(PREFIX)/bin
	cp manuals/ddcpuid.1 $(PREFIX)/share/man/man1

uninstall: 
	rm -fv $(PREFIX)/bin/ddcpuid
	rm -fv $(PREFIX)/share/man/man1/ddcpuid.1

ddcpuid: src/ddcpuid.d src/main.d
	$(DC) $(DFLAGS) src/ddcpuid.d src/main.d

