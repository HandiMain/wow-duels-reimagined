# Duels Reimagined — Project Guide

This document is for work in progress. It records the agreed direction and prevents ideas from being mistaken for finished features.

## Current state

- **Phase:** Approved visual concept; window-shell build authorized
- **Addon source:** UI prototype on `develop`; no released gameplay system
- **Build authorization:** Main window shell, compact layout, and header Fold/Peek/Search controls explicitly authorized
- **Live game verification:** Current window shell and layout shown in Retail screenshots; new header controls and automatic movement Peek remain IMPLEMENTED/UNTESTED
- **Target clients:** World of Warcraft Forever and Retail; PNG rendering requires in-game verification on each client

The user-approved 1672 × 941 **Hall concept image** is the visual reference, not a loose inspiration. Reproduce its actual icon artwork, depth, metallic treatment, decorative dividers, shaded panels and button finishes as independent reusable assets. The original art is reconstructed under `addon/DuelsReimagined/Media/Concept/`; do not use one whole-window wallpaper or bake text and hit regions into images. Respect later explicit revisions: the top-right X was restored as a functional Close control (the footer Close remains), while footer branding is omitted. Keep shared navigation, themes, saved settings, animations, input handling and optional EllesmereUI compatibility intact.

## Branches

- `main`: Player-facing project page and approved, stable work only.
- `develop`: Current designs, notes, and eventually implementation/testing after explicit authorization.
- Both branches are **public**. Do not store secrets, private records, test-player personal data, or unlicensed assets in either branch.
- Do not merge to `main`, tag a version, or publish a release without explicit approval.

## Approval states

1. **IDEA** — Being discussed. No commitment to build.
2. **CONCEPT APPROVED** — Appearance, visible behavior, and scope agreed.
3. **BUILD AUTHORIZED** — Implementation explicitly requested.
4. **IMPLEMENTED / UNTESTED** — Written, but not yet proven in the game.
5. **VERIFIED** — Relevant checks and required in-game tests have passed. Multiplayer claims require real multiplayer tests.

Visual approval is not permission to implement.

## Unified systems and cross-feature compatibility

Every approved feature must cooperate with the existing addon, not form a separate mini-addon. Keep one owner for each shared concern (settings, themes, animation, data, events, networking, and diagnostics) and reuse that owner's public interface from individual features.

Before modifying a feature, inspect its callers, shared UI, Options, event lifecycle, data storage, client-specific paths, and nearby behavior. Confirm that theme and font changes update all applicable existing and future controls. Preserve chat focus, Escape, combat safety, and clean open/close behavior. Avoid duplicates and redundant adapters. Test neighboring behavior after each focused change, and do not call integration verified without in-game evidence.

## Before implementation

For each approved feature, agree on its player purpose, visible interface, interactions, empty and error states, settings, game API limits, exclusions, dependencies, and tests. Prefer one focused behavior change at a time.

Build for clear, WoW-native controls, safe Blizzard chat/input behavior, a central Options area, predictable window focus and combat-safe interaction. Keep responsibilities separated; avoid duplicate engines or settings owners.

## Reference research

Inspect relevant **Polestar** source and behavior first whenever it is accessible. Then review **EllesmereUI**, **Horizon Suite**, and **BurstFX** when useful. References inform decisions; they do not determine our identity or roadmap.

Respect upstream license requirements and original attribution for any reused material. Check the actual source, permissions, and compatibility before adapting code or artwork. Never present uninspected behavior as verified.

## Feature candidates — not promises

Past experiments included duel history, personal statistics, rankings, player profiles, rivalries, community, tournaments, achievements, communication, and War Games organization. Every candidate needs separate design and feasibility approval. None is committed to implementation by appearing here.

## Verification and reporting

- Validate client differences between Forever and Retail before claiming support.
- Do not invent ranking, synchronization, matchmaking, tournament results, or verified match evidence.
- Clearly distinguish **LOCAL**, **MANUAL**, **SIMULATED**, **ESTIMATED**, and **NOT OBSERVED** data when applicable.
- Automated checks and mock tests do not prove WoW gameplay.
- Report what changed, why, test evidence, required in-game checks, and remaining uncertainty.
- Prefer focused changes with checks for nearby behavior and regressions.


## Header controls — approved November 19, 2026

- Compact scale slider applies window scaling only after releasing the drag.
- Close is available from either the top-right X or footer; Escape should retain Blizzard's standard behavior.
- **Peek:** holding the eye temporarily fades the window and releasing restores it; **Fold:** collapses to the header while preserving the selected page and restores on demand.
- **Automatic Peek while moving** is a saved, default-off switch under **Options → Interface**, separate from **Appearance**. It uses client movement start/stop events only while the window is visible and the preference is enabled. Do not infer secret gameplay data or poll permanently.
- Search includes registered visible pages, options rows and applicable header actions, not unbuilt feature ideas. Adding a page or setting must register it through the shared search owner.
- Keep search EditBox focus isolated from Blizzard chat. Search Escape clears search first, while the regular window Escape closes it. The UI must recover from /reload, hide, fold, scale changes and combat transitions without leaving transient state behind.
- Current status: **IMPLEMENTED / UNTESTED IN-GAME** for these new controls. Test in both Retail and Forever, including moving/standing, typing Enter/Escape, opening/closing, changing scale and EllesmereUI appearance matching.

## Decisions — November 18, 2026

- Rebuild the addon from zero. Earlier prototypes are learning references, not a code baseline.
- Stay in visual design until the appearance and behavior are approved; implementation needs separate authorization.
- Both GitHub branches are public, with `main` reserved for approved, stable work.
- Public-facing descriptions should be written clearly for players. Technical working notes belong on `develop`.
- No automatic releases, surprise features, or unverified claims.


## Persistent settings, footer and resizing (test build)

- All preferences use `Core/Settings.lua`. `GetDefault`, `IsModified`, and `Reset` compare effective values with defaults, not raw SavedVariables presence. Add every future option here and to Search.
- Window dimensions are optional account-wide data, clamped to the physical screen and Menu Scale. The grip persists size only when released and is inactive when Fold is on. Reset window restores default dimensions and 100% scale; right-clicking the corner grip resets only dimensions.
- Reload UI remains disabled unless a future setting opts in to reload tracking and its value differs from the value loaded at session start. All current settings apply live.
- Footer test build label with BETA, Discord Coming Soon popup, Reset window and Reload UI. Added actions also register with Search.
- Asset credit: the three original 32x32 icon textures `Media/Polestar/reset.tga`, `discord.tga`, `resize.tga` are from Polestar by fitzforge (https://github.com/fitzforge/polestar), licensed under GPL-3.0. The repository's LICENSE applies and this notice must be retained on redistribution. Interaction code is independently written after inspecting Polestar, EllesmereUI, Horizon Suite and BurstFX references.

## Conditional EllesmereUI defaults and corner grip

- `matchColors` and `matchFont` default ON **only when** the optional EllesmereUI appearance API is available; otherwise their effective default is OFF. A saved boolean is an explicit legacy/modern override. Reset clears that override (nil = automatic) rather than replacing it with a current boolean. No forced migration of pre-existing false values, because older builds did not distinguish implicit defaults from manual OFF. When EllesmereUI is unavailable the effective state is OFF while its saved override remains for restoration.
- Options change indicators compare effective state to the current contextual default. The rest of the preferences, saved window size and reload gating are unchanged.
- The bottom-right metal corner alone uses a newly authored `CornerBRResize.png`, with an unmistakable diagonal grip, and the hover overlay `ResizeGripHighlight.png`. Both derive from the user-approved resized-corner design concept and are original project assets; other frame corners remain unchanged. The hit target is kept inside the corner and clear of the footer Close button. Retain Fold/resizing lifecycle and persisted dimensions.

## Header wordmark approval and placement

- Replace the former shield/crest header lockup with the approved flat DUELS / REIMAGINED artwork: gold text, a restrained divider, and faint blue Alliance lion / red Horde crest blended *behind* the text. Use a single transparent power-of-two source image at `Media/Concept/DuelsReimagined-HeaderLogoFlat.png` with cropped empty padding. Retain `DuelsReimagined-HeaderLogo.png` for possible rollback; do not change the addon icon.
- The logo belongs to a responsive header brand area bounded by the left header edge and the left edge of Search (with padding). Center within the area and scale down only if its width is constrained. The Search, Fold, Peek, Menu Scale, chat focus, Fold and window resize logic remain unchanged. In-game visual fit still requires verification on both clients.

## UI foundation expansion — fonts, interactions and motion

- Our current Motion driver, Style/theme owner, Widgets controls, Options search and Settings SavedVariables remain authoritative. No second BurstFX-style engine. Reduce Motion (default OFF) snaps transitions using the existing driver. Sound playback is explicitly deferred.
- Interface Options now contain a scroll-safe typography section: font face, text size (90–115%), and outlines. Defaults are Blizzard font/100%/original outlines. When EllesmereUI font matching is active, it wins over manual face selection, and the manual selection remains saved for later use. Size and outline remain independent. Font choices include built-in Blizzard fonts plus dynamically registered LibSharedMedia fonts when the optional library/font packs are loaded. The submitted LibSharedMedia ZIP includes API code only, not additional font files; no license-bound library code is copied into this addon.
- All new preferences use the centralized Settings owner, modified indicators and resets, and a Search entry. The new shared ChoiceRow and SliderRow widgets respect the unified UI colors, short press feedback, disabled explanations, compact scroll pages and restrained motion. Existing visual assets and the dual header logo are unchanged.
- Footer Discord modal now exposes one show/close owner and closes before Fold or page navigation; the existing Escape registration and window-close cleanup remain. Window-scale refreshes only 1-pixel plain borders, not custom gold metal textures. Live WoW tests are required before calling these behaviors verified.

## Options layout and scrollbars — visual correction (November 19, 2026)

- Interface options are grouped into separate reusable card surfaces: Window behavior and Typography; Appearance remains its own single card. The scroll content itself has no border or fill. Add future settings using the same Card helper, never by extending one giant framed panel.
- Polestar reference: `Polestar/Theme/Widgets.lua` `W.Scroll`, `scrollUpdate`, `scrollDrag`, `W.ScrollBarRoom`. Duels adapts the thin, proportionate, draggable bar with no permanent OnUpdate. Shared `Widgets.ScrollBar` also serves virtualized dropdown menus and is visible only on overflow. Source and drag behavior studied; implementation independently written.
- Dropdown chevron is the existing local `Media/Concept/Header/FoldDown.png`, not a Unicode glyph; avoids unsupported font glyph squares.
- Text-size setting now supports 75–150% at 5% increments through Settings' shared clamping function. Existing saved values/default/reset remain intact and independent of Menu Scale and the EllesmereUI font face selection.
- Scroll-aware search reveals the actual setting row. Confirm wheel, drag, smaller windows, 75/100/150% labels, Escape/outside click, Fold, /reload and theme switching in-game before VERIFIED. Sounds remain deferred.

## Duels-only tooltip preference and universal UI binding

- `UI/Tooltips.lua` owns the sole Duels-specific tooltip frame. It never calls or hooks Blizzard `GameTooltip`, never touches other addons' tooltip skins, and uses current Style colors/fonts and Motion animation. Controls use `ns.Tooltips.Bind(control, {title, detail, disabled, anchor})`, or supply a function for changing wording; `Show/Hide` are available for special cases. Binding hooks rather than replaces existing control scripts. All future interactive widgets and manually created buttons must bind through this owner.
- **Show addon tooltips** lives under **Options → Interface → Window behavior**, default ON, saved account-wide by Core/Settings, searchable and resettable. Turning OFF hides an already-visible tooltip immediately and prevents all new Duels tooltips until toggled ON again. Keep disabled explanations available only when tooltips are enabled. The preference has no effect on Blizzard/global tooltips or other addons. This feature does not require a UI reload.
- Existing tooltip callers from header, footer, Navigation, Options widgets, dropdowns, sliders, scrollbars, reset buttons, close buttons, Search and resize controls use the shared owner. Dynamically resolved copy reports Fold/Unfold, disabled settings, search results, and changed labels. Reference research: Polestar widget tooltip helpers, EllesmereUI widget hints, Horizon tooltip framework (do not import its game tooltip ownership) and BurstFX interaction/disabled-state style. Test in WoW for positioning, focus, reveal states and reset/reload. UI sounds deferred.

## Community page — approved build and GitHub-only submission

- Concept approved: **The Duelist's Circle**, with muted navy Alliance lion and dark crimson Horde glyph behind the hero; four reusable cards (Contributors, Bug Hunters, Community Ideas, Special Thanks), explicit empty states and two primary GitHub actions. No in-game GitHub API access, fabricated data, Discord integration or gameplay features.
- `Community/Credits.lua` is the single generated data source, loaded before the Community UI. Navigation uses one overview and four category detail pages with scrollable full lists. Search automatically includes the category pages; standalone GitHub actions register through the same Search owner.
- The existing Footer popup owner also displays a selectable/read-only GitHub Issue form URL for Ctrl+C. WoW cannot launch a browser or copy to the system clipboard. Popup Escape/close must restore focus and hide correctly, preserving Blizzard chat Enter outside the dialog.
- Reuse Widgets.ScrollBar for overflow, Tooltips.Bind for every clickable control, Style/Chrome for theme and artwork, and existing navigation/Close/Fold/Peek without duplication. Source artwork was generated for this addon and stored as a transparent faction atlas; decorations never take mouse focus.
- This is an **IMPLEMENTED/UNTESTED** feature until both Forever/Retail checks pass. GitHub generator passed a real Actions run on develop. Public issue forms and issue event triggers require the approved GitHub-only files on default branch/main; no automatic releases, main code merges or Discord setup.
