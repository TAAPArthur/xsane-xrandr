pkgname := xsane-xrandr
install:
	install -D -m 0755 "xsane-xrandr-autocomplete.sh" "$(DESTDIR)/etc/bash_completion.d/xsane-xrandr-autocomplete"
	install -D -m 0755 "xsane-xrandr.sh" "$(DESTDIR)/usr/bin/$(pkgname)"
test:

.PHONY: install test
