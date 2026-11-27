# killsuru.sh — kill() wrapper for interactive shells.
#
# Works in bash, zsh and POSIX sh (dash, ash, ksh). OS independent:
# Linux, macOS, *BSD, WSL, Git Bash / MSYS2.
#
# It defines a kill() function that, after a process is successfully
# signalled, prints a SUSURUTV ASCII art via the `killsuru` helper command.
# The real kill is never replaced; we only shadow it with a shell function
# and call the shell builtin from inside.
#
# Load it from your rc file with:
#   eval "$(killsuru init)"
# which sets KILLSURU_BIN (absolute path of the helper) and sources this file.

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
    # Pass purely-informational invocations straight through (no art).
    case " $* " in
        *" -l "*|*" -L "*|*" --help "*|*" --version "*)
            _killsuru_real "$@"
            return $?
            ;;
    esac

    _killsuru_real "$@"
    _killsuru_rc=$?

    # Only susuru on an actual, successful signal.
    if [ "$_killsuru_rc" -eq 0 ] &&
       command -v "${KILLSURU_BIN:-killsuru}" >/dev/null 2>&1; then
        "${KILLSURU_BIN:-killsuru}" show
    fi

    return "$_killsuru_rc"
}
