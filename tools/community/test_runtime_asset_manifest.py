"""Static asset ownership contract. Not a substitute for viewing the UI in WoW."""
from pathlib import Path
import unittest

ADDON = Path(__file__).resolve().parents[2] / "addon" / "DuelsReimagined"

class RuntimeAssetManifestTests(unittest.TestCase):
    def test_every_packaged_image_has_a_runtime_reference(self):
        toc = (ADDON / "DuelsReimagined.toc").read_text(encoding="utf-8")
        lua = "\n".join(path.read_text(encoding="utf-8")
                        for path in ADDON.rglob("*.lua"))
        sources = toc + "\n" + lua
        media = ADDON / "Media"
        # These three variants are assembled at runtime by Header's iconBase;
        # their file extensions do not occur in literal source strings.
        dynamic = {"Close.png", "Eye.png", "FoldUp.png"}
        images = [p for p in media.rglob("*")
                  if p.is_file() and p.suffix.lower() in (".png", ".tga", ".blp", ".jpg", ".jpeg")]
        self.assertGreater(len(images), 0)
        for image in images:
            with self.subTest(asset=str(image.relative_to(ADDON))):
                self.assertTrue(image.name in sources or image.name in dynamic,
                                "Unreferenced addon image: " + str(image))

    def test_no_old_artwork_or_reused_addon_path_names(self):
        for item in ADDON.rglob("*"):
            relative = str(item.relative_to(ADDON)).lower()
            self.assertNotIn("polestar", relative)
            self.assertNotIn("artworkconcept", relative)
            self.assertNotIn("concept", relative)
        sources = "\\n".join(path.read_text(encoding="utf-8")
                            for path in ADDON.rglob("*.lua"))
        for obsolete in ("CommunityFactionMarks.png", "CommunityAllianceLion.png",
                         "CommunitySymbols.png", "CommunityHeaders.png",
                         "Media\\\\Polestar\\\\", "Style.ArtworkImage",
                         "Style.Rule(", "Style.ForgedEdge(", "movingBar"):
            self.assertNotIn(obsolete, sources)

    def test_no_dead_asset_aliases_or_comment_only_references(self):
        import re
        lua_sources = {p: p.read_text(encoding="utf-8")
                       for p in ADDON.rglob("*.lua")}
        media = ADDON / "Media"
        for image in media.rglob("*"):
            if not image.is_file() or image.suffix.lower() not in (
                    ".png", ".tga", ".jpg", ".jpeg", ".blp"):
                continue
            # Literal media names must be present in active Lua, not solely
            # in obsolete comments or a single unused local declaration.
            active = [src for src in lua_sources.values()
                      if image.name in "\\n".join(
                          line.split("--", 1)[0] for line in src.splitlines())]
            if image.name in {"Close.png", "Eye.png", "FoldUp.png"}:
                continue  # Header constructs these filenames at runtime.
            self.assertTrue(active, "Unreferenced runtime media: " + image.name)
            for src in active:
                for match in re.finditer(
                    r"\\blocal\\s+(\\w+)\\s*=\\s*[^\\n]*" +
                    re.escape(image.name), src):
                    symbol = match.group(1)
                    uses = re.findall(r"\\b" + re.escape(symbol) + r"\\b", src)
                    self.assertGreater(len(uses), 1,
                        "Unused media alias: " + symbol + " for " + image.name)

    def test_no_runtime_reference_addon_branding(self):
        # Names required to call EllesmereUI APIs are functional integration
        # contracts; study references must not become Duels product labels.
        for path in ADDON.rglob("*.lua"):
            body = path.read_text(encoding="utf-8")
            for obsolete in ("Polestar", "BurstFX", "Narcissus", "Horizon",
                             "First Concept", "CommunityConcept"):
                self.assertNotIn(obsolete, body, str(path))

    def test_icon_and_toggle_files_exist(self):
        for name in (
            "Media/Icons/DuelsDRIcon.png",
            "Media/Icons/DuelsNavigationAtlas.png",
            "Media/Skin/NeutralMasks.tga",
            "Media/Artwork/Landing/LandingWordmark.png",
            "Media/Textures/ToggleTrack.tga",
            "Media/Textures/ToggleThumb.tga",
            "Media/Textures/SliderThumb.tga",
        ):
            with self.subTest(name=name):
                self.assertTrue((ADDON / name).is_file())

    def test_toc_loads_every_lua_file_once(self):
        toc = (ADDON / "DuelsReimagined.toc").read_text(encoding="utf-8")
        listed = [line.strip().split(" [", 1)[0].replace("\\", "/")
                  for line in toc.splitlines()
                  if ".lua" in line and not line.lstrip().startswith("#")]
        actual = [str(path.relative_to(ADDON)).replace("\\", "/")
                  for path in ADDON.rglob("*.lua")]
        self.assertEqual(len(listed), len(set(listed)))
        self.assertEqual(set(listed), set(actual))

if __name__ == "__main__":
    unittest.main()
