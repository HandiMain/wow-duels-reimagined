local _, ns = ...

SLASH_DUELSREIMAGINED1 = "/duels"
SlashCmdList.DUELSREIMAGINED = function(message)
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
