# Retail War Games — approved design and test limits

This feature is Retail-only. The two Players layouts (setup and inside arena) and faction-neutral Host/Spectate layout were approved by the user; the 5v5 roster capacity is five fighters on each side. The host is not one of the fighters. Tournament /roll rules are explicitly excluded.

Players: Detect the Blizzard party/raid through the shared Core/Group owner. Select 2v2, 3v3 or 5v5, an arena and one real Battle.net friend captain. The group leader may submit a StartWarGameByName request only with an exactly matching group size. The action never claims that anyone accepted or entered.

Host/Spectate: Select two DISTINCT real Battle.net friend captains, bracket and arena, then request StartSpectatorWarGame through Blizzard's API. We cannot reliably derive complete spectator team rosters; show selected captains and mark everyone else Awaiting player. Do not invent scores, classes, camera controls or match verification. The teams have no Horde/Alliance identity.

Arena: On Retail IsInInstance(... arena), hide match setup. Players see the Blizzard group and up to five arena1..arena5 opponent slots, only when Blizzard exposes nonsecret UnitName and UnitClass information. The interface does not interfere with ArenaCore or Blizzard arena frames. Leaving an arena restores setup selections.

Forever: Core/WarGames.lua and UI/WarGames.lua are excluded at load time by AllowLoadGameType standard, as verified in EllesmereUI and WarGameHelper. The War Games primary navigation plaque is gray, blocked from Search/workspace and click, but displays a helpful tooltip on hover. No Retail APIs run on Forever.

UI integrates with existing Window, Navigation, Theme, Search, Motion, Tooltips, Styles and Group. No added settings, SavedVariables, duplicate communication, polling or fake data. Battle.net friends and arena maps share the existing Options dropdown styling, hover and drag/wheel scrolling (one popup owner in Widgets). Their status dots are green/online or red/offline ONLY when Blizzard reports a boolean status; unavailable status is omitted. Team 1 and Team 2 captains are independent, and either can be cleared without changing the other. The Retail fallback lists 16 known arena maps; the optional Blizzard War Game type catalogue adds additional explicitly marked Arena entries when exposed. A reference entry does not guarantee live map availability. The War Games plaque is derived directly from the same Hall 256x128 sprite in DuelAtlas.png: only the baked swords and HALL text are replaced with the underlying red gradient, leaving the copper frame and laurels pixel-identical. War Games bakes original metallic crossed swords with a matched gold serif WAR GAMES title, at Hall's exact 205x84 geometry. The earlier mismatched brown concept crop was removed.

Sources inspected: Polestar Compat, WarGameHelper 1.2.6, ArenaLive Spectator, Wargames+, ArenaCore, EllesmereUI. The code is independently authored. API support and match behavior still require LIVE RETAIL MULTIPLAYER tests. Mocks only establish contract behavior.

Quick tests: Forever disabled hover; Retail open Players/Host, group count and leader restrictions, BNet picker including empty/friends and duplicate captains, map/bracket, disabled buttons, outside/inside arena transitions, minimum window size, tab/search/back/Enter/Escape, reload; friends verify real challenge, acceptance, spectator entry and five enemy slots.

## Visual regression correction (2026-11-23)

The first in-game Retail screenshot revealed a ghost Arena Match panel overlapping Your Team, two separate header dividers, clipped Retail Only copy behind Back, and mismatched warm-brown War Games artwork. Corrected by deleting the unused always-visible panel; removing the redundant title label and divider; reusing the original Hall skin; and giving each UI state independent, non-overlapping geometry. Host controls are four evenly sized columns. The Players setup card is above its team roster, with one card divider and status message. Panels are scrollable rather than drawn beyond the content area. All changes are visual only; no networking, Game API or match request changes.

The derived asset can be reproduced or verified with `python3 tools/community/generate_wargames_plate.py [--check]`. Only the already-owned Hall atlas is used. This avoids independent painted frames that drift away from the main addon design.

## Picker / logo correction (2026-11-23)

The original War Games baked title touched the lower inner ornament: its serif mask is now centered and scaled to fit safely inside the plaque. Arena and Battle.net friend pickers reuse exactly the Options dropdown controls, popup art, hover, scrolling and close behavior; Previous/Next paging has been removed. Fixed the Lua `and/or` fallback which accidentally displayed Team 1's captain in Team 2 when the second slot was unselected. Added negative tests covering one-friend and clearing scenarios. These changes do not validate War Game multiplayer behavior.
