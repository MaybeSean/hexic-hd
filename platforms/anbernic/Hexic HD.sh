#!/bin/bash
# PortMaster launcher for Hexic HD (Ruffle + the original Xbox 360 Flash game).
# Runs Ruffle's Linux player inside PortMaster's Weston runtime (Weston +
# Xwayland with OpenGL ES), the same setup PortMaster uses for Godot ports.

XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}

if [ -d "/opt/system/Tools/PortMaster/" ]; then
  controlfolder="/opt/system/Tools/PortMaster"
elif [ -d "/opt/tools/PortMaster/" ]; then
  controlfolder="/opt/tools/PortMaster"
elif [ -d "$XDG_DATA_HOME/PortMaster/" ]; then
  controlfolder="$XDG_DATA_HOME/PortMaster"
else
  controlfolder="/roms/ports/PortMaster"
fi

source $controlfolder/control.txt
[ -f "${controlfolder}/mod_${CFW_NAME}.txt" ] && source "${controlfolder}/mod_${CFW_NAME}.txt"
get_controls

# Older PortMaster releases (as shipped with some stock firmwares) lack these helpers.
type pm_message >/dev/null 2>&1 || pm_message() { echo "$*"; }
type pm_finish >/dev/null 2>&1 || pm_finish() { :; }
type pm_platform_helper >/dev/null 2>&1 || pm_platform_helper() { :; }

# The port folder sits next to this script, wherever the firmware keeps ports
# (e.g. /mnt/mmc/Roms/PORTS on Anbernic's stock OS).
GAMEDIR="$(cd "$(dirname "$0")" && pwd)/hexichd"
[ -d "$GAMEDIR" ] || GAMEDIR="/$directory/ports/hexichd"
weston_runtime="weston_pkg_0.2"
weston_dir=/tmp/weston

# Older PortMaster versions don't report the screen size. The framebuffer's
# first listed mode can be an HDMI one (1280x1024 on the RG35XX Plus), so use
# its virtual size instead, halving a double-buffered height ("640,960");
# fall back to the RG35XX Plus's 640x480.
if [ -z "$DISPLAY_WIDTH" ] || [ -z "$DISPLAY_HEIGHT" ]; then
  fb_size="$(cat /sys/class/graphics/fb0/virtual_size 2>/dev/null)"
  DISPLAY_WIDTH="${fb_size%%,*}"
  DISPLAY_HEIGHT="${fb_size##*,}"
  case "$DISPLAY_WIDTH$DISPLAY_HEIGHT" in
    ''|*[!0-9]*) DISPLAY_WIDTH=640; DISPLAY_HEIGHT=480 ;;
    *) [ "$DISPLAY_HEIGHT" -gt "$DISPLAY_WIDTH" ] && DISPLAY_HEIGHT=$((DISPLAY_HEIGHT / 2)) ;;
  esac
fi
export DISPLAY_WIDTH DISPLAY_HEIGHT

cd "$GAMEDIR"
> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1
echo "Hexic HD: CFW=$CFW_NAME device=$DEVICE_NAME arch=$DEVICE_ARCH display=${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}"
echo "port folder: $GAMEDIR, PortMaster: $controlfolder"

if [ ! -f "$GAMEDIR/game/HexicDeluxe.swf" ]; then
  pm_message "Missing game files in $GAMEDIR/game. Reinstall the port."
  sleep 5
  pm_finish
  exit 1
fi

# Weston runtime: PortMaster's copy if it has one, otherwise the one shipped
# with the port, so older PortMaster versions that can't download runtimes work.
weston_squashfs="$controlfolder/libs/${weston_runtime}.squashfs"
if [ ! -f "$weston_squashfs" ] && [ -f "$controlfolder/harbourmaster" ]; then
  $ESUDO $controlfolder/harbourmaster --quiet --no-check runtime_check "${weston_runtime}.squashfs"
fi
[ -f "$weston_squashfs" ] || weston_squashfs="$GAMEDIR/runtime/${weston_runtime}.squashfs"
if [ ! -f "$weston_squashfs" ]; then
  pm_message "Missing the Weston runtime ($weston_runtime). Reinstall the port or update PortMaster."
  sleep 5
  pm_finish
  exit 1
fi
echo "weston runtime: $weston_squashfs"

$ESUDO mkdir -p "$weston_dir"
if [[ "$PM_CAN_MOUNT" != "N" ]]; then
  $ESUDO umount "$weston_dir" 2>/dev/null
fi
if ! $ESUDO mount "$weston_squashfs" "$weston_dir" || [ ! -x "$weston_dir/westonwrap.sh" ]; then
  pm_message "Could not mount the Weston runtime. See ports/hexichd/log.txt."
  sleep 5
  pm_finish
  exit 1
fi

# Run the CPU flat out while playing (the stock OS idles it on "ondemand"/
# "schedutil"); restored on exit. Newer PortMaster does this itself.
cpu_governor=/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
previous_governor="$(cat "$cpu_governor" 2>/dev/null)"
if [ -n "$previous_governor" ] && grep -qw performance /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors 2>/dev/null; then
  echo performance | $ESUDO tee "$cpu_governor" >/dev/null && echo "cpu governor: $previous_governor -> performance"
fi

# The device's buttons become the keyboard keys the game was written for
# (see hexichd.gptk). "hexichd" is the bundled loader's process name, which
# the PortMaster exit hotkey (Select + Start) closes.
$GPTOKEYB "hexichd" -c "$GAMEDIR/hexichd.gptk" &
pm_platform_helper "$GAMEDIR/hexichd"

# Westonwrap sets DISPLAY, LD_PRELOAD (Crusty, its X11/EGL-to-screen bridge)
# and LD_LIBRARY_PATH for the game itself; don't override them here.
$ESUDO env $weston_dir/westonwrap.sh headless noop kiosk crusty_x11egl \
  HEXIC_WIDTH="${DISPLAY_WIDTH:-640}" HEXIC_HEIGHT="${DISPLAY_HEIGHT:-480}" \
  "$GAMEDIR/run.sh"
echo "game exited with status $?"

[ -n "$previous_governor" ] && echo "$previous_governor" | $ESUDO tee "$cpu_governor" >/dev/null
$ESUDO $weston_dir/westonwrap.sh cleanup
if [[ "$PM_CAN_MOUNT" != "N" ]]; then
  $ESUDO umount "$weston_dir"
fi
pm_finish
