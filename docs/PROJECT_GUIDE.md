# Duels Reimagined — Project Guide

This document is for work in progress. It records the agreed direction and prevents ideas from being mistaken for finished features.

## Current state

- **Phase:** Approved visual concept; window-shell build authorized
- **Addon source:** UI prototype on `develop`; no released gameplay system
- **Build authorization:** Main window shell, compact layout, and header Fold/Peek/Search controls explicitly authorized
- **Live game verification:** Current window shell and layout shown in Retail screenshots; new header controls and automatic movement Peek remain IMPLEMENTED/UNTESTED
- **Target clients:** World of Warcraft Forever and Retail; PNG rendering requires in-game verification on each client

The user-approved 1672 × 941 **Hall concept image** is the visual reference, not a loose inspiration. Reproduce its actual icon artwork, depth, metallic treatment, decorative dividers, shaded panels and button finishes as independent reusable assets. The original art is reconstructed under `addon/DuelsReimagined/Media/Concept/`; do not use one whole-window wallpaper or bake **interactive** text, controls or hit regions into images. The later approved Options-banner exception intentionally bakes fixed section titles and descriptions into six concept-extracted header graphics, with all settings rows, tooltips and interactions remaining live. Respect later explicit revisions: the top-right X was restored as a functional Close control (the footer Close remains), while footer branding is omitted. Keep shared navigation, themes, saved settings, animations, input handling and optional EllesmereUI compatibility intact.

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


## Approved concept fidelity — binding design rule (2026-11-19)

- The exact **approved concept image** is the visual specification and acceptance baseline, not an inspiration prompt. Reproduce the same shapes, watermarks, layout, colors, panel proportions, icon treatment, texture detail, spacing, opacity, and hierarchy as closely as the WoW UI permits.
- **Never replace approved artwork with newly generated, random, vaguely similar, or placeholder artwork without explicit approval.** When available, extract/reuse the actual pixels from the approved reference, preserving its distinctive details, rather than reimagining the subject. Creating a new asset requires a separate explicit design review.
- If an asset cannot be reliably extracted, matched, or displayed in WoW, mark the mismatch and ask to approve the specific substitute. Never silently assert a 1:1 match or use untested PNGs as proof of in-game fidelity.
- Before committing UI, inspect and compare the actual approved concept and current in-game screenshot. Validate positions, proportions, colors, texture integrity, legibility, aspect ratios, and UI scaling. A code/CI pass is **not** visual or live-client verification.
- Source of Community marks and icons: the approved Nov 19 Duelist's Circle concept screenshot. `Media/Concept/CommunityFactionMarks.png` and `CommunityConceptSymbols.png` contain **pixel-derived masked crops** from that image, with transparent backgrounds; they are not newly invented emblems. They are approximate crops at low resolution and still require the user's in-game visual review.


## Alliance watermark clarity — visual-only targeted correction

- Current Community hero used the concept-derived 64px Alliance crop magnified to 229 UI units, losing the face into a blurry blue patch. Horde was already visually approved.
- Re-extracted the same lion from the approved `a_high_detail_screenshot_of_a_fantasy_mmorpg_addon.png` design (not a new/generated emblem), retained its face/mane details and fade in the dedicated 128x128 RGBA `Media/Concept/CommunityAllianceLion.png`.
- The Alliance watermark retains its 229-unit dimensions and original anchor; alpha increases modestly from 0.78 to 0.84 for legibility. The Horde continues to use the untouched atlas with **identical bytes**, UV coordinates, size, location and 0.76 alpha. No changes to gameplay, buttons, community credits, Search or options.
- Dedicated Community regression test verifies the Horde atlas SHA-256 and new Alliance image dimensions/format. Automated tests do not substitute for an in-game visual check.


## Community hero buttons — exact concept fit (2026-11-19)

- Previously the entire 256x64 primary-button texture was stretched to 270x43, distorting the corner bevels and making them visually extend beyond the red body. Polestar's primary button styling reinforced avoiding stacked/doubled edges. Duels retains its own approved PNG and shared Style.Action owner, with an opt-in `community` variant rendered as one **three-slice frame** in Chrome. The two end caps retain their shape and only the straight middle stretches. A strictly inset hover layer cannot spill over the gold corners. Default/footer buttons are unchanged.
- Removed both redundant `Copy GitHub link` **buttons** under the primary hero actions. Replaced them with quiet, non-clickable descriptions of what each main action does. The only click target is the original main action, which still opens the existing selectable GitHub link dialog. No changes to GitHub automation, credits, search, tooltips, or navigation.
- Regression test checks source ownership, cap sizing, proper button variant and a single click handler. Verify in WoW at varied Menu Scale and font sizes; automated checks cannot prove on-screen corner alignment.

## Primary vs secondary sidebar buttons — approved Hall design

- User-approved second Hall concept from 2026-11-19 is the exact visual reference. The screenshot was carefully cropped to retain its red enamel face, gold perimeter and small upper/lower diamond accents, but the baked-in sword icon and caption were removed so the existing WoW-rendered `IconHall` and `Style.Text` stay responsive to font/theme changes. Asset: `Media/Concept/NavPrimary.png` (128x128 RGBA with transparent margins; screenshot-derived, not newly generated).
- Reuse `Chrome.PrimaryRail(button)` **only** on navigation sections explicitly tagged `primary = true`. Hall is the first primary section. Community and Options remain completely unchanged. Other page titles, nav columns, content and window shell are untouched.
- The primary background is brighter while selected and dimmed when inactive. Hover/pressed tint is limited to the red center, never painted over the metal rim. The original navigation owner retains click, tooltips, search, hover motion, icon and label. No new animation driver or settings.
- Static regression checks ensure primary selectability, secondary unchanged, source art dimensions and clean tooltip integration. Must verify real WoW at differing menu/font scales, page switching, click areas, and combat; visual match is still unverified until user screenshots it in client.


## Hall primary rail — alignment and hover repair (2026-11-19)

- In-game screenshot revealed crossed swords touching the top gold frame and the Hall artwork visually offset inside the narrow 88-unit rail. The approved 128x128 PNG contains significant transparent padding; its 100x90 full-canvas display was too large.
- Corrected only the primary rail geometry: 86x74 hit area centered within 88-unit rail, art 92x90 with 5px downward compensation, top at -19, swords 35x35 anchored -11px and text -1px below icon. Secondary Community/Options buttons keep their original 86x68 hit area, -12 top/previous bottom anchoring, 39px icon and labels.
- Fixed hover root cause: the selected Hall was explicitly excluded from hover animations. Now both selected and inactive primary buttons get a soft additive gold rim gleam, using the exact approved Hall PNG a second time as an overlay. `Motion` remains the only animator, with the same press/tooltip owner and no global UI changes.
- Static tests check geometry and selected/unselected hover paths. Visual feedback, hit areas, tooltip lifecycle and menu scaling must be verified in WoW; CI alone is not in-game proof.


## Hall primary alignment / hover root-cause re-audit (2026-11-19)

- After two unsuccessful offset passes, compared against the last verified secondary rail (commit `4b850733`), Polestar primary buttons, EllesmereUI hover/tint patterns, Horizon sidebar and BurstFX UIFramework. Preserve one `Navigation` owner, shared `Widgets.PressFeedback`, and existing `Motion` driver; no new engine.
- Measured **actual** `NavPrimary.png` 128x128 RGBA alpha bbox: x=4..124, y=10..118 — symmetric around source center. This proves padding is not asymmetric; **do not re-crop/re-generate** the approved asset. The failure was applying a -5px compensating offset and positioning the swords from a top edge instead of composing icon + caption within the visible red panel.
- `Chrome.PrimaryRail` now draws the approved asset centered at 88x78 (visible alpha about 82.5x65.8) within the existing 88px rail; no artwork offset. Primary icon is 30x30 centered +8px vertically from the button center; Hall caption sits directly below. Community and Options retain 39px top-anchored icons, original click areas and styles.
- Original press feedback uses `MouseUp` to set the supplied texture alpha to 0.20, canceling the primary hover glow after a click. Primary uses its existing selected tint for press feedback instead, leaving the additive shaped hover independent. A single `PrimaryHoverAlpha` defines strong hover when selected (0.54) or inactive (0.66); the already-owned `Motion` handles all fades.
- Automated syntax/regression checks are **not** visual verification. In WoW, validate gold frame centered in sidebar without icon touching upper diamond, readable HALL caption, visible hover when selected and inactive, click/press, tooltip and other sections unchanged.

## Hall restoration and BurstFX access icons — 2026-11-19

**Hall restoration:** User explicitly abandoned the premium Hall tab. Restored `UI/Navigation.lua` and `UI/Chrome.lua` exactly from verified pre-experiment commit `4b850733`. The original 86x68 Hall button, 39px crossed swords, same selection/hover and Community/Options navigation return. Premium `NavPrimary.png` is no longer referenced; do not reinstate without a new approved concept.

**BurstFX source:** ChatGPT Library upload `Handi’s BurstFX v0.1.0 — Build 1004bugfix.zip`, studied its `UI/Minimap.lua`, `UI/AccessWidget.lua`, `UI/MinimapPersonality.lua`, `UI/GlobalSettingsPages.lua`. Polestar `Maps/MinimapButton.lua` supplied shape-aware dragging/collector context; EllesmereUI `EUI_Minimap_Buttons.lua` and Horizon `core/MinimapButton.lua` supplied compatibility/idle context. Implemented one adapted access owner, not a separate skin/settings/motion engine. BurstFX is owned by this project's author.

- `UI/AccessIcons.lua` owns a minimap icon and optionally draggable floating widget; both reuse the addon-list `DuelsReimagined-AddonIcon.blp`. Minimap default; modes: minimap, widget, both, hidden. Button and widget are independent of Minimap's child list, following BurstFX's compatibility choice. Minimap radius honors round/square/corner shape; position saved by angle (default 225) after drag. Widget saved offset from UIParent center (default +280/0), clamped, size 24–128 (default42), idle transparency 0–90%.
- BurstFX hover/press scale, highlight, silhouette glows, optional circular-masked one-shot sweep, and four-second minimap idle fade are adapted through existing `UI/Motion.lua` and short-lived `C_Timer.After`; no permanent polling except during actual minimap drag. Reduced-motion follows existing Motion owner.
- Only left click calls `Window.Toggle` (also from addon compartment if supported); it opens or closes the window with existing animation. No right-click menu, quick panel, patch notes, fake duel-triggered pulse, global tooltip override or UI sounds. Dragging never opens the window.
- Options → Interface → **Access icons** is a separate third card below Typography, offering mode, widget size, transparency, and a reset for both positions; controls are searchable, saved account-wide in Core/Settings, and only widget settings are enabled when widget mode is active. The Hidden mode retains `/duels` as a recovery route.
- `Tooltips.Show` permits explicitly marked outside-window launchers; all existing tips keep their previous window-visibility rule. Tooltip preference still applies globally to Duels-only tips, not Blizzard.
- Static / Lua parse / CI tests cannot prove game behavior. In WoW check tooltip with closed window, repeated left-click open/close including Fold/Peek, drag without opening, restart/reload persistence, Minimaps with EllemsereUI, widget transparency/size and Reset, all modes, reduced motion, and no Lua/combat errors.


## Minimap launcher tooltip / live widget sliders — 2026-11-19

- Inspected real BurstFX `UI/AccessWidget.lua` and `UI/GlobalSettingsPages.lua`, Polestar `Maps/MinimapButton.lua`, Horizon `core/MinimapButton.lua`, and EllesmereUI minimap button code. BurstFX treats icon access as an Interface setting; Duels keeps Options → Interface and renames the existing card `Minimap button` without adding another options page. This heading is now searchable.
- Root cause for missing tooltip: `AccessIcons.ConnectClick` called `Tooltips.Bind` (which HookScripts OnEnter/OnLeave) before subsequent `SetScript` overwrote those hover handlers. Binding the existing shared addon-only tooltip after all launcher handlers fixes it. Dynamic tooltip says Left-click Open/Close based on current window state plus Drag instructions; uses the existing outsideWindow exemption and honors Show addon tooltips.
- Added *opt-in* live slider mode to existing `Widgets.SliderRow`; only widget size and transparency use it, not other sliders. Normal on-release mode remains unchanged. Programmatic updates are suppressed, and duplicate drag values are ignored; wheel changes are immediate.
- `Settings.Set` previously called `Options.Refresh` for every widget step, resetting the actively dragged slider thumb. Now live widget settings call `Options.RefreshAccessModified` (reset/modified state only) plus existing `AccessIcons.Refresh`, so the visible widget updates instantly while held. Full refresh occurs for switching modes and for deliberate reset actions.
- TEST IN WOW: hover minimap button with main window closed and open, hover widget, disable and enable Show addon tooltips, left-click toggle, drag to move, drag sliders and verify size/transparency before mouse release, wheel adjust, reset settings, switch modes, /reload persistence; confirm menu scale/font sliders and Community/Options unaffected. Static Lua/CI tests are not in-game verification.

## Integration audit fixes & compartment membership (2026-11-19)

- Reused Polestar's collector ownership pattern and EllesmereUI 9.8.9's direct-Minimap-child discovery. The minimap button is a named Minimap child with a named Icon; when a collector changes its parent/anchor, Duels stops overwriting placement. The Show lifecycle only restores visibility after our own Minimap/mode transitions, not every settings repaint. Actual collector behavior needs in-game verification.
- Reused BurstFX 1004bugfix's registered-compartment setting approach. `showInCompartment` defaults ON and only controls Duels' entry in Blizzard's AddOn Compartment, not Blizzard's menu icon. AddOn Compartment registration occurs at PLAYER_LOGIN and does not have a supported official unregister; the toggle therefore needs `/reload`, tracked through existing Settings/RegisterReloadRequired and Footer Reload UI. UI hides the option with explanation where the API is unavailable; Search registration comes from AddToggle.
- Fixed all identified audit items: window-grip tooltip OnHide now HookScript; Search shows every result through paged six-row wheel/keyboard viewport; unavailable Reload/Reset actions are filtered via optional availability callback; Menu Scale search highlights the header slider independently of tooltip preference; Close Window is indexed; Theme.Refresh repaints nav selection without reopening pages, dismissing a modal or clearing search; auto Peek checks current movement on open; CI triggers on the whole addon tree; Community guide reflects the verified issue forms on main.
- Contract verification now includes Lua 5.1 **execution** checks for Search filtering/full result list and central SavedVariables reload tracking, in addition to syntax, source-level contracts and credits tests. Do not call mock contracts in-game PASS. Run user visual tests for collector, compartment before/after reload, search keyboard + wheel, tooltip/resize, movement Peek, Search during theme refresh, and combat.


## Patch Notes — visual concept authorized, November 19, 2026

- User-approved in-game concept: add a Patch Notes rail button between Community and Options; keep the existing gold Duels shell, navigation proportions, title treatment, footer, and search.
- Implementation on develop: separate Latest Update and Previous Updates pages; branded demo banner, readable update cards, optional deep links to existing searchable settings, gentle hover and entrance effects, shared scrollbar, and a pulsing unread rail dot.
- Demo entries are **fictional**, deliberately marked DEMO NOTES and not counted as actual releases or completed features. Replace with factual approved release notes before publication.
- Unread state uses a stable content ID rather than test-build version metadata; saved once account-wide through Core/Settings.lua. Patch reminder is a toggle under Options → Interface, not a preference hidden inside the Patch Notes page.
- Shared Motion/Widgets/Search/Navigation/Settings own behaviors. Native dot alpha animation runs only while shown, and respects Reduce Motion. Patch prose is excluded from the settings search registry.
- Validation status: IMPLEMENTED/UNTESTED. In-game check both clients: sidebar placement, latest/history scroll/resizing, active/hover feedback, reminder after first view and /reload, disabled reminder, reduced motion, View setting link/scroll highlight, Escape/chat focus, fold/peek, scale, optional theme/font integration.


## Patch Notes visual revision and version navigation — authorized November 19, 2026

- Approved player screenshot and upgraded design: fixed the Patch Notes rail text with a matching, stacked PATCH / NOTES label and replaced the generic WoW scroll with a locally authored Duels gold-scroll atlas icon.
- Added original TGA media art: PatchNotesAtlas (scroll, parchment, cog, crossed blades) and PatchNotesHero (dark engraved banner with Alliance/Horde colors). Real text remains UI text rather than baked into the banner.
- PatchNotesData.lua owns the ordered, stable release IDs and demo version labels. Navigation auto-creates a searchable sidebar subpage per version; PatchNotes.lua renders the selected version without a second animation, scroll, search or settings owner. New versions require a new reviewed data record, not a new nav implementation.
- The demo labels v0.1.2, v0.1.1, v0.1.0 are EXAMPLES ONLY and do not reflect the installed addon version. No TOC version change, tag, release, or main-branch modification.
- Latest-only mark-read keeps older version browsing from clearing a newer update. Read reminder remains in centralized Options; feature rows only react if their Search target exists.
- Status: IMPLEMENTED/UNTESTED IN-GAME until screenshots and manual checks confirm the custom art, label font/line fit, menu resizing, scroll, older version selection, action link, theme/animation, reload persistence, and client compatibility.

## Deferred Polestar inspiration backlog — November 19, 2026

**Decision: IDEA / DEFERRED — NOT BUILD AUTHORIZED.** Save all 30 ideas from the Polestar-vs-Duels Options and settings audit, but implement **none yet**. The addon is still missing core dueling/gameplay features. These are reference IDs, **not priorities, approvals, promises, or a development roadmap**. Do not infer build permission from this documentation.

Before implementing an item in the future, first re-audit the current Duels code to avoid duplicating an existing feature, inspect the relevant Polestar source and other approved references, design the behavior and UI, request separate approval and perform appropriate in-game tests. Polestar patterns are references, not automatic requirements. The audit was made against the UI-only Duels foundation and Polestar 0.4.1.1.

### Current-interface improvement ideas
1. **Lock the interface:** Prevent accidental moving and resizing; optionally lock the floating widget separately.
2. **Undo changes and resets:** Let a player reverse a recent reset or reversible settings change; reuse existing Settings ownership.
3. **Interactive live previews:** Show a small real-looking example of the relevant interface setting, never simulated as actual gameplay evidence.
4. **Minimap right-click quick menu:** Quick access to Duels, Patch Notes, Lock and Options; preferences stay in the central Options area.
5. **Smarter search:** Typo forgiveness, matched-word highlighting and easier browsing of long results; do not reimplement the existing search registry and result navigation.
6. **Combat fade or hide:** Get the full menu out of the way during combat while respecting Blizzard restrictions and future match-critical widgets.
7. **Background opacity:** Control the dark panel backgrounds separately from Peek, retaining readable text and the gold frame.
8. **Hover-to-highlight:** Briefly identify the actual widget controlled by a setting when hovering over its Options row.
9. **Exact slider input:** Type a numeric value with existing minimum, maximum, step and SavedVariables validation.
10. **Open Duels keybind:** A configurable shortcut that leaves Blizzard chat and combat bindings intact.
11. **Blizzard AddOns settings entry:** Simple entry opening Duels' own Options, no duplicate settings system.
12. **Copyable bug report summary:** Read-only client/addon diagnostic text with sensitive details excluded.
13. **Snap to screen edges:** Optional guides when moving a window or widget.
14. **High-contrast text protection:** Keep text readable after custom/EllesmereUI color changes.
15. **Separate heading and description text sizes:** More typography control without scaling all text together.
16. **Text shadow options:** Readability alternative to our existing text outline choices.
17. **Animation speed:** Slow/Normal/Fast with existing Reduce Motion respected, not a new animation engine.
18. **Back to Top:** A contextual shortcut on long scrollable pages.
19. **Custom accent selection:** Restrained interactive highlights while keeping Duels' recognizable gold framing.
20. **Modified-settings indicators:** Clearly show which sections differ from defaults; optional contextual Reset Section.

### More substantial ideas for later

21. **Appearance presets:** Cohesive visual configurations, not a sprawling skin marketplace.
22. **Personal UI profiles:** Named account/character layout presets with optional export; never mix with real dueling records.
23. **Unlock/arrange mode:** Outline movable widgets, grid/snap and Undo when Duels has multiple movable match elements.
24. **Shared notification system:** Consistent position, timing, animation and sound for future *verified* duel events.
25. **First-time onboarding:** Guided introduction when core features are finished enough to explain.
26. **What's New after real updates:** Show a one-time release summary through existing Patch Notes; demo notes must not be presented as releases.
27. **New-version detection:** Only with reliable release metadata and tested peer communication; no invented version proof.
28. **Gamepad navigation:** Focus and input support without interfering with WoW binds.
29. **Localization:** Translation-friendly text and adaptable layouts when multiple languages are maintained.
30. **Optional performance diagnostics:** On-demand own-addon analysis for future gameplay/networking, no permanent profiling.

### Explicitly deprioritized / avoid

- No Polestar questing, leveling, map or travel systems: unrelated to Duels.
- No dozens of redundant visual sliders, full skin marketplace or complicated wizard during the current foundation stage.
- No multi-widget arrangement editor without multiple real Duels widgets.
- No speculative rank, sync, peer-update or matchmaking claims before WoW API verification and real tests.

### Revisit gate

Prioritize the missing core dueling and player-facing functionality first. Keep the currently approved Patch Notes design and demo content untouched until real release notes are available. When core features mature, revisit these ideas one by one only if they solve observed player problems. **No code, TOC, UI settings, tests, releases or main-branch changes are authorized by this backlog.**

## Blizzard AddOns landing — authorized Nov 19 2026

- Minimal native Settings > AddOns page with the Duels gold logo, short description, and exactly TWO buttons: Open Duels Reimagined and View Community. No character card, diagnostics, fake release number, or separate settings UI.
- UI/BlizzardSettings.lua is an external launcher only; it reuses the existing Window, Navigation, Style, Chrome, Motion and Tooltips. Blizzard owns the outer Settings shell and normal menu controls.
- **Optional EllesmereUI integration:** reuse existing Theme.Refresh and Style.ApplyTheme for matching accent, panel and font when supported/enabled; preserve the standalone Duels gold visuals otherwise. Refresh on display and on appearance changes through the existing owner. Do not call an Ellesmere Shell or register a duplicate skin.
- Safe panel handoff: close Blizzard Settings outside combat, then show Duels; View Community selects its real Community page. In combat, leave protected Blizzard UI alone and give manual /duels instructions.
- Status: IMPLEMENTED / UNTESTED IN GAME. Test Forever and Retail, with/without EllesmereUI, theme matching ON/OFF and live changes, button navigation, Fold, Escape/chat/Game Menu, combat, small settings window, tooltips and /reload. No TOC interface or version bump, no main/release change.

## Approved Option 5 main-window header — authorized November 19, 2026

- Replace **only** the main Duels window's earlier small Alliance/Horde header image with the exact approved Option 5 design: large gold DR monogram, thin vertical gold divider, and two-line DUELS REIMAGINED wordmark with a subtle red flourish. Source: crop/extraction from the user-selected five-option concept comparison; keep the unique art independent of the rest of the UI.
- New isolated, transparent, power-of-two (512x128) `Media/Concept/Option5HeaderLogo.png` preserves the approved DR artwork. The image's logo is cropped with 420x102 inner UV coordinates. `UI/Window.lua` retains the existing responsive brand area, resizing only when space is constrained and remaining clear of Search, Peek, Fold, Menu Scale and Close.
- **Do not change the Blizzard Settings landing logo:** `UI/BlizzardSettings.lua` keeps `DuelsReimagined-HeaderLogoFlat.png`, whose faction artwork fits that page. All other buttons, sections, settings, motion, footer, title/empty states, saved data and scripts remain as-is. Prior wordmark approvals are superseded only for the main header.
- Source graphic was created within the project's image concept workflow; no Polestar art or code is copied. Polestar's responsive header-space pattern was inspected as an architecture reference. No new customization settings, independent renderer or animation machinery.
- Status: IMPLEMENTED/UNTESTED IN-GAME, not verified. Test appearance with WoW Forever and Retail, 100%/65%/120% Menu Scale, resized window, Peek, Fold, EllesmereUI matched/unmatched style, font settings and Blizzard landing screen. Revert to the prior logo if legibility or scaling breaks. No version/TOC bump or main-branch changes.

## Compact default window and Option 5 clearance — authorized November 19, 2026

- User-approved live screenshot: the bottom-right resize grip's existing **smallest allowed size** is preferred as the new first-load/default main-window size, not Polestar's former larger 1300×946 starting dimensions.
- `UI/Window.lua` uses its **single geometry owner** for both resize bounds and default dimensions: **1050×650 WoW UI units**, independently clamped to the available screen after Menu Scale. This preserves small-screen safety and the existing custom window dimensions stored through the Settings owner.
- The footer **Reset window** and corner right-click Reset Size now return to that same compact default. The footer no longer treats an older saved **1050×650** window as modified when Menu Scale is at its default; true custom dimensions and custom scale remain resettable. No SavedVariables migration or data deletion.
- Approved **Option 5** header logo is reduced slightly in height from 106 to **96 UI units** to prevent crowding/clipping against the gold border. Its crop, artwork and responsive placement remain unchanged; Blizzard AddOns landing logo remains separate and untouched.
- TEST: first load with no saved size, old saved min, larger custom size, footer Reset, corner right-click, 65%/100%/120% scale, smaller screen, resize grip, header Fold/Peek/Search, landing logo and /reload on both Forever/Retail. Keep other gameplay and UI behavior unchanged.
- **Status: IMPLEMENTED / AUTOMATED CHECKS PENDING / IN-GAME UNTESTED** until the specified validations are actually run.

## APPROVED REDESIGN: Ivory & Plum / code-driven themes — 2026-11-20

- User selected the exact charcoal/plum horizontal navigation + ivory content concept from this chat (uploaded approved image e691f93b-cdde-478e-9f36-72605bf4f567.webp). This screenshot is a fixed visual comparison target, NOT generic inspiration. Exact in-game parity requires screenshot-based manual checks, not an automated claim.
- New default is Ivory & Plum. Shared Style.lua defines semantic palette roles (dark header/footer/tabs, light page sidebar/content, text, borders, buttons, selected and hover); two optional TEST recolors are Midnight Slate and Forest & Ivory. Core/Settings.lua is the only SavedVariables owner: validated uiTheme property defaults to ivory. New searchable Color theme selector lives ONLY at Options > Appearance. No second UI engine.
- Optional EllesmereUI integration is still owned by Theme.lua. Existing optional RegisterSkin contract and Match Colors/Match Font preferences feed the SAME roles, recoloring panels, text, tab backgrounds, accent details and buttons as well as fonts. It must remain fully optional with readable contrast. Source reference: Polestar Theme/Theme.lua, Theme/House.lua, Theme/Widgets.lua, docs/SKINS-API.md, Polestar_Options/Theme/SkinPicker.lua. No Polestar runtime dependency or source copied.
- Main Window.lua layout changed to dark compact header, horizontal Hall/Community/Patch/Options tab strip, pale page sidebar, broad pale content region, dark utility footer. Chrome.Shell, Divider, selection and Style.Action are composed from small code-driven texture-region fills/lines. Authored DR logo, icons, crossed swords, and faction marks remain small purpose-built assets; large Patch Notes hero image is retired from rendering.
- Reused existing ownership of Search, Header Peek/Fold/movement, Motion, Settings, Options, Footer Reset/Reload, Community and Community links, Patch Notes reminders/history, Tooltips, minimap/widget, Discord placeholder and Blizzard Settings two-button launcher. No new gameplay data or claims, no TOC version bump, no main branch or release.
- Rollback baseline: develop SHA 1d6200189fe13284467c6d666793f1b95090d108. Status: IMPLEMENTED/UNTESTED IN GAME. Required: test full UI load, no Lua errors, 1050x650/resized window, header Fold/Peek/Search/Enter/Escape, settings typography/toggles/slider/dropdown, all three themes, reload persistence, Ellesmere match ON/OFF + not installed, Community link flow, Patch Notes selector/reminder, minimap/widget/compartment, footer reset/reload, Blizzard landing, combat safety, Forever/Retail client. Report visual differences with actual screenshots; concept is not inherently achievable pixel-perfect through native WoW primitives.

## Premium 3D skin pass — approved November 20, 2026

Approved visual goal: reproduce the ivory/plum concept's premium bevels, capsules, soft shadows and polished surfaces while preserving the already-approved geometry and every feature. It is the fixed visual acceptance target, not merely inspiration. Exact fidelity requires in-game screenshot comparison.

Architecture: UI/Style.lua remains the ONE skin/color owner. New Media/Skin/NeutralMasks.tga is a power-of-two 128x128 RGBA atlas of four neutral white/alpha masks (rounded face, upper sheen, lower shade, border rim). Nine-slice texture regions are vertex-tinted via Style.color, with motion-compatible GetAlpha/SetAlpha groups. No painted texture copies for each theme. Theme.Refresh/Style.ApplyTheme also preserve region alpha on repaint, so hover/selected state does not break during Ellesmere recoloring.

Shared kit applies to shell/header, horizontal navigation, sidebar/content, footer, Search, options cards, community panels, patch notes, dropdowns and the Blizzard AddOns two-button landing. Purpose-built DR logo, icons and watermark stay intact. Grip becomes drawn lines, keeping its resizing owner. Existing Header Peek/Fold/Search, Motion, footer Reset/Reload, Community, Patch Notes, Settings/SavedVariables, input focus, combat safety and minimap controls are not rewritten.

Reference inspected first: Polestar Theme/Theme.lua, Theme/House.lua, Theme/Widgets.lua and docs/SKINS-API.md. Use its role-based paint and refresh principles without copying its entire skin engine. EllesmereUI's documented SetVertexColor use also informed the neutral atlas. Keep the ONE existing optional RegisterSkin integration with match options and full theme recoloring.

Rollback baseline: develop 3167cb00341e768c6d6efa8649be374081676ec6. No main branch, release, version bump or gameplay features changed.

Status: IMPLEMENTED/UNTESTED IN GAME. Verify Lua 5.1 syntax, existing runtime and regression tests, atlas dimensions/transparency, then inspect all three themes and Ellesmere matching ON/OFF in Forever/Retail. Test hover while recoloring, buttons, search edit-box contrast, Fold/Peek, resizing, Reset, /reload, all pages, tooltips, dropdowns, Blizzard landing, combat, reduced motion and focus. Visual parity is NOT VERIFIED until screenshot comparison.

## APPROVED NAVIGATION HIERARCHY — bottom concept / Nov 20, 2026

User selected the BOTTOM image of the side-rail concept comparison, not the top. Hall must be the **only current primary** item in the horizontal top gameplay-navigation strip, leaving space for future actual game systems (no placeholders). Community, Patch Notes and Options are *secondary* and live in a slim premium, vertical utility rail on the FAR LEFT of the body; a distinct pale page/sidebar panel sits immediately to its right, followed by content. This is an approved, authorized visual/layout change, not a gameplay feature change.

Window.lua owns the geometry: the separate premium dark utility frame is a child of Window.body (it therefore hides with Fold), width 78 UI units; the contextual page nav stays independent at width 210. Existing premium code-driven/tintable Style.Skin and Chrome.Divider render all rail backgrounds, selection and hover; do NOT reintroduce flat buttons or paint-specific artwork. Navigation.lua remains the single owner for all four destinations, section/page state, search registration, patch reminder and reduced-motion animation. Only `primaryKeys = { hall = true }` enters the horizontal row. In the future, new primary tabs can be promoted only after their real pages are implemented.

The `FitTabs` handler acts ONLY on primary buttons. Utility icons are vertically stacked, small, with two-line Patch Notes, visual dividers and the same motion/tooltip behavior as before. Do not duplicate settings or network owners. Preserve Search, Header Fold/Peek/keyboard focus, Footer controls, Options/theme selector, optional EllesmereUI recoloring, current SavedVariables, /reload, combat, and minimap/widget/compartment controls.

Relevant Polestar research: UI/GuideFrameTabs.lua renders only real tabs using available-width measurement rather than fake blank tabs; UI/GuideFrameMenu.lua separates menu actions from navigation; Theme/Theme.lua uses palette roles for recoloring. We adopt the ownership/semantic ideas, not its source or UI assets.

Status: IMPLEMENTED/UNTESTED IN GAME until verified. Required WoW check: default and min/resized window, selected Hall and each utility page, scrollbar/card fit in narrower content, search jump to secondary page, Patch Notes unread dot and reduced motion, Fold hides the utility rail, Peek and scale, all three themes and EllesmereUI matching, footer/reset/reload, chat Enter/Escape, Blizzard landing and combat. Automated checks do not prove actual gameplay behavior. Baseline before this change: develop 88357404f177128e8aef77b3b6650236623bbea3. No TOC/release/main changes.

## Premium polish and palette expansion — authorized November 20, 2026

Visual bug report: in-game screenshot showed clipped COMMUNITY text in narrow secondary rail, a transparent world-visible band between shell and contents, sharp/not fully integrated corner appearance, and a primitive three-line resize handle. User additionally authorized two theme choices and disabling manual color-theme selection whenever effective EllesmereUI color matching is ON.

Code/UI changes: Window.lua renders a fully theme-driven rounded root skin (with Style.Skin) beneath all content, inset remains 6 UI units to keep square inner bands INSIDE rounded corners. The root is now visibly filled to the rim, not transparent. UI utility rail widened 78→98, its buttons 70→90 and label 68→88, keeping Hall-only top primary navigation and the separate 210-unit subpage sidebar. Resizer uses existing Style.Skin + tinted embossed strokes, background/hover/pressed feedback via existing Motion.Fade and Motion.Stop, and prior left-drag/right-click/resize/tooltip/fold contracts remain. No new atlas, PNGs, SavedVariable owner, or animation driver.

Added independent complete semantic color palettes 'Obsidian & Ember' (dark copper) and 'Moonstone & Violet' (light violet) alongside existing Ivory & Plum(default), Midnight Slate, Forest & Ivory. Validation for persisted uiTheme now uses Style.IsTheme from one centralized palette owner instead of duplicating allowlists in Settings.lua. Unknown saved themes fall back safely; existing theme keys/data remain unchanged.

In Options → Appearance, if **both** Theme.IsAvailable() AND effective Settings.Get('matchColors') are true, themeChoice displays 'Managed by EllesmereUI' and SetAvailable(false, explanation). Turning matchColors off re-enables the picker with the previously saved theme unchanged, no reload. Match Font is independent. The existing Theme.Refresh and Style.ApplyTheme remain owners. Tests target this interaction and five complete palettes.

Reference review: Polestar Theme/Theme.lua + Theme/Widgets.lua (role-based repaint and disabled-control semantics), UI/GuideFrameTabs.lua (compact label fitting). No code or graphics copied. Window appearance remains tintable for EllesmereUI through C tokens.

Status: IMPLEMENTED/UNTESTED IN GAME until WoW checks; desktop proof only Lua/CI. Required: display all utility labels at default/min and font size up to 120%, verify filled corners never spill outside frame, hover/press/drag/right-click grip, then five themes and Ellesmere installed/absent colors on/off including stored-theme restoration; check all pages, scrollbar, Fold/Peek, Search focus, Escape/Enter, minimap, Reset/Reload, gameplay, combat and both clients. Do not bump TOC/release or main. Rollback baseline develop cb2e08e6bf999f58773615f5f2dfdab7fd68d463.

## Resize grip and default burgundy typography polish — 2026-11-20

Approved focused fix of TWO screenshot-observed visual regressions in one update. The grip had a large permanently visible 34px skinned square, visually separate from our outer frame. Keep the original invisible 34x34 mouse drag target and mouse safety. Draw only a 26x26 engraved neutral glyph inside the corner. New Media/Skin/ResizeGlyph.tga is 32x32 white/alpha; Style.TintedImage ties it to the existing ONE color owner and EllesmereUI live theme repaint. Existing Motion.Fade handles small hover and press glow; OnHide and Fold cleanup also stops glyph fading. No new animation polling, code engine, version bump or gameplay change.

Default-theme red/plum typography: remove historic per-widget forced outlines from light-panel Community, Patch Notes and shared tooltip titles, while keeping existing semantic colors, typography hierarchy and user-controlled Options > Interface > Text outline preference (none, outline, thick). This addresses muddy dark strokes alongside otherwise clean Hall/Options text; explicit user font outline settings continue to override defaults.

Polestar reference reviewed: UI/GuideFrame.lua uses small corner grabber with hover feedback, Theme/Widgets.lua preserves sizing callbacks, Theme/Theme.lua manages outline/shadow styling centrally. No direct code or image reuse. Verify in WoW: screenshot closed grip at rest / hovered / dragging; right-click reset, Fold, reduced motion, theme recolor across 5 themes and optional Ellesmere, Search/Enter/Escape; check default Community and Patch titles for clean burgundy text, explicitly select Outline then return Default. Status IMPLEMENTED/UNTESTED IN GAME. Rollback SHA: 280f0a70f940d24629cbf4e43c613c03c43c2a20.

## Approved new Option 5 wordmark + resizing-stable shared dividers — 2026-11-20

User selected the BOTTOM fifth logo in the NEW five-logo concept sheet, not the older file named Option5HeaderLogo.png. The approved design is a one-line premium serif DUELS (gold) REIMAGINED (pale) with a fine angular underline and centered gold diamond. No DR monogram. Reproduce it only in the main header; the Blizzard Settings landing uses its established distinct faction logo.

Asset: Media/Skin/HeaderOption5TintAtlas.png is one 256×256 transparent indexed/tRNS PNG, neutral white with three independent 256×64 alpha-mask bands (gold word, pale word, gold diamond/underline). UI/Window.lua uses three Style.TintedImage regions on the existing responsive brand frame, with C.gold and C.headerText palette roles. All five Duels themes and optional EllesmereUI matching recolor the logo live; no color-locked background artwork or font files. Width capped at 280, height 70, aspect 4:1, left-aligned, still leaves room for Search.

Bug: Community/side page/central heading/card decorative horizontal hairlines became invisible on some single-pixel resize steps. Root suspected: 1 UI-unit colored strokes centered at fractional render positions. Before edit reviewed Polestar Theme/Widgets.lua W.Divider and Theme/Theme.lua Theme.Pixel; these use white-pixel textures and effective-scale pixel sizes. Our single owner UI/Chrome.lua now creates 2 physical-pixel theme-tinted WHITE8X8 rules with reduced alpha and snap-to-pixel-grid; Chrome.Refresh reapplies physical width on theme/scale changes, Window.ApplyScale calls this. No new OnUpdate/permanent polling, duplicate engines, page layout, game logic or SavedVariables changes.

Status: IMPLEMENTED/UNTESTED IN GAME; run available Lua 5.1 syntax, Search/SavedVariables runtime, regression tests. In WoW resize one pixel at a time on Community/Options/Patch Notes at different menu scales, confirm dividers stay visible and diamond centered. Inspect logo spelling/alignment at default and min window widths, all five themes and EllesmereUI matching, and no overlap with Search. Confirm the existing Blizzard Settings logo remains. Screenshot concept fidelity remains unverified until manually compared. Rollback from develop SHA 4750b09e9af9d3ba1d9490af6d152c8b76589ff9; do not change main, TOC/version or release.

## Compact page density, wordmark alignment and secondary icon legibility — Nov 20, 2026

Approved one-pass visual refinement based on two actual WoW screenshots. The current Option 5 DUELS REIMAGINED wordmark is somewhat narrow and the letters sit high relative to the underline. The 90x90 secondary utility buttons have small, off-center icons/labels. Appearance, Interface, Community and Patch Notes waste too much vertical space.

References consulted first: Polestar UI/GuideFrameTabs.lua (size a glyph and label to fit), Theme/Widgets.lua (shared row metrics/interaction affordances), Theme/Theme.lua (palette-aware text state). No Polestar source or artwork was copied.

Changes: Window.lua retains the single theme-tintable Option 5 atlas and its Search-aware brand area, increasing the wordmark width cap from 280 to 312, with a 4.65:1 display aspect and small independent vertical offsets for letters and underline. Blizzard Settings landing logo remains separate. Navigation.lua enlarges secondary icons to 35 and labels to 12 with a vertically centered 36-unit text area, fits two-line Patch Notes, and makes selected subpage text use high-contrast C.tabText against plum. Secondary button behaviors, unread reminder, active/hover animations, tooltips and Hall-only top primary row are unchanged.

Density: Widgets.lua only reduces setting row heights (toggle 56 to 54; choice 74 to 66; slider 72 to 64); button, slider and dropdown interaction sizes/owners remain untouched. Options.lua repositions rows and accompanying search offsets, and reduces Appearance content 405 to 303 and Interface 1365 to 1055. Community.lua makes action buttons and the two-column cards shorter (214 to 155), overview canvas 694 to 523, and detail list shorter while preserving real, local GitHub credit data and links. PatchNotes.lua reduces oversized heading space, banner 155 to 118 and rows 92 to 82 (pitch 104 to 90), with footer positions recomputed per version, retaining linked setting jumps, history, reminders and DEMO labels.

Purpose is to fit more content at the approved 1050x650 compact size without making text illegibly tiny. At larger font scaling or with longer translations, scrolling may still be necessary. All five themes and optional EllesmereUI matching should continue to work via the existing shared skin.

Status: IMPLEMENTED/UNTESTED IN GAME pending 7 new source/layout regression tests, full CI, then user WoW check: verify centered wider logo not overlapping Search, secondary buttons centered at 100% and large font, readable selected subpages, Appearance no endless scroll, Interface settings/search/reset, Community 2x2 previews/detail lists and link dialogs, Patch Notes banner/history/scroll/links, five themes and EllesmereUI ON/OFF, Fold/Peek, resize, Enter/Escape focus and combat. No new gameplay, storage owner, permanent polling, TOC bump, release or main branch updates.

Rollback develop baseline: 5167ea5d7e47093f1bdaeea3bb6393150e9a50fc.

## Emergency secondary-rail recovery + simplified logo ornament — 2026-11-20

**IN-GAME REGRESSION REPORTED:** After last successful CI, live WoW screenshot shows only an inert Community tile and blank utility rail where Patch Notes/Options should be. Cause identified in UI/Navigation.lua: `label:SetJustifyV("CENTER")` is an invalid WoW FontString justifyV enum (valid values TOP/MIDDLE/BOTTOM). It runs during the first secondary button's creation, before its OnClick handler, halting navigation initialization and preventing remaining utility buttons and page Search registration. Lua 5.1 syntax CI was green because this is a runtime API violation, not syntax. Relevant Polestar-first comparison: Theme/Widgets.lua and UI/GuideFrameTabs.lua use game-proven glyph+label layouts and shared tab widgets; verified FontString justifyV values against WoW UI API documentation. No Polestar code copied.

**Fix:** Change to `SetJustifyV("MIDDLE")`. Keep the established 90x90 utility clickable buttons but make icon frames 43 (was 35), labels 11 (was 12), shift icon top -7 and gap -2, adjust label area to 32, giving visible yet balanced two-line Patch Notes label. Preserve all section order, OnClick handlers, animation, hover, tooltips, unread badge, search integration, future Hall-only primary tab design, and single Navigation owner.

**Logo polish:** User likes centered DUELS REIMAGINED wordmark but wants no central diamond and wants its paired underline lower and balanced. Keep existing lettering/position/width and alpha-mask file unchanged; remove the third atlas layer entirely from actual drawing. Make two **equal and symmetrical** coded 2-unit lines with C.gold/alpha 0.66, starting 12 units from each side and separated by a centered 18-unit gap. Anchor in a small frame 3 units lower than the wordmark bottom; no bent ends, no new media, no new theme owner. Existing Style.Fill recolors with all five Duels themes and EllesmereUI. Blizzard Settings faction logo still untouched.

**Regression prevention:** New `test_secondary_rail_recovery.py` guards vertical justification enums across all addon Lua files, section construction, OnClick registration after valid text layout, utility proportions, logo symmetry and theme ownership. Update previous positive tests to assert the revised, approved layout rather than stale metrics. Prior CI (commit 8ae2c552) had 87 automated PASS yet failed live due to this missing API test. Do not claim those CI checks prove live client behavior.

**Status:** IMPLEMENTED/UNTESTED IN GAME until green full CI followed by manual WoW test. Required: completely restart/reload and ensure all three dark secondary buttons appear and can be clicked; Community opens Circle, Patch Notes versions and reminder work, Options Appearance/Interface open; hover/click animation, tooltip and Search navigation; test 100%, 150% text, min window size, theme/Ellesmere matching and logo balanced line; test Peek/Fold/chat Enter/Escape/resize. No TOC, SavedVariables, game features, main branch or release changes.

Rollback last automated-success baseline `8ae2c5526da678e680471e063ca4c9b861920189` (note its in-game regression is now identified); for last user-seen functioning sidebar, compare prior approved screenshot/source history before this baseline.

## One authorized responsive-settings and brand/navigation polish update — 2026-11-20

User approved ALL in one batch: remove both main-logo underlines but keep centered text, put that SAME wordmark in Blizzard's AddOns landing (rather than older faction logo), ensure Hall has a visible idle premium border, replace the mismatched Patch Notes parchment bitmap with a coherent theme-tinted icon, add explanatory text UNDER Color theme for manual/Ellesmere/unavailable modes, and replace fixed-height one-column options lists with dynamic one/two-column responsive settings rows like Polestar.

Polestar-first inspection (actual live GitHub next branch): `addon/Polestar_Options/UI/Options.lua` layoutRows at lines 1564–1609 and layoutSections at 1780–1841, `addon/Polestar_Options/UI/Controls.lua` row layout helpers, Theme/Widgets.lua for shared input interactions. Polestar measures available width, pairs controls only when wide enough, stacks when narrow, recalculates section heights. Adopt the useful behavior but not its code, looks, control ownership or complexity.

Duels implementation: UI/Options.lua retains ONE scroll owner per page, one Settings/Search owner and all existing settings and callbacks. At page scroll width >=630, each section may pair rows; smaller widths reflow to one column. Color theme and the state-specific explanation always span full width, matching toggles may pair; Interface behavior, typography and minimap controls pair where width allows. Card and scroll child heights recompute, search offsets updated to actual row positions. UI/Widgets.lua adds three shared LayoutForWidth methods for existing toggle/choice/slider classes, placing a dropdown/slider BELOW its caption/description when paired so no overlap with text; popups/tooltips/reset remain the same. Only scroll frame OnSizeChanged and OnShow reflow; no permanent polling. No new SavedVariables or gameplay changes.

Main Header wordmark still uses the same two independently-tintable alpha-mask layers from HeaderOption5TintAtlas; no ornament layer or coded underline. BlizzardSettings.lua now uses the same two-color palette-based wordmark rather than old HeaderLogoFlat asset. Landing keeps ONLY its existing two actions, Community and Open Duels, combat checks and responsive scaling. Hall's unselected button has a low-intensity C.rail/C.goldDim premium skin beneath the existing hover and selected skins. Patch Notes icon uses small gold/recolorable programmatic scroll details instead of unmatching PatchNotesAtlas; unread pulse remains unchanged.

Color-theme helper text three states: manual Duels palette active (matching off), EllesmereUI controls palette (matching on, dropdown disabled), Ellesmere unavailable (matching controls disabled, manual Duels dropdown active). Existing manual choice remains saved when matching turns off. Keep theme and font matching independent and honor Ellesmere registration/skin refresh.

Status: IMPLEMENTED/UNTESTED IN GAME until automated full CI and user WoW verification. Test in-game: both logo placements, all 5 themes, Ellesmere ON/OFF/absent, Hall resting/hover/selected, Patch icon and reminder, default/near-min and enlarged window one/two-column reflow, no text/control collision at 75/100/150% text size, focus/chat Enter/Escape, scrollbar and wheel, Search to moved options after resizing, popups and resets, minimap/widget sliders, compartment reload, Fold/Peek, combat and character SavedVariables integrity. No TOC/version bump, main/release, gameplay, new engine or new texture assets.

Rollback baseline before the patch: develop 4495c83dd1d161dfa0f8aff27528ba9459b5e262.

## Responsive layout refinement after 102-test CI pass

After the initial 102-test pass, the paired controls still retained huge 96–102-unit heights, which did not meet the user's Polestar-style compactness goal. Shared Widgets.LayoutForWidth now makes paired control rows 54–56 units high. Long descriptions are hidden *only in paired mode*, with their same full text accessible through existing Tooltips on row or control; at one-column widths descriptions remain visible. Choice buttons shrink to a legible 112–140 width; sliders to 75–112. At fontScale > 1.20, two columns require 860 units of content width (rather than 630) to protect large text. Options.Refresh recomputes layout after font-scale changes. No new engine, polling, or persistence. Verify full text in tooltip, label alignment and control clickability in-game at 75/100/150% text scale.

## Whole-card compact Options repair — 2026-11-20

In-game screenshot regression: pairing individual SETTINGS within oversized
Window behavior / Typography / Minimap panels made control placement look
random and did not actually shorten the page. The user's clarified approved
behavior is a ONE-card-wide vertical stack at small window widths and TWO
complete SECTION CARDS side by side only when enough content width is available.
Each card retains its own header, setting order, tooltips, reset controls,
theme helpers, footer text, hover, Settings callbacks and Search destinations.

Polestar-first reference: Polestar_Options/UI/Options.lua layoutSections,
layoutRows and section-card measurements (next branch), and Controls.lua
section-card construction. Use measured section geometry, NOT Polestar's
two-settings-per-row behavior; no source/assets copied. Duels UI/Options.lua
remains the sole card/scroll owner. Single-column card list until scroll width
>=930; at >120% font scale require >=1080. A page with only one card stays
full width. At two columns, cards go in source order, row height is the taller
card, and scroll positions are recomputed/clamped after reflow. Within each
card, existing shared widgets display a compact ONE-LINE label and control;
detailed descriptions remain on the original tooltips. Shared row heights are
34 for toggles, 38 for dropdowns/sliders; existing normal fallback still
retains multi-line descriptions. Tooltip for disabled widget sliders reads its
current descriptive reason. Theme explanation and minimap position reset stay
inside their own boxes. No new saved settings, animation engine, polling,
gameplay, media or TOC bump.

Status: IMPLEMENTED/UNTESTED IN GAME. Verify at default 1050x650 window,
smallest allowed window and progressively wider resize; confirm each card
moves INTACT to two-column layout and back, no overlapping cards/text/dropdowns,
and shorter narrow scrolling. Check font 75/100/150%, manual and Ellesmere
themes, disabled widget tooltips, all widget sliders/pickers/toggles/reset,
Search jump/reflow, wheel/scrollbar, reload persistence, Peek/Fold/Enter/
Escape, and both Forever and Retail. Source contract tests updated; do not
interpret them as live-WoW proof. Baseline before this repair: develop
5bd0477cec2811d6185a62dea801679c9d250843.

## Extra-dense settings cards — requested live trial, 2026-11-20

The user verified that whole-section card reflow works, but supplied narrow and
wide in-game screenshots showing cards still taller than desired, asking for
roughly twice the visual density. Exact 50% card height is NOT possible without
clipping four actual controls plus a header/reset action. This conservative
experimental change keeps every control inside its original card, reduces
visible spacing significantly, and keeps two complete small cards in the
default viewport.

Polestar-first reference checked: Polestar_Options/UI/Options.lua
layoutSections/layoutRows and Polestar_Options/UI/Controls.lua SectionCard.
The useful principle is a compact header and measured rows/cards; no upstream
source was copied. Duels' shared Widgets retains Settings, reset, live slider,
dropdown, animations, tooltips, Search, theme, access-icon and compartment
contracts. Toggle rows shrink from 34 to 28; dropdown/slider rows 38 to 32.
A 38-unit heading area replaces the former two-line title/subtitle block;
secondary section descriptions and previously redundant footer hints remain
accessible on the section-header tooltip via existing Tooltips.Bind. The
EllesmereUI color explanation stays visible and grows with its actual string
height. The minimap Reset icon positions action remains visible in the same
card, with normal 34-unit click height. Card/row gaps and bottom margins tighten.
At fonts >120%, the original multi-line descriptive rows return to avoid
unreadable text. Full cards remain single-column at compact width and two-card
columns at wide width. No additional settings, assets or gameplay machinery.

Estimated 100%-font card heights: behavior ~160 (formerly 231), typography
~143 (formerly 206), minimap ~210 (formerly 289); the full narrow page is
about 535 tall vs ~756. This is NOT literal half dimensions; the visual target
is approximately two first cards visible together rather than only one.
Status: IMPLEMENTED/UNTESTED IN WOW. After pulling develop /reload: check
headers and hover explanation, toggle click targets, disabled reasons, choices,
sliders, icon reset, entire-card wide reflow, Search jumps after resize,
scrollbars, font 75/100/150%, all themes, Ellesmere ON/OFF, minimap and widget
live settings, Fold/Peek/Enter/Escape and combat. Neither mock/static checks
nor screenshots can substitute for live testing. Prior rollback baseline:
develop 241abcacbee92f4d9d14cb5d9c57c22939a94e85.

## Landing and minimap emblem replacement — approved November 20, 2026

Selected visual: the user's DR shield with crossed swords and laurels,
above a dark burgundy/gold nameplate reading DUELS REIMAGINED. The user
explicitly authorized extracting and installing exactly these two graphics.
Keep the addon name, tagline, original Open Duels Reimagined/View Community
buttons, footer, Blizzard Settings navigation and other UI untouched.

Polestar-first references: Theme/Theme.lua's independent brand colors,
and docs/DESIGN.md's brand lockup and power-of-two media. No Polestar
art/code is reused. Extracted user-selected concept artwork is separated
into fixed-color, transparent RGBA textures:
- Media/Brand/DuelsLandingEmblem.png (512x256) on Blizzard landing ONLY;
- Media/Icons/DuelsCrestIcon.png (128x128) on minimap and floating widget.

UI/BlizzardSettings.lua replaces the old tinted atlas with an independent
untinted texture, UV cropping unused vertical padding. The same themed
background, two actions and combat/tooltip behavior are preserved. The main
window header's Option 5 theme-tinted wordmark stays unchanged.
UI/AccessIcons.lua changes only the ICON media path; its shared minimap
and floating-widget machinery, color glows, hover/drag, collectors,
SavedVariables, and Search/Options are preserved. ## IconTexture in TOC
remains the old Blizzard AddOns-list icon, outside this scope. No new
settings/modules/animations and no main-branch release or TOC bump.

Status: IMPLEMENTED/UNTESTED IN GAME. Structural PNG/test checks run
on CI; user should test all five themes and Ellesmere match ON/OFF,
Blizzard landing logo fit/readability at native and reduced screen sizes,
both buttons, minimap crest clarity and hover/drag/collector, widget
24/42/128 size and opacity, /reload, focus and combat, Forever/Retail.
Rollback baseline: develop 6811448019612b7084e1bb7dee2ade5d7de73670.

## Approved landing background and original wordmark — 2026-11-20

The detailed DR-crest landing graphic failed live readability checks; the
user then rejected the new flat-assets color choices and explicitly selected
the ORIGINAL two-word header logo on the Blizzard AddOns landing instead,
with the header's dark charcoal-plum background as a single permanent color.
The screenshot's solid base sample is approximately #302B30; minor gradient
variations were intentionally not carried into this single-color decision.

Read-only Polestar-first reference: Polestar/Theme/Theme.lua keeps brand
identity outside its regular scheme recoloring, and tests contrast roles.
Duels' implementation reuses the EXACT HeaderOption5TintAtlas.png mask and
the same two UV bands as UI/Window.lua (gold DUELS; pale REIMAGINED), but
uses LOCAL fixed RGB tables rather than Style.color tokens, so changing
Color Themes or EllesmereUI never recolors the landing panel or its logo.
The landing subtitle and footer also receive fixed pale inks so they
remain legible on the permanent dark background. The existing two action
buttons and shared divider/tooltip/motion behavior remain theme-driven,
unchanged. The main-window header still follows its existing themes.
No new image files, architecture, settings, SavedVariables, or TOC bump.

The earlier crest files remain in Media for rollback only and are not used
on the landing page. The previously approved small minimap/widget icon and
the TOC AddOns-list icon are NOT changed by this targeted landing revision.
Status: IMPLEMENTED / IN-GAME UNTESTED. Verify with Ivory, Midnight Slate,
Forest & Ivory, Obsidian & Ember, Moonstone, and EllesmereUI matching
enabled/disabled: background and letter colors stay identical; text legible;
buttons still work, tooltip remains accessible, no clipping at small sizes;
main header continues theming; /reload/Enter/Escape unaffected.
Source baseline: develop 37e0e9af6db1aa1ec3b3bbc74c03adf292affe00.

## Landing buttons locked to brand gold — 2026-11-20

The user observed in-game that the now-fixed charcoal landing and original
wordmark were working, but both launcher buttons were still turning blue
from their active theme. Explicit decision: both landing actions have one
fixed muted-gold fill EXACTLY matching the "DUELS" letters, and dark ink
text for contrast. Preserve their names, placement, clicks, tooltips, hover
and press animations; leave theme-aware buttons elsewhere untouched.

Polestar-first reference: Polestar_Options/UI/Controls.lua has a centralized
button constructor (W.Button) and uses separate appearance tokens. Our
shared Style.Action remains the one behavior owner. Its optional private
palette overrides EVERY fixed paint role (fill/edge/light/dark/hover/text)
so neither Duels Theme.Refresh nor optional EllesmereUI recolors these two
buttons. No global skin override, duplicate action handler, additional
SavedVariables, new media, TOC bump, or unrelated minimap changes.

Status: IMPLEMENTED / IN-GAME UNTESTED. Test all five UI color themes,
Ellesmere color matching on/off; both buttons should retain identical
gold fill and dark legible text while other addon buttons remain themeable.
Hover, click, tooltip, Blizzard Settings handoff, keyboard chat behavior,
and /reload require live verification.
Rollback point: develop fb67017c4c1a309a1491875cafc4e55fc841fa66.

## Approved small-icon DR badge — 2026-11-20

The user chose the GOLD DR overlapping-letter rounded-square emblem from
five original minimap icon concepts, explicitly authorized the icon's
implementation for minimap, floating widget, and AddOns-list icon. This is
a specific visual choice, NOT permission to touch landing branding again.

Polestar-first check: Polestar.toc uses ## IconTexture for the addon-list icon.
Duels existing UI/AccessIcons.lua already supplies ONE shared texture path for
minimap, widget and AddOn Compartment; its movement/collector/hover/press/idle
lifecycle remains untouched. WoW-compatible explicit .png file path for both
the shared ICON and ## IconTexture. Selected source concept image contained a
dark studio backdrop; this was isolated away via its real gold frame silhouette,
preserving the same gold/DR/plum design, and scaled to an optimized transparent
128x128 indexed PNG at Media/Icons/DuelsDRIcon.png. Small-resolution previews
were inspected at 16/24/32/42/64/128 px. Prior assets remain committed for
rollback, but are not referenced by the minimap/TOC after this update.
Theme-color choices, landing buttons/wordmark, saved settings, gameplay,
frame ownership, and animation logic were not changed; no TOC version bump.

Status IMPLEMENTED / IN-GAME UNTESTED. Full WoW client restart is recommended
after pulling develop because the TOC IconTexture changed and new art was
added. Test gold DR badge around the minimap, at widget sizes 24/42/128,
and in AddOns list; verify the AddOn Compartment entry icon, left click,
drag, tooltips, hover, idle, icon visibility modes, live opacity/size sliders,
collector ownership, combat safety and /reload/relog. Source parser,
runtime and regression CI results do not prove visual clarity in WoW.
Rollback baseline develop 507f33c09800cbff17373d8a9ef42b826e5838c5.

## Navigation icon set replaced — 2026-11-20

User chose the 4-symbol icon-board screenshot (Hall crossed swords,
Community three people, Patch Notes scroll, Options gear) and explicitly
authorized applying its artwork inside the existing navigation buttons.
Source is the user's selected concept image, NOT Polestar/Blizzard art.
Icons were extracted from that image, backgrounds discarded, and packed
into a 128x128 power-of-two indexed RGBA PNG atlas, with four 64x64 cells.
A thin baked dark edge is retained for readability on bright themes.
Original proportions and fixed gold/ivory colors are retained; no theme
tinting or reskinned icon backgrounds.

Polestar-first source inspected: Polestar/Theme/Widgets.lua icon button
and media ownership; Polestar_Options/UI/Controls.lua W.Button. Principle:
a single icon renderer, button/hover behavior separate from decorative art.
Our Chrome.Icon owns atlas UVs, Navigation.lua owns icon+label geometry,
selection, motion, Search, Patch Notes unread status and button handlers.
No new settings, SavedVariables, gameplay, polling or TOC bump.

Only existing button contents change: utilities remain 90x90 with 50-unit
icon and 12-point label, 4-unit top pad and 30-unit label box. Hall remains
216x44 with 34-unit icon and 18-point label, anchored around the center
and still hides the icon when the header becomes too narrow. Colors of
buttons/borders/selection remain themeable; decorative glyphs remain fixed.
The older themed Patch Notes line renderer is removed.

Status: IMPLEMENTED / IN-GAME UNTESTED until reviewed in WoW. Test four
icons at compact/wide layouts, Ivory/Slate/Verdant/Ember/Moonstone and
EllesmereUI, including hover/selection/click, click hit areas, Patch Notes
unread badge, Search navigation, Fold/Peek, text scaling and /reload.
Potential risk: 12pt long "COMMUNITY" label with large UI font scales.
Rollback baseline: develop 4ae969deca1f83761cf8bc2634302829ac9b59c4.

## Minimap login visibility / collector ownership fix — 2026-11-20

An in-game screenshot showed that the fixed-color DR minimap icon could be
missing immediately after login until the player located/dragged it. Root-cause
candidates reviewed against Polestar's Maps/MinimapButton.lua and the actual
EllesmereUI-v9.8.9 minimap zip (EUI_Minimap_Buttons.lua,
EUI_Minimap_Layout.lua, EUI_Minimap_Lifecycle.lua).

EllesmereUI hooks collected Button:Hide()/Show() to track whether an addon
wants a button. It also hides the Minimap for its own visibility modes and
uses root button alpha to manage grouped flyout buttons. Duels previously
called miniButton:Hide() whenever Minimap:IsShown() was false, AND again on
Minimap OnHide; a temporary parent hide was therefore reported as the addon
disabling its button. Our lastMiniWanted flag could block the next Show.
Duels' idle root-alpha tween could also interfere with collector alpha=0.

A focused change in UI/AccessIcons.lua now derives minimap intent only from
PLAYER_LOGIN and the user's iconMode, letting the Minimap parent hide its
children naturally. There is no Minimap OnHide -> explicit button Hide hook.
When iconMode is turned off we still explicitly hide; when re-enabled we
explicitly show once. All later refreshes respect collection instead of
forcing visibility. Idle/Wake fade only the small minimap icon artwork, not
the root button's alpha; widget root opacity remains under widget settings.
The frame still exposes the named button and named Icon used by collectors.
No new permanent polling, EUI API calls, extra settings or texture changes.

Status: IMPLEMENTED / AUTOMATED CHECKS PENDING / IN-GAME UNTESTED. Verify:
1. full restart and /reload with EllesmereUI minimap enabled and DR minimap
mode; icon shows on the ungrouped row OR in the intended addon-button flyout,
without first having to drag it; do not expect a grouped button on the map.
2. EllesmereUI mouseover-hide / show the Minimap and zone loading: the icon
remains available and is not silently removed from flyout.
3. test grouped and ungrouped buttons, move positions, resize minimap,
no forced jump/reappearance; then switch minimap/widget/both/none and relog.
4. widget transparency and size, hover/press, tooltips, AddOn Compartment,
window open/close, input/combat and /reload remain unaffected.
This is code+source evidence only; WoW and true collector behavior still need
player confirmation. Baseline: develop 2f16d466f6d67f6e9c8969841192bd3ecb487fc1.

## Ellesmere initial minimap-button visibility snapshot — 2026-11-20

Player confirmed: standalone Duels DR minimap icon appears immediately
without EllesmereUI, but remains missing with EllesmereUI enabled after the
previous minimap parent-visibility correction (develop 9102a77). This
isolates an integration bug; no assertion of successful in-game repair.

Polestar-first reference: addon/Polestar/Maps/MinimapButton.lua lazily builds
the button when enabled and Shows it in its first refresh. Inspected exact
EllesmereUI-v9.8.9.zip source, especially EUI_Minimap_Buttons.lua:
GatherMinimapButtons scans named Button children of Minimap, recording
_addonVisible[child] = child:IsShown() ON FIRST DISCOVERY (lines 310-344);
HideMinimapChild suppresses tracking during its own Hide/SetAlpha(0), so
a false initial snapshot is not corrected by the collector's own hide
(lines 215-265). EUI's ADDON_LOADED handler scans for late addon buttons.

Duels had constructed the named button and called miniButton:Hide()
unconditionally before PLAYER_LOGIN. This can cause EUI to snapshot
the button as disabled even though saved iconMode == minimap/both. Duels
now uses the existing PositionMinimap() as soon as it is defined, then
sets the button's shown state from Settings.Get("iconMode") at addon-load
time (BEFORE the loader fires ADDON_LOADED), not first at PLAYER_LOGIN.
Mode "widget"/"none" remains initially hidden. The existing PLAYER_LOGIN,
PLAYER_ENTERING_WORLD, Minimap sizing, widget, collector ownership, drag
and compartment routines remain intact. No EUI private API calls, timers,
polling, SavedVariables edits, UI or artwork changes.

Status: IMPLEMENTED / IN-GAME UNTESTED. Automated tests model/check the
first-scan intended state and preserve mode transitions; EUI live scan
timing and final flyout presentation require real WoW observation. Verify
cold login and /reload with EUI minimap enabled: if EUI groups buttons,
DR should be available via its addon-buttons flyout; to see DR on the
button row, mark DR under EUI's Ungroup Minimap Buttons setting.
Check without EUI, all minimap/widget/both/none modes, minimap reload/
scale, icon drag, tooltip, hover, and AddOn Compartment. If still missing
with grouped AND ungrouped, STOP and inspect EUI's cached _addonVisible
and button parent in game before further edits, avoiding timer hacks.
Rollback baseline: develop 9102a772a1f20b6373e4b472942a56a0c866dca0.

## Minimap independent placement + Ember default — 2026-11-20

The user verified repeated failed attempts to restore the minimap DR icon
with EllesmereUI enabled (though it works without EllesmereUI).
Previous commits 9102a77 and 4d162f9 did not resolve the in-game issue.
Before touching code again, reviewed:
- Polestar/Maps/MinimapButton.lua, direct Minimap child + collector handoff
- EllesmereUI 9.8.9 EUI_Minimap_Buttons.lua first discovery
  (GatherMinimapButtons collects named direct Minimap/flyout children,
  hides/alpha-zeroes them) and lifecycle
- Narcissus MinimapButton.lua SetIndependent (UIParent-owned container,
  but anchored to Minimap) and old BurstFX's verified independent approach.

Approved direction: DuelsReimaginedMinimapButton now has UIParent as its
frame parent. Its CENTER anchor still follows Minimap shape/angle/size and
drag retains Settings.SetMinimapAngle; the icon is not a direct child that
EllesmereUI sweeps into a button flyout. Access.Refresh owns visibility:
mode minimap/both and Minimap:IsShown; explicit Minimap OnHide/OnShow hooks
restore that state because UIParent parenting does not inherit map hiding.
The AddOn Compartment registration, widget mode/size/transparency,
click/tooltip/motion, and saved angle are otherwise unchanged. No private
Ellesmere calls or permanent polling. Independent means the DR icon will
appear beside the minimap, NOT inside EllesmereUI's grouped flyout.

The user also explicitly approved **Obsidian & Ember** as the default
theme. Settings.GetDefault(uiTheme), fallback of invalid saved values,
initial Style.color palette, Style.FromTheme fallback and the Options
choice label/order now all use "ember"; Ivory & Plum remains an ordinary
selectable theme. A VALID EXISTING SAVED theme (including ivory from
previous versions) is preserved; it cannot be safely distinguished from
a deliberate choice. New installs and Reset choose Ember. The existing
optional EllesmereUI color matching still overrides the visible palette
when enabled; the fixed charcoal landing branding stays independent.

Status: IMPLEMENTED / IN-GAME UNTESTED. Automated tests and GitHub
Actions are separate evidence, not live verification. In-game checks:
1) With EllesmereUI enabled, restart WoW, icon mode Minimap, ensure DR icon
   is immediately next to map and does NOT need collecting/dragging;
2) /reload, login, minimap show/hide, minimap resize and drag persist;
3) without EllesmereUI, same tests; test Widget, Both, None;
4) check Options + Search + tooltips + AddOn Compartment and no Lua errors;
5) new/Reset theme uses Obsidian & Ember, existing valid saved theme is
   retained, Ivory/other 3 choices remain, matchColors on/off still works.
Previous baseline develop 4d162f9786a4e7b3692e47d832f298c58367e9d6.

## Premium visual skin families — 2026-11-20

Approved concept targets: Forest & Ivory, Ivory & Plum, Midnight Slate
and Moonstone & Violet are to become distinct premium skins, with
Obsidian & Ember preserved as the default. Architecture follows
Option B: two distinct *visual* shell families (crafted hall and sharp
arena steel) sharing the existing real navigation/resize/search/option
geometry and behavior, rather than two separate addon interfaces.

References inspected FIRST: Polestar Theme/Theme.lua built-in skin
palettes, Theme/Widgets.lua shared painting and the Polestar design
system; then EllesmereUI 9.8.9 Skin API; existing Duels Style,
Chrome, Window, Navigation, Options, Theme, and test fixtures.
The matchColors/matchFont public EllesmereUI integration remains the
single optional appearance adapter; matchColors recolors shared
semantic tokens and keeps each skin's own motif and frame geometry,
while user/third-party font selections override built-in heading styles.

Implementation: UI/SkinDecor.lua owns one 4-cell original transparent
RGBA motif atlas (one per non-Ember skin), individual role-specific
trim, seal, and background watermark treatment, and a skin-family
corner-radius resolver. Style.SkinMask adds a safe SetCorner operation
to existing 9-slice regions, not a second skin engine. All chrome,
navigation, card, and content surfaces attach visual-only decorations
that don't create buttons or intercept input. Theme.Refresh repaints
existing decorations without rebuilding any page. Options' existing
searchable 'Color theme' entry is renamed to 'Visual skin'; choices
and saved keys stay unchanged. No new settings, state, async drivers,
data or gameplay machinery.

Source images from user-approved visual concepts are REFERENCES, not
shipped screenshots or copied media. Artwork is newly authored and
small. The original Ember profile has uv=nil, radius=1, and shows
none of the new decorations, preserving its established appearance.
All pages, compact whole-card reflow, Search, Tooltip, Patch Notes,
Community and EUI color/font settings have ONE existing owner.

Status: IMPLEMENTED/UNTESTED until automated CI and in-game review.
Testing required: every theme Appearance/Interface/Hall/Community/
Patch Notes at compact and resized widths, folded/search/Peek/drag,
hover/selection, popup, /reload, EUI matching on/off, custom font,
no interception of clicks or combat restrictions, and confirm the
Ember default before/after is visually unchanged. Source-only checks
do NOT prove full concept-art fidelity. Do not add unapproved motion
or independent navigation owners. Baseline commit: 60e472f03efb90de1b88c8d3079946cc40ff8d3f.

## Premium skins visibility correction — 2026-11-20

IN-GAME REPORT from the player: initial premium visual skin build f1a5e6c
produced only mild changes and did not resemble the approved concept
screenshots. This is a real failed visual acceptance test despite the green
GitHub checks. Root-cause audit: each non-default theme had only one
low-opacity 64px motif (0.16-0.21) and a 1px line; surfaces still used
plain semantic palette fills, and Chrome.Icon used exactly one fixed-color
gold atlas for ALL themes. Also, the EUI color matching control disabled
the entire Visual skin picker even though EUI should own only colors.

Now each premium profile has a distinct surface material (original
compact 2x4 atlas: parchment, forest paper, etched steel, violet arcana),
raised perimeter framing, visible motifs and an original 4x4 theme/nav
icon atlas, with dynamic in-place repaint through the existing
Chrome.Refresh. The nav button idle face now belongs to SkinDecor,
attached BEFORE existing selected/hover layers. EUI still supplies
semantic colors and fonts through its existing API; when matchColors is
enabled, material opacity is reduced so its selected panel palette
remains dominant, but the Visual skin selector stays usable. Ember has
nil UV, no materials or additional resting faces/edges, and preserves
the original icon atlas. No extra gameplay, network or settings owner.

The new textures are custom compact PNGs, no concept screenshot assets.
Visual fidelity is still subject to in-game test; screen-level concepts
contain detailed illustrations not trivially reproduced by 64px tiles.
Regression tests guard new source/atlas paths, modes, layering order,
Ember fallback and picker interaction. Tests do NOT independently
prove visual completeness, client rendering, or absence of clipping.

Status: IMPLEMENTED / IN-GAME UNTESTED, CI results separate.
Test: update develop; full client restart for new texture assets,
check all 4 premium skins vs original Ember, content/secondary nav,
4 utility icons + Hall, selected/unselected/hover and resizing;
toggle EllesmereUI matchColors and change skin again; inspect color
contrast (esp light backgrounds), tooltip and clicks, dropdown
legibility, no UI errors, and unchanged original Ember; then send
screenshots of actual window.

## Premium skin experiment withdrawn — 2026-11-20

USER DECISION: Scrap the multi-layout/premium-reskin experiment and return to
the ORIGINAL FIVE RECOLOR-ONLY themes. The user reported the experiment
felt broken and excessive. The approved restored code baseline is develop
commit 60e472f03efb90de1b88c8d3079946cc40ff8d3f, predating premium
skin commits f1a5e6c and 57a2439. Their implementation and test changes
are REVERTED by restoring the original baseline Git blobs and removing
the three new visual atlases, SkinDecor.lua and premium-only test.
This is a NEW non-destructive rollback commit on develop (no forced ref
reset and no main branch change). Earlier premium proposals and records
above are historical and NO LONGER ACTIVE.

PRESERVED intentionally: independent UIParent-owned DR minimap button
compatibility with EllesmereUI, the fixed-color original DR/navigation
icons, central Options, search, widget, animations, the approved layout,
all existing color themes, optional EllesmereUI matching, and Obsidian &
Ember as the default. Existing per-player saved theme selections remain.

The active system is again Style.lua semantic token recoloring through
Theme.lua; no SkinDecor module, premium image atlases, premium icon
switching, or material backdrop changes. Validate a full WoW client
restart, theme switching, all buttons and tooltips, minimap with
EllesmereUI enabled, window scaling/reflow, /reload and input behavior.
Status: SOURCE RESTORED; CI/in-game verification must be reported
separately. This rollback follows player feedback, NOT a claim that
the abandoned concept was verified.

## Compact Hall tab and consistent utility separators — 2026-11-20

User screenshots revealed (a) the only primary Hall button retained an
overly broad 220-unit resting/clickable area despite a ~90-unit icon/text
group, and (b) the Community graphic included a small built-in gold
flourish above the heads, while the Patch Notes and Options breaks used
actual external dividers. Requested both adjustments together.

Polestar first: Theme/Widgets.lua W.SetButtonText measures text + icon
and uses fixed/tight padding instead of an arbitrarily broad button.
Our UI/Navigation.lua FitTabs previously reset the initial 216-unit Hall
button to 220. New HALL_BUTTON_WIDTH=156 caps the FitTabs slot and
sets the initial width consistently. Hall remains 44 tall with identical
34-unit sword icon, 18pt text, clickable hit area equal to the new border,
and unchanged hover/selection/click behaviors.

The existing original gold Community atlas cell in Media/Icons/
DuelsNavigationAtlas.png has an ornamental star-and-horizontal-line
in source rows 0..18. We did NOT regenerate or overwrite the approved
art asset: Chrome.Icon crops that ornament using the same texture with
a top UV starting at row 19. Navigation.lua adjusts only Community's
texture height and anchor to preserve the figures' original display
size, position, and the icon/label spacing. In addition, 44x8
Chrome.Divider frames now anchor TOP to the preceding utility button's
BOTTOM, aligning their center in the actual 8-unit gap between
90x90 buttons, instead of relying on a fixed utility-parent offset.
All dividers are non-interactive and outside the buttons.

No new settings, assets, media ownership, navigation state, polling,
or gameplay changes. Regression tests updated in navigation-icon and
utility-rail suites. Expected in-game: Hall button ends closer to its
label; Community shows only the group icon; matching diamond dividers
appear between Community/Patch Notes and Patch Notes/Options, including
hover/selected states, at different UI scales and /reload. Existing
Obsidian & Ember default, recolor themes, EUI integration, minimap,
search, widget, tooltips and layout remain unchanged.

Status: IMPLEMENTED/UNTESTED before CI and in-game evidence.
Rollback baseline develop 9abba02e9ed7b52fa15abe374a02396ff552698b.

## BurstFX presentation polish — 9 approved ideas (no audio) — 2026-11-20

USER AUTHORIZATION: implement nine BurstFX Build 1004 UI details together
except ALL UI sounds. The user explicitly requested the combined change,
but the existing premium-skin experiment remains abandoned. Preserve the
five recolor-only themes (Ember default), compact Hall, icon atlas,
independent Ellesmere-safe minimap launchers, real Blizzard chat
focus/combat restrictions, and current Settings/Search/Page ownership.
SOURCE REVIEW: Polestar Theme/Anim.lua (single idle motion driver,
reduced-motion snap), UI/WhatsNew.lua (versioned feature awareness),
UI/Toasts.lua (nonblocking feedback), then the actual Library ZIP
Handi's BurstFX v0.1.0 Build 1004bugfix.zip:
UI/UIMotion.lua (MoveSelectionIndicator, PlayPageTransition,
ShowContextPreview, ShowToast, FlashActionButton), UI/CustomSettings.lua
(PulseNavigationTarget, runtime return stack), UI/SettingsPolish.lua
(persistent discovery), UI/MinimapPersonality.lua (PlayNotificationBling).
Relevant current Duels modules independently cross-checked.

Implementation responsibilities and limits:
1. Patch Notes -> Search registered setting -> Options scroll/2-pulse
   gold outline, cancellation and reduced-motion static alternative.
2. One moving selection marker, still using Navigation as sole page owner.
3. Short horizontal divider glint ONLY on real page transitions.
4. NEW tags on NEW Back and widget-preview controls, with acknowledged
   account IDs owned centrally by Settings (not another DB).
5. One reused in-window toast on actual window layout reset.
6. Temporary confirmation on the existing reset-icon-positions action.
7. UI sounds deliberately EXCLUDED; no sound preferences or assets.
8. One ring ping on an actual unread Patch Notes update, respecting
   reduced motion and preserving UIParent-owned minimap/button opacity.
9. Hover mini-preview of real DR widget settings; never mutates them.
10. Runtime-only bounded Back stack (12 entries), hidden on close, never
    exposed or persisted as gameplay/history, no extra navigation engine.

New UI/Feedback.lua owns transient visual effects and optional feature
tags; it is loaded AFTER Style, Motion and Window and BEFORE Navigation,
Options and Footer. It has NO OnUpdate, networking, profile database
access, permanent polling or unrelated gameplay events. C_Timer.After
is one-shot with generation tokens for transient label/notice cleanup.
All animation values use the same existing UI/Motion.lua driver.

Verification: CI/static source contracts are not a live WoW PASS.
Live checks required in Forever/Retail: every Patch Notes link points to
the correct visible target, pulses twice, cancels old pulse; navigate
Community/Options/Patch Notes and Back; Search/keyboard/Enter/Escape;
NEW tags disappear only on first use and stay gone after /reload;
window reset toast and icon-reset confirmation; minimap ping doesn't
steal collector opacity (test EllesmereUI on/off); preview does not
steal mouse from a slider or render outside compact windows; theme
switch during animation, reduced motion, resizing, fold, Peek,
drag, combat restrictions, error states, tooltip stacking.
Source labels remain DEMO for Patch Notes; don't invent real releases.
Scope: UI only, no TOC version bump or new media. Status:
IMPLEMENTED/UNTESTED pending CI and player's in-game verification.
Baseline commit: 11b7beaf751774271a7cb5a4e32deadc4e46abc9.

## Live widget-preview repaint after size/transparency drag — 2026-11-20

Additional cross-system audit after the complete nine-feature CI gate: the
two access sliders stream changes via Settings.Set and Options.RefreshAccessModified,
but an initial hover-only preview would otherwise remain visually stale
until hover exit/re-entry. Feedback.RefreshWidgetPreview now repaints only
the miniature size/alpha when a preview is shown. No full Options.Refresh
during drag, slider state owner changes, new settings, animation or layout
changes. The regular Options.Refresh also refreshes a visible miniature.
Live in-game slider responsiveness and popup overlap remain UNVERIFIED.

## Search integration for new Back and preview actions — 2026-11-20

Final cross-system audit: Navigation.Back is registered in the EXISTING
ns.Search registry, with Navigation.CanGoBack gating it when no history
is available (therefore no dead result). Widget Size's already-registered
Options search entry now includes the phrase 'widget preview', leading
to the real hoverable control without creating a duplicate setting.
This adds no new search owner or storage. CI/source checks cover both.

## Window polish: logo shimmer, magnetic snap, restored page — 2026-11-20

Explicitly approved after recolor-only baseline and BurstFX presentation
polish: (4) one-shot hovered header logo light reflection, (5) magnetic
screen-edge snap with temporary alignment guides, (8) restore the last real
page and scroll offset across window close and /reload. Additional request:
compact Back button in footer immediately LEFT of Close (not Hall rail);
NEW feature labels auto-dismiss once the player has actually seen them
(in account SavedVariables); action notification toasts appear immediately
above the button that caused them, never centered over content.

Reference-first: Polestar Theme/Anim.lua demonstrates one temporary motion
driver and reduced-motion behavior; Polestar_Options/UI/Options.lua O.Flash
uses short self-ending appearance cues, and the same module's Fold restores
the previous top-left anchor. Narcissus MinimapButton.lua confirms the
importance of separate frame ownership and guarded drag behavior.
BurstFX presentation lessons already inspected in previous build. No
reference source was copied verbatim. Existing approved skin/UI retained.

Implementation ownership:
- UI/Window.lua owns header logo mouse/drag and masked reflection, all
  edge proximity calculations (14-unit gap, 24-unit snap range), Alt to
  bypass, 2px visual guides while dragging, and a 0.13-second Motion.Value
  snap. No idle polling. Window.CancelMagnet handles fold, scale, hide
  safely. Unsupported mask APIs show NO unmasked light rectangle.
- Core/Settings.lua is the ONLY account database owner for lastWorkspace
  {section,page,scroll}; validates page-key string and finite/clamped
  offset. No character data or page engine duplicated.
- UI/Navigation.lua is the ONLY owner of page selection, ephemeral
  bounded Back history, last-page resume on first actual window open, and
  scroll snapshot on navigation, close and PLAYER_LOGOUT. Saved unknown
  keys gracefully fall back to Hall. Importantly, no hidden Patch Notes
  page is visited/read during ADDON_LOADED.
- UI/Options.lua, UI/Community.lua and UI/PatchNotes.lua expose their
  own Get/SetPageScroll APIs and clamp through their existing scrollbars;
  Navigation only delegates to those owners.
- UI/Feedback.lua keeps reusable toasts and discovery badges. Toast now
  requires an actual visible action button and anchors just above it;
  Footer sends its real Reset button, including when invoked by Search.
  NEW badges auto-acknowledge after ~2 seconds of visible exposure, or
  upon hovering the feature, and Settings keeps their acknowledgement.
  Off-screen scroll rows do NOT auto-acknowledge. No new timer loop.
- Window exposes its existing footer Close control as the anchor for
  the 66x26 Back button, still owned by Navigation. Back tooltip/search/
  first-use badge remain; no secondary page or settings store.
- Neither audio nor premium reskins, gameplay/data, ranking, network,
  minimap ownership, default theme, UI scale or icons were changed.

Scope/verification: source + GitHub automation checks do NOT prove WoW
behavior. Player must verify logo sweep and drag, Edge/Alt snap and guides,
Fold/Peek/scale/resize including scaled UI, page restoration after close
and /reload at nonzero scroll, search links and unread Patch Notes, Back
beside Close, NEW disappearance/relog persistence, toast beside reset,
EllesmereUI on/off, combat/chat input and no blocked buttons. Window drag
position itself retains its previous session-only behavior; no new
position-persistence preference is introduced. Status: IMPLEMENTED /
IN-GAME UNTESTED. Baseline develop aa3aac6454ca0b911f2f339ba82541e8ea192f75.

## Escape menu entry + removal of logo hover shimmer — 2026-11-20

USER REQUEST: remove the earlier header-logo hover reflection entirely,
retain its original wordmark and drag. Add "Duels Reimagined" to Blizzard's
Escape menu and an enabled-by-default "Show Escape menu button" switch in
Options > Interface, searchable and saved account-wide by Core/Settings.lua.

Reference-first (code actually inspected, not inferred): Polestar
addon/Polestar/UI/GameMenu.lua uses the native GameMenu button template,
reads the menu's buttonPool layoutIndex instead of modifying Blizzard pool
buttons, inserts its own section/spacer after Shop/Options, handles
Ellesmere's external buttons, and has a legacy fallback. Polestar's
Theme/Anim.lua and game-menu helper also informed no-poll lifecycle and
safe button ownership. EllesmereUI v9.8.9 ZIP inspected directly:
EllesmereUI/EllesmereUI.lua lines 4466-4680 adds its custom buttons below
Shop and uses branded inline color text plus optional menu skinning;
EllesmereUIBlizzardSkin/EUI_BlizzardSkin_Dialogs.lua and
EUI_BlizzardSkin_TooltipSkin.lua supply the live popup menu text color,
background and border controls. Unlike Ellesmere's own menu integration,
Duels never rewrites/reshuffles Blizzard's pooled button anchors or
menu height, nor skins the full GameMenuFrame.

Only our UI/GameMenu.lua owns its own native button + optional spacer.
If EllesmereUIBlizzardSkin is loaded AND reskinGameMenu is on, the button
hides its native template textures, adopts the current EUI flat inset,
configured menu background/border/font, and draws "Duels" using the
Ellesmere-configured popup-element color and "Reimagined" in white
with a two-tone Blizzard font string. If EUI is disabled, the optional
skin module is absent, or the specific pause-menu reskin is off, our
button is exactly Blizzard-native: no Duels theme colors or custom art,
and no custom label tint. No dependency on matching Duels theme colors.

For compatibility with Polestar already installed, Duels reserves a
separate layoutIndex after Polestar's slot when the native menu lays
out sections. When EUI is active, it anchors under EUI's last menu
button (or Polestar's button if present) and holds its own layout
space. It creates nothing when disabled; clicks close Escape and open
or raise the existing addon window; hidden windows still restore their
last page through Window.Toggle. No new sounds, gameplay hooks, data
owners, version/TOC bump, custom menu art, or permanent polling.

Verification status: IMPLEMENTED/UNTESTED until CI and in-game testing.
Check Forever and Retail: addon enabled alone gives plain native
Blizzard button; with EllesmereUI BlizzardSkin on gives EUI-aligned
background/border, color-coded 'Duels' and matching font; EUI menu
reskin off falls back to native; Polestar + EUI both installed shows all
buttons without overlaps; combat and ESC close; setting on/off, /reload,
search discoverability, compact Options card reflow, no mouse/keyboard
stealing and normal logo dragging. Do not call it in-game VERIFIED
without actual game observation. Baseline develop
dfc82ab7aa962f986ed2c65a026849d2113ff662.

## Escape-menu collision re-audit + settings categories — 2026-11-20

USER BUG EVIDENCE: Menu screenshots with EllesmereUI, Polestar and Horizon
Suite showed Duels overlapping Polestar. With Ellesmere disabled, Duels
shifted other menu buttons. The Interface settings screenshot showed
unrelated options crowded into a single Window behavior card.

SOURCES REVIEWED FIRST: Polestar addon/Polestar/UI/GameMenu.lua uses a
Blizzard layoutIndex slot, with an Ellesmere-specific spacer/anchor.
EllesmereUI v9.8.9 ZIP EllesmereUI/EllesmereUI.lua (4467-4680) manually
anchors buttons after Shop and shifts Blizzard pooled buttons down.
Horizon Suite v6.14.0 ZIP HorizonSuite/core/GameMenuButton.lua combines
an indexed menu entry with a one-frame-later visual gap search.
The different placement systems explain the collision: Duels used both
a layout index and a manually anchored frame while guessing other
addons' positions. Neither installed addon alone provides a universal
spacing contract. No author source was copied verbatim.

FIX: Duels now reserves ONE layout frame in Blizzard's vertical menu
after all currently visible numeric layout entries above AddOns.
Its real button has NO competing layoutIndex, and is positioned
after layout using the actual rectangles of ALL shown GameMenu Button
children (not named Polestar, EUI or Horizon globals). A suitable gap
must fit the full button height plus spacing and overlap horizontally;
otherwise our own button remains hidden instead of covering a third-
party button. Two bounded one-shot post-layout rechecks catch delayed
third-party anchors. No permanent polling. Our addon never writes to
any other button nor calls GameMenuFrame:Layout in a settings handler.
GameMenu.GetPlacementStatus distinguishes crowded/unsupported/visible
for future diagnostics. This does not control UIParent-anchored addons
outside the GameMenuFrame child tree and MUST be verified in actual WoW.

OPTIONS: The SAME central Options > Interface area is split into five
responsive whole-card sections (NOT new tabs/DBs): Window & motion
(Auto Peek/Reduce Motion), Game access (Escape menu/compartment),
Minimap & widget (mode/size/opacity/reset), Typography (font/size/
outline), and Notifications & help (tooltips/update dot). All original
preference IDs, option search registration, active SavedVariables,
responsive height measurement and scroll targets remain unchanged.
No new artwork, sound, gameplay/ranking/networking or theme changes.

STATUS: IMPLEMENTED/UNTESTED, awaiting automated CI and actual in-game
verification. Test with Duels alone, EUI on/off, Polestar, Horizon, all
four simultaneously; observe buttons from Shop through Return to Game
including Esc navigation. If the menu is too crowded Duels may be
hidden intentionally rather than overlap. For Options test 100% scale,
compact width, large fonts, Search, rows, and section scroll targets.
Baseline develop: 87c8e3276efed02798c5fff45eb57fbb8475e808.

## Escape menu test boundary and flicker correction — 2026-11-20

First CI after the category/menu re-audit passed Lua parsing and almost all
checks. Three obsolete source tests referenced the old Minimap button header,
the old direct buttonPool field access and a harmless Layout() mention in
commentary. The updated tests now assert the new heading, actual pooled
enumerator, and forbid only REAL addon menu:Layout() calls. A final quality
pass removes the unnecessary Hide/Show during the second delayed geometry
check; if a valid slot still exists, the button stays visible while its
position is re-evaluated. If no slot remains, our button hides immediately
to avoid overlap. No gameplay, media, sound or other settings changes.

## Repository audit — 2026-11-20

The addon is currently a UI-first prototype. The current TOC and source files,
not historical design notes, define the runtime assets. Obsolete concept artwork
and unused helpers were pruned from the packaged addon after checking loaded Lua
and TOC references. Git history remains the rollback source for removed media.
The Polestar-derived reset and Discord icons are still present and retain
their existing GPL attribution; its unused resize icon is no longer shipped.
The update does **not** establish live-game verification of every UI state,
and does not implement duel/ranking/multiplayer features.

## Approved interface baseline — Duel Hall (2026-11-21)

**Status:** CONCEPT APPROVED → BUILD AUTHORIZED → IMPLEMENTED/UNTESTED.
The supplied screenshot in the design conversation is the visual intent. Source
files contain separate native WoW frames, buttons, font strings, atlas glyphs,
and shared controls; the screenshot itself is never overlaid or shipped.

- The compact header contains the crossed-swords emblem, DUELS REIMAGINED,
  YOUR DUELING HUB, Search, Peek, Fold, Menu Scale, and close X.
- The **left rail is reserved for Hall and future implemented primary gameplay
  destinations**. Hall remains visually distinct even when another page is open.
- Appearance/Interface are **subcategories inside Options**: horizontal tabs
  above the page's content, not buttons in the primary rail.
- The footer retains build/BETA, Discord, Reset Window, Reload UI, and Close,
  with small Community, Patch Notes, and Options links between utilities/Close.
  Back history remains session-only, surfaced above the content when relevant.
- One default house palette: **Duel Hall** (dark charcoal, bronze/gold and
  restrained crimson). Old five-theme preferences migrate to Duel Hall on load;
  the picker stays present but unavailable while there is only one installed
  theme. EllesmereUI color/font matching remains optional and cannot be
  required for basic use. Colors default to Duel Hall even with EllesmereUI
  installed; explicitly enabled matching is respected, while font matching
  continues to follow EllesmereUI availability by default.
- Shared layout/skin/navigation/Options owners remain in their original
  modules. The Interface page uses two full setting cards per row at a safe
  desktop width, with single-column/large-font fallbacks. Scroll and Search
  track the actual page's controls.
- No ranked statistics, duels, matchmaking, War Games or network logic are
  added by this visual change. Existing ESC-menu compatibility and SavedVariable
  owners remain unchanged.

**Regression rule:** assess header search/text clearance, Hall/future primary
rail, footer minimum-width collisions, page tabs with many choices, current
community/patch-notes scrolling, theme migration, chat Enter/Escape, fold/peek,
combat restrictions, menu scaling, tooltip layering, and optional EllesmereUI
states in the actual WoW client. Static contract tests do not prove visual
pixel-exactness or live WoW behavior.

## Approved Duel Hall — screenshot fidelity pass (2026-11-21)

**State:** IMPLEMENTED/UNTESTED pending in-game acceptance. The reference is
the approved 1536x1024 concept and the 1119x700 user-provided in-game capture.
The earlier build landed the main frame geometry but underrepresented the
reference's native Warcraft styling. This focused pass changes presentation,
not the navigation model, gameplay, networking, storage schema or ESC menu.

- Header Peek/Fold/Close receive real metallic button frames; Close uses the
  crimson action skin. The wordmark tagline receives separate tiny gold rules.
- Hall remains the prominent left gameplay destination. Its actual button
  receives two native painted edge lines, a restrained red sheen, original
  code-drawn laurel leaves and a divider anchored beneath the **last**
  gameplay button (safe when more primary pages arrive).
- Content cards receive a slim bronze heading band and stronger border.
  Appearance's palette tab is painted in ARTWORK rather than behind the tab.
- The shared text owner now supports a *display* role using Blizzard's own
  Morpheus font for major headings, falling back safely. Optional manually
  chosen or EllesmereUI-matched fonts still win when explicitly configured.
- A fresh install starts with both third-party color and font matching OFF so
  the actual approved house appearance is visible. Existing explicitly saved
  user choices are not overwritten.
- Interface card grouping may use two columns in ordinary desktop widths
  (720px content breakpoint); large fonts keep a single-column fallback.
- No concept screenshot is included as an asset or composited onto the UI.
  All visual pieces remain ordinary WoW textures, frames, font strings,
  interactions and reusable theme tokens.

**Evidence:** source-level and UI-ownership/static tests can verify the
invariants, but only the player can verify line thickness, actual font shape,
texture readability, tab/menu collisions, popup layering, mouse focus,
combat behavior, scaling and ESC-menu compatibility in WoW. Screenshots of
Appearance and Interface at the same Menu Scale are required for comparison.

## Duel Hall artwork fidelity baseline — 2026-11-21

**State:** approved screenshot remains the design source; implementation is
**IMPLEMENTED/UNTESTED** until in-game inspection. Two compared captures:
the approved 1536x1024 concept (consept(1).webp) and the 1120x711 in-game
build (Screenshot_2). Window dimensions were normalized for comparison; the
overall major regions were already close, while painted surfaces and controls
lacked the concept's depth.

**Chosen implementation: Option A.** The new independent texture assets are
all ORIGINAL artwork drawn procedurally for Duels, not cutouts of the concept
or borrowed from another addon. The main Hall plaque, its laurel ornament,
raised gold and dark menu plates, corner jewel and subcategory icon atlas are
small, power-of-two, uncompressed 32-bit TGA files under Media/Skin. Text,
click targets, responsive geometry, icon selection, Search, settings and
animations remain ordinary independent WoW elements. Style.Plate owns their
nine-slice layout, and Navigation switches only the selected subtab's painted
plate. No separate theme or state/animation owner was added.

**Proportions retained from approved composition:** ~226 UI-unit left
gameplay rail at the minimum 1050x650 window, 72-unit header, 50-unit footer,
84-unit Hall destination and 35-unit options tabs. Enlarged Appearance card
spacing matches the reference's roomier ledger without making the Interface
grid taller. An appearance page that fits must not show a phantom scroll thumb.
Dark metal/bronze framing and red/gold accents remain the only house palette;
the five former themes stay retired. User overrides from EllesmereUI remain
optional.

**Quality gates:** static regression checks for TGA headers/transparency,
reference usage, resizing and click state; Lua syntax/runtime Search and
SavedVariables checks; manual 100% Menu Scale visual review in WoW of Appearance
and Interface, icons, hover/selection, resize extremes, other addons absent,
Ellesmere enabled, combat, ESC, Enter, Fold/Peek and footer. Automated checks
do NOT establish a perfect pixel match in the real client. Refine source pieces,
not screenshot crops, when the player's in-game reference shows differences.

## Exact concept-source extraction — checkpoint (2026-11-21)

The uploaded approved 1536 × 1024 concept is the **literal visual source**
for `Media/Skin/DuelExactAtlas.png` (512 × 256). The current full-color
extraction also uses the subsequently approved 1536 × 1024 concept image.
Unlike earlier hand-drawn approximations, these pixels were extracted from
the user-approved artwork:

- Hall plaque: actual swords, curved red laurels, HALL wordmark, reflected
  crimson/gold metal frame. This is one fixed branded art region displayed
  inside an actual WoW Button. Its title is intentionally *baked* for visual
  fidelity; the click, hover, tooltip, page selection and Search stay native.
  Future primary destinations still use independent native labels/icons.
- Gold and dark category plates: actual selected/unselected concept borders
  and metal shading; text/icon pixels in the source were removed and rebuilt
  as a clean backdrop so Appearance/Interface retain real live labels.
- Appearance card body/header: concept-sampled border and title-band artwork,
  reconstructed without fake option text. Interactive rows, toggles, choice
  widgets, descriptions and scrolling are separate and searchable.
- Small frame corners: source-derived metallic corner art; non-interactive.
- Header identity: `DuelExactBrand.png` extracts the actual swords, two-tone
  DUELS REIMAGINED wordmark and YOUR DUELING HUB subtitle as a transparent
  512x128 atlas with a 384x68 visible crop. The existing drag owner and header
  geometry stay active. Like Hall's fixed label, this is deliberately static
  branded text; it does not respond to optional third-party font matching.

The regions share a power-of-two 512×256 RGBA PNG sprite atlas with explicit
texture coordinates. The old destructive 32/128-color quantization was
replaced by full RGBA assets extracted from the approved concept. There are
also separate 512×128 RGBA branding and 32-bit TGA textures for native
categories, button face and divider. These assets are now committed to
GitHub, not supplied as a manual ZIP or composited full-window screenshot.
The original full screenshot is NOT included as an overlay, and no gameplay
or ESC-menu behavior was changed. The shared fallback masks remain, but obsolete procedural laurel and tab
textures were removed because no runtime code uses them.

**2026-11-21 code cleanup:** removed duplicate brand widgets and image-layer
overlays so the approved header, Hall and options panels each have one visual
owner. Fixed footer action double-skinning; mirrored the corner art; removed
duplicate tab selection rims/underlines. Neutral black backgrounds replace
brownish sepia defaults. Existing keyboard, Search, Peek/Fold, resize, settings,
SavedVariables, AddOn compartment, and ESC menu remain owned by their
original modules.

**Remaining in-game visual verification:** inspect the true client-rendered
texture quality, alignment and scale at 100% Menu Scale; verify no duplicate
brand text, no old underpaint on the Hall or tab buttons, option card borders,
category icon colors, golden corners and scroll behavior. Check larger font
scale, Peek/Fold, ESC menu, third-party color matching and other addon states. A source-level/CI pass cannot certify client texture
loading or pixel accuracy. An approval screenshot is still required.


## Copper frame and three-state button polish — 2026-11-21

Design: preserve the approved Duel Hall composition and all current button
art, replace only the outer ornate corners/stacked rim with a restrained,
brushed-copper/bronze chamfered perimeter. `DuelCopperRim.png` is an
independent transparent 512×512 RGBA nine-slice asset; it is not a fullscreen
screenshot and does not contain text or interactions. `Chrome.Shell` is its
single perimeter owner. Its frame-level texture is non-interactive, so it
cannot block native click targets. Do not reintroduce the four floating
corner jewels or redundant border glow strips.

All applicable native buttons now have three explicit visual experiences:
hover fade (including currently selected destinations), a short gold press
and release glint via the existing shared Motion driver, and a persistent
selected accent on navigation destinations/tabs or the active Fold/held
Peek controls. One-time actions (Close, Reset, Reload) have transient click
feedback, not a misleading persistent selection. Disabled controls do not
flash. Mouse leave, hide, reduced-motion, search-driven navigation and
Fold/Peek lifecycle must be checked. Do not add permanent polling.

Status after commit: IMPLEMENTED/UNTESTED in WoW. Static checks and GitHub
CI are useful but cannot certify actual live client rendering. Quick manual
verification: at 100% Menu Scale, open Hall and Options, hover and press
Hall, Appearance/Interface, Community/Patch Notes/Options, Eye, Fold,
Close, reset/reload and Back. Ensure no double outlines, no hover trapping,
selected state survives page changes, Peek is only active while held, Fold
stays highlighted only while collapsed, and resize at minimum and maximum
does not stretch the copper corners. Test with and without EllesmereUI.

## Fixed Duel Hall look and larger first-open size — November 21, 2026

- Duel Hall's copper/bronze visual design is the **only** addon color palette. Retire the selectable Color theme and Match EllesmereUI colors controls; the optional third-party integration may read **font only**. No external accent/panel colors can repaint our buttons, cards or frame.
- Keep the Appearance page for the optional **Match EllesmereUI font** setting and its explanatory status. Existing manual font choice, scale and outline under Interface remain.
- First-open and Reset window dimensions are **1240 × 770 UI units at 100% scale**, fitted to the available UIParent screen bounds. The resize minimum stays 1050 × 650 where the screen permits; saved custom dimensions always win. The larger default was selected to match the wider screenshot from the user, not as proof of pixel-perfect in-game parity.
- Remove retired `uiTheme` and `matchColors` SavedVariables on addon load without touching other preferences. Do not add new color themes unless separately proposed and approved.
- Verification state: **IMPLEMENTED / UNTESTED IN-GAME** until the user checks both Forever and Retail (when available). Test initial open, Reset window, resize persist + /reload, scale/clamp, both Ellesmere enabled/disabled, font changes, search and tooltips.

## Options banner artwork — approved November 21, 2026
- Both Options pages (Appearance and Interface) share one screenshot-extracted banner renderer and fixed Duel Hall copper styling. Every category has a left icon, live title/subtitle and a faded motif at right. Header backgrounds preserve the established nine-slice card chrome, not a painted full-window screenshot.
- Controls, search destinations, settings, tooltips, scrolling, category grouping, tab state and fonts remain under their previous owners. No additional theme or setting added.
- Polestar reference: compact setting rows and common painter ownership in Theme/Widgets.lua; no source copied.
- In-game visual verification required at narrow, standard and large text scales.

## Exact screenshot-transferred Options banners — November 21, 2026

- **Approved target:** the user-provided Interface concept (1672 × 941). Its five complete category headers are directly extracted as pixels: copper/gold edging, icon, title, subtitle, brushed metallic lighting and right-hand motifs are ONE artwork per card. No approximate rebuilding with native type or separate symbol layers.
- **Appearance:** the same renderer, with palette and lettering sourced from the separate generated Appearance concept, composed into the matching category banner structure because the approved Interface screenshot does not depict Appearance as one of its five cards.
- Media: one RGBA power-of-two `Media/Skin/DuelOptionsExactBanners.png` (1024 × 256). Six 512 × 64 cells, with a 3-part horizontal UV split to preserve title/icon scale and stretch only the quiet center gradient on window resize. This replaces `DuelOptionsCategoryArt.png` and its generic reconstructed headers.
- Keep each card's existing **real** rows, buttons, reset states, search targets, tooltip data, scroll/frame owners, options tabs, saved settings, and gameplay untouched. Do not add a second color/skin owner or permanent update ticker.
- Visual proof requires a new in-game screenshot at the current size. CI confirms file integrity, Lua syntax, and structural contracts but does NOT prove exact on-screen rendering.

## Options, footer and integrated resize-corner polish — November 21, 2026

- The two Options pages retain their six exact screenshot-derived category graphics. Their header frames now inset 4 UI units to align to the shared 9-slice card border. The banner split has moved into the narrow quiet band after the baked subtitle, avoiding stretched text/motifs.
- Appearance/Interface tab glyphs reuse their real approved category icons inside the existing 128×64 TGA atlas, rather than old unrelated icons.
- Footer links are 112-wide and all footer/Action/tab labels share one bounded-font fitter that refits after font changes and width changes. No independent font pollers. Close is inset further from the forged corner without overlapping the utility group.
- One existing resize behavior owner remains: drag to resize/persist, right click to reset. The new 84×84 transparent copper relief is an actual corner/edge continuation, while the mouse input remains a separate clear 38×38 hit zone. Hide both when folded. No added settings, themes, or gameplay.
- Automated/static checks are evidence only; player verifies final geometry/hover/click in actual WoW at 100/150% text and smaller window sizes.

## Corrected Options artwork and shell clipping — 2026-11-21

- The earlier two-by-three Options banner atlas discarded the right corners and lower trim. Replace with six COMPLETE photographic crops from the approved concept in RGBA 2048x256 atlas, two 640x80 source-derived banners per row. Three-slice code keeps the left text and right motifs/corner intact; only the quiet brown gap expands. Both Appearance and Interface use the same full-bleed asset. One card/one Settings/Search ownership remains.
- Appearance and Interface tabs use independently rendered 128x64 TGA palette/window medallions with dark-forged brass edges. Live text and native hover/selected interactions remain; simpler font role avoids unnecessary decorative-text conflict.
- Replace former diagonal stripe resizer decoration with a single 128x128 alpha-backed sculpted copper plate (raised wedge, seal, rivet), attached to the same 84x84 noninteractive visual frame and unchanged 38x38 corner drag/right-click hitbox.
- Root dark skin is inset 5 UI units beneath the perimeter 9-slice. Optional clipping on the interior ensures a black square/panel cannot extend past the window's metal rim. Do NOT clip overlay dialogs/tooltips on the root frame.
- Verify both tabs at default/minimum window size and 100/150% text, bottom-right outside the frame on a bright game background, drag/reset and /reload. Automated checks cannot prove live WoW pixels.

## Visual correction: single card rim, clearer tabs and quiet resize corner — Nov 21, 2026

- User in-game screenshot showed the repeated crop issue persisted: baked top and left banner borders overlaid the card body's already working 9-slice, while the lower/right baked lines were cut by three-slice scaling. Retire the bordered banner asset. Use six concept-derived, feathered *art-only* header inlays in `DuelOptionsBannerInlays.png`, inset within each card. `Style.Plate(card,"cardBody")` is the SOLE owner of the complete copper frame on all sides. A narrow native gold separator connects the inlay to the controls without duplicating the exterior rim.
- Replace ornate, tiny medallion tabs with two **simple readable gold glyphs** in `DuelMinimalGoldTabs.tga`: four-point sparkle for Appearance and bold window for Interface. Both remain live selected/hover/click buttons.
- Replace the triangular multi-line grip with a compact 64x64 transparent forged L-plate and one rivet in `DuelArchitecturalResizeL.png`; it shares the existing rim and single resize owner. Leave 38x38 interactive hotspot and right-click Reset semantics unchanged. Clamp additive hover glow to 0.22 to avoid visually doubling the art.
- Scope limited to Options visual art, tab symbols and resize-corner ornament. No gameplay, persistence, search, controls or top-level shell changes. **In-game visual inspection required** at normal/compact width and 100/150% text. Automated checks are static + Lua tests only.

## Soft category artwork and filled corner — 2026-11-21

- Approved visual correction: The six Options headers retain their concept-derived lettering/icons/motifs, but artwork backgrounds are now transparent and softened rather than baked into rectangular bars. `DuelOptionsSoftArt.png` is alpha-only foreground and `DuelBannerAmbient.png` is one scalable diffuse bronze wash. The title and right motif use independent texture slices, without a horizontally stretched center strip. `Style.Plate(card,"cardBody")` remains the only four-sided copper frame.
- Resize ornament is now a solid, beveled copper triangle with one rivet in `DuelFilledTriangleCorner.png`, retaining original 64x64 visual frame and 38x38 live drag/right-click area; hover glow ceiling 0.18. Appearance/Interface tab icons and interactions stay unchanged.
- In-game visual verification required; automated tests are structural and asset checks, not pixel proof.

## Approved Alliance & Horde Resize Corner 06 — November 21, 2026

- Design: User-approved concept **06** from the metallic Alliance/Horde corner comparison. An open copper sweep contains a blue Alliance lion and red Horde crest separated by a curved metal partition, with a small blue diamond at the bottom. The generated concept is directly cropped for the addon rather than reinterpreted as a solid triangle or generic border. Native RGBA assets are `DuelFactionCorner06.png`, `DuelFactionCorner06Hover.png` and `DuelFactionCorner06Press.png`.
- Single owner: `UI/Window.lua` keeps one 54×54 working corner button and 106×106 *noninteractive* artwork. Hover softly illuminates faction motifs, mouse down adds a distinct sapphire/copper flash and one-pixel depression while held/dragging, and release fades back to hover/idle. Uses shared Motion tweens and respects Reduce motion. Right click resets; left drag resizes and commits saved dimensions; Fold hides art and input; hide safely releases sizing.
- Footer Close and utility button anchors move 20 UI points left to keep their hitboxes clear of the larger corner. No other visual language, layouts, settings, gameplay, or theme changes.
- Ref: inspected Polestar Theme/Widgets.lua mouse enter/leave/down/up button pattern and Anim.lua shared-motion approach; code remains independently implemented. Verify in WoW: bright background, mouse hover/click/drag/reset, footer Close, Fold, /reload, reduced motion. Static CI cannot prove on-screen appearance.

## Concept 06 corner integration and size balance — 21 November 2026

- User confirmed the copper/faction corner design but reported a pasted-on border, Close interference, and an Alliance lion smaller than the Horde emblem. **Correct the lion's displayed size, NOT its brightness**: the lion source glyph is scaled ~1.35× inside its blue enamel, keeping its original RGB palette; the Horde artwork and emblem are unchanged.
- Three new native 256×256 RGBA assets: `DuelCorner03Copper.png`, `DuelCorner03Hover.png` and `DuelCorner03Press.png`. Transparency feathers the long lower-left sweep before the Close button and lets the main shell border own the straight bottom/right metal lines. No outer dark rectangle.
- Window.lua uses a 96×96 noninteractive corner at frame level +18, **below** the established copper Shell rim at +20; the existing transparent 54×54 drag hotspot stays above at +45. Hover, pressed, drag, release, right-click reset, Fold, reduced motion and persistence retain the existing single owners. No settings/gameplay change.
- Verify in WoW: comparable emblem sizes without color change, seamless border joining, no Close/utility overlap at default/compact, 100%/150% font, resize/reload and hover/drag/press/reduced motion. CI proves code/art integrity only, not live pixels.

## Resizer Corner 03 — approved replacement for dual-faction art (21 November 2026)

- User discarded the Alliance/Horde emblems and chose **03 from the nine-panel copper corner study**: one curved, open forged-copper filigree with a round gold jewel. The new PNGs are directly isolated from the user-supplied approved concept artwork, without its black screenshot background, Close button, labels or long extra border lines.
- One copper frame owner: `Chrome.Shell` at frame level +20 remains responsible for the window's straight bottom/right perimeter. The art sits at +18 behind it, at the existing 96×96 noninteractive anchor; its edges feather into the rim and end before Close. Do not add a second border engine, opaque triangle or faction icons.
- Assets `DuelCorner03Copper.png`, `DuelCorner03Hover.png`, `DuelCorner03Press.png` (each 256×256 RGBA). The hover layer traces the warm metal and jewel; the press layer flashes around the round jewel using existing `Motion.Fade` and `pressed` state. Preserve one-pixel pressed displacement, 54×54 corner-only live hitbox, left drag/commit, right-click reset, Fold cleanup, and Reduce Motion. No new feature or setting.
- Polestar `Theme/Widgets.lua` button input and `Theme/Anim.lua` short event-driven tween ownership were rechecked. All game controls remain independently written in Duels Reimagined.
- Automated syntax and asset validation is not evidence of in-game appearance. Verify idle/hover/press/drag, bottom/right seam, Close clearance, 100%/150% font, minimum/resized dimensions and /reload.

## Options banner text-safe rendering, compact header X, Hall hover — November 21, 2026

- Retain all six approved `DuelOptionsSoftArt.png` banners. Their 80px source labels became cramped when displayed at 50px; now their native source slices render within 62px high banner frames with a 2px top/bottom guard (58px maximum artwork). Move each card's separator to -72 and native setting rows to -80 (or -94 for large fonts) so the taller art cannot collide with controls. The exact graphic remains unchanged; no alternate font, banner re-painting or added settings. LayoutPage continues to measure card heights and scroll offsets responsively.
- The Header's red X reduces from 34×34 to 24×24 and its artwork from 23×23 to 15×15. Position, tooltip, escape-safe close callback and pressed/hover feedback remain unchanged; Peek/Fold buttons are still 29×29.
- Hall's existing concept plaque is preserved. A second transparent, additive instance of the SAME artwork is used only as a visible pointer-hover gold/red sheen (alpha 0.30), fading in/out through existing Motion; selected and click effects are still handled by the original controls. Hide stops its tween, and no permanent update ticker or extra option is added.
- Tests: static/header, Options and Hall contracts plus existing CI checks. Player must verify banner lettering at default/narrow and 100–150% text scale, X hit target and hover/close, Hall hover/selection/click, /reload. In-game behavior remains UNVERIFIED until observed.

## Flat dark category banners — November 21, 2026

User in-game screenshot confirmed the brown stripe was still visible after increasing banner height. Root cause was **not the approved transparent gold artwork** but a second diffuse PNG painted across the top of every card. Removed the `DuelBannerAmbient.png` texture and its creation code entirely, for both Appearance and Interface. The original `DuelOptionsSoftArt.png` retains gold category text, subtitle, left icon and right ornament; `Style.Plate(card, "cardBody")` remains the single continuous copper frame. Existing divider, geometry (62px artwork zone; rows from 80px), tooltips and controls are preserved. No unrelated UI changes. In-game visual verification remains pending.
