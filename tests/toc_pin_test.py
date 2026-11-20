"""The TOC's ForeverCore pin is the release tools/forever-core.txt names, and the addon embeds it."""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def toc_fields() -> dict[str, str]:
    fields = {}
    for line in (ROOT / "LedgerForever.toc").read_text(encoding="utf-8").splitlines():
        if line.startswith("## ") and ":" in line:
            key, value = line[3:].split(":", 1)
            fields[key.strip()] = value.strip()
    return fields


class TocPin(unittest.TestCase):
    def test_pin_matches_forever_core_txt(self) -> None:
        pin = (ROOT / "tools" / "forever-core.txt").read_text(encoding="utf-8").strip()
        self.assertEqual(toc_fields()["X-Forever-Core"], pin)

    def test_core_is_embedded(self) -> None:
        self.assertEqual(toc_fields()["X-Forever-Core-Embed"], "1")


if __name__ == "__main__":
    unittest.main()
