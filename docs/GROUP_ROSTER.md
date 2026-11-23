# Shared group roster — Step 2

Purpose: one cross-client Blizzard party/raid roster for **both Retail and Forever**, reused by future addon detection, War Games (Retail only), and any future Forever dueling features. This adds NO new UI, War Games actions, player messages or SavedVariables.

Implementation: `Core/Group.lua` loads after Client and Settings and before the UI. It uses `IsInGroup`, `IsInRaid`, `GetNumGroupMembers`, `GetNumSubgroupMembers`, `UnitName`, `UnitFullName`, `UnitClass`, `UnitGUID`, `UnitIsGroupLeader`, `UnitIsGroupAssistant`, `UnitIsConnected`, and `GetRaidRosterInfo` when available. It reads Forever surname identities differently from Retail realm identities. No permanent polling.

API:
- `Group.GetSnapshot()`: detached copy with `mode` (unknown/solo/party/raid), `complete`, `stale`, `revision`, and `members`. Each member has unit, name, fullName, GUID, class, classFile/classID, optional raid subgroup, isLeader/isAssistant/online (nil if protected/unavailable).
- `Group.IsReady()`: true only for a complete current roster.
- `Group.Subscribe(callback)`: event-driven updates; returns an unsubscribe function. Bad callbacks cannot break the roster owner.
- `Group.Refresh()`: manual on-demand reread for later consumers; does nothing when unchanged.

Secrets: read `issecretvalue` before inspecting values. A name that is secret/unknown invalidates the snapshot; no guessed identities. The last complete SAME-MODE roster can be retained as visibly stale, but is never marked ready. Group-type changes discard old members immediately. Future actions must revalidate the current roster and leader state.

Events: `PLAYER_ENTERING_WORLD`, `GROUP_ROSTER_UPDATE`, `PARTY_LEADER_CHANGED`, `UNIT_CONNECTION`, and optional `UNIT_NAME_UPDATE`. Only relevant unit changes trigger a reread. No `OnUpdate`, ticker, or network traffic.

References inspected: Polestar's Forever party roster and compatibility readers; EllesmereUI's Retail/Forever roster/leader and secret-value guards; RCT's party and raid enumeration; Wargames+' roster and matchmaking prep; WarGameHelper, ArenaLive Spectator, and LayerSwap for relevant player/group behavior. Implementation is independently written and has one owner.

Automated tests check mocked solo, party, raid, Forever surnames, Retail realms, leadership, incomplete/secret values, recovery and no-change events. Automated checks do not prove live client or multiplayer behavior.
