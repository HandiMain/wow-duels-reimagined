local _, ns = ...

SLASH_DUELSREIMAGINED1 = "/duels"
SlashCmdList.DUELSREIMAGINED = function(message)
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
    if message=="hud" or message=="hud reset" or message=="hud preview" then
        if message=="hud reset" then ns.Settings.ResetDuelHUDPosition();ns.Settings.Reset("duelHUDScale")
        elseif message=="hud preview" then ns.DuelHUD.TogglePreview()
        else ns.Settings.Set("duelHUDEnabled",not ns.Settings.Get("duelHUDEnabled")) end
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
    if message=="diagnostics" then
        ns.DiagnosticsUI.Open()
        return
    end
    ns.Window.Toggle()
end
