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
    if message=="diagnostics" then
        ns.DiagnosticsUI.Open()
        return
    end
    ns.Window.Toggle()
end
