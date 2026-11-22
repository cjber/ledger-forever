#!/usr/bin/env python3
"""Render Ledger's book opened through /ledger with a representative character."""

import argparse
import os
import subprocess
import sys
from pathlib import Path

from PIL import ImageDraw

ROOT = Path(__file__).resolve().parents[1]
CORE = Path(os.environ.get("FOREVER_CORE", ROOT.parent / "forever-core")).resolve()
sys.path.insert(0, str(CORE / "tools" / "wowmock"))

import wowmock  # ty: ignore[import-not-found]

FONTS = {
    **wowmock.FONTS,
    "GameFontNormalHuge": wowmock.Font(wowmock.FRIZQT, 20, wowmock.NORMAL, (1, -1)),
}


def capture(source, width, constrain, empty):
    command = [
        "luajit",
        str(ROOT / "tools/book_scene.lua"),
        str(width),
        "constrain" if constrain else "native",
        "empty" if empty else "active",
    ]
    result = subprocess.run(
        command,
        cwd=source,
        env={**os.environ, "FOREVER_CORE": str(CORE)},
        capture_output=True,
        text=True,
        stdin=subprocess.DEVNULL,
        check=False,
    )
    if result.returncode:
        sys.exit(result.stderr + result.stdout)
    return [line.split("\t")[1:] for line in result.stdout.splitlines() if line.startswith("BOOK\t")]


def book(ui, widgets, label=None):
    """Draw the captured addon widgets within the pinned native frame and content insets."""
    _, width, height, title, portrait = widgets[0]
    width, height = int(width), int(height)
    margin_x, margin_y = 24, 32
    canvas = wowmock.backdrop(ui, width + margin_x * 2, height + margin_y * 2)
    x0, y0 = margin_x, margin_y
    rock = ui.texture("interface/framegeneral/ui-background-rock.blp")
    wowmock.tiled(canvas, rock, x0 + 2, y0 + 21, width - 4, height - 23, rock.width, rock.height)
    marble = ui.texture("interface/framegeneral/ui-background-marble.blp")
    for kind, left, top, w, h, *fields in widgets[1:]:
        x, y, w, h = (float(number) for number in (left, top, w, h))
        x += x0
        y += y0
        if kind == "inset":
            wowmock.tiled(canvas, marble, x, y, w, h, marble.width, marble.height)
            canvas.nine_slice(wowmock.INSET_FRAME_LAYOUT, x, y, w, h)
        elif kind == "text":
            font_name, justify, r, g, b, text = fields
            font = FONTS[font_name]
            # Some inherited font colours have no explicit value in the simulator.
            color = tuple(map(float, (r, g, b)))
            color = None if color == (1, 1, 1) else color
            canvas.text(x, y, text, font, color=color, width=w, justify="RIGHT" if justify == "RIGHT" else "LEFT")
        elif kind == "atlas":
            atlas, alpha = fields
            art = ui.atlas(atlas)
            # The capture supplies anchored boxes at the simulator build's native aspect.
            scale = min(w / art.width, h / art.height)
            dw, dh = art.width * scale, art.height * scale
            canvas.draw(art, x + (w - dw) / 2, y + (h - dh) / 2, dw, dh, color=(1, 1, 1, float(alpha)))
        elif kind == "track":
            canvas.draw(ui.atlas(fields[0]), x, y, w, h)
        elif kind == "bar":
            atlas, *state = fields
            value, *color = map(float, state)
            if value > 0:
                canvas.draw(ui.atlas(atlas), x, y, w * value, h, color=tuple(color))
        elif kind == "button":
            wowmock.three_slice_button(canvas, x, y, w, h, fields[0])
    portrait_path = portrait.lower().replace("\\", "/") + ".blp"
    wowmock.portrait_frame_art(canvas, x0, y0, width, height, portrait_path, title)
    if label:
        mark_changes(canvas, label, x0, y0, width)
    return canvas.image


def mark_changes(canvas, label, x0, y0, width):
    canvas.text(x0 + 85, 6, label, FONTS["GameFontHighlight"])
    draw = ImageDraw.Draw(canvas.image)
    color = (103, 224, 243)
    left_inset_width = 270 if label == "Before mock" else 270 - (780 - width) / 2
    right_x = 28 + left_inset_width
    for left, top, right, bottom in [
        (25, 104, 26 + left_inset_width - 16, 292),
        (right_x + 5, 75, width - 23, 197),
        (right_x + 5, 212, width - 23, 474),
        (25, 486, width - 23, 544),
    ]:
        bounds = tuple(canvas.px(n) for n in (x0 + left, y0 + top, x0 + right, y0 + bottom))
        draw.rectangle(bounds, outline=color, width=canvas.px(1))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    parser.add_argument("--source", type=Path, default=ROOT)
    parser.add_argument("--width", type=int, choices=(680, 780), default=780)
    parser.add_argument("--label", choices=("Before mock", "After mock"))
    parser.add_argument("--empty", action="store_true", help="show the empty daily progress bar")
    args = parser.parse_args()
    scene = capture(args.source, args.width, args.label == "Before mock", args.empty)
    book(wowmock.Ui(), scene, args.label).save(args.output)
