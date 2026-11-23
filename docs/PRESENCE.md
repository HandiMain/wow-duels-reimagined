# Shared addon presence — Foundation Step 3

**Purpose:** Detect which members of the user's *current party or raid* are confirmed to be running Duels Reimagined on Retail or Forever. This is separate from Retail-only War Games and from the group roster. No new UI, preferences, SavedVariables, public matchmaking or gameplay claims.

## Responsibilities

- `Core/Group.lua` remains the one Blizzard roster reader.
- `Core/Communication.lua` is the **only** owner of addon prefix registration, `CHAT_MSG_ADDON`, payload dispatch, game chat restrictions, and `C_ChatInfo.SendAddonMessage`. It sends only approved PARTY/RAID messages, never open-world stranger whispers. Future networking must reuse this owner.
- `Core/Presence.lua` subscribes to Group and Communication. It maintains an ephemeral, bounded per-group map of replies and exposes read-only copies through `Presence.GetSnapshot()`. `Presence.CheckNow()` requests an additional check and can return `false, reason`. `Presence.Subscribe(fn)` returns an unsubscriber.

## Wire protocol and statuses

Single prefix: `DuelsReimagined` (15 bytes). Presence protocol `P1|H|version` (hello) and `P1|A|version` (announcement). The version is read from the addon's shipped TOC metadata, never inferred from fake patch-note samples. If no `## Version` is declared (current develop), it is `?` over the wire and `nil` to API consumers. Peer-reported versions are not authoritative release checks.

Each current member is `self`, `confirmed`, `checking`, `unknown`, or `offline`. **Unknown is NOT missing.** A complete roster and sender-to-member match are required before accepting a response. Exact full name/realm match or Blizzard `UnitIsUnit` proof is used; different realm identities with the same short name cannot be conflated. No messages from outsiders, unrelated channels or unsupported protocol versions are accepted. When the player leaves their group, peer confirmations are discarded. When group identity is unreadable, the feature fails closed.

Hello is sent at most every 15 seconds; responses have their own 10-second burst limit. One bounded, 8-second expiry notification uses a one-shot timer, not OnUpdate or permanent polling. No repeated periodic requests. The game may refuse sends: transport rejects explicit refusal codes, restricted chat, active Retail arena/BG communication, absent APIs, and malformed payloads. The addon never interprets a successful SendAddonMessage as a confirmed delivery.

A future settings page can display these statuses as plain player-first labels without inventing an addon installation result. A future Retail War Games feature can ask presence for its party's confirmation state, but must not make actual group or spectator access depend on everyone installing Duels Reimagined.

## References and tests

Polestar `Quests/Party.lua` and `Core/Update.lua` (hello, version, roster validation, throttling), RCT `Sync/addoncheck.lua` (player state), Wargames+ `comm.lua` (bounded messaging and arena restriction handling), EllesmereUI `LibSpecialization` (shared prefix and chat channels), LayerSwap and Horizon Suite for relevant complementary integration patterns. Code written independently.

`check_presence_runtime.lua` tests message validation, cross-realm identity isolation, party and raid channels, unknown status, version data, response throttles, refused sends, chat restrictions, stale group recovery and subscriptions. The usual Lua syntax, existing group/client runtime tests and all UI regressions still apply. **No multiplayer verification has occurred.**
