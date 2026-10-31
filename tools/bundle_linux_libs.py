#!/usr/bin/env python3
"""Collect the shared libraries Ruffle's Linux ARM64 build needs, glibc included.

Ruffle's official aarch64 build is linked on Ubuntu 24.04 (glibc 2.39), and
handheld firmwares ship older or unknown userlands. The port therefore runs
Ruffle through a bundled glibc loader with these libraries next to it. They
are taken from the Ubuntu 24.04 ARM64 archive with their dependencies; the
GPU and display stack (EGL/GLES/DRM/Vulkan) is left out on purpose, because
it has to be the device's own driver.

usage: bundle_linux_libs.py <out_dir>
"""
import io
import lzma
import posixpath
import re
import sys
import tarfile
import urllib.request
from compression import zstd
from pathlib import Path

MIRROR = "http://ports.ubuntu.com/ubuntu-ports"
SUITES = ["noble-updates", "noble"]  # first listed wins
ARCH = "arm64"

# Libraries Ruffle links against or loads at runtime (winit/X11/Wayland, ALSA, fonts, TLS, D-Bus, udev).
SEEDS = [
    "libc6", "libgcc-s1", "libasound2t64", "libssl3t64", "libfontconfig1", "libfreetype6",
    "libdbus-1-3", "libudev1", "libxkbcommon0", "libxkbcommon-x11-0", "libxcb1", "libxcb-xkb1",
    "libwayland-client0", "libwayland-egl1", "libwayland-cursor0", "libx11-6", "libx11-xcb1",
    "libxcursor1", "libxrandr2", "libxi6", "libxrender1", "libxext6", "libxfixes3",
]
# Must come from the device: its GPU driver, display stack and anything that drags them in.
# Runtime names only (libfoo.so.6, ld-linux-aarch64.so.1, libc.so.6), not the unversioned dev links.
SONAME = re.compile(r"\.so\.\d+$")
EXCLUDE = re.compile(r"^(libegl|libgles|libgl1|libglx|libglvnd|libgbm|libdrm|mesa-|libvulkan|libllvm|"
                     r"debconf|perl|dpkg|gcc-.*-base|libc-bin|libcrypt1|tzdata|adduser)")


def fetch(url):
    with urllib.request.urlopen(url, timeout=60) as response:
        return response.read()


def package_index():
    index = {}
    for suite in reversed(SUITES):  # later assignments (earlier suites) win
        text = lzma.decompress(fetch(f"{MIRROR}/dists/{suite}/main/binary-{ARCH}/Packages.xz")).decode()
        for block in text.split("\n\n"):
            fields = dict(re.findall(r"^([A-Za-z-]+): (.*)$", block, re.M))
            if "Package" in fields:
                index[fields["Package"]] = fields
    provides = {}
    for name, fields in index.items():
        for provided in fields.get("Provides", "").split(","):
            provided = provided.strip().split(" ")[0]
            if provided:
                provides.setdefault(provided, name)
    return index, provides


def resolve(index, provides):
    wanted, queue = [], list(SEEDS)
    while queue:
        name = queue.pop(0)
        name = name if name in index else provides.get(name, name)
        if name in wanted or EXCLUDE.match(name):
            continue
        if name not in index:
            sys.exit(f"package {name} not found in the Ubuntu index")
        wanted.append(name)
        for dep in re.split(r",\s*", index[name].get("Depends", "") + "," + index[name].get("Pre-Depends", "")):
            if dep.strip():
                queue.append(dep.split("|")[0].strip().split(" ")[0].split(":")[0])
    return wanted


def deb_data(deb):
    """Return the data tarball of a .deb (an ar archive)."""
    pos = 8
    while pos < len(deb):
        name = deb[pos:pos + 16].decode().strip().rstrip("/")
        size = int(deb[pos + 48:pos + 58].decode().strip())
        body = deb[pos + 60:pos + 60 + size]
        if name.startswith("data.tar"):
            if name.endswith(".zst"):
                body = zstd.decompress(body)
            elif name.endswith(".xz"):
                body = lzma.decompress(body)
            return tarfile.open(fileobj=io.BytesIO(body))
        pos += 60 + size + (size & 1)
    raise ValueError("no data.tar in package")


def main(out_dir):
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    index, provides = package_index()
    packages = resolve(index, provides)
    print(f"bundling {len(packages)} packages: {' '.join(packages)}")
    for name in packages:
        tar = deb_data(fetch(f"{MIRROR}/{index[name]['Filename']}"))
        members = {posixpath.normpath(m.name): m for m in tar.getmembers()}
        libs = {path: m for path, m in members.items()
                if "/lib/" in path and SONAME.search(posixpath.basename(path)) and "/gconv/" not in path}
        link_targets = set()
        for path, member in libs.items():
            if member.issym():
                link_targets.add(posixpath.normpath(posixpath.join(posixpath.dirname(path), member.linkname)))
        for path, member in members.items():
            if "/share/alsa/" in path and member.isfile() and "/ucm" not in path:
                dest = out / "alsa" / path.split("/share/alsa/", 1)[1]
                dest.parent.mkdir(parents=True, exist_ok=True)
                dest.write_bytes(tar.extractfile(member).read())
        for path, member in libs.items():
            # SD cards are FAT/exFAT, so no symlinks: each soname becomes a real
            # file, and fully versioned files that only back a soname are skipped.
            if member.isfile() and path in link_targets:
                continue
            target = member
            while target is not None and target.issym():
                target = members.get(posixpath.normpath(posixpath.join(posixpath.dirname(target.name), target.linkname)))
            if target is None or not target.isfile():
                continue
            (out / posixpath.basename(path)).write_bytes(tar.extractfile(target).read())
    (out / "PACKAGES.txt").write_text("\n".join(f"{n} {index[n]['Version']}" for n in packages) + "\n")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
