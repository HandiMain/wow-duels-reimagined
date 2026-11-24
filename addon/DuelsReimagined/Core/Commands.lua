local _, ns = ...

SLASH_DUELSREIMAGINED1 = "/duels"
SlashCmdList.DUELSREIMAGINED = function(message)
    if ns.DuelDetection and (message=="detect" or message=="trace") then
        ns.DuelDetection.PrintStatus(message=="trace")
        return
    end
    ns.Window.Toggle()
end
