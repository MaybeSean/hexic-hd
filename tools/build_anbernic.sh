#!/bin/sh
# Assemble the PortMaster port in dist/anbernic from original/ assets:
#   dist/anbernic/Hexic HD.sh + hexichd/   (copy both into the device's ports folder)
#   dist/anbernic/hexichd.zip              (the same, as a PortMaster install zip)
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ORIG="$ROOT/original"
SRC="$ROOT/platforms/anbernic"
OUT="$ROOT/dist/anbernic"
PORT="$OUT/hexichd"
RUFFLE="$ROOT/vendor/ruffle-desktop-linux-aarch64"
# PortMaster's Weston runtime (Westonpack), shipped with the port for older
# PortMaster versions that can't download runtimes themselves.
WESTON="$ROOT/vendor/portmaster/weston_pkg_0.2.squashfs"
LIBS_CACHE="$ROOT/build/linux-aarch64-libs"
# Ruffle streams music from MP3 only; cached per encoder setting.
MUSIC_OPTS="-af volume=-1dB -c:a libmp3lame -q:a 4 -ar 44100"
MUSIC_CACHE="$ROOT/build/music/mp3-v4-1dB"

mkdir -p "$ROOT/build" "$MUSIC_CACHE"
[ -x "$RUFFLE/ruffle" ] || { echo "missing $RUFFLE/ruffle (Ruffle 0.7.1 linux-aarch64 release)" >&2; exit 1; }
[ -f "$WESTON" ] || { echo "missing $WESTON (PortsMaster/PortMaster-New runtimes/weston_pkg_0.2.aarch64.squashfs)" >&2; exit 1; }

python3 "$ROOT/tools/build_swf.py" "$ORIG/HexicDeluxe.swf" "$ROOT/build/HexicDeluxe.swf"
[ -f "$LIBS_CACHE/alsa/alsa.conf" ] || python3 "$ROOT/tools/bundle_linux_libs.py" "$LIBS_CACHE"

rm -rf "$OUT"
mkdir -p "$PORT/game/music" "$PORT/libs" "$PORT/fonts" "$PORT/licenses" "$PORT/runtime"
cp "$WESTON" "$PORT/runtime/"
cp "$SRC/Hexic HD.sh" "$SRC/gameinfo.xml" "$OUT/"
cp "$SRC/README.md" "$SRC/hexichd/run.sh" "$SRC/hexichd/hexichd.gptk" "$PORT/"
chmod +x "$OUT/Hexic HD.sh" "$PORT/run.sh"

# Ruffle and its libraries; the glibc loader doubles as the process name
# PortMaster's exit hotkey looks for.
cp "$RUFFLE/ruffle" "$PORT/ruffle"
cp "$LIBS_CACHE"/*.so.* "$PORT/libs/"
cp -R "$LIBS_CACHE/alsa" "$PORT/libs/alsa"
mv "$PORT/libs/ld-linux-aarch64.so.1" "$PORT/hexichd"
chmod +x "$PORT/ruffle" "$PORT/hexichd"
cp "$RUFFLE/LICENSE.md" "$PORT/licenses/LICENSE.ruffle.md"
cp "$LIBS_CACHE/PACKAGES.txt" "$PORT/licenses/ubuntu-packages.txt"
cp "$ROOT/vendor/fonts/LICENSE-Liberation" "$PORT/licenses/"

# The game
cp "$ROOT/build/HexicDeluxe.swf" "$ORIG"/*.xml "$PORT/game/"
# The menu's D-pad order gains the Leaderboards button (tools/menu_layout.py).
python3 "$ROOT/tools/menu_layout.py" "$ORIG/KeyMap_HXIC.xml" "$PORT/game/KeyMap_HXIC.xml"
cp "$SRC/hexichd/fonts/fonts.conf" "$ORIG/convectionui.ttf" "$ROOT"/vendor/fonts/LiberationSans-*.ttf "$PORT/fonts/"
python3 "$ROOT/tools/repair_xbox_font.py" "$ORIG/xarialuni.ttf" "$PORT/fonts/xarialuni.ttf"

found=0
for f in "$ORIG"/*.wma; do
    [ -e "$f" ] || continue
    found=$((found + 1))
    name="$(basename "$f" .wma)"
    cached="$MUSIC_CACHE/$name.mp3"
    if [ ! -f "$cached" ] || [ "$f" -nt "$cached" ]; then
        # shellcheck disable=SC2086
        ffmpeg -hide_banner -loglevel error -y -i "$f" -vn $MUSIC_OPTS -f mp3 "$cached.tmp"
        mv "$cached.tmp" "$cached"
    fi
    cp "$cached" "$PORT/game/music/"
done
[ "$found" -gt 0 ] || { echo "no .wma soundtrack files found in $ORIG" >&2; exit 1; }

# Box art: PortMaster front-ends read hexichd/cover.png via gameinfo.xml;
# Anbernic's stock OS shows Roms/PORTS/Imgs/<launcher name>.png instead.
sips -Z 400 "$ROOT/platforms/desktop/build/icon.png" --out "$PORT/cover.png" >/dev/null
mkdir -p "$OUT/Imgs"
cp "$PORT/cover.png" "$OUT/Imgs/Hexic HD.png"

# No macOS metadata (._ files, .DS_Store) in the package.
find "$OUT" \( -name "._*" -o -name ".DS_Store" \) -delete
(cd "$OUT" && rm -f hexichd.zip && COPYFILE_DISABLE=1 zip -qr -X hexichd.zip "Hexic HD.sh" gameinfo.xml hexichd)
echo "port ready: $OUT ($(du -sh "$OUT/hexichd.zip" | cut -f1) zip)"
