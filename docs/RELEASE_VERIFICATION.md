# Pre-release verification register

Established 2026-11-24; implementation baseline `09cc4e1` (develop). Practical verification is deferred until **December 15, 2026**, when the user plans to obtain a second WoW account. An optional separately authorized Retail War Games session with Dalaran Gaming may occur earlier. No unsolicited distribution.

## Maintenance and closure rules

- Read this register on every development resumption. Every new feature, fix or changed dependency must add/update its relevant entry. Preserve IDs and evidence history; reopen affected checks after changes.
- Unchecked means outstanding, not necessarily unimplemented. Record exact commit/build, client/version, date, scenario, observed outcome and evidence (log, screenshot or user report) before checking an item. Record failed/skipped scenarios explicitly.
- Distinguish PLANNED, IMPLEMENTED/UNTESTED, AUTOMATED PASS, SOLO IN-GAME VERIFIED and MULTIPLAYER VERIFIED. Simulation, CI and API acceptance are not live evidence.
- Both clients require applicable checks. Use isolated test characters and backed-up test SavedVariables. No destructive resets, automatic acceptance, unapproved activation, distribution or release.
- This is a consolidated starting register from the audit and subsystem records, not exhaustive certification of every historical change. Reconcile older individual checks before release.
- Existing evidence: prior documented simulation/CI checkpoints and one user-reported Forever outgoing duel loss in DUEL_DETECTION.md. Neither verifies the new integration baseline; no new tests were performed when creating this register.

## A. Engineering blockers (not merely tests)

- [ ] A01 — Sustainable retention beyond 8,192 shared IDs and 8,192 personal observations: exact evidence or explicit archive trust/finality, no silent loss, deterministic replay, late corrections and rolling seven-day opponent budget across seasons.
- [ ] A02 — Durable late conflicting-claim handling after settlement; provenance, relayed claims, correction and replay policy; no claims of global authoritative standings.
- [ ] A03 — Finalize season epoch, rollover, version compatibility, privacy/metadata/consent, migration and release scope.
- [ ] A04 — Review new gated adapter call contracts, source, client/API limitations and matching-build CI failures before activation.
- [ ] A05 — Authorize isolated local-only test build first; then separate peer test activation with common test epoch and consent. Keep production season disabled until approved.

## B. Automated checks and persistence

- [ ] B01 — Review matching-commit CI; run Lua syntax, TOC/load-order, client, manifest, regression, assets and simulation suites; add tests for new live-adapter contracts; record actual results.
- [ ] B02 — Fresh install and upgrade from prior builds; defaults, invalid/missing roots, unsupported schema, failed writes, no destructive reset; preserve preferences.
- [ ] B03 — Account vs character separation, Forever vs Retail separation, reload/relog, durable run ID, duplicate terminal cycles, saved local history and peer ledger reconstruction.
- [ ] B04 — Capacity near/full behavior, duplicate/stale writes, compact round-trip, canonical validation, deterministic dispute selection, no silent eviction or simulation contamination.
- [ ] B05 — Confirm release build fingerprint matches packaged files; compare diagnostics baseline and investigate all new failures/warnings.

## C. Ordinary duels and personal recording (both clients)

- [ ] C01 — Incoming/outgoing invitation, cancellation/decline/expiry, accepted countdown, ordinary win/loss both roles, repeated rematches; exactly one local record per accepted duel.
- [ ] C02 — Opponent without addon; no reply is unknown not absence; personal wins/losses still recorded, rating unchanged.
- [ ] C03 — Retreat both roles, finish/result event order, duplicate/missing/late/conflicting lines, unrelated nearby duel, disconnect/reload/zone interruption; unknown not automatically a loss.
- [ ] C04 — Identity resolution: target/focus/mouseover/nameplate, absent/ambiguous identity, Forever surnames and accents, Retail realm-qualified names, localization and secret values.
- [ ] C05 — Validate elapsed duration label, server timestamps, opponent name/class/faction and missing metadata; exclude known death duels and spectator events (do not perform lethal tests).
- [ ] C06 — Verify persistence after reload/relog and character swap; no duplicate stats, false match or live writes while disabled.

## D. Multiplayer ranking and communication (both clients)

- [ ] D01 — Two enabled clients, opt-in/out, addon discovery and exact sender/GUID, compatible/incompatible build/season, same/cross-realm as supported, no response, restricted communication.
- [ ] D02 — Handshake before countdown in both directions; fast acceptance, expired/missing offer/ack/final confirmation, wrong sender, stale/replayed packets, opt-out; never auto-accept or upgrade late.
- [ ] D03 — Complementary results, timestamps within tolerance, duplicate/conflicting results, timeout, refused sends, disconnects, late conflict policy, both clients converge without inventing evidence.
- [ ] D04 — Known Elo expected values, placements, unique opponents, repeat-opponent weight limits, practice matches, peak/streak, ranks, season rollover and carry; compare deterministic reference results.
- [ ] D05 — Bounded delta sync, request/responder pacing, duplicate/reordered/malformed fragments, partial failure, reconnect/retry, combat/zone cancellation, privacy and compatibility; no permanent traffic.
- [ ] D06 — Multi-peer convergence, partial leaderboard honesty, conflicting relayed data, new player catch-up, unknown names; requires additional participants beyond initial two accounts.

## E. Competitive UI (both clients)

- [ ] E01 — Preview on/off, no cross-contamination, empty/error/disabled states, real history and Hall statistics, known standings and player card, correct pending/disputed/unconfirmed/practice/ranked labels.
- [ ] E02 — Search, filters, sorting, scrolling, pinned standing, graph time range, dynamic seasons, long names, missing icons/metadata, history detail rating changes, capacity notices.
- [ ] E03 — Independent movable/closable player card, focus/stacking, Back button, navigation and preserved scroll; no stale simulated profile after switching.
- [ ] E04 — Approved main design, War Games lower rim, Your Standing wrap, missing glyph fixes, hover/click/selection, scaling and font legibility; validate screenshots at minimum/default/large windows.

## F. Shared UI and client compatibility

- [ ] F01 — Retail/Forever load without Lua errors, unsupported client and optional API handling; all supported features gated correctly.
- [ ] F02 — Main window, landing page, Options, Addon Status, Community, Patch Notes, footer, search, Back, tooltip and all navigation states; no cropping, broken assets or seam overlap.
- [ ] F03 — Default Blizzard chat Enter/Escape, keyboard focus, menus, dialogs, combat, close/reopen, movement peek, dragging and resizing, reduced motion, font/scale settings.
- [ ] F04 — EllesmereUI enabled/disabled, theme/font matching and unavailable explanations; Escape-menu addon button coexists with Polestar and other addons, no overlap; Blizzard default fallback.
- [ ] F05 — Minimap/widget/both/hidden modes, independent size/opacity, drag, reset, tooltips, reload and Search visibility; all preferences centralized and persisted.

## G. Retail War Games (separate test authorization)

- [ ] G01 — Forever disabled/unavailable; Retail Players and Host/Spectate, party/raid leader, group/bracket checks, absent or unsupported APIs, combat restriction, inside/outside arena transitions.
- [ ] G02 — Captain selection, duplicate prevention, one/zero friends, online/offline indicators where observable, scroll, clearing and Battle.net routing.
- [ ] G03 — Arena gallery: all supported/client-discovered maps, search, favorites, selected state, Cancel/Escape/outside click, resize, native thumbnails, labelled illustrations and unavailable art; no incorrect map association.
- [ ] G04 — Actual native challenges, acceptance, match entry for both teams, spectator entry and roster, tournament rules ON/OFF, invalid/refused requests and reconnect. API acceptance alone is not success. Additional participants may be needed.
- [ ] G05 — Team borders and scrollbar gutters, separate emblem, nav placement, button feedback and dropdown consistency.
- [ ] G06 — Native ready check: leader-only, active per-member responses, offline/unknown, expiration, roster changes, combat/arena refusal, no automatic ready response; ordinary challenge still works without addon peers.
- [ ] G07 — One pending native request across modes; duplicate suppression, timeout/entry unlock, refusal and ambiguous return, stale configuration, no automatic resend, ordinary arena vs War Game vs unavailable classification, match state transitions without invented winner/association.
- [ ] G08 — Captain availability and client-listed vs reference arena labels; multiple/no Retail accounts, stale Battle.net cache, reconnect and event coalescing, fresh pre-request validation and exact routing.
- [ ] G09 — Separately authorize W1 private peer build; mutual selected captains and consent, matching/mismatched setup, no reply, expiry, wrong sender/token, throttling, roster/ready changes, combat/arena restriction and no effect on native challenge or duel ranking. Host remote rosters/readiness remain unknown; no BNet IDs/names in packets.
- [ ] G10 — New readiness button/row status and captain/map text: minimum/default/max window and font scale, both page modes, hidden gated controls, Escape/Enter, Options, tooltip and no duplicate painting; repeat existing G01–G05 on changed build.

## H. Group, presence and diagnostics

- [ ] H01 — Real solo/party/raid roster changes, leadership, incomplete/secret identities, cross-realm/Forever surname behavior, group recovery and addon-user presence/version display; no response treated as unknown.
- [ ] H02 — Diagnostics entry points, full scan, cancellation, copy report, developer controls, baselines, saved report isolation, error capture forwarding/restoration and BugGrabber coexistence.
- [ ] H03 — Performance: idle/open/hidden UI, animation cleanup, resource counts, repeated page/card opens, memory samples, frame-time during replay and synchronization at capacity; no simulated performance claims.
- [ ] H04 — Verify no regression to War Games, chat, Options, other addon buttons, group status or lifecycle after each fix.

## I. Public release gate

- [ ] I01 — Reconcile all older per-change unverified checks in PROJECT_GUIDE.md and linked subsystem documents; reopen affected evidence when implementation changes.
- [ ] I02 — Review source provenance, permissions and required notices, media assets and generated illustrations; confirm reference addon reuse and redistribution rights.
- [ ] I03 — Remove/disable development preview by default; remove fake patch-note fixtures from public presentation, verify real version metadata and honest statuses.
- [ ] I04 — Community report/suggestion links and browser forms, credits workflow and verified-fix rules; no automatic publishing or invented credits.
- [ ] I05 — Clean package/install/update on both supported clients; correct TOC/version only with approval, release notes, supported scope, privacy explanation and known limitations.
- [ ] I06 — Review all applicable blockers, evidence and exclusions; get explicit release approval before merging main or distributing. No public release just because two-account tests pass.

## Evidence log

| ID | Commit/build | Client/version | Date | Result | Evidence / remaining limitation |
|---|---|---|---|---|---|
| — | 09cc4e1 | Both | 2026-11-24 | IMPLEMENTED/UNTESTED | Integration baseline; no new live tests. |

## Supporting records

[Project guide](PROJECT_GUIDE.md) · [Competitive](COMPETITIVE.md) · [Duel detection](DUEL_DETECTION.md) · [War Games](WAR_GAMES.md) · [Client compatibility](CLIENT_COMPATIBILITY.md) · [Diagnostics](DIAGNOSTICS.md) · [Presence](PRESENCE.md) · [Group roster](GROUP_ROSTER.md) · [Addon status](ADDON_STATUS.md) · [Community](COMMUNITY_GITHUB.md) · [Asset provenance](ASSET_PROVENANCE.md) · [Patch notes](PATCH_NOTES_TEMPLATE.md)

### Open regression — 2026-11-24

- [ ] B-reg01 — Re-run ResultConfirmation isolated QA after correcting omitted simulation scope in fixture calls. Expect all 21 cases to pass; confirm other suites and live-disabled gates unchanged. User report for b5f0e349f9a5: 77/0/1/5, 12 failed result subcases. Prior CI runtime failure also requires review; do not close this item on source inspection alone. No live multiplayer testing requested before December.


### Solo test commands and placement UI
- [ ] E-sim01 — Fresh login/reload defaults to local data, even with an old competitivePreview preference; empty states with no fake active season; real SavedVariables untouched.
- [ ] E-sim02 — /duels sim start, win/loss (default rotation and specified rival), invalid input, reset/stop, reload; no live data or transport changes; verify all pages and player card refresh, simulation caption never absent, no stale fixture rows.
- [ ] E-sim03 — Check 0/5 through 5/5 credits, fractional same-rival credits, minimum three distinct rivals, transition to normal rank, history/graph/statistics consistency, font scale and compact layout.
- [ ] I-sim01 — Disable or remove TEST_ENABLED and test commands before public package, verify commands cannot mutate local or peer data, no automatic populated fixture. Retain isolated automated test capability as appropriate.


- [ ] E-placement04 — Confirm actual approved placement plate at zero progress in real empty Hall even when ranked seasons inactive; all five sockets, title, instruction, plaque and opponent text visible. Check fractional fills, same-rival cap, first rank reveal only once when both requirements fulfilled, reduced motion, resize/reopen, hide/stop/reset, default and compact font/menu scales. Confirm normal rank art and other Hall panels preserved, no new persistent animation or simulated data leaking to live records.


### Duel intent and result edge cases
- [ ] E-mode01 — /duels mode ranked|practice; default Ranked intent, saved preference, next-challenge capture, mid-countdown/mid-duel change applies only to next challenge. Consent and build gates independently locked; no native auto accept/forfeit. Practice toggle absent from Options and Options search, other settings layout unchanged. Future HUD mode control must use the same owner; add HUD-specific verification when implemented. Verify both clients.
- [ ] D-mode02 — Private peer mode revision 2: R/R, R/P, P/R, P/P, incompatible/no addon, missing offer/ack/confirm, fast acceptance, stale packets and changed target. No rating/placement for practice, no false remote agreement; both local views may differ when evidence incomplete. No conversion after countdown or loss.
- [ ] D-mode03 — Pending only while actual collector exists; timeout/restriction/consent withdrawal, rapid new challenge during settlement, world transition/disconnect, local unknown and retreat, no invented winner, sync deferred outside duel. Verify accepted candidate not relabelled practice and no stale pending after reload; preserve previous evidence.
- [ ] E-mode04 — Solo test practice/unranked/pending win/loss, unknown/fled/retreat and repeated capped opponent; Match History filters and reason line; no rating/placement for noncompetitive results, unknown not counted as loss, normal placements unchanged; no live data or transport. Verify closing Hall does not stop real detector/recording during separately authorized live checks. HUD intentionally deferred.
- [ ] B-reg02 — a0d343d UI mock CI failed at line 143 while syntax and preceding core suites passed. Mock had no live storage loaded; assert unavailable state, zero active season/rows. Require full fresh CI, not just screenshot approval.


### Duel HUD — initial independent widget
- [ ] H01 — Default enabled on fresh login; disable/enable in Options, saved position, lock, bounded 80–120% scale, reset, resolution/UI scale, maximum font scale, no overlap with critical gameplay controls; separate from main window and floating access icon; Enter/Escape behavior unchanged.
- [ ] H02 — Target/self identity, class and rank from existing local read model; unknown opponent, no player target, provisional rank, Player Card click and simulation isolation; exact opponent stays bound through target changes and lost readable GUID.
- [ ] H03 — Click Challenge Target and Forfeit through documented native APIs, including combat, missing API, invalid target, incoming challenge, repeated click, death-duel exclusion; no automated native action or chat input/macro creation. Verify Retail and Forever separately.
- [ ] H04 — Native health display including secret values (direct StatusBar setters only), readable health percentage, unknown/missing unit and unavailable health; no secret arithmetic/storage, no taint.
- [ ] H05 — Observe countdown, local result, incomplete result, interruption and new duel; timer is since acceptance not verified combat start. Check mode freeze, no rating claim without matching evidence; no stale result or damage values. Preview is explicit and never sends native actions or peer packets.
- [ ] H06 — Implement and verify reliable per-duel damage isolation before advertising damage totals; reset private counters at each new cycle; no global C_DamageMeter.ResetAllCombatSessions or third-party data changes. Test unrelated combat, target switches, pets/absorbs, restrictions and both clients. Currently unavailable by design.
- [ ] H07 — Inspect shared style visual alignment, scaling, preview/normal state, frame and event cleanup on hide, no idle polling, only bounded result/active timer; disable developer preview before public release.
- [ ] B-reg03 — Existing 6f4d411 CI run 45452614381 failed check_opponent_discovery_runtime.lua:37 (isolated agreement suite). Resolve and obtain fresh automated evidence before private activation; HUD changes do not repair this failure.

- [ ] H08 — Visual repair: compare approved compact concept to idle and /duels hud preview; clean dark interior, no giant flat brown/grey rectangles, crest and bronze rim, lit selected mode, mirrored player information, intact timer and stat plate, button states, gear and close. Check 80/100/120% and all font scales. Confirm movement, hide and native-action gating unchanged. No gameplay or damage source changes in this visual update.


### Widget-only ranked eligibility checkpoint
- [ ] H09 — On both clients, actual native /duel, unit-menu and other native outgoing actions always Unranked even when Ranked preferred; explicit widget Unranked also Unranked. Only direct widget Ranked click may originate a ranked candidate; no stale origin after failed launch, changed target, duplicate native attempt, cancellation or reload. Recipient uses normal Blizzard acceptance; never auto-accept.
- [ ] H10 — Target detection, unknown/no reply, same GUID, incompatible build/season, local consent off, capacity full, previous result pending, timeout, rapid retarget, remote R/U changes and expiry. Ranked disabled when eligibility missing; compatible U permits changing preference but never ranked launch until both R. Check both players can switch back from U. Native action remains guarded; click rechecks availability, no silent downgrade of previously displayed ranked action.
- [ ] H11 — Two-account verification of compatible widget R/R, R/U, U/R, U/U, ordinary slash/normal menu initiator with both R, fast accept and late/lost packets; no incorrect rating/placement award. No live activation until authorized.
- [ ] H12 — Ranked/Unranked labels, combined legacy history filter, reasons, updated commands; no fake opponent evidence, no additional rating engine. Review timer artwork, unclipped rank labels, circular portraits and masks at 80–120% scale. Existing damage readings still unavailable by design.
- [ ] B-reg04 — Update stale hard-coded suite expectations (agreement 25, history 27, discovery 15, lifecycle 15) and run full CI. Added mock origin/pref tests. Do not mark this checked until actual automated result is available.


- [ ] H13 — Forever reported widget unranked challenge no invitation, 90s false pending lock. Verify near/far/self/no target, movement into/out of range, unknown/secret range, exact native launch, confirmation/decline/cancel, failed attempt returns idle within 5s, target switch/dismiss, retry and no synthetic match. Verify actual recipient receives native invitation separately on Forever and Retail. Confirm hidden HUD has no range polling. User report diagnostics 75 PASS/0 WARN/0 FAIL/8 SKIP on 64e0253; not evidence of invitation delivery. CI 45460740312 fails separately on mixed-history preview storage; keep release blocked.


### Update notifications
- [ ] N01 — Default enabled, master visibility and sound toggles/search, preview button and /duels notify preview, no actual release inferred from demo patch notes or versionless test build. Both clients, 80–120% HUD scale, fonts, moved HUD, top-edge fallback, hidden HUD, resolution and reduced motion. Compare exact approved artwork; no stale connector, overlap, focus or chat changes.
- [ ] N02 — General.mp3 uses native SFX/Effects; test Effects volume zero/low/high, master audio, disabled notification audio, one sound per displayed card, combat pause/resume and rapid dismissal. No global sound changes. Confirm redistribution rights before release.
- [ ] N03 — Existing Presence two distinct corroborating group peers, exact stable version comparison, reject malformed/dev/RC/implausible versions, same/older, duplicate GUID, stale roster, no false official latest claim; no extra traffic. Actual peer detection unavailable on versionless private build. Verify real published versions and both clients before enabling public release claims; target-only and guild discovery are out of this milestone.
- [ ] N04 — Queue bounds, deduplication, safe combat/instance/duel deferral, login delay, dismissal, per-version 24h snooze, new version, reload, settings disable, fixed GitHub copy link and no preview persistence. No active gameplay writes. Future notification producers require explicit approval and their own evidence.
- [ ] B-reg05 — b5cd610 CI run 45462377715 still fails CompetitivePreview.lua:74 invalid_or_unsupported_storage during mixed-history simulation. Notification tests are ordered before that old suite so their results can be observed independently; full CI remains a release blocker.


### Tournaments — Stage 1 interface foundation
- [ ] T01 — Verify Tournament navigation and empty states on Retail and Forever, War Games position and client gating, no fictional listings, controls or peer traffic; existing page/Back/Search/workspace, resize/scroll, theme/font/keyboard behavior and Full Scan. Approved sidebar plaque integrated; overview/banner art remains pending.
- [ ] T02 — Check isolated adaptive policy across registration, competing, eliminated, host and complete; no bracket before actual draw, no joining/hosting during active participation. Live role and network state not implemented. Do not mark live behavior verified from self-tests.
