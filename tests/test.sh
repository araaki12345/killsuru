#!/bin/sh
# End-to-end test: install into a throw-away HOME, kill a process from an
# interactive shell and check that the art shows up (and only then).
#
#   sh tests/test.sh
#
# Tests every one of bash / zsh / dash that is installed.
set -u

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
T=$(mktemp -d 2>/dev/null || mktemp -d -t killsuru-test)
T=$(CDPATH='' cd -- "$T" && pwd -P)   # macOS: /var is a symlink to /private/var
trap 'rm -rf "$T"' EXIT

MARK="SUSURU_TEST_MARK"
fails=0
ok()   { printf 'ok   - %s\n' "$1"; }
fail() { printf 'FAIL - %s\n' "$1"; fails=$((fails + 1)); }
check() { # check DESC COMMAND...
    desc=$1; shift
    if "$@"; then ok "$desc"; else fail "$desc"; fi
}
has()  { printf '%s' "$1" | grep -qF "$MARK"; }
hasnt() { ! has "$1"; }

export HOME="$T/home with space"
export SHELL=/bin/bash
unset ZDOTDIR XDG_CONFIG_HOME PREFIX DESTDIR KILLSURU_DISABLE KILLSURU_NO_RC 2>/dev/null
mkdir -p "$HOME/.config/killsuru"
printf '%s\n' "$MARK" > "$HOME/.config/killsuru/art.txt"
: > "$HOME/.zshrc"
BIN="$HOME/.local/bin/killsuru"

# --- install -----------------------------------------------------------------
sh "$ROOT/install.sh" >/dev/null || fail "install.sh exits 0"
sh "$ROOT/install.sh" >/dev/null || fail "install.sh is re-runnable"
check "binary installed" test -x "$BIN"
check "bashrc hooked exactly once" test "$(grep -c '>>> killsuru >>>' "$HOME/.bashrc")" = 1
check "zshrc hooked exactly once"  test "$(grep -c '>>> killsuru >>>' "$HOME/.zshrc")" = 1

# --- helper command ----------------------------------------------------------
check "version" test "$("$BIN" version)" = "killsuru $(sed -n 's/^VERSION="\(.*\)"$/\1/p' "$ROOT/bin/killsuru")"
check "user art wins" test "$("$BIN" path)" = "$HOME/.config/killsuru/art.txt"
check "show prints art" has "$("$BIN" show)"
check "KILLSURU_DISABLE silences" hasnt "$(KILLSURU_DISABLE=1 "$BIN" show)"
mkdir -p "$T/link"
ln -s "$BIN" "$T/link/killsuru"
check "init works through a symlink" test "$("$T/link/killsuru" init | sed -n 2p)" = ". '$HOME/.local/share/killsuru/killsuru.sh'"
mv "$HOME/.config/killsuru/art.txt" "$T/art.bak"
check "default art found relative to the binary" \
    cmp -s "$ROOT/share/killsuru/art.txt" "$("$BIN" path)"
mv "$T/art.bak" "$HOME/.config/killsuru/art.txt"

# --- the kill() wrapper in real shells ---------------------------------------
# Give the child a moment before signalling it: an interactive shell ignores
# SIGTERM, and a freshly forked job inherits that until it has exec'd.
KILL_OK='sleep 10 & sleep 1; kill $!'
KILL_BAD='kill 2147483000; echo "rc=$?"'

for sh_name in bash zsh dash; do
    command -v "$sh_name" >/dev/null 2>&1 || { printf 'skip - %s not installed\n' "$sh_name"; continue; }
    case "$sh_name" in
        dash) pre="eval \"\$(\"$BIN\" init)\"; " ;;   # dash has no rc file by default
        *)    pre="" ;;                                # bash / zsh read the hooked rc file
    esac

    out=$("$sh_name" -i -c "$pre$KILL_OK" 2>/dev/null)
    check "$sh_name: art after successful kill" has "$out"

    out=$("$sh_name" -i -c "$pre$KILL_BAD" 2>/dev/null)
    check "$sh_name: no art after failed kill" hasnt "$out"
    check "$sh_name: failed kill keeps non-zero status" \
        sh -c 'printf "%s" "$1" | grep -q "rc=[1-9]"' _ "$out"

    out=$("$sh_name" -i -c "${pre}kill -l" 2>/dev/null)
    check "$sh_name: no art for kill -l" hasnt "$out"

    out=$("$sh_name" -c ". \"$HOME/.local/share/killsuru/killsuru.sh\"; $KILL_OK" 2>/dev/null)
    check "$sh_name: non-interactive shells untouched" hasnt "$out"
done

# --- uninstall ---------------------------------------------------------------
sh "$ROOT/install.sh" uninstall >/dev/null || fail "uninstall exits 0"
check "binary removed" test ! -e "$BIN"
check "share dir removed" test ! -e "$HOME/.local/share/killsuru"
check "bashrc unhooked" sh -c '! grep -q killsuru "$1"' _ "$HOME/.bashrc"
check "zshrc unhooked"  sh -c '! grep -q killsuru "$1"' _ "$HOME/.zshrc"

# --- staged install (packagers) ----------------------------------------------
DESTDIR="$T/stage" PREFIX=/usr/local sh "$ROOT/install.sh" >/dev/null
check "DESTDIR staging" test -x "$T/stage/usr/local/bin/killsuru"
check "DESTDIR leaves rc files alone" sh -c '! grep -q killsuru "$1"' _ "$HOME/.bashrc"

if [ "$fails" -eq 0 ]; then
    echo "All tests passed."
else
    echo "$fails test(s) failed."
    exit 1
fi
