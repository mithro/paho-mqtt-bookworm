#!/bin/sh
# Rebuild Debian's paho-mqtt source package for bookworm.
#
# Run inside a debian:bookworm container. The SOURCE comes from trixie; the
# BUILD-DEPENDENCIES must resolve from bookworm alone. Only a deb-src line is
# added for trixie, never a binary one -- pulling trixie binaries would make
# this a partial upgrade rather than a backport, and would poison the resulting
# package's dependencies.
#
# Why this exists: bookworm ships python3-paho-mqtt 1.6.1, but sensors2mqtt
# requires paho-mqtt >= 2 (it calls mqtt.Client(CallbackAPIVersion.VERSION2,...),
# an API that does not exist in 1.x). Without this, sensors2mqtt simply cannot
# be built or run on bookworm.
set -eux

export DEBIAN_FRONTEND=noninteractive
OUT=${OUT:-/w/built-debs}

# The BINARY package we want. apt resolves this to its source package
# (python-paho-mqtt), so the source name is never hardcoded here -- naming it
# wrongly is exactly what broke the first attempt.
BINARY=python3-paho-mqtt

apt-get update
apt-get install -y --no-install-recommends \
  dpkg-dev devscripts ca-certificates

# Source only. No binary line for trixie.
echo "deb-src http://deb.debian.org/debian trixie main" \
  > /etc/apt/sources.list.d/trixie-src.list
apt-get update

echo "--- source package apt maps ${BINARY} to ---"
apt-cache showsrc "$BINARY" | sed -n 's/^Package: //p' | head -1

cd /tmp
apt-get source "$BINARY"
srcdir=$(find . -maxdepth 1 -type d -name '*paho*' | head -1)
[ -n "$srcdir" ] || { echo "no source directory unpacked"; exit 1; }
cd "$srcdir"

version=$(dpkg-parsechangelog -S Version)
echo "--- upstream version being backported: $version ---"

# Guard against silently backporting the wrong thing: the whole point is >= 2.
case "$version" in
  2.*|[3-9].*) : ;;
  *) echo "refusing to backport $version -- expected 2.x or newer"; exit 1 ;;
esac

# If bookworm cannot satisfy these, the backport is not viable as a plain
# rebuild and the failure should be loud rather than worked around.
apt-get build-dep -y --no-install-recommends ./

# ~bpo12+1 sorts above bookworm's 1.6.1-1 and below trixie's own 2.1.0-1, so a
# host that later moves to trixie upgrades cleanly rather than being pinned here.
dch --local "~bpo12+" --distribution bookworm \
  "Rebuild for bookworm: sensors2mqtt requires paho-mqtt >= 2, which bookworm does not ship."
echo "--- backport version: $(dpkg-parsechangelog -S Version) ---"

dpkg-buildpackage -us -uc -b

mkdir -p "$OUT"
cp ../*.deb "$OUT/"
ls -lh "$OUT"
