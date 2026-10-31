#!/bin/sh
# Starts Ruffle through the bundled glibc loader. Ruffle's Linux build needs
# glibc 2.39, newer than many handheld firmwares ship, so it runs with its own
# libraries from libs/; the GPU driver still comes from the device, found on
# the search path after libs/. Settings for testing (all optional):
#   HEXIC_QUALITY   low | medium | high        (default medium)
#   HEXIC_GRAPHICS  gl | vulkan | default      (default gl)
#   HEXIC_SCALE     no-border | show-all       (default no-border: the 16:9
#                   game fills a 4:3 screen, trimming decorative side art;
#                   show-all fits the whole frame with bars top and bottom)
#   HEXIC_WIDTH, HEXIC_HEIGHT   window size    (default 640x480)
# Shell built-ins only for paths: under Westonpack every program gets Crusty
# preloaded, and it prints a banner on stdout ("Crusty loaded by dirname")
# that would end up inside a $(...) result.
GAMEDIR="${0%/*}"
case "$GAMEDIR" in
  /*) ;;
  *) GAMEDIR="$PWD/$GAMEDIR" ;;
esac

export HOME="$GAMEDIR/conf"
export XDG_CONFIG_HOME="$GAMEDIR/conf"
export XDG_DATA_HOME="$GAMEDIR/conf"
export XDG_CACHE_HOME="$GAMEDIR/conf/cache"
export FONTCONFIG_FILE="$GAMEDIR/fonts/fonts.conf"
# The bundled ALSA library reads the firmware's own config; fall back to ours.
if [ ! -f /usr/share/alsa/alsa.conf ]; then
  export ALSA_CONFIG_DIR="$GAMEDIR/libs/alsa" ALSA_CONFIG_PATH="$GAMEDIR/libs/alsa/alsa.conf"
fi
mkdir -p "$HOME" "$XDG_CACHE_HOME" "$GAMEDIR/saves"
# Draw through X11, which Westonwrap's Crusty bridge puts on the screen; its
# Wayland compositor has no renderer, and Ruffle would pick Wayland if offered.
unset WAYLAND_DISPLAY
export DISPLAY="${DISPLAY:-:0}"
echo "run.sh: DISPLAY=$DISPLAY LD_PRELOAD=$LD_PRELOAD LD_LIBRARY_PATH=$LD_LIBRARY_PATH size=${HEXIC_WIDTH}x${HEXIC_HEIGHT}"

exec "$GAMEDIR/hexichd" --library-path "$GAMEDIR/libs${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
  "$GAMEDIR/ruffle" \
  --no-gui --fullscreen \
  --width "${HEXIC_WIDTH:-640}" --height "${HEXIC_HEIGHT:-480}" \
  -g "${HEXIC_GRAPHICS:-gl}" -q "${HEXIC_QUALITY:-medium}" \
  --scale "${HEXIC_SCALE:-no-border}" --force-scale \
  --filesystem-access-mode allow \
  --save-directory "$GAMEDIR/saves" --cache-directory "$GAMEDIR/conf/cache" \
  -PHexicMusic=swf -PHexicHandheld=1 -PGamerTag=Player \
  --base "file://$GAMEDIR/game/" \
  "$GAMEDIR/game/HexicDeluxe.swf"
