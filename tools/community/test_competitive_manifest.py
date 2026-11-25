"""Offline build identifier, not runtime file attestation.
Run with --write after an intentional competitive source change.
"""
import hashlib
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2] / "addon" / "DuelsReimagined"
FILES = tuple(sorted("""Client Communication CompetitiveIntegrity CompetitiveLifecycle CompetitiveRules
CompetitiveScope CompetitiveStorage DuelDetection Group LeaderboardSync MatchLedger OpponentDiscovery
PeerAgreement PersonalHistory Presence RatingEngine ResultConfirmation SeasonRules Settings SyncProtocol""".split()))

def fingerprint(root=ROOT):
    # Git blob IDs preserve exact packaged bytes and work without a git checkout.
    rows = []
    for name in FILES:
        path = f"Core/{name}.lua"
        data = (root / path).read_bytes()
        blob = hashlib.sha1(f"blob {len(data)}\0".encode() + data).hexdigest()
        rows.append(f"{path} {blob}\n")
    return hashlib.sha256("".join(rows).encode()).hexdigest()

def render(digest):
    return ('-- Generated offline; advertised identity, not proof of unmodified files.\n'
            'local _,ns=...\n'
            f'ns.CompetitiveManifest={{version=1,fingerprint="{digest}"}}\n')

class CompetitiveManifestTest(unittest.TestCase):
    def test_manifest_matches_sources(self):
        expected = render(fingerprint())
        actual = (ROOT / "Core/CompetitiveManifest.lua").read_text(encoding="utf-8")
        self.assertEqual(expected, actual, "Regenerate the competitive build manifest after approved core changes")

if __name__ == "__main__":
    if sys.argv[1:] == ["--write"]:
        (ROOT / "Core/CompetitiveManifest.lua").write_text(render(fingerprint()), encoding="utf-8")
    else:
        unittest.main()
