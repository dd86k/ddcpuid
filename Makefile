DC=dmd
DFLAGS=-betterC
PREFIX=/usr/local

.PHONY: clean install uninstall

ddcpuid: ddcpuid.d
	$(DC) $(DFLAGS) ddcpuid.d

clean:
	rm -fv ddcpuid.o
	rm -fv ddcpuid

install: ddcpuid
	cp ddcpuid $(PREFIX)/bin
	cp ddcpuid.1 $(PREFIX)/share/man/man1

uninstall: 
	rm -fv $(PREFIX)/bin/ddcpuid
	rm -fv $(PREFIX)/share/man/man1/ddcpuid.1

