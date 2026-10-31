#!/usr/bin/env python3
"""Draw the app icon from the game's own vector art.

A Hexic "flower" — six gems ringed around the silver star piece — on a
purple macOS-style tile with the in-game hex-grid backdrop. The shapes are
exported straight from HexicDeluxe.swf with JPEXS, so the icon stays crisp
at every size; electron-builder derives the .icns/.ico from the PNG.

usage: make_icon.py <HexicDeluxe.swf> <icon.png> [--logo]
--logo adds the HEXIC HD wordmark under the flower.
"""
import re
import subprocess
import sys
import tempfile
from pathlib import Path

from build_swf import FFDEC, java

# Shape ids in HexicDeluxe.swf
GEMS = [608, 602, 603, 609, 607, 611]  # red, orange, green, teal, blue, purple, clockwise from the top
STAR = 743
HEX_GRID = 477
LOGO = 588

GEM_W, GEM_H = 60.65, 52.5  # flat-topped hexes as drawn on the board
GAP = 1.06                  # same breathing room as the board


def export_shapes(swf, ids, out):
    subprocess.run([java(), "-jar", str(FFDEC), "-format", "shape:svg", "-selectid", ",".join(map(str, ids)),
                    "-export", "shape", str(out), str(swf)], check=True, capture_output=True)
    return {i: (out / f"{i}.svg").read_text() for i in ids}


_embedded = 0


def embed(svg, x, y, w, h, fit="meet"):
    """Inline an exported shape as a nested <svg> placed at x,y sized w x h."""
    global _embedded
    _embedded += 1
    # Every export names its gradients gradient0, gradient1, ...; scope them per copy.
    prefix = f"s{_embedded}_"
    body = re.sub(r"<\?xml[^>]*>", "", svg)
    body = re.sub(r'\bid="([^"]+)"', rf'id="{prefix}\1"', body)
    body = re.sub(r"url\(#([^)]+)\)", rf"url(#{prefix}\1)", body)
    body = re.sub(r'href="#([^"]+)"', rf'href="#{prefix}\1"', body)
    width = float(re.search(r'width="([\d.]+)px"', body).group(1))
    height = float(re.search(r'height="([\d.]+)px"', body).group(1))
    body = re.sub(r"<svg\b[^>]*>", f'<svg x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" '
                  f'viewBox="0 0 {width} {height}" preserveAspectRatio="xMidYMid {fit}">', body, count=1)
    return body


def flower(shapes, cx, cy, scale):
    w, h = GEM_W * scale, GEM_H * scale
    ring = [(0, -GEM_H), (0.75 * GEM_W, -GEM_H / 2), (0.75 * GEM_W, GEM_H / 2),
            (0, GEM_H), (-0.75 * GEM_W, GEM_H / 2), (-0.75 * GEM_W, -GEM_H / 2)]
    parts = [embed(shapes[g], cx + dx * GAP * scale - w / 2, cy + dy * GAP * scale - h / 2, w, h)
             for (dx, dy), g in zip(ring, GEMS)]
    sw, sh = 57.15 * scale * 1.18, 50.5 * scale * 1.18
    parts.append(embed(shapes[STAR], cx - sw / 2, cy - sh / 2, sw, sh))
    return "\n".join(parts)


def icon_svg(shapes, logo):
    art = flower(shapes, 512, 440, 2.95) if logo else flower(shapes, 512, 512, 3.55)
    if logo:
        art += embed(shapes[LOGO], 352, 668, 320, 220)
    return f'''<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="1024" height="1024" viewBox="0 0 1024 1024">
<defs>
 <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#4b2a99"/><stop offset="0.55" stop-color="#241060"/><stop offset="1" stop-color="#0f0630"/></linearGradient>
 <radialGradient id="glow" cx="0.5" cy="0.45" r="0.5"><stop offset="0" stop-color="#9b7bff" stop-opacity="0.55"/><stop offset="1" stop-color="#9b7bff" stop-opacity="0"/></radialGradient>
 <linearGradient id="rim" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#d9ccff" stop-opacity="0.7"/><stop offset="1" stop-color="#6a4fd0" stop-opacity="0.25"/></linearGradient>
 <clipPath id="tile"><rect x="100" y="100" width="824" height="824" rx="185"/></clipPath>
 <filter id="shadow" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="12" stdDeviation="14" flood-color="#000" flood-opacity="0.35"/></filter>
 <filter id="gemshadow" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="10" stdDeviation="12" flood-color="#05001a" flood-opacity="0.6"/></filter>
</defs>
<g filter="url(#shadow)"><rect x="100" y="100" width="824" height="824" rx="185" fill="url(#bg)"/></g>
<g clip-path="url(#tile)">
 <g opacity="0.35">{embed(shapes[HEX_GRID], 60, 60, 904, 904, "slice")}</g>
 <rect x="100" y="100" width="824" height="824" fill="url(#glow)"/>
 <g filter="url(#gemshadow)">{art}</g>
</g>
<rect x="104" y="104" width="816" height="816" rx="181" fill="none" stroke="url(#rim)" stroke-width="8"/>
</svg>'''


def main(swf, out_png, logo=False):
    with tempfile.TemporaryDirectory() as tmp:
        shapes = export_shapes(swf, GEMS + [STAR, HEX_GRID, LOGO], Path(tmp))
        svg = Path(tmp) / "icon.svg"
        svg.write_text(icon_svg(shapes, logo))
        subprocess.run(["rsvg-convert", "-w", "1024", "-h", "1024", "-o", str(out_png), str(svg)], check=True)
    print(f"wrote {out_png}")


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if a != "--logo"]
    main(*args[:2], logo="--logo" in sys.argv)
