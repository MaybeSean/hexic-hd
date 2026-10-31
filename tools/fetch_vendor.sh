#!/bin/sh
# Download the third-party tools the build uses into vendor/ (not committed).
# Every download is pinned to an exact version; re-running skips what's there.
#
#   Ruffle 0.7.1 web build (npm)          -> vendor/ruffle               MIT / Apache-2.0
#   JPEXS Free Flash Decompiler 26.3.0    -> vendor/ffdec                GPL-3.0
#   Liberation Sans 2.1.5                 -> vendor/fonts                SIL OFL 1.1
#   Anbernic port only:
#   Ruffle 0.7.1 Linux ARM64 desktop      -> vendor/ruffle-desktop-linux-aarch64
#   PortMaster Westonpack 0.2.7.1         -> vendor/portmaster           MIT
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
V="$ROOT/vendor"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$V"

fetch() { curl -fsSL --retry 3 -o "$2" "$1"; }

if [ ! -f "$V/ruffle/ruffle.js" ]; then
    echo "Ruffle 0.7.1 (web)"
    fetch https://registry.npmjs.org/@ruffle-rs/ruffle/-/ruffle-0.7.1.tgz "$TMP/ruffle.tgz"
    mkdir -p "$V/ruffle"
    tar xzf "$TMP/ruffle.tgz" -C "$V/ruffle" --strip-components=1
fi

if [ ! -f "$V/ffdec/ffdec-cli.jar" ]; then
    echo "JPEXS Free Flash Decompiler 26.3.0"
    fetch https://github.com/jindrapetrik/jpexs-decompiler/releases/download/version26.3.0/ffdec_26.3.0.zip "$TMP/ffdec.zip"
    mkdir -p "$V/ffdec"
    unzip -q -o "$TMP/ffdec.zip" -d "$V/ffdec"
fi

if [ ! -f "$V/fonts/LiberationSans-Regular.ttf" ]; then
    echo "Liberation Sans 2.1.5"
    fetch https://github.com/liberationfonts/liberation-fonts/files/7261482/liberation-fonts-ttf-2.1.5.tar.gz "$TMP/lib.tgz"
    tar xzf "$TMP/lib.tgz" -C "$TMP"
    mkdir -p "$V/fonts"
    cp "$TMP"/liberation-fonts-ttf-2.1.5/LiberationSans-Regular.ttf "$TMP"/liberation-fonts-ttf-2.1.5/LiberationSans-Bold.ttf "$V/fonts/"
    cp "$TMP/liberation-fonts-ttf-2.1.5/LICENSE" "$V/fonts/LICENSE-Liberation"
fi

if [ "$1" = "--anbernic" ]; then
    if [ ! -x "$V/ruffle-desktop-linux-aarch64/ruffle" ]; then
        echo "Ruffle 0.7.1 (Linux ARM64)"
        fetch https://github.com/ruffle-rs/ruffle/releases/download/v0.7.1/ruffle-0.7.1-linux-aarch64.tar.gz "$TMP/ruffle-arm.tgz"
        mkdir -p "$V/ruffle-desktop-linux-aarch64"
        tar xzf "$TMP/ruffle-arm.tgz" -C "$V/ruffle-desktop-linux-aarch64"
    fi
    if [ ! -f "$V/portmaster/weston_pkg_0.2.squashfs" ]; then
        echo "PortMaster Westonpack 0.2.7.1"
        mkdir -p "$V/portmaster"
        fetch https://raw.githubusercontent.com/PortsMaster/PortMaster-New/b0e8206422c0fe79bec9ad266387ee45a861b2eb/runtimes/weston_pkg_0.2.aarch64.squashfs "$V/portmaster/weston_pkg_0.2.squashfs"
    fi
fi
echo "vendor/ ready"
