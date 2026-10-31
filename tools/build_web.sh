#!/bin/sh
# Assemble the playable web bundle in build/www from original/ assets.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ORIG="$ROOT/original"
OUT="$ROOT/build/www"
# Music is cached per encoder setting, so changing them re-encodes.
MUSIC_OPTS="-af volume=-1dB -c:a libopus -b:a 160k"
MUSIC_CACHE="$ROOT/build/music/opus160-1dB"

mkdir -p "$ROOT/build" "$MUSIC_CACHE"
python3 "$ROOT/tools/build_swf.py" "$ORIG/HexicDeluxe.swf" "$ROOT/build/HexicDeluxe.swf"

rm -rf "$OUT"
mkdir -p "$OUT/game" "$OUT/music" "$OUT/ruffle" "$OUT/fonts"
cp "$ROOT/platforms/desktop/web/index.html" "$ROOT/platforms/desktop/web/host.js" "$OUT/"
cp "$ROOT/build/HexicDeluxe.swf" "$ORIG"/*.xml "$ORIG/convectionui.ttf" "$OUT/game/"
# The menu's D-pad order gains the Leaderboards button (tools/menu_layout.py).
python3 "$ROOT/tools/menu_layout.py" "$ORIG/KeyMap_HXIC.xml" "$OUT/game/KeyMap_HXIC.xml"
cp "$ROOT"/vendor/ruffle/*.js "$ROOT"/vendor/ruffle/*.wasm "$ROOT"/vendor/ruffle/LICENSE_* "$OUT/ruffle/"
cp "$ROOT"/vendor/fonts/* "$OUT/fonts/"
python3 "$ROOT/tools/repair_xbox_font.py" "$ORIG/xarialuni.ttf" "$OUT/fonts/xarialuni.ttf"

found=0
for f in "$ORIG"/*.wma; do
    [ -e "$f" ] || continue
    found=$((found + 1))
    name="$(basename "$f" .wma)"
    cached="$MUSIC_CACHE/$name.ogg"
    if [ ! -f "$cached" ] || [ "$f" -nt "$cached" ]; then
        # Music peaks slightly above full scale; -1 dB keeps it from clipping in the mix.
        # shellcheck disable=SC2086
        ffmpeg -hide_banner -loglevel error -y -i "$f" -vn $MUSIC_OPTS -f ogg "$cached.tmp"
        mv "$cached.tmp" "$cached"
    fi
    cp "$cached" "$OUT/music/"
done
[ "$found" -gt 0 ] || { echo "no .wma soundtrack files found in $ORIG" >&2; exit 1; }
echo "web bundle ready: $OUT"
