# Client compatibility — Foundation Step 1

**Scope:** World of Warcraft Retail and WoW Forever. **Implementation:** Shared client identity; no War Games gameplay or button added in this step.

The single client identity owner is `addon/DuelsReimagined/Core/Client.lua`, loaded before Settings and every UI file. It reads the fourth `GetBuildInfo()` return value (interface number), which is the tested approach in EllesmereUI's 9.8.9 `EllesmereUI_ClientGate.lua`. Polestar was consulted for safe API and event handling, but Polestar is Forever-specific and is not the cross-client reference.

| Client | Interface range | Client.Kind() |
| --- | --- | --- |
| Forever (Camelot) | 16000–19999 (currently 16001) | `forever` |
| Retail (Standard) | 120000–199999 (currently 120105) | `retail` |
| Unknown / other / unavailable | anything else | `unsupported` |

**Future Retail-only code:** Prefer load-time conditional filenames in the existing TOC: `WarGames/YourFile.lua [AllowLoadGameType standard]`. The modern Blizzard loader supports `standard` for Retail and `camelot` for Forever (as verified in EllesmereUI modules). In addition, gate actual game calls behind `ns.Client.IsRetail()` and confirm the specific Blizzard API exists before calling it. The loader gate prevents Forever from even executing Retail-only feature files; the runtime gate provides a second defensive check.

**Future interface:** A shared navigation row can be visible on both clients, with Retail-only interactions enabled and Forever offering an explanation via an enabled tooltip hit area. This is a design plan, not part of Step 1. No new search entry, setting, asset, SavedVariables field, or game command is needed here.

**Safety:** Never infer the client from `WOW_PROJECT_ID` or from the presence of a single API. Never call a Retail War Games API on an unknown client. Client identity is immutable within a session and creates no timers, globals or game events. Runtime/API availability is a separate question from client detection.

**Tests:** `lua5.1 tools/community/check_runtime.lua` checks Retail, Forever, string-encoded interface and unsupported/missing/error cases; `test_client_compat.py` checks source ownership and TOC load order. CI Lua syntax and existing UI regressions still apply. Actual dual-client proof requires solo in-game observation on both Retail and Forever. Status: IMPLEMENTED / AUTOMATED UNVERIFIED until CI completes.
