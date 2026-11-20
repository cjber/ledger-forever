"""Pure checks for the zone exploration overlay generator."""

import unittest

from tools.gen_areas import area_keys, overlay_key, render


def row(identifier, **values):
    return {"ID": identifier, **values}


class AreasTest(unittest.TestCase):
    def test_overlay_key_matches_the_client_record(self):
        self.assertEqual(
            overlay_key({"OffsetX": 10, "OffsetY": 20, "TextureWidth": 30, "TextureHeight": 40}), "10:20:30:40"
        )

    def test_groups_drawable_unconditioned_overlays_by_zone_and_deduplicates(self):
        tables = {
            "UiMap": [row(1411, Type=3), row(1412, Type=2)],
            "UiMapXMapArt": [
                row(1, UiMapID=1411, UiMapArtID=99, PhaseID=0),
                row(2, UiMapID=1412, UiMapArtID=99, PhaseID=0),
            ],
            "WorldMapOverlay": [
                row(
                    1,
                    UiMapArtID=99,
                    OffsetX=10,
                    OffsetY=20,
                    TextureWidth=30,
                    TextureHeight=40,
                    PlayerConditionID=0,
                ),
                row(
                    2,
                    UiMapArtID=99,
                    OffsetX=10,
                    OffsetY=20,
                    TextureWidth=30,
                    TextureHeight=40,
                    PlayerConditionID=0,
                ),
                row(
                    3,
                    UiMapArtID=99,
                    OffsetX=50,
                    OffsetY=60,
                    TextureWidth=70,
                    TextureHeight=80,
                    PlayerConditionID=123,
                ),
                row(
                    4,
                    UiMapArtID=99,
                    OffsetX=90,
                    OffsetY=100,
                    TextureWidth=0,
                    TextureHeight=20,
                    PlayerConditionID=0,
                ),
            ],
        }
        self.assertEqual(area_keys(tables), {1411: ["10:20:30:40"]})

    def test_render_uses_the_runtime_set_shape(self):
        text = render({1411: ["10:20:30:40"]})
        self.assertIn("ns.Areas = {\n\t[1411] = {\n", text)
        self.assertIn('["10:20:30:40"] = true,', text)
        self.assertIn("Pinned client build", text)


if __name__ == "__main__":
    unittest.main()
