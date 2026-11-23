# Retail War Games — approved design and test limits

This feature is Retail-only. The two Players layouts (setup and inside arena) and faction-neutral Host/Spectate layout were approved by the user; the 5v5 roster capacity is five fighters on each side. The host is not one of the fighters. Tournament /roll rules are explicitly excluded.

Players: Detect the Blizzard party/raid through the shared Core/Group owner. Select 2v2, 3v3 or 5v5, an arena and one real Battle.net friend captain. The group leader may submit a StartWarGameByName request only with an exactly matching group size. The action never claims that anyone accepted or entered.

Host/Spectate: Select two DISTINCT real Battle.net friend captains, bracket and arena, then request StartSpectatorWarGame through Blizzard's API. We cannot reliably derive complete spectator team rosters; show selected captains and mark everyone else Awaiting player. Do not invent scores, classes, camera controls or match verification. The teams have no Horde/Alliance identity.

Arena: On Retail IsInInstance(... arena), hide match setup. Players see the Blizzard group and up to five arena1..arena5 opponent slots, only when Blizzard exposes nonsecret UnitName and UnitClass information. The interface does not interfere with ArenaCore or Blizzard arena frames. Leaving an arena restores setup selections.

Forever: Core/WarGames.lua and UI/WarGames.lua are excluded at load time by AllowLoadGameType standard, as verified in EllesmereUI and WarGameHelper. The War Games primary navigation plaque is gray, blocked from Search/workspace and click, but displays a helpful tooltip on hover. No Retail APIs run on Forever.

UI integrates with existing Window, Navigation, Theme, Search, Motion, Tooltips, Styles and Group. No added settings, SavedVariables, duplicate communication, polling or fake data. Battle.net friends are offered in a bounded/paged chooser. The original War Games plaque was cropped from the user's approved concept artwork.

Sources inspected: Polestar Compat, WarGameHelper 1.2.6, ArenaLive Spectator, Wargames+, ArenaCore, EllesmereUI. The code is independently authored. API support and match behavior still require LIVE RETAIL MULTIPLAYER tests. Mocks only establish contract behavior.

Quick tests: Forever disabled hover; Retail open Players/Host, group count and leader restrictions, BNet picker including empty/friends and duplicate captains, map/bracket, disabled buttons, outside/inside arena transitions, minimum window size, tab/search/back/Enter/Escape, reload; friends verify real challenge, acceptance, spectator entry and five enemy slots.
