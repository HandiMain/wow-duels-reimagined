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

### Tournaments — Stage 2 shared integrity foundation
- [ ] T03 — Run shared integrity isolated peer review and existing recovery QA on both clients: 10 agreeing copies + 1 mismatch, repeated peer, stale revision/expiry, malformed/incomplete exchange, client/domain/event isolation, bounded receipt count, actual simulated recovery receipt. All rank/record/live gates remain disabled.
- [ ] T04 — Two-account real delivery and reconciliation, then additional independent peers and disconnects. No global discovery, file attestation, majority trust or live tournament integration certified. Tournament evidence adapter remains pending until event engine exists.


## Mandatory production activation gate (approved 2026-11-25)
Do not ship a development build with intended production features silently disabled. This is a release-blocking checklist; it is not permission to activate live systems now. Review every gate on the final candidate, including indirect and build-time flags. Verify on Retail and Forever separately and preserve player consent and permanent client limitations.

- [ ] Inventory every disabled/preview/simulation-only feature, hardcoded feature flag, nil schedule, placeholder and developer command. Record source owner, intended production state, activation prerequisites and evidence; identify deliberately deferred features and hide them or describe them accurately. Do not indiscriminately enable unsupported, opt-in, unfinished or debug-only behavior.
- [ ] Prepare safe account/character storage and migrations; activate personal duel recording, match history, statistics, profiles and earned achievements; verify reload/relog/character isolation and no simulated records in live stores.
- [ ] Configure approved season epoch and activate the mutually verified ranked lifecycle: consent, opponent detection, agreement, result confirmation, canonical ledger, rating/placements, anti-farming, ranked history, season progression and competitive achievements. Verify real wins, losses, rematches and unranked reasons with two accounts on both clients.
- [ ] Activate peer synchronization, bounded recovery and shared integrity only after real sender/delivery, disconnect, conflicting evidence, replay, opt-out and performance verification. Never treat matching summaries as authentication or discrepancies as cheating proof.
- [ ] Complete and test tournament creation, discovery, registration, brackets, host/referee authority, results, widget, trophies and event recovery; keep Retail/Forever isolated, ordinary 1v1 duels only. Any unfinished format remains out of the approved release scope.
- [ ] Verify public Community integration and approved War Games behavior; keep War Games Retail-only, optional sound/media and preferences intact.
- [ ] Remove or isolate Solo Lab and test-only controls/fixtures, run package syntax/TOC, fingerprint, asset, storage, regression and performance checks. Update Diagnostics release gate to flag unintended disabled production capabilities; diagnostic PASS in development is not release certification.
- [ ] Publish only the approved stable candidate after required tests and user approval. Record actual activation values, commit, test evidence and any explicitly deferred features. No automatic public release.

### Stage 2 corrective verification (2026-11-25)
Retail user report for build cdd847e9f7d4: 80 PASS / 1 WARN / 1 FAIL / 7 SKIP. Storage lifecycle 22/22 PASS; shared review 11/13 with NaN revision rejection failing in both fixture client paths (CompetitiveIntegrity.lua:156). Existing recovery suite 9/9 and isolation/resource checks passed. Corrective scope: finite nonnegative validation for review revisions and timestamps, expanded regression assertions; no live gates, transport or storage changes. The optional BugGrabber absence explains the baseline warning. Rerun the full scan in each game client; no live multiplayer certification.

Performance follow-up: report measured 852.23 ms total work, PeakTime 821.8422 ms, SessionAverageTime 0.0040 ms; delta comparison 136.18 ms, final data foundation 120.45 ms and competitive data view 104.36 ms are among the slowest individual providers. Source inspection confirms RunAsync batches the UI audit but D.Run executes the remaining providers in one callback. This is a credible scan hitch source, not proven attribution of the client peak. Compare a fresh quiet-session sample before/after Full Scan (without resetting the profiler or running another scan in the quiet interval); separately profile and time-slice expensive QA as a focused follow-up. Preserve per-case isolation and existing scan/release semantics. No performance regression fix or certification claimed here.

Offline test evidence: exact prepared review block (9119 bytes, FNV-1a 679973287) executed using local LuaTeX Lua with a minimal compatibility snapshot stub: 13/13 without native predicates, 13/13 with mocked correct predicates, 13/13 with deliberately permissive predicates (representation fallback). This is isolated review logic, not full module suite, WoW or multiplayer evidence. Original literal 0/0 and runtime-generated NaN remain covered. Reference: Warcraft Wiki Lua functions and Patch 12.1.5 API changes document math.isfinite/isnan; portable fallback tested independently.

### Stage 3 — tournament creation draft
- [ ] T05 — Both clients: open Host & Manage, enter valid UTC start and location, select 4–32 players, best-of, deadline, optional level limits and rules; Save Draft confirms local session only. Invalid date/past cutoff/reversed levels/blank name must refuse; successful draft remains unchanged after invalid edits. Scroll, resize, options/font, Enter/Escape and page close should remain functional. No publishing, live records or peer traffic. Verify draft is discarded on reload/logout.
- [ ] T06 — Full Scan: Tournament creation / isolated draft QA 15/15 plus existing UI policy, storage, shared integrity, recovery and isolation. Record separate Retail and Forever results. No live tournament certification; publication and registration pending.

- [ ] T07 — Confirm live detected EU/US and each Forever ruleset (PvE/PvP/RP/RP-PvP), unavailable/Hardcore gate and cross-scope rejection; verify actual region and routing before enabling discovery, faction/layer reachability separately. Test local schedule preview on different timezones and DST dates. Audit ranking/storage partition separately before live activation. No claim of cross-region or cross-ruleset reachability.

### Stage 4 — shared population boundaries
- [ ] T08 — Run Full Scan: Competitive population / isolated scope QA 7/7, Tournament creation 15/15, navigation 10/10. On Forever EU PvP character verify actual faction and all four read-only values in Host & Manage/Browse; repeat on Retail and other available communities. Check neutral/unknown/Hardcore refusal and stale displayed population refusal. UI resizing, text and scrolling, no fake events.
- [ ] T09 — Complete scoped ranked evidence/schema/wire migration, no silent reinterpretation of existing client-only evidence; preserve personal histories and probes. Verify region, ruleset and faction policy, consent, compatibility, profile/replay and integrity isolation. RankedReady remains false until explicitly verified and authorized. No multiplayer claim. Verify real realm/layer/War Mode reachability separately.

### Stage 4B — scoped ranked storage and exchanges
- [ ] Run new Competitive storage / isolated population QA 9/9, scope 7/7, existing competitive storage 22/22, recovery and all other regression checks on both clients and CI. Confirm old unscoped records preserved and excluded, matching scope only in storage/replay, mismatched scope rejected even if page metadata is altered; no test fixtures saved. RankedReady stays false pending separate activation decision and real multi-account evidence. Confirm faction policy for ranked vs local unranked, switching populations and actual sender reachability.

### Stage 5A — registration rehearsal
- [ ] T10 — Valid future UTC draft, Test Publishing, Local Test label, empty roster. Player Preview, Test Join, Test Check-in Time, Test Check-in, Organizer View shows checked-in participant, Player Preview, Leave Test, Cancel Test. Normal Browse empty afterward. Verify invalid level/deadline, resize, scroll, navigation, reload discards. No real player or records affected.
- [ ] T11 — Full Scan registration / isolated host QA 13/13 and existing regression checks. Real discovery, delivery, acknowledgments, commitment and recovery still required in Stage 5B; release blocked.

- [ ] T12 — Creator/coordinator separation: reject cancellation or rule edit by any replacement coordinator or ordinary participant. Verify owner disconnect/reconnect, acknowledged replication, eligible deterministic succession with mutually exclusive terms, late packets and partition conflicts; pause safely when authority is ambiguous. Verify owner returning, all peers offline, persistence/recovery, no duplicate advancement, owner-only cancellation relay, and exact community separation in real two/multi-account trials before enabling live tournament hosting. No solo simulation certifies failover.

- [ ] T13 — Host calendar: pick future date/month, hour and minute; confirm updates local start and registration deadline. Past days disabled, too-early time or DST ambiguity invalid; cancel/outside click/Escape and page hide leave committed value untouched. Resize/scroll/scale, chat focus, reload; verify actual client local-time conversion and compare UTC draft across timezones. Full Scan calendar scheduling QA 5/5 and prior Stage 5A registration 13/13; no live systems activated.

- [ ] T14 — One active tournament: Host Tournament disappears upon test publishing; Manage Tournament replaces it; Player Preview must show neither create nor manage tab (Organizer View returns to management); cancel test restores Host Tournament. Full Scan registration 17/17, navigation 12/12, creation 15/15, calendar 5/5. Validate scheduled-start lock, terminal-only release and duplicate owner cache check. Before live activation: persistent creator commitment, recovery on reload/reconnect/community change and coordinator migration, verified completion, stale/foreign/conflicting peer advertisements rejected. No global uniqueness proof from local cache alone.

- [ ] T15 — Stage 5B1 isolated tournament wire QA 10/10 (both client fixtures, exact community and sender, reverse/duplicate/conflicting/expired fragments, oversized input, lost join ACK and cross-host commitment, stale/altered request refusal). Existing registration 17/17, calendar 5/5, navigation 12/12. Verify real transport sender binding, durable one-event commitment across reload and community change, receipt epoch/recovery, roster/cancellation synchronization and host failover before activation. All live paths remain closed.

- [ ] T16 — Recovery journal QA 10/10, exchange 10/10, registration 17/17. Simulated storage reopen restores pending exact requests, keeps commitment after lost ACK, refuses community changes and corrupted storage, rejects stale writer, isolates characters. Host lock fixture requires explicit terminal release. Actual disk recovery, roster/receipt reconstruction, owner/coordinator handoff and real transport remain blocked.

- [ ] T17 — Host recovery checkpoint QA 10/10, prior recovery/exchange 10/10 each, registration 17/17. Simulated lost join and host reopen, exact receipt, owner-only cancellation, status recovery, stale controller and snapshot, rate bound and corrupt journal. Verify full roster wire paging, historical cancellation tombstones, actual persistence/transport and multi-account coordinator migration before enabling live. Retail UI audit should cover >20k objects with explicit bounded-limit reporting; compare same optional addons for baseline and inspect resource coverage, do not suppress skip/warn.

- [ ] T18 — Host recovery expanded QA 20/20; prior suites unchanged. Test historical cancel across next publish/reopen, archive immutability, member-only and sender-bound pages, complete 32-player transfer, changed revision fresh recovery, and matching checked-in checkpoint copies. Fixture-only; full peer roster transport integration, session binding, safe archive capacity management, disk recovery and coordinator election/failover remain blocked pending actual multiplayer verification.

- [ ] T19 — Stage 6A bracket engine QA 16/16; all prior suites unchanged. Capacities 4/8/16/32, sparse byes, start and owner gates, checked-in roster, BO1/3/5, matching reports, replay/evidence duplication, premature advance, conflicts and deterministic recovery. Actual duel capture, bracket journal integration, start lock, coordinator terms, interactive rehearsal and visuals remain outstanding; no multiplayer proof.

- [ ] T20 — Stage 6B organizer recovery 26/26 (includes six new registration-to-bracket cases), bracket QA 16/16, previous suites unchanged. Owner-only start, frozen check-in roster despite time rollback, stale controller, append-only reports, exact duplicate, late dispute after provisional champion, owner cancellation and corruption refusal. Actual terminal finalization, duel evidence, wire transport, interactive rehearsal, persistence and coordinator takeover remain blocked.

- [ ] T21 — Stage 7A organizer recovery 34/34, bracket QA 16/16. Verify creator remains owner before start and cannot participate; unknown connection pause; incomplete/conflicting checkpoint refusal; term fencing; coordinator lacks cancellation authority; handback only with current synchronized creator checkpoint; all-disconnected pause and missing control rejection. Simulated one-journal transitions only. Actual peer election, presence, durable replicated votes, handback, offline registration, completion/disputes and multiplayer tests required before release. Approved living policy docs/TOURNAMENT_POLICY.md.

- [ ] T22 — Stage 7B host recovery 42/42, brackets 16/16. Relayed pending join cannot create roster or release commitment; expiry and cancellation; fixed majority with missing peer, minority/conflicting copies refused, owner handback; full bracket replicas reject old term and conflicting/rewritten reports. These are local fixture tests only. Actual peer connectivity, election votes, offline relay persistence and wire delivery remain release blockers. Diagnostics optimization deferred until tournament completion.

Stage 7B integrity refinement: the progress-replica fixture verifier must supply the exact independently accepted journal log in addition to current control. Reject a valid-looking appended duel report invented by the coordinator. Single-journal evidence only; live independent report receipts and certificates still required.

- [ ] T23 — Stage 7C1 organizer recovery 50/50 and brackets 16/16. Finalize only with complete undisputed log, owner current term and matching participant copies; archive persists; host releases and may publish another event; participant completion receipt survives lost ack/new event; owner hold and term resume; tampering fails closed. No actual peer authentication, terminal correction, retention or disconnect adjudication claim. Test counts only until executed.

- [ ] T24 — Stage 7C2 host recovery 54/54; brackets 20/20. Check 299/300 boundary, reconnect reset, unknown/both offline, continuity gap, stale term/controller, withdrawal and replay. No real presence, timers, visible countdown or notification firing tested; absent-player completion and dispute correction pending.

T24 also checks finalization after verified offline forfeit without an absent loser's acknowledgement; missing champion or conflicting supplied copy rejected.

- [ ] T25 — Stage 7C3 host recovery 58/58 and bracket 24/24; consent exact dispute revision, both duelists, no confirmed-result reset, old evidence/attempt refused, repeated disputes held, reopen, stale controller, final receipts without semifinalists. Runtime pending; live authority and late corrections unverified.

- [ ] T26 — Stage 8A host recovery 66/66, bracket 24/24; assigned tournament observations and shared result validation, no rank eligibility, unagreed/foreign/ranked challenge, old cycle, incomplete evidence, paused control and conflicting observations. No actual detector subscription or gameplay, ranked exclusion in live lifecycle still required. CI and real Retail/Forever peers pending.

- [ ] T27 — Stage 8B host 72/72, bracket 24/24. Actual isolated detector instances connect/disconnect, freeze mode through hold, advance only from complete observations; peer result validation excludes tournament. Live arm intentionally disabled. Verify manifest and static checks, then Forever/Retail multiplayer before activation.

T27 additionally checks wrong opponent and cancellation cleanup, immediate listener removal before querying assignment status.

### Tournament finalization — F1 private registration adapter
- [ ] T-F1 — Separately authorize an isolated test build with TOURNAMENT_TEST_ENABLED, then two consenting same-population grouped accounts; verify host publish, direct query, join/leave/check-in, exact owner receipt, refused send/retry, duplicate/stale/wrong sender, partial fragments, group change, combat, reload, cancel/terminal status. Verify disabled build never sends/writes; private test journal never enters rank/history or local simulations. Public/global discovery, roster replication, real match assignments/results and distributed recovery remain engineering blockers. Implemented/untested; matching-commit CI and live evidence required.
