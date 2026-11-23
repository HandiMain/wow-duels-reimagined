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
                  if p.is_file() and p.suffix.lower() in (".png", ".tga", ".blp")]
        self.assertGreater(len(images), 0)
        for image in images:
            with self.subTest(asset=str(image.relative_to(ADDON))):
                self.assertTrue(image.name in sources or image.name in dynamic,
                                "Unreferenced addon image: " + str(image))

    def test_icon_and_toggle_files_exist(self):
        for name in (
            "Media/Icons/DuelsDRIcon.png",
            "Media/Icons/DuelsNavigationAtlas.png",
            "Media/Skin/NeutralMasks.tga",
            "Media/Concept/Landing/LandingWordmark.png",
            "Media/Textures/ToggleTrack.tga",
            "Media/Textures/ToggleThumb.tga",
            "Media/Textures/SliderThumb.tga",
        ):
            with self.subTest(name=name):
                self.assertTrue((ADDON / name).is_file())

    def test_toc_loads_every_lua_file_once(self):
        toc = (ADDON / "DuelsReimagined.toc").read_text(encoding="utf-8")
        listed = [line.strip().replace("\\", "/")
                  for line in toc.splitlines() if line.strip().endswith(".lua")]
        actual = [str(path.relative_to(ADDON)).replace("\\", "/")
                  for path in ADDON.rglob("*.lua")]
        self.assertEqual(len(listed), len(set(listed)))
        self.assertEqual(set(listed), set(actual))

if __name__ == "__main__":
    unittest.main()
