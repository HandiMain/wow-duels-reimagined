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
    if message=="diagnostics" then
        ns.DiagnosticsUI.Open()
        return
    end
    ns.Window.Toggle()
end
