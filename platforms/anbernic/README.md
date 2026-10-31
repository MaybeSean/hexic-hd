# Hexic HD for Anbernic handhelds (PortMaster)

Runs the original Xbox 360 Hexic HD Flash game with Ruffle's Linux player,
inside PortMaster's Weston runtime. It targets the RG35XX Plus on Anbernic's
stock OS, and should work on other 64-bit PortMaster devices.

## Install

You need PortMaster installed on the device. Old versions work too: the port
ships its own copy of PortMaster's Weston runtime (`hexichd/runtime/`), so no
download or Wi-Fi is needed. Then do one of these:

- **Copy the files** into the ports folder (`Roms/PORTS` on Anbernic's stock
  OS), and refresh the game list:
  - `Hexic HD.sh`
  - the `hexichd` folder
  - the `Imgs` folder, which holds the box art for the stock OS
  - `gameinfo.xml`, which holds the box art and description for PortMaster
    front-ends
- **Install zip:** copy `hexichd.zip` into PortMaster's `autoinstall` folder
  and open PortMaster.

When copying from a Mac, run `dot_clean` on the SD card afterwards to remove
macOS's hidden `._` files.

## Controls

| Button | Does |
|---|---|
| D-pad / left stick | Move the cursor |
| A | Select / rotate clockwise |
| X | Rotate counter-clockwise |
| B, Select | Back |
| Start | Pause |
| Y | Leaderboards |
| L1 / R1 | Rotate counter-clockwise / clockwise |
| Select + Start | Quit (PortMaster hotkey) |

## Files

- Saves: `hexichd/saves/`
- Log of the last launch: `hexichd/log.txt` (include this when reporting a problem)

## Tuning

To change a setting, edit the default in `hexichd/run.sh`. For example,
`${HEXIC_QUALITY:-medium}` becomes `${HEXIC_QUALITY:-low}`.

- `HEXIC_QUALITY=low|medium|high`: anti-aliasing. The default is `medium`;
  `low` is fastest.
- `HEXIC_SCALE=no-border|show-all`:
  - `no-border` (default): fills the 4:3 screen and trims decorative side art.
  - `show-all`: fits the whole 16:9 frame, with bars above and below.
- `HEXIC_GRAPHICS=gl|vulkan|default`: the rendering API. The default is `gl`
  (OpenGL ES).

While the game runs, the launcher switches the CPU governor to `performance`
and restores it afterwards.

## How it works

Ruffle's Linux build needs glibc 2.39, which is newer than most handheld
firmwares ship. So `hexichd/libs/` carries Ruffle's own copy of glibc and the
other libraries it needs, taken from Ubuntu 24.04 ARM64. `hexichd/hexichd` is
that glibc's loader, renamed so PortMaster's exit hotkey can find the process.
The GPU driver, display and audio hardware still come from the device.

Build it from the repository root with `./tools/fetch_vendor.sh --anbernic`, then `./tools/build_anbernic.sh`. The output goes to `dist/anbernic/`.
