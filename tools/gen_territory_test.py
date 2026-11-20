"""Pure checks for the faction territory generator."""

import unittest

from tools.gen_territory import render, territory, zone_ids


def assignment(ui_map, area, doodad=0):
    return {"UiMapID": ui_map, "AreaID": area, "WMODoodadPlacementID": doodad}


def area(identifier, mask):
    return {"ID": identifier, "FactionGroupMask": mask}


class TerritoryTest(unittest.TestCase):
    def test_zone_ids_ignore_continents(self):
        self.assertEqual(zone_ids([{"ID": 1411, "Type": 3}, {"ID": 947, "Type": 2}]), {1411})

    def test_the_whole_map_assignment_pins_the_area(self):
        assignments = [assignment(1411, 14), assignment(1411, 99, 7), assignment(1413, 17)]
        areas = [area(14, 4), area(17, 0), area(99, 2)]
        self.assertEqual(territory({1411, 1413}, assignments, areas), {1411: 4, 1413: 0})

    def test_a_map_without_a_mask_is_left_out(self):
        self.assertEqual(territory({1411}, [assignment(1411, 14)], []), {})

    def test_render_keeps_the_reference_namespace_shape(self):
        text = render({1411: 4, 1413: 0})
        self.assertIn("Pinned client build", text)
        self.assertIn("ns.Data.territory = {\n\t[1411] = 4,\n\t[1413] = 0,\n", text)


if __name__ == "__main__":
    unittest.main()
