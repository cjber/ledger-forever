#!/usr/bin/env python3
"""Mock the Ledger book opened by /ledger with a representative character."""

import argparse
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CORE = Path(os.environ.get("FOREVER_CORE", ROOT.parent / "forever-core"))
sys.path.insert(0, str(CORE / "tools" / "wowmock"))

import wowmock

FONTS = wowmock.FONTS


def progress(canvas, x, y, width, fraction):
    ui = canvas.ui
    canvas.draw(ui.atlas("common-stat-bar-BG"), x - 2, y - 1, width + 4, 16)
    if fraction > 0:
        canvas.draw(ui.atlas("common-stat-bar-white"), x, y, width * fraction, 14, color=(0.85, 0.68, 0.25, 1))


def book(ui):
    """Follow UI/Book.lua's portrait frame and four content insets."""
    canvas = ui.canvas(810, 590)
    frame = ui.canvas(780, 560)
    rock = ui.texture("interface/framegeneral/ui-background-rock.blp")
    wowmock.tiled(frame, rock, 2, 21, 776, 537, rock.width / ui.scale, rock.height / ui.scale)
    for x, y, width, height in [(18, 70, 270, 400), (298, 70, 454, 130), (298, 208, 454, 262), (18, 482, 744, 66)]:
        frame.fill(x, y, width, height, (0, 0, 0, 0.5))
        frame.nine_slice(wowmock.INSET_FRAME_LAYOUT, x, y, width, height)
    title = FONTS["GameFontNormalLarge"]
    rank_title = wowmock.Font(wowmock.FRIZQT, 20, wowmock.NORMAL, (1, -1))
    small = FONTS["GameFontDisableSmall"]
    normal = FONTS["GameFontHighlight"]
    frame.text(74, 34, "Alyra · Level 24", normal)
    frame.text(32, 82, "Today's orders", title)
    frame.text(32, 438, "Orders arrive after the next daily reset.", small)
    frame.draw(ui.atlas("honorsystem-prestige-laurel"), 312, 82, 64, 64)
    frame.text(388, 84, "Wayfarer II", rank_title)
    frame.text(388, 109, "52 marks · 0 stamps · 0 orders done", normal)
    frame.text(388, 126, "Next: Wayfarer III  52 of 62 marks", small)
    progress(frame, 314, 156, 420, 7 / 17)
    ranks = ["Wanderer", "Wayfarer", "Pathfinder", "Trailblazer", "Pioneer", "Cartographer"]
    for index, rank in enumerate(ranks):
        frame.text(314 + index * 70, 180, rank, small)
    frame.text(312, 220, "Stamps", title)
    frame.text(32, 490, "Today's orders 0 of 3", title)
    progress(frame, 32, 516, 300, 0)
    frame.text(346, 516, "+0 marks so far", normal)
    wowmock.three_slice_button(frame, 600, 502, 150, 26, "Track orders")
    canvas.paste(frame, 15, 15)
    wowmock.portrait_frame_art(canvas, 15, 15, 780, 560, "interface/icons/inv_misc_book_11.blp", "Ledger")
    return wowmock.scene(ui, [(canvas, 0, 0)])


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    book(wowmock.Ui()).save(args.output)
