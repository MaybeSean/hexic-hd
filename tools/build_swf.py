#!/usr/bin/env python3
"""Build a desktop-playable HexicDeluxe.swf from the original Xbox 360 one.

1. Re-encode the embedded XMA sounds as PCM (convert_sounds.py).
2. Lay the main menu out like the later title update, with a Leaderboards
   button (menu_layout.py).
3. Import the patched scripts in patches/scripts/ with JPEXS.
4. Compile patches/inject/frame1_host.as and insert it as a new DoAction
   right after the main frame-1 script, so its overrides survive that
   script re-running.

usage: build_swf.py <original.swf> <out.swf>
"""
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from convert_sounds import convert_sounds
from menu_layout import relayout_menu
from swf import DO_ACTION, Swf

ROOT = Path(__file__).resolve().parent.parent
FFDEC = ROOT / "vendor" / "ffdec" / "ffdec-cli.jar"
PATCHED_SCRIPTS = ROOT / "patches" / "scripts"
INJECT_SCRIPT = ROOT / "patches" / "inject" / "frame1_host.as"


def java():
    for candidate in ("/opt/homebrew/opt/openjdk/bin/java", "/usr/local/opt/openjdk/bin/java", "java"):
        # macOS ships a /usr/bin/java stub that only prints an install prompt.
        if shutil.which(candidate) and subprocess.run([candidate, "-version"], capture_output=True).returncode == 0:
            return candidate
    sys.exit("Java is required for JPEXS (brew install openjdk)")


def import_scripts(src, dst, scripts_dir):
    """Import every .as under scripts_dir, failing unless each one replaced a tag.

    JPEXS exits non-zero on a syntax error but silently skips a script whose
    path matches nothing, so the changed tags are counted.
    """
    result = subprocess.run([java(), "-jar", str(FFDEC), "-importScript", str(src), str(dst), str(scripts_dir)],
                            capture_output=True, text=True)
    if result.returncode != 0 or not Path(dst).exists():
        sys.exit(f"JPEXS script import failed:\n{result.stdout}\n{result.stderr}")
    before, after = Swf.load(src).tags, Swf.load(dst).tags
    expected = len(list(Path(scripts_dir).rglob("*.as")))
    changed = sum(1 for a, b in zip(before, after) if a != b)
    if len(before) != len(after) or changed != expected:
        sys.exit(f"JPEXS imported {changed} of {expected} scripts from {scripts_dir}; "
                 "check that each patch path matches a script in the SWF")


def main(src_path, out_path):
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)

        swf = Swf.load(src_path)
        print(f"converted {convert_sounds(swf)} sounds")
        relayout_menu(swf)
        swf.save(tmp / "sounds.swf")

        import_scripts(tmp / "sounds.swf", tmp / "patched.swf", PATCHED_SCRIPTS)

        # Compile the injected script by importing it over frame 1's first
        # DoAction in a scratch copy, then lift that compiled tag out.
        inject_dir = tmp / "inject" / "frame_1"
        inject_dir.mkdir(parents=True)
        shutil.copy(INJECT_SCRIPT, inject_dir / "DoAction.as")
        import_scripts(tmp / "patched.swf", tmp / "compiled.swf", inject_dir.parent)
        compiled = Swf.load(tmp / "compiled.swf")
        injected = compiled.tags[compiled.frame_tag_indexes(1, DO_ACTION)[0]]

        swf = Swf.load(tmp / "patched.swf")
        if injected == swf.tags[swf.frame_tag_indexes(1, DO_ACTION)[0]]:
            sys.exit("the injected script did not compile into frame 1")
        frame1_actions = swf.frame_tag_indexes(1, DO_ACTION)
        if len(frame1_actions) != 2:
            sys.exit(f"expected 2 DoActions in frame 1, found {len(frame1_actions)}")
        swf.tags.insert(frame1_actions[-1] + 1, injected)
        swf.save(out_path)
        print(f"wrote {out_path}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(*sys.argv[1:3])
