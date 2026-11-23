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
