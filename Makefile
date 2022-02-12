pkgname := xsane-xrandr

all:

install:
	install -D -m 0755 "xsane-xrandr-autocomplete.sh" "$(DESTDIR)/etc/bash_completion.d/xsane-xrandr-autocomplete"
	install -D -m 0755 "xsane-xrandr.sh" "$(DESTDIR)/usr/bin/$(pkgname)"
	install -m 0744 -Dt "$(DESTDIR)/usr/share/man/man1/" xsane-xrandr.1
test:
	./fake-display.sh ./tests.sh

.PHONY: install test
