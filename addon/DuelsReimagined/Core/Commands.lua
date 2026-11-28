local _, ns = ...
-- One public command catalogue supplies both dispatch and chat help.
-- Development shortcuts are retained separately in this build, never listed.
local commands, ordered = {}, {}
local function Register(name, group, description, action, available)
    assert(not commands[name], "Duplicate slash command")
    local entry={name=name,group=group,description=description,action=action,available=available}
    commands[name]=entry;ordered[#ordered+1]=entry
end
local function Chat(line)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(line)
    else print(line) end
end
local function Tell(message)
    Chat("|cffd8b36aDuels Reimagined|r |cffc4c4c4"..message.."|r")
end
local function Combat()
    if type(InCombatLockdown)~="function" then return false end
    local ok,value=pcall(InCombatLockdown)
    if not ok or (type(issecretvalue)=="function" and issecretvalue(value)) then return true end
    return value~=false and value~=nil
end
local function SafeOpen()
    if Combat() then Tell("Finish combat before opening Duels.");return false end
    if ns.EditMode and ns.EditMode.IsActive() then Tell("Finish editing your layout first.");return false end
    return true
end
local function EnsureWindow()
    if not ns.Window.frame:IsShown() then ns.Window.Toggle() end
    return ns.Window.frame:IsShown()
end
local function Destination(id)
    return function()
        if not SafeOpen() then return end
        local item=ns.Search.entries[id]
        if not item then Tell("This page is unavailable.");return end
        if item.available then
            local ok,available=pcall(item.available)
            if not ok or available~=true then Tell("This page is unavailable right now.");return end
        end
        if EnsureWindow() then ns.Search.Open(item) end
    end
end
local function Page(section,page) return Destination("page:"..section..":"..page) end
local function Setting(key) return Destination("setting:"..key) end
local function Help()
    Chat("|cffd8b36aDuels Reimagined - Available Commands|r")
    local group
    for _,entry in ipairs(ordered) do
        if not entry.available or entry.available() then
            if group~=entry.group then
                group=entry.group;Chat("|cffd8b36a"..group.."|r")
            end
            local suffix=entry.name=="" and "" or " "..entry.name
            Chat("  |cffffdc80/duels"..suffix.."|r  |cffbfbfbf"..entry.description.."|r")
        end
    end
end
Register("","General","Open or close the addon.",function()
    if ns.Window.frame:IsShown() or SafeOpen() then ns.Window.Toggle() end
end)
Register("help","General","Display available commands.",Help)
Register("options","General","Open addon settings.",Page("options","options"))
Register("status","General","Open Addon Status.",Page("addonstatus","status"))
Register("diagnostics","General","Open diagnostics.",function()
    if SafeOpen() then ns.DiagnosticsUI.Open() end
end)
Register("hall","Competition","Open the Hall.",Page("hall","overview"))
Register("profile","Competition","Open your Duelist Profile.",function()
    if SafeOpen() and EnsureWindow() and not ns.CompetitiveUI.OpenMyProfile() then Tell("Your profile is unavailable right now.") end
end)
Register("titles","Competition","Browse your Duelist Titles.",function()
    if SafeOpen() and EnsureWindow() and not ns.CompetitiveUI.OpenMyTitles() then Tell("Your titles are unavailable right now.") end
end)
Register("leaderboard","Competition","View the leaderboard.",Page("leaderboard","standings"))
Register("history","Competition","View your match history.",Page("matchhistory","history"))
Register("achievements","Competition","View your achievements.",Page("achievements","achievements"))
Register("tournaments","Competition","Open tournaments.",Page("tournaments","overview"))
Register("champions","Competition","Open the Hall of Champions.",Page("tournaments","champions"))
Register("wargames","Competition","Open War Games.",Page("wargames","player"),function()return ns.Client.IsRetail() end)
Register("hud","Interface","Toggle the Duel HUD.",function()
    if Combat() then Tell("Finish combat before changing the Duel HUD.");return end
    local enabled=not ns.Settings.Get("duelHUDEnabled")
    ns.Settings.Set("duelHUDEnabled",enabled)
    Tell(enabled and "Duel HUD enabled." or "Duel HUD disabled.")
end)
Register("hud reset","Interface","Reset the Duel HUD position and scale.",function()
    if not SafeOpen() then return end
    ns.Settings.ResetDuelHUDPosition();ns.Settings.Reset("duelHUDScale")
    Tell("Duel HUD position and scale reset.")
end)
Register("edit","Interface","Edit the countdown layout.",function()
    if ns.EditMode.IsActive() then ns.EditMode.Cancel(true);return end
    local ok,why=ns.EditMode.Open("countdown")
    if not ok then Tell(tostring(why or "Layout unavailable.")) end
end)
Register("countdown","Interface","Open countdown settings.",Setting("duelCountdownVisual"))
Register("notifications","Interface","Open notification settings.",Setting("notificationEnabled"))
Register("sounds","Interface","Open combat sound settings.",Setting("duelCountdownSoundPack"))
Register("community","Community","Open the community page.",Page("community","community"))
Register("patchnotes","Community","Read the latest patch notes.",function()
    local latest=ns.PatchNotesData and ns.PatchNotesData[1]
    if latest then Page("patchnotes",latest.key)() else Tell("Patch notes are unavailable.") end
end)
-- Existing internal test and preview routes intentionally omitted from help.
local function Development(message)
    if message=="countdown edit" then
        if ns.EditMode.IsActive() then ns.EditMode.Cancel(true)
        else
            local ok,why=ns.EditMode.Open("countdown")
            if not ok then print("DR | "..tostring(why)) end
        end
        return
    end
    if message=="sounds status" then
        local _,countdown,fight,detail=ns.CountdownAudio.GetPackStatus()
        local victory,defeat=ns.CountdownAudio.GetResultSoundCounts()
        print("DR | "..detail.." | "..countdown.." countdown packs / "..fight.." FIGHT! sounds / "..victory.." victory / "..defeat.." defeat / "..ns.CountdownAudio.GetSharedSoundCount().." SharedMedia sounds")
        return
    end
    if message=="result victory" or message=="result defeat" then
        local ok,why=ns.DuelResult.Preview(message=="result victory" and "won" or "lost")
        if not ok then print("DR | "..tostring(why)) end
        return
    end
    if message=="countdown preview" then
        local ok,why=ns.DuelCountdown.Preview()
        if not ok then print("DR | "..tostring(why)) end
        return
    end
    if message=="notify warning" then
        local ok,why=ns.Notifications.PreviewWarning()
        if not ok then print("DR | "..tostring(why)) end
        return
    end
    if message=="notify achievement" then
        local ok,why=ns.Notifications.PreviewAchievement()
        if not ok then print("DR | "..tostring(why)) end
        return
    end
    if message=="notify rank" then
        local ok,why=ns.Notifications.PreviewPromotion()
        if not ok then print("DR | "..tostring(why)) end
        return
    end
    if message=="notify" or message=="notify preview" or message=="notify status" then
        if message=="notify status" then
            local status=ns.UpdateNotices.GetStatus()
            print("DR | Update notifications: "..status)
        else
            local ok,why=ns.Notifications.Preview()
            if not ok then print("DR | "..tostring(why)) end
        end
        return
    end
    if message=="hud preview" then
        ns.DuelHUD.TogglePreview()
        return
    end
    if message=="sim" or message:match("^sim%s") then
        local command=message:match("^sim%s+(.+)$") or "help"
        local ok,why=ns.CompetitivePreview.Command(command)
        print("DR | "..tostring(why))
        return
    end
    if ns.DuelDetection and (message=="detect" or message=="trace") then
        ns.DuelDetection.PrintStatus(message=="trace")
        return
    end
    if message=="test" or message=="test verbose" then
        ns.DuelSelfTest.Run(nil,message=="test verbose")
        return
    end
    if message=="peer" then
        local ok,why=ns.OpponentDiscovery.ProbeTarget()
        print("DR | Opponent discovery: "..(ok and "check requested" or tostring(why)))
        return
    end
    if message=="peer status" then
        local s=ns.OpponentDiscovery.GetSnapshot()
        print("DR | LOCAL opponent discovery: "..s.state.." ("..s.reason..") | ranking disabled")
        return
    end
    if message=="peer test" then
        local p,f=ns.OpponentDiscovery.RunSelfTest(print)
        print("DR | SIMULATED peer discovery: "..p.." passed / "..f.." failed")
        return
    end
    if message=="storage" or message=="storage status" or message=="storage test" or message=="storage prepare" then
        local S=ns.CompetitiveStorage
        if message=="storage test" then
            local ok,why=S.RunPersistenceProbe()
            if not ok then print("DR | Storage probe refused: "..tostring(why));return end
            print("DR | LOCAL storage probe incremented; development counters only.")
        end
        if message=="storage prepare" then
            local ok,why=S.PrepareSchema()
            if not ok then print("DR | Storage preparation refused: "..tostring(why));return end
            print("DR | LOCAL schema prepared; existing probe values preserved.")
        end
        local s=S.GetSnapshot()
        if s.state=="ready" then
            print("DR | LOCAL storage "..s.client.." | schema v"..s.version..(s.prepared and " prepared" or " preparation pending").."; account probe="..s.accountProbe.."; character probe="..s.characterProbe.."; matches and rating disabled")
        else print("DR | Storage unavailable: "..tostring(s.reason)) end
        return
    end
    if message=="mode" or message=="mode ranked" or message=="mode unranked" or message=="mode practice" then
        if message~="mode" then ns.Settings.Set("practiceDuels",message~="mode ranked") end
        local mode=ns.CompetitiveLifecycle.GetPreferredMode()
        print("DR | Next duel: "..mode..". Ranked challenges must start in the Duel HUD; native duels are Unranked.")
        return
    end
    if message=="competitive status" or message=="sync" then
        local C=ns.CompetitiveLifecycle
        if message=="sync" then
            local ok,why=C.StartSync()
            print("DR | Competitive sync: "..(ok and "requested" or tostring(why)))
        end
        local s=C.GetSnapshot()
        print("DR | Competitive: "..s.state.." | local recording: "..(s.localRecording and "on" or "off").." | peer exchange: "..(s.peerEnabled and "on" or "off"))
        local c=ns.CompetitiveStorage.ReadLocalCapacity()
        if c then print("DR | Evidence capacity: "..c.ledger.used.."/"..c.ledger.limit.." | Personal history: "..c.history.used.."/"..c.history.limit) end
        return
    end
    if message=="tournament net" or message:match("^tournament net%s") then
        local command=message:match("^tournament net%s+(.+)$") or "status"
        local ok,why=ns.TournamentSession.Command(command)
        print("DR | "..tostring(why or (ok and "Request submitted." or "Request unavailable.")))
        return
    end
    return false
end
SLASH_DUELSREIMAGINED1="/duels"
SlashCmdList.DUELSREIMAGINED=function(message)
    message=(type(message)=="string" and message or ""):lower():gsub("^%s+",""):gsub("%s+$",""):gsub("%s+"," ")
    local entry=commands[message]
    if entry then
        if entry.available and not entry.available() then
            Tell("This command is unavailable on your client.");return
        end
        entry.action();return
    end
    -- Legacy handlers return nil on a recognized command and false otherwise.
    if Development(message)==false then Tell("Unknown command. Type /duels help for available commands.") end
end
