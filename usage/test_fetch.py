"""Run: python3 -I -m unittest discover -s usage -q   (from the repo root; no network, no credentials)."""
import unittest

import fetch

PAYLOAD = {
    "five_hour": {"utilization": 51.0, "resets_at": "2026-10-13T05:49:59.681518+00:00"},
    "seven_day": {"utilization": 20.6, "resets_at": "2026-10-17T05:59:59.681538+00:00"},
    "seven_day_opus": None,
}


class NormalizeTest(unittest.TestCase):
    def test_maps_both_windows(self):
        out = fetch.normalize(PAYLOAD, plan="pro", now=1000)
        self.assertEqual(out["ok"], True)
        self.assertEqual(out["plan"], "pro")
        self.assertEqual(out["fetchedAt"], 1000)
        self.assertEqual(out["session"], {"percent": 51, "resetsAt": "2026-10-13T05:49:59.681518+00:00"})
        self.assertEqual(out["week"]["percent"], 21)  # rounded

    def test_missing_window_is_none(self):
        out = fetch.normalize({"five_hour": None}, now=1)
        self.assertIsNone(out["session"])
        self.assertIsNone(out["week"])

    def test_utilization_is_clamped(self):
        out = fetch.normalize({"five_hour": {"utilization": 140, "resets_at": None},
                               "seven_day": {"utilization": -3, "resets_at": None}}, now=1)
        self.assertEqual(out["session"]["percent"], 100)
        self.assertEqual(out["week"]["percent"], 0)

    def test_failure_shape(self):
        self.assertEqual(fetch.fail("network"), {"ok": False, "error": "network"})


if __name__ == "__main__":
    unittest.main()
