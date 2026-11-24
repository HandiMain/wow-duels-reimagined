# Duel Detection — Phase 1 foundation

Status: IMPLEMENTED / live WoW untested. Build authorized by the user on 2026-11-24. This is a core-only change, not a visual redesign or ranking launch.

## Purpose and boundaries

One read-only owner, Core/DuelDetection.lua, tracks the user's own ordinary player-versus-player duel evidence independently of the Hall, War Games and the UI window. Works toward both Forever and Retail, with runtime capability checks; neither client's actual gameplay behavior is verified here. No combat log reading, attackability inference, simulated result, automated duel action, network messages, permanent duel records, new settings, scores, statistics, ranked play, matchmaking, death-duel result tracking, or spectator tracking. There is no new visible panel. No edits to account or character SavedVariables. Temporary evidence resets at reload/logout; last terminal snapshot and 24 transitions are session-memory only.

## Reference audit

- Polestar (fitzforge/polestar, next, tree 9848026a42fe7af6636e1a2b4c3a5fecf4dfe95d), Core/Init.lua and Core/Compat.lua: defensive event registration, guarded secret reads, event-driven listeners. Adopt patterns, not source; no permanent polling or new general event bus.
- Social Diary v4.2.4, Features/Duels/Capture.lua and Core/Events.lua (user-provided ZIP, GPL-3.0-or-later): documented Forever probes of DUEL_REQUESTED / StartDuel, localized DUEL_COUNTDOWN, DUEL_FINISHED, and knockout/retreat chat messages. Countdown marks an accepted duel, not the moment attacks become possible. The reference reports both result/finish orderings and distinguishes a cancelled challenge. We require correlated finish AND result, and reject contradictory evidence before pairing. Its surname matching is particularly useful on Forever.
- DuelTracker 2.4.0, Core.lua, Minimap.lua, Tooltip.lua (user ZIP): localized numbered placeholders, filtering results for the local player, guarded reads. Its main statistics accept matching local result messages without lifecycle correlation; its minimap falls back to combat events. Do not adopt either as proof for future ratings. No statistics or range overlay copied.
- DuelResponse 6.13.182, DuelResponse.lua and DuelResponse_Classic.lua / Forever TOC (user ZIP): incoming challenge and death-duel events, outgoing request system text. Its auto-decline actions and counters are not duel outcomes; do not copy automation.
- Current API references: https://warcraft.wiki.gg/wiki/Category:API_systems/DuelInfo and https://warcraft.wiki.gg/wiki/API:StartDuel (signatures/events, not evidence of this addon's behavior).
All new Lua independently authored. No reference assets or source code imported. This records source attribution and design provenance without replacing existing license notices.

## Contract

The shared Group.ReadPlayerIdentity(unit) accessor reuses existing surname/realm handling and secret-value checks. It does not change group roster behavior. When a named opponent is observed in target, focus, mouseover or up to 40 nameplate tokens at a relevant transition, its exact identity can be attached; no short-name-only Retail GUID inference. Unknown opponent names/IDs remain unknown. Forever preserves surnames and normalizes space/hyphen; Retail keeps explicit realms and rejects ambiguous same-name roles. Short-name result matching is locally observed, not a peer or globally unique identity proof.

States:
- unavailable: required client/event/format/timer missing; no detection.
- idle: no accepted or pending duel.
- challenge: incoming DUEL_REQUESTED or outgoing StartDuel post-hook. The outgoing hook records an attempt only; targeting cursor, refused or expired challenge does not count. Pending request expires after 90 seconds or DUEL_FINISHED before countdown.
- accepted: first valid localized countdown (including later ticks if the first is missed); repeated ticks share one session cycle. No inferred exact combat-start time or fighting duration.
- finishing: first result or DUEL_FINISHED seen, awaiting the other for up to 2 seconds. Either order supported. Only a result that identifies the local player and does not contradict the known opponent can pair. Conflicting outcomes before pairing, missing finish/result, world transition produce unknown. Result without an observed countdown is ignored, not retroactively reconstructed.
- idle after terminal: one immutable-copy last snapshot with id, locally observed outcome (won/lost/fled/they_fled/unknown), endType, opponent if known, acceptedAt/endedAt, evidence booleans and reason. rankEligible is ALWAYS false. A new challenge opens a new cycle; callbacks are bound to their original state so cannot close a rematch. Known incoming death-duel challenges are excluded; outgoing or missed challenges can be unclassified and are never rank eligible. No claim to distinguish all death duels on all clients.

Future consumers use ns.DuelDetection.GetSnapshot() and Subscribe(callback) (returns unsubscribe). The snapshot is a copy. Only the core owns transitions. Use terminal cycle ID and revision to avoid duplicate downstream processing. IDs are session-only, not global match IDs. Do not attach statistics until real client tests establish coverage and identity semantics. Client messages have no unique match ID; stale or contradictory late messages outside the observed pairing window remain a limitation. Missing events fail safely; do not treat unknown as defeat.

## Diagnostics and validation

/duels still toggles the main window. /duels detect prints current state and last local outcome; /duels trace prints capabilities and a bounded transition trace (no raw chat log). Neither changes game state or persists anything. Empty state explicitly reports no completed duel; unsupported reports reason.

The existing CI runtime entry calls check_duel_detection_runtime.lua with isolated simulated events; both client identities, localization/reordered placeholders, cancel, duplicate, retreat, unrelated nearby duel, cross-realm ambiguity, missing/secret data, timeout, stale callbacks/rematch, unsupported API, known death duel and snapshot isolation are tested. Source checks ensure load order and absence of additional gameplay/network/storage owners. CI is not multiplayer proof.

### In-game test gate (repeat on Retail and Forever)

1. /reload, /duels detect; expect idle or explicit unavailable. /duels still opens/closes the normal addon.
2. With a real partner, issue and decline one incoming and one outgoing challenge; expect no completed duel. Start and finish ordinary PvE combat; no accepted duel.
3. Accept a normal duel and run /duels detect during countdown/after it; expect accepted (not exact attack-start proof). Finish by knockout and /duels trace after 2 seconds. Expect correct local result and opponent.
4. Repeat with both player roles reversed; deliberately retreat (leave duel boundary) and test opponent retreat. Expect fled / they_fled respectively.
5. Watch someone else's duel without participating; expect no result. Repeat a quick rematch and a cancelled accepted duel. /reload or world transition while active must not create a win/loss.
6. Use a real Forever surname and a Retail cross-realm opponent; compare both participants' independently reported evidence, especially event ordering. Report unreadable/missing signals as unknown, not bugs to mask with guesses.
7. Verify War Games, addon window, group roster and existing Options behavior did not change. Do not try a lethal duel for testing.

Required status before rankings: SOLO IN-GAME VERIFIED for UI/diagnostics and MULTIPLAYER VERIFIED for the actual local duel lifecycle on each supported client, with observations recorded. Phase 1 does not claim either yet.
