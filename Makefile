# killsuru — convenience Makefile
#
#   make install    install for the current user (PREFIX=$$HOME/.local) and hook rc files
#   make uninstall  remove a `make install` installation
#   make test       end-to-end test in a throw-away HOME (bash / zsh / dash)
#   make check      shell-syntax check the scripts
#   make deb        build the .deb (Debian / Ubuntu; needs dpkg-dev, debhelper)
#   make clean      remove build artifacts
#
# Works with GNU make and BSD make. Packagers:
#   make install PREFIX=/usr/local DESTDIR=/tmp/stage   (rc files are not touched)

PREFIX  ?= $(HOME)/.local
DESTDIR ?=

SCRIPTS = bin/killsuru share/killsuru/killsuru.sh install.sh tests/test.sh \
          debian/profile.d/killsuru.sh debian/postinst debian/postrm

.PHONY: install uninstall test check deb clean

install:
	PREFIX="$(PREFIX)" DESTDIR="$(DESTDIR)" sh install.sh install

uninstall:
	PREFIX="$(PREFIX)" DESTDIR="$(DESTDIR)" sh install.sh uninstall

test:
	sh tests/test.sh

check:
	@set -e; for f in $(SCRIPTS); do \
		echo "sh -n $$f"; sh -n "$$f"; \
		if command -v bash >/dev/null 2>&1; then bash -n "$$f"; fi; \
		if command -v zsh  >/dev/null 2>&1; then zsh  -n "$$f"; fi; \
	done
	@echo "Syntax OK."

deb:
	dpkg-buildpackage -us -uc -b
	@echo "Built .deb is in the parent directory."

clean:
	rm -rf debian/killsuru debian/.debhelper debian/files \
	       debian/debhelper-build-stamp debian/*.substvars debian/*.log
