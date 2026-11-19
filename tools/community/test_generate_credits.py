#!/usr/bin/env python3
"""No network, no SavedVariables: regression tests for bundled credits."""

import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from generate_credits import build_data, config_load, lua_render, safe_display


class CommunityCreditsTests(unittest.TestCase):
    def setUp(self):
        self.config = {"aliases": {"hunter": "Hunter One"},
                       "exclude": ["OptOut"],
                       "special_thanks": ["KindPlayer", "KindPlayer", "OptOut"],
                       "ideas": [{"name": "Creative", "ref": 5}]}
        self.issues = [
            {"state": "closed", "state_reason": "completed", "user": {"login": "hunter"},
             "labels": [{"name": "bug"}, {"name": "verified-fix"}]},
            {"state": "open", "user": {"login": "hunter"},
             "labels": [{"name": "bug"}, {"name": "verified-fix"}]},
            {"state": "closed", "user": {"login": "OptOut"},
             "labels": [{"name": "bug"}, {"name": "verified-fix"}]},
            {"state": "closed", "user": {"login": "hunter"},
             "labels": [{"name": "bug"}, {"name": "duplicate"}, {"name": "verified-fix"}]},
            {"state": "closed", "user": {"login": "hunter"},
             "labels": [{"name": "enhancement"}, {"name": "verified-fix"}]},
        ]
        self.pulls = [
            {"merged_at": "2026-11-19T09:00:00Z", "user": {"login": "SomeDev"}},
            {"merged_at": "2026-11-19T09:01:00Z", "user": {"login": "SomeDev"}},
            {"merged_at": None, "user": {"login": "Unmerged"}},
            {"merged_at": "2026-11-19T09:00:00Z", "user": {"login": "HandiMain"}},
            {"merged_at": "2026-11-19T09:00:00Z", "user": {"login": "ci[bot]", "type": "Bot"}},
        ]

    def test_requires_verified_fixed_closed_bug(self):
        credits = build_data(self.config, self.issues, self.pulls,
                             "HandiMain/wow-duels-reimagined")
        self.assertEqual(credits["bugHunters"], [{"name": "Hunter One", "reports": 1}])
        self.assertEqual(credits["contributors"], [{"name": "SomeDev", "prs": 2}])
        self.assertEqual(credits["specialThanks"], ["KindPlayer"])
        self.assertEqual(credits["ideas"], [{"name": "Creative", "ref": 5}])

    def test_bot_duplicates_and_invalid_are_excluded(self):
        self.issues[0]["labels"].append({"name": "invalid"})
        self.assertEqual(build_data(self.config, self.issues, self.pulls,
                         "HandiMain/wow-duels-reimagined")["bugHunters"], [])

    def test_lua_output_escapes_quotes(self):
        data = build_data({"aliases": {}, "exclude": [],
            "special_thanks": ['Duel "Master" \\ Test'], "ideas": []}, [], [],
            "HandiMain/wow-duels-reimagined")
        result = lua_render(data)
        self.assertIn('Duel \\"Master\\" \\\\ Test', result)
        self.assertIn("ns.CommunityCredits = {", result)

    def test_invalid_config_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "credits.json"
            path.write_text(json.dumps({"aliases": {}, "exclude": [],
                             "special_thanks": [], "ideas": [{"name": "Nope", "ref": -2}]}))
            with self.assertRaises(ValueError):
                config_load(path)
        with self.assertRaises(ValueError):
            safe_display("broken\nline")

    def test_output_is_deterministic(self):
        data = build_data(self.config, self.issues, self.pulls,
                          "HandiMain/wow-duels-reimagined")
        self.assertEqual(lua_render(data), lua_render(data))
        self.assertNotIn("2026-11-19", lua_render(data))

    def test_fixture_cli_without_network(self):
        root = Path(__file__).resolve().parents[2]
        script = root / "tools" / "community" / "generate_credits.py"
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            conf = directory / "config.json"
            fixture = directory / "fixture.json"
            outfile = directory / "out.lua"
            conf.write_text(json.dumps(self.config))
            fixture.write_text(json.dumps({"issues": self.issues, "pulls": self.pulls}))
            result = subprocess.run([sys.executable, str(script), "--config", str(conf),
                        "--fixture", str(fixture), "--output", str(outfile)],
                        text=True, capture_output=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("Hunter One", outfile.read_text())


if __name__ == "__main__":
    unittest.main()
