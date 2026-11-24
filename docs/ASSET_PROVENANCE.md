# Third-party asset provenance

Duels Reimagined uses its own branding, interface architecture and asset naming. The project preserves provenance for directly reused third-party material, as required by license obligations and author permissions. Runtime paths are never a substitute for attribution.

## Polestar source assets
- Source: Polestar 0.4.1.1, `Polestar/Media/UI/reset.tga` and `Polestar/Media/UI/discord.tga`
- Authors: the Polestar authors, copyright © 2026
- New shipped paths: `addon/DuelsReimagined/Media/Controls/reset.tga` and `addon/DuelsReimagined/Media/Controls/discord.tga`.
- These two TGA files are unchanged byte-for-byte. Their license and copyright obligations survive file renaming. See the upstream `Polestar/LICENSE` (GNU GPL), and this repository's `LICENSE`.

A future replacement with newly authored art should be documented here, rather than silently erasing this history.

## Reference-only influences
Polestar, EllesmereUI, Horizon Suite, and Handi's BurstFX have been studied for design and engineering patterns. Study alone does not imply copied assets or code. EllesmereUI's optional integration necessarily retains its external addon name in code and the TOC so it can detect that plugin at runtime.

The public interface itself has no third-party branding or internal `Concept` / `Polestar` media directories.

## Duels Reimagined War Games coliseum plaque
- Source: the project's approved 2026-11-23 coliseum concept, chosen by the project owner.
- Original artwork was cropped and fitted into an RGBA 256x128 power-of-two plate, with transparent corners and the full gold WAR GAMES title safely inside the copper frame.
- Master: `tools/community/artwork/WarGamesColiseumPlate.png`. Runtime: `addon/DuelsReimagined/Media/Skin/DuelWarGamesPlate.png`.
- The War Games button retains its existing game-frame behavior and hover/press feedback; only the baked visual plate changed. No other addon's artwork was used.

## Retail War Games arena thumbnail browser (2026-11-23)

No arena thumbnails are distributed in the addon. The visual arena picker (`UI/WarGamesArenaPicker.lua`) queries the **player's own installed World of Warcraft Retail client** for Blizzard arena-specific loading screen art. The only mapped loading-screen candidates are the eight entries explicitly documented in Details! (`boot.lua`, `_detalhes.arena_info`): Nagrand, Blade's Edge, Ruins of Lordaeron, Dalaran Sewers, Tol'viron, Tiger's Peak, Ashamane's Fall and Black Rook Hold. Older Blizzard `PVPFrame.lua` documents the specific arena LFG icons that can act as fallbacks for Nagrand, Blade's Edge, Ruins and Dalaran. Runtime texture fileIDs are required: nonexistent paths or newer arenas without corroborated game art receive the honest **PREVIEW UNAVAILABLE** treatment. The entire arena list remains selectable.

No third-party screenshot files were downloaded or rehosted; no generated concept images or synthetic map artwork were bundled or labeled as real arenas. The screenshot concept remains UI design inspiration only. Game artwork is the property of Blizzard Entertainment and remains in the user's WoW installation. The path mapping derives from publicly accessible reference tables only; no reference addon code was copied. The Retail client must verify those fileIDs in-game before any thumbnail resolution is marked VERIFIED.

## War Games arena chooser glyph atlas — 2026-11-23

`addon/DuelsReimagined/Media/Skin/WarGamesPickerGlyphs.tga`: independently authored 128×32 RGBA8 uncompressed top-origin TGA. Cells 0, 1 and 2 hold a gold outline star, solid favorite star and gold check on dark copper enamel. Created programmatically from basic geometric shapes for this addon to prevent missing Unicode favorite/checkmark glyphs when Blizzard fonts or optional EllesmereUI fonts lack the characters; no third-party artwork, AI-generated arena image or font is included. All WoW arena thumbnails remain sourced at runtime from the installed Blizzard client, never from this atlas.

## War Games arena fallback illustrations — 2026-11-23

`addon/DuelsReimagined/Media/Arenas/WarGamesArenaFallback.png` is a **generated** 1024x512 eight-bit indexed PNG atlas, using a nine-scene original AI illustration created from publicly viewable World of Warcraft arena screenshot references. The artwork cells are 256x128 arranged left-to-right then top-to-bottom: (0,0) Nagrand Arena; (1,0) Cage of Carnage; (2,0) Empyrean Domain; (3,0) Enigma Crucible; (0,1) Hook Point; (1,1) Maldraxxus Coliseum; (2,1) Mugambala; (3,1) Nokhudon Proving Grounds; (0,2) The Robodrome. The remaining atlas cells are blank. SHA256: `029f3a70d4dba215a87bd3fcacb15ec5798cb0e6fbe800dd1485fb9833b22265`.

These are visual interpretations, **not game screenshots, exact arena geometry, native Blizzard textures, or gameplay evidence**. Reference sources included Blizzard's official Cage of Carnage release notes and Enigma arena announcement, Warcraft Wiki/Liquipedia arena descriptions, and in-game screenshots from Wowhead, Blizzard's galleries, and arena articles. The images were generated anew; no source screenshot was redistributed or directly copied into the atlas. Genuine Blizzard client's own textures always take priority where present; this atlas is the fallback for documented maps only. This entry supersedes the previous "no generated map artwork" policy for these nine user-authorized exceptions.


## Placement panel — 2026-11-24

- `Media/Skin/DuelPlacementPanel.png` (512x256 RGB PNG; git blob 1908c10e80228c758b185d81b9440c4c5ab2f68a): derived from the user's explicitly approved generated Hall placement image supplied 2026-11-24. Cropped the placement-only art and removed all baked text, preserving decorative shield, sockets, track, laurels, plate and border. No screenshot of the surrounding game or third-party addon included in package.
- `Media/Skin/DuelPlacementEffects.png` (128x64 RGBA PNG; git blob 51fd7e095baccc85e31c7e3e1bcf68ce06be3f39): gold shield treatment derived from an approved socket, transparent mask and original soft radial glow. No baked result or rank. Both assets have active references in CompetitiveUI.lua. Live visual verification pending.
