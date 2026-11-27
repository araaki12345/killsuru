#!/bin/sh
# killsuru installer — Linux, macOS, *BSD, WSL, Git Bash / MSYS2.
#
#   sh install.sh              install for the current user (no root needed)
#   sh install.sh uninstall    remove it again
#
# Or without cloning:
#   curl -fsSL https://raw.githubusercontent.com/araaki12345/killsuru/main/install.sh | sh
#
# Environment:
#   PREFIX            install prefix               (default: $HOME/.local)
#   DESTDIR           staging root for packagers   (implies KILLSURU_NO_RC=1)
#   KILLSURU_NO_RC=1  do not touch shell rc files
#   KILLSURU_REF      branch / tag to download when not run from a checkout
#                     (default: main)
set -eu

REPO="araaki12345/killsuru"
REF="${KILLSURU_REF:-main}"
PREFIX="${PREFIX:-$HOME/.local}"
DESTDIR="${DESTDIR:-}"
NO_RC="${KILLSURU_NO_RC:-0}"
[ -n "$DESTDIR" ] && NO_RC=1

BEGIN_MARK="# >>> killsuru >>>"
END_MARK="# <<< killsuru <<<"

BIN="$PREFIX/bin/killsuru"
SHARE="$PREFIX/share/killsuru"

say() { printf '%s\n' "$*"; }
die() { printf 'install.sh: %s\n' "$*" >&2; exit 1; }

TMP=""
cleanup() { [ -z "$TMP" ] || rm -rf "$TMP"; }
trap cleanup EXIT
trap 'exit 1' INT TERM

# --- locate the source files (checkout, or download a tarball) --------------

find_source() {
    here=$(CDPATH='' cd -- "$(dirname -- "$0")" 2>/dev/null && pwd) || here=""
    if [ -n "$here" ] && [ -f "$here/bin/killsuru" ] &&
       [ -f "$here/share/killsuru/killsuru.sh" ]; then
        SRC=$here
        return 0
    fi

    command -v tar >/dev/null 2>&1 || die "tar is required"
    TMP=$(mktemp -d 2>/dev/null || mktemp -d -t killsuru)
    url="https://github.com/$REPO/archive/$REF.tar.gz"
    say "Downloading $url"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url" -o "$TMP/src.tar.gz" || die "download failed: $url"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$TMP/src.tar.gz" "$url" || die "download failed: $url"
    else
        die "curl or wget is required"
    fi
    mkdir "$TMP/src"
    tar -xzf "$TMP/src.tar.gz" -C "$TMP/src" || die "could not extract the archive"
    for d in "$TMP"/src/*/; do
        if [ -f "${d}bin/killsuru" ]; then
            SRC=${d%/}
            return 0
        fi
    done
    die "unexpected archive layout (ref: $REF)"
}

# --- rc file handling --------------------------------------------------------

login_shell=$(basename -- "${SHELL:-}")
os=$(uname -s 2>/dev/null || echo unknown)

# Print the rc files that should carry the hook, one per line.
rc_targets() {
    zshrc="${ZDOTDIR:-$HOME}/.zshrc"
    if [ -e "$zshrc" ] || [ "$login_shell" = "zsh" ]; then
        say "$zshrc"
    fi

    if [ -e "$HOME/.bashrc" ] || [ "$login_shell" = "bash" ]; then
        say "$HOME/.bashrc"
    fi

    # macOS terminals (and Git Bash) start bash as a *login* shell, which
    # reads only the first of these and not ~/.bashrc.
    case "$os" in
        Darwin|MINGW*|MSYS*|CYGWIN*)
            for f in .bash_profile .bash_login .profile; do
                if [ -e "$HOME/$f" ]; then
                    say "$HOME/$f"
                    return 0
                fi
            done
            if [ "$login_shell" = "bash" ]; then
                say "$HOME/.bash_profile"
            fi
            ;;
    esac
}

add_block() {
    rc=$1
    if [ -e "$rc" ] && grep -qF "$BEGIN_MARK" "$rc" 2>/dev/null; then
        return 0
    fi
    {
        printf '\n%s\n' "$BEGIN_MARK"
        printf '[ -x "%s" ] && eval "$("%s" init)"\n' "$BIN" "$BIN"
        printf '%s\n' "$END_MARK"
    } >> "$rc"
    say "  hooked  $rc"
}

strip_block() {
    rc=$1
    [ -f "$rc" ] || return 0
    grep -qF "$BEGIN_MARK" "$rc" 2>/dev/null || return 0
    tmp=$(mktemp 2>/dev/null || mktemp -t killsuru)
    # Write back in place (not mv) so symlinked dotfiles and modes survive.
    if sed "/^$BEGIN_MARK\$/,/^$END_MARK\$/d" "$rc" > "$tmp" && cat "$tmp" > "$rc"; then
        say "  unhooked $rc"
    fi
    rm -f "$tmp"
}

# --- commands ----------------------------------------------------------------

do_install() {
    find_source

    mkdir -p "$DESTDIR$PREFIX/bin" "$DESTDIR$SHARE"
    cp "$SRC/bin/killsuru"               "$DESTDIR$BIN"
    cp "$SRC/share/killsuru/killsuru.sh" "$DESTDIR$SHARE/killsuru.sh"
    cp "$SRC/share/killsuru/art.txt"     "$DESTDIR$SHARE/art.txt"
    chmod 0755 "$DESTDIR$BIN"
    chmod 0644 "$DESTDIR$SHARE/killsuru.sh" "$DESTDIR$SHARE/art.txt"
    say "Installed killsuru into $DESTDIR$PREFIX"

    hooked=0
    if [ "$NO_RC" != "1" ]; then
        while IFS= read -r rc; do
            [ -n "$rc" ] || continue
            add_block "$rc"
            hooked=1
        done <<EOF
$(rc_targets)
EOF
    fi

    if [ "$hooked" = "1" ]; then
        say "Open a new shell (or: exec \$SHELL) and try: sleep 100 & kill \$!"
    else
        say "Add this line to your shell rc file (~/.bashrc, ~/.zshrc, ...):"
        say "  eval \"\$(\"$BIN\" init)\""
    fi

    case ":${PATH:-}:" in
        *":$PREFIX/bin:"*) ;;
        *) say "Note: $PREFIX/bin is not in PATH (kill still works; only the bare 'killsuru' command needs it)." ;;
    esac
}

do_uninstall() {
    if [ "$NO_RC" != "1" ]; then
        for rc in "${ZDOTDIR:-$HOME}/.zshrc" "$HOME/.bashrc" \
                  "$HOME/.bash_profile" "$HOME/.bash_login" "$HOME/.profile"; do
            strip_block "$rc"
        done
    fi
    rm -f "$DESTDIR$BIN" "$DESTDIR$SHARE/killsuru.sh" "$DESTDIR$SHARE/art.txt"
    rmdir "$DESTDIR$SHARE" 2>/dev/null || true
    say "Uninstalled killsuru from $DESTDIR$PREFIX"
}

case "${1:-install}" in
    install)   do_install ;;
    uninstall) do_uninstall ;;
    -h|--help|help)
        sed -n '2,/^set -eu$/p' "$0" | sed '$d; s/^# \{0,1\}//'
        ;;
    *) die "unknown command: $1 (use: install | uninstall)" ;;
esac
