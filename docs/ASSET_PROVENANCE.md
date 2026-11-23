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
