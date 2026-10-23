#!/bin/sh
#
# SedaiBasic - installs the libraries the prebuilt Linux binaries need at run time.
#
# Shipped at the root of the Linux release archive. It is self-contained on purpose: the archive
# carries no other script, so nothing here may source scripts/lib/.
#
#   sb, sbc, sbd, sbw   need only the C library (glibc 2.34 or newer)
#   sb                  opens its graphics window through SDL2, loaded only when a program asks for
#                       graphics: without SDL2 it still runs and draws off screen
#   sbv                 needs SDL2, SDL2_ttf and libX11 to start at all
#
# The FreeBASIC headers (crt.bi, fbgfx.bi, ...) are not part of SedaiBasic: sb finds them through a
# FreeBASIC installation. This script only checks for one; FreeBASIC is not packaged by most
# distributions, so it says where to get it instead of guessing.
#
# Usage: sh install-deps.sh [-y]      -y = do not ask before running the install command
#
# ⛔ POSIX sh, not bash: Alpine and minimal Void have no bash, and on Alpine the point is to say WHY the
# binaries cannot run there - a script that dies with "bash: not found" says nothing. Only tools every
# base image has are used (no awk: openSUSE Tumbleweed's base image lacks it).

ASSUME_YES=false
for a in "$@"; do
    case "$a" in
        -y|--yes) ASSUME_YES=true ;;
        -h|--help) sed -n '3,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Unknown option: $a (try --help)" >&2; exit 1 ;;
    esac
done

say()  { printf '%s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

# --- the machine ---------------------------------------------------------------------------------
[ "$(uname -s)" = "Linux" ] || die "this script is for Linux (found $(uname -s))"
[ "$(uname -m)" = "x86_64" ] || die "the release binaries are x86_64; this machine is $(uname -m)"

# ⛔ musl (Alpine, Void-musl) cannot load a glibc binary at all: installing SDL2 there would succeed and
# change nothing. Said here, before any package is touched.
if [ -e /lib/ld-musl-x86_64.so.1 ] || { have ldd && ldd --version 2>&1 | grep -qi musl; }; then
    die "this system uses musl libc; the release binaries need glibc 2.34 or newer (build from source instead)"
fi
glibc=""
have ldd && glibc="$(ldd --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+$')"
[ -z "$glibc" ] && have getconf && glibc="$(getconf GNU_LIBC_VERSION 2>/dev/null | grep -oE '[0-9]+\.[0-9]+$')"
if [ -n "$glibc" ]; then
    major="${glibc%%.*}"; minor="${glibc#*.}"
    if [ "$major" -lt 2 ] || { [ "$major" -eq 2 ] && [ "$minor" -lt 34 ]; }; then
        die "glibc $glibc found, the release binaries need 2.34 or newer (Debian 12+, Ubuntu 22.04+, Fedora 35+, RHEL 9+)"
    fi
    say "glibc $glibc: ok"
else
    warn "could not read the glibc version; going ahead"
fi

# --- the package manager -------------------------------------------------------------------------
ID=""; ID_LIKE=""
[ -r /etc/os-release ] && . /etc/os-release

PM=""
for m in apt-get dnf yum zypper pacman xbps-install emerge eopkg; do
    have "$m" && { PM="$m"; break; }
done

PRE=""   # a command that has to run first (a repository to enable, a database to refresh)
case "$PM" in
    apt-get)      PKGS="libsdl2-2.0-0 libsdl2-ttf-2.0-0 libx11-6"
                  PRE="apt-get update"
                  CMD="apt-get install -y $PKGS" ;;
    # SDL's X11 driver LOADS libXext, libXcursor, libXi, libXrandr, libXfixes and libXss at run time, so no
    # package depends on them: a desktop has them anyway, a minimal install does not, and then SDL opens no
    # window (measured: Rocky 9, Fedora 42, openSUSE Leap 15.6 containers). apt, pacman and xbps pull them
    # in through their SDL2 package; these three do not.
    dnf|yum)      PKGS="SDL2 SDL2_ttf libX11 libXext libXcursor libXi libXrandr libXfixes libXScrnSaver"
                  CMD="$PM install -y $PKGS"
                  # RHEL and its rebuilds (Rocky, Alma, Oracle, CentOS Stream) ship SDL2 but not SDL2_ttf:
                  # that one is in EPEL. Fedora has both in its own repositories.
                  case " $ID $ID_LIKE " in
                      *" rhel "*|*" centos "*)
                          [ "$ID" != "fedora" ] && PRE="$PM install -y epel-release" ;;
                  esac ;;
    zypper)       PKGS="libSDL2-2_0-0 libSDL2_ttf-2_0-0 libX11-6 libXext6 libXcursor1 libXi6 libXrandr2 libXfixes3 libXss1"
                  CMD="zypper --non-interactive install $PKGS" ;;
    # -Syu, not -S: Arch does not support installing against a stale package database (a partial
    # upgrade), and a fresh install has no database at all ("target not found").
    pacman)       PKGS="sdl2 sdl2_ttf libx11"
                  CMD="pacman -Syu --needed --noconfirm $PKGS" ;;
    xbps-install) PKGS="SDL2 SDL2_ttf libX11"
                  CMD="xbps-install -Sy $PKGS" ;;
    emerge)       PKGS="media-libs/libsdl2 media-libs/sdl2-ttf x11-libs/libX11"
                  CMD="emerge --noreplace $PKGS" ;;
    eopkg)        PKGS="sdl2 sdl2-ttf libx11"
                  CMD="eopkg install -y $PKGS" ;;
    *)            PKGS=""; CMD=""
                  say ""
                  say "No supported package manager found (apt, dnf, yum, zypper, pacman, xbps, emerge, eopkg)."
                  say "Install these with your system's tools: SDL2 (2.0.x), SDL2_ttf (2.0.x), libX11." ;;
esac

if [ -n "$CMD" ]; then
    SUDO=""
    if [ "$(id -u)" -ne 0 ]; then
        have sudo || die "not root and sudo is missing; run as root: ${PRE:+$PRE && }$CMD"
        SUDO="sudo"
    fi
    FULL="$CMD"; [ -n "$PRE" ] && FULL="$PRE && $CMD"
    say ""
    say "Packages to install: $PKGS"
    say "Command: ${SUDO:+$SUDO }sh -c \"$FULL\""
    if [ "$ASSUME_YES" != "true" ]; then
        printf 'Run it now? [Y/n] '
        read -r ans
        case "$ans" in [nN]*) say "Nothing installed."; exit 0 ;; esac
    fi
    # With -y nobody is there to answer: a package that asks during its configuration (tzdata wants a time
    # zone, and apt pulls it in on a minimal Ubuntu) would wait for ever. Asked interactively, it asks.
    if [ "$ASSUME_YES" = "true" ] && [ "$PM" = "apt-get" ]; then FULL="export DEBIAN_FRONTEND=noninteractive; $FULL"; fi
    $SUDO sh -c "$FULL" || die "the install command failed; install SDL2, SDL2_ttf and libX11 with your package manager"
fi

# --- what is there now ---------------------------------------------------------------------------
# The library cache is read with ldconfig when there is one; a path probe covers the rest.
lib_path() {
    p=""
    have ldconfig && p="$(ldconfig -p 2>/dev/null | grep -m1 "$1 " | sed 's/.*=> //')"
    if [ -z "$p" ]; then
        for d in /usr/lib/x86_64-linux-gnu /usr/lib64 /usr/lib /lib/x86_64-linux-gnu /lib64; do
            [ -e "$d/$1" ] && { p="$d/$1"; break; }
        done
    fi
    printf '%s' "$p"
}

say ""
missing=0
for lib in libSDL2-2.0.so.0 libSDL2_ttf-2.0.so.0 libX11.so.6; do
    if [ -n "$(lib_path "$lib")" ]; then say "  $lib: found"; else say "  $lib: MISSING"; missing=1; fi
done

# sbv is linked against the SDL2 Pascal bindings, which name entry points that older libraries lack:
# SDL2 2.30 and SDL2_ttf 2.22 or newer (Debian 13, Ubuntu 24.04, Fedora 40 and later have them). The
# version is in the file name the soname points to: libSDL2-2.0.so.0.3000.0 is 2.30.0.
lib_minor() {
    f="$(lib_path "$1")"; [ -n "$f" ] || return 1
    f="$(readlink -f "$f")"; n="${f##*.so.0.}"; n="${n%%.*}"
    case "$n" in ''|*[!0-9]*) return 1 ;; esac
    echo $((n / 100))
}
v="$(lib_minor libSDL2-2.0.so.0)" && [ "$v" -lt 30 ] && warn "SDL2 2.$v found: sbv needs 2.30 or newer (sb is not affected)"
v="$(lib_minor libSDL2_ttf-2.0.so.0)" && [ "$v" -lt 22 ] && warn "SDL2_ttf 2.$v found: sbv needs 2.22 or newer (sb is not affected)"

say ""
if have fbc; then
    say "FreeBASIC: $(command -v fbc) - sb will use its headers."
else
    say "FreeBASIC: not found on the PATH."
    say "  Programs that #include FreeBASIC headers (crt.bi, fbgfx.bi, ...) need a FreeBASIC installation:"
    say "  https://www.freebasic.net/  - put fbc on the PATH, or set SEDAI_INCLUDE to its include/freebasic folder."
fi

if [ "$missing" -ne 0 ]; then
    say ""
    warn "some libraries are still missing: sbv will not start, and sb will draw without a window"
    exit 1
fi
say ""
say "Done. Try:  ./sb --help"
