# killsuru — convenience Makefile
#
#   make deb        build the .deb (needs dpkg-dev, debhelper)
#   make install    install straight into the system (no .deb; needs root)
#   make uninstall  remove a `make install` installation
#   make check      shell-syntax check the scripts
#   make clean      remove build artifacts

DESTDIR ?=

.PHONY: deb install uninstall check clean

deb:
	dpkg-buildpackage -us -uc -b
	@echo "Built .deb is in the parent directory."

install:
	install -Dm0755 src/usr/bin/killsuru                $(DESTDIR)/usr/bin/killsuru
	install -Dm0644 src/usr/share/killsuru/killsuru.sh  $(DESTDIR)/usr/share/killsuru/killsuru.sh
	install -Dm0644 src/usr/share/killsuru/art.txt      $(DESTDIR)/usr/share/killsuru/art.txt
	install -Dm0644 src/etc/profile.d/killsuru.sh       $(DESTDIR)/etc/profile.d/killsuru.sh
	@if [ -z "$(DESTDIR)" ]; then \
		sh debian/postinst configure; \
		echo "Installed. Open a new shell (or: source /usr/share/killsuru/killsuru.sh)."; \
	else \
		echo "Staged into $(DESTDIR). Run debian/postinst on the target to wire rc files."; \
	fi

uninstall:
	@if [ -z "$(DESTDIR)" ]; then sh debian/postrm remove || true; fi
	rm -f  $(DESTDIR)/usr/bin/killsuru
	rm -f  $(DESTDIR)/usr/share/killsuru/killsuru.sh
	rm -f  $(DESTDIR)/usr/share/killsuru/art.txt
	rm -f  $(DESTDIR)/etc/profile.d/killsuru.sh
	rmdir  $(DESTDIR)/usr/share/killsuru 2>/dev/null || true
	@echo "Uninstalled."

check:
	@set -e; for f in src/usr/bin/killsuru src/usr/share/killsuru/killsuru.sh \
	                 src/etc/profile.d/killsuru.sh debian/postinst debian/postrm; do \
		echo "sh -n $$f"; sh -n "$$f"; \
		if command -v bash >/dev/null 2>&1; then bash -n "$$f"; fi; \
		if command -v zsh  >/dev/null 2>&1; then zsh  -n "$$f"; fi; \
	done
	@echo "Syntax OK."

clean:
	rm -rf debian/killsuru debian/.debhelper debian/files \
	       debian/debhelper-build-stamp debian/*.substvars debian/*.log
