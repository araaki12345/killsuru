# /usr/share/killsuru/killsuru.sh
#
# killsuru — shared shell function for bash & zsh
# (also safe to be sourced by POSIX sh login shells such as dash).
#
# It defines a kill() wrapper that, after a process is successfully
# signalled, prints a SUSURUTV ASCII art via the `killsuru` helper command.
# The real kill is never replaced; we only shadow it with a shell function
# and call the shell builtin from inside.
#
# This file is sourced from:
#   /etc/profile.d/killsuru.sh   (login shells: bash, sh)
#   /etc/bash.bashrc             (interactive non-login bash)
#   /etc/zsh/zshrc               (interactive zsh)

# Hook interactive shells only — never disturb scripts / non-interactive use.
case "$-" in
    *i*) ;;
    *) return 0 2>/dev/null || : ;;
esac

# Invoke the *real* kill in a way that works across shells.
#   bash / zsh : `builtin kill` keeps job-spec support (e.g. %1) intact.
#   dash / sh  : no `builtin` keyword, so fall back to `command kill`.
_killsuru_real() {
    if [ -n "${ZSH_VERSION:-}" ] || [ -n "${BASH_VERSION:-}" ]; then
        builtin kill "$@"
    else
        command kill "$@"
    fi
}

kill() {
    local _rc

    # Pass purely-informational invocations straight through (no art).
    case " $* " in
        *" -l "*|*" -L "*|*" --help "*|*" --version "*)
            _killsuru_real "$@"
            return $?
            ;;
    esac

    _killsuru_real "$@"
    _rc=$?

    # Only susuru on an actual, successful signal.
    if [ "$_rc" -eq 0 ] && command -v killsuru >/dev/null 2>&1; then
        killsuru show
    fi

    return $_rc
}
