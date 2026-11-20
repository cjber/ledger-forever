"""Pure checks for the zone level generator."""

import unittest

from tools.gen_zonelevels import exploration_range, render


def area(area_id, level):
    return {"ID": str(area_id), "ExplorationLevel": str(level), "ParentAreaID": "0"}


class ExplorationRangeTest(unittest.TestCase):
    def test_spans_the_areas_and_their_subzones(self):
        areas = {1: area(1, 10), 2: area(2, 0), 3: area(3, 20)}
        self.assertEqual(exploration_range(5, {(5, 1), (5, 2)}, areas, {2: [3]}), (10, 20))

    def test_an_assignment_to_an_unknown_area_fails(self):
        with self.assertRaisesRegex(ValueError, "area 9"):
            exploration_range(5, {(5, 1), (5, 9)}, {1: area(1, 10)}, {})

    def test_a_map_without_nonzero_exploration_is_missing(self):
        areas = {1: area(1, 0)}
        self.assertIsNone(exploration_range(5, {(5, 1)}, areas, {}))

    def test_render_keeps_the_runtime_shape_and_pin(self):
        text = render([(1411, "Durotar", (1, 10), False)])
        self.assertIn("Pinned client build: 1.60.1.70959", text)
        self.assertIn("ns.ZoneRanges = {\n\t[1411] = { 1, 10 }, -- Durotar\n", text)


if __name__ == "__main__":
    unittest.main()
