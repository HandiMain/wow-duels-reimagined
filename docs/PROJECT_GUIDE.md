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
