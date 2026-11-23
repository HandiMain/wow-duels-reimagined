# Addon Status — Footer utility (approved 2026-11-23)

**Status:** User approved realistic in-game visual concept, then explicitly authorized implementation. This is a shared Retail/Forever UI feature, not part of Hall or Retail-only War Games.

**Purpose:** Tell a party/raid member which peers have explicitly responded to the Duels Reimagined addon handshake. No response is *not* proof of absence, and a reported version is not a verified installed build.

**Visible UI:** Fourth footer utility destination, positioned before Community, with the same shared dark plate, gold selected state, hover and pressed feedback. Its own view contains title/icon, the existing divider style, centered bordered member table with player/class icon, status and version columns, explanatory copy and a prominent Check Again action. The footer adjusts width on resize to avoid Reset/Reload overlap at the smallest supported window. Hall and its content are unchanged.

**Data and interaction:** Uses `Core/Presence.lua` and `Core/Group.lua` only. The table lists actual current party/raid members; it never displays fake people. Status labels are This client, Confirmed, Checking, Not confirmed and Offline. The version column uses the TOC report when present or Not reported otherwise. The action invokes Presence.CheckNow, respects cooldown and chat restrictions, and reports sending as a request—not confirmed delivery.

**Empty/error:** When solo, invite the user to join a party/raid and disable Check Again. Incomplete rosters get a specific explanation and no actionable list. If Blizzard restricts addon messages, Check Again is disabled with an explanatory tooltip. Network silence stays Not confirmed. Cooldowns are explained after clicking; they do not become claims about a player's installation.

**Architecture:** No additional roster listener or communication engine. UI subscribes to Presence only while shown and unsubscribes on hide; scroll uses the shared Widgets.ScrollBar. The page uses existing Style/Chrome/Motion theme primitives and is registered in Navigation's Back, Search and workspace memory. Check Again also has a Search entry. No new preferences/SavedVariables or permanent polling. Reduced motion follows the shared button/animation machinery.

**Checks:** Lua 5.1 syntax, existing client/group/communication runtime mocks and Python UI integration tests. In-game checks still required on Forever and Retail: solo/party/raid, chat restrictions, live resizing and scale, hover/selection, Back/Search, page scroll, chat Enter/Escape, reload/relog, optional Ellesmere theme, and two-addon peer confirmation.

**References:** Polestar PartyPanel/Party for status wording, listener lifecycle and cautious confirmation; EllesmereUI for cross-client UI; RCT addoncheck/checkpanel and Wargames+ for panel semantics. Code and page artwork are independently authored from our approved Duels design.
