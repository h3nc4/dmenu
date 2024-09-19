# dmenu - dynamic menu
# See LICENSE file for copyright and license details.

include config.mk

SRC = drw.c dmenu.c stest.c util.c
OBJ = $(SRC:.c=.o)

all: dmenu stest
	cp dmenu dmenu_path dmenu_run dmenu.1 stest stest.1 build

.c.o:
	$(CC) -c $(CFLAGS) $<

config.h:
	cp config.def.h $@

$(OBJ): arg.h config.h config.mk drw.h

dmenu: dmenu.o drw.o util.o
	$(CC) -o $@ dmenu.o drw.o util.o $(LDFLAGS)

stest: stest.o
	$(CC) -o $@ stest.o $(LDFLAGS)

clean:
	rm -f dmenu stest $(OBJ) dmenu-$(VERSION).tar.gz

dist: clean
	mkdir -p dmenu-$(VERSION)
	cp LICENSE Makefile README arg.h config.def.h config.mk dmenu.1\
		drw.h util.h dmenu_path dmenu_run stest.1 $(SRC)\
		dmenu-$(VERSION)
	tar -cf dmenu-$(VERSION).tar dmenu-$(VERSION)
	gzip dmenu-$(VERSION).tar
	rm -rf dmenu-$(VERSION)

install: all
	install -Dm755 dmenu $(DESTDIR)$(PREFIX)/bin/dmenu
	install -Dm755 dmenu_path $(DESTDIR)$(PREFIX)/bin/dmenu_path
	install -Dm755 dmenu_run $(DESTDIR)$(PREFIX)/bin/dmenu_run
	install -Dm755 stest $(DESTDIR)$(PREFIX)/bin/stest
	install -Dm644 dmenu.1 $(DESTDIR)$(MANPREFIX)/man1/dmenu.1
	sed -i "s/VERSION/$(VERSION)/g" $(DESTDIR)$(MANPREFIX)/man1/dmenu.1
	install -Dm644 stest.1 $(DESTDIR)$(MANPREFIX)/man1/stest.1
	sed -i "s/VERSION/$(VERSION)/g" $(DESTDIR)$(MANPREFIX)/man1/stest.1

uninstall:
	rm -f $(DESTDIR)$(PREFIX)/bin/dmenu\
		$(DESTDIR)$(PREFIX)/bin/dmenu_path\
		$(DESTDIR)$(PREFIX)/bin/dmenu_run\
		$(DESTDIR)$(PREFIX)/bin/stest\
		$(DESTDIR)$(MANPREFIX)/man1/dmenu.1\
		$(DESTDIR)$(MANPREFIX)/man1/stest.1

.PHONY: all clean dist install uninstall
