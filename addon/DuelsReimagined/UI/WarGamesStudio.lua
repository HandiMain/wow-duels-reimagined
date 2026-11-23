local _,ns=...
-- War Games setup companion. Owns no gameplay, network traffic or persistence.
-- The core session owner provides all data; this is a conservative extension
-- of the existing approved bronze War Games panel, not spectator overlay #10.
local Engine,Tools=ns.WarGames,ns.WarGamesSession
local Style,Widgets,View=ns.Style,ns.Widgets,ns.WarGamesUI
local C=Style.color
local frame=CreateFrame("Frame",nil,View.GetCanvas())
frame:SetSize(700,342)
Style.Skin(frame,C.body,{corner=9,edge=C.goldDim,light=C.goldDim,
    dark=C.window,shade=0.12,shine=0.11,rim=0.82})
local heading=Style.Text(frame,"MATCH COMMAND",19,C.pale,nil,"display")
heading:SetPoint("TOPLEFT",frame,"TOPLEFT",18,-11)
local rule=Style.Fill(frame,C.goldDim,"BORDER")
rule:SetPoint("TOPLEFT",frame,"TOPLEFT",18,-44)
rule:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-18,-44)
rule:SetHeight(1)
rule:SetAlpha(0.52)
local tabs={{"quick","QUICK PLAY"},{"series","SERIES"},{"veto","MAP VETO"},{"community","COMMUNITY"}}
local selected={player="quick",host="quick"}
local tabButtons={}
local buttons={}
local functions={}
local currentPage="player"
local function Label(text,y,size,color)
    local f=Style.Text(frame,text,size or 13,color or C.text)
    f:SetPoint("TOPLEFT",frame,"TOPLEFT",18,-y)
    f:SetWidth(664)
    f:SetJustifyH("LEFT")
    f:SetWordWrap(false)
    return f
end
local line1=Label("",111,13,C.pale)
local line2=Label("",139,12,C.muted)
local notice=Label("",318,12,C.muted)
local function Action(caption)
    local b=Style.Action(frame,caption,"footer",{
        fill=C.button,edge=C.goldDim,light=C.goldDim,
        dark=C.window,hover=C.selected,text=C.text,
    })
    b:SetSize(175,31)
    return b
end
for i,t in ipairs(tabs) do
    local b=Action(t[2])
    tabButtons[i]=b
    b:SetSize(154,31)
    local active=Style.Fill(b,C.selected,"ARTWORK")
    active:SetAllPoints(b)
    active:SetAlpha(0)
    b.studioSelected=active
    b:SetScript("OnClick",function()
        selected[currentPage]=t[1]
        Widgets.CloseChoices()
        frame:Refresh()
    end)
end
local function Do(i)
    local entry=functions[i]
    if not entry or entry.disabled then return end
    if entry.action then entry.action(buttons[i]) end
end
for i=1,9 do
    local b=Action("")
    b:SetScript("OnClick",function() Do(i) end)
    ns.Tooltips.Bind(b,function()
        local entry=functions[i]
        if not entry then return end
        return {title=entry.text,detail=entry.detail or
            "War Games setup tool.",anchor="RIGHT"}
    end)
    buttons[i]=b
end
local function SetNotice(success,text)
    if type(text)=="string" then
        Tools.SetNotice((success and "✓ " or "• ")..text)
    end
    frame:Refresh()
end
local function Choose(anchor,entries,callback)
    if #entries==0 then
        return SetNotice(false,"No available entries.")
    end
    Widgets.OpenChoices(anchor,entries,nil,callback,true)
end
local function SelectedCaptain()
    return Engine.GetCaptain(currentPage,1)
end
local function CurrentMap()
    local cfg=Engine.GetConfig(currentPage)
    return cfg and Engine.GetMaps()[cfg.map]
end
local function ToggleCaptain()
    local f=SelectedCaptain()
    if not f then return SetNotice(false,"Choose a captain first.") end
    local ok,on=Tools.ToggleFavorite("captain",f.id)
    SetNotice(ok,on and "Captain added to favorites." or
        "Captain removed from favorites.")
end
local function ToggleMap()
    local m=CurrentMap()
    if not m then return SetNotice(false,"Choose an arena first.") end
    local ok,on=Tools.ToggleFavorite("map",m.name)
    SetNotice(ok,on and "Arena added to favorites." or
        "Arena removed from favorites.")
end
local function PickCaptain(anchor,onlyFavorites,onlyRecent)
    local data=Tools.GetLibrary()
    local items=Tools.Choices("captain")
    local ranked={}
    for _,entry in ipairs(items) do
        if (not onlyFavorites or Tools.IsFavorite("captain",entry.key)) and
            (not onlyRecent or
             (function()
                for _,id in ipairs(data.recentCaptains) do
                    if id==entry.key then return true end
                end
                return false
             end)()) then
            ranked[#ranked+1]=entry
        end
    end
    Choose(anchor,ranked,function(key)
        if Engine.SelectCaptain(currentPage,1,key) then
            Tools.Remember("captain",key)
            SetNotice(true,"Captain selected from your shortcuts.")
        end
    end)
end
local function PickArena(anchor,onlyFavorites,onlyRecent)
    local data=Tools.GetLibrary()
    local entries={}
    for _,entry in ipairs(Tools.Choices("map")) do
        local m=Engine.GetMaps()[entry.key]
        if m and (not onlyFavorites or Tools.IsFavorite("map",m.name)) then
            local found=not onlyRecent
            if onlyRecent then
                for _,v in ipairs(data.recentMaps) do
                    if v==m.name then found=true;break end
                end
            end
            if found then entries[#entries+1]=entry end
        end
    end
    Choose(anchor,entries,function(key)
        if Engine.SelectMap(currentPage,key) then
            local map=Engine.GetMaps()[key]
            if map then Tools.Remember("map",map.name) end
            SetNotice(true,"Arena selected from your shortcuts.")
        end
    end)
end
local function History(anchor)
    local data=Tools.GetLibrary()
    local entries={}
    for i,h in ipairs(data.history) do
        local win=h.winner==1 and "Team 1" or "Team 2"
        entries[#entries+1]={key=i,disabled=true,
            label="MANUAL • Bo"..h.format.." "..h.score1.."-"..h.score2..
                " • "..h.opponent,
            detail=win.." was marked as the winner; not game-verified."}
    end
    if #entries==0 then
        SetNotice(false,"No manually recorded completed series yet.")
    else
        Choose(anchor,entries,function() end)
    end
end
local function Rivalries(anchor)
    local entries={}
    for i,r in ipairs(Tools.Rivalries()) do
        entries[#entries+1]={key=i,disabled=true,
            label="MANUAL • "..r.name.." • "..r.wins.."W/"..r.losses.."L",
            detail="Only your explicitly entered Players series records."}
    end
    if #entries==0 then
        SetNotice(false,"No manually entered player rivalry results yet.")
    else
        Choose(anchor,entries,function() end)
    end
end
local function PickBan(anchor)
    local entries={}
    for i,m in ipairs(Engine.GetMaps()) do
        local available=true
        for _,v in ipairs(Tools.GetVeto()) do
            if v==m.name then available=false;break end
        end
        if available then entries[#entries+1]={key=i,label=m.name} end
    end
    Choose(anchor,entries,function(key)
        local map=Engine.GetMaps()[key]
        if map then
            local ok,msg=Tools.BanMap(map.name)
            SetNotice(ok,msg or (map.name.." vetoed locally."))
        end
    end)
end
local function PickRestore(anchor)
    local entries={}
    for i,name in ipairs(Tools.GetVeto()) do
        entries[#entries+1]={key=i,label=name}
    end
    Choose(anchor,entries,function(key)
        local name=Tools.GetVeto()[key]
        if name and Tools.RestoreMap(name) then
            SetNotice(true,name.." restored to available maps.")
        end
    end)
end
local function PickRemaining(anchor)
    Choose(anchor,Tools.AvailableMaps(),function(key)
        if Tools.VetoSelectMap(currentPage,key) then
            local m=Engine.GetMaps()[key]
            if m then Tools.Remember("map",m.name) end
            SetNotice(true,"Remaining arena selected. Share veto choices manually.")
        end
    end)
end
local function UseTarget()
    if currentPage~="player" then
        return SetNotice(false,"Target shortcut only works for Players.")
    end
    local ok,msg=Tools.UseTarget()
    SetNotice(ok,msg)
end
local function Reuse()
    local ok,msg=Tools.PrepareRematch(currentPage)
    SetNotice(ok,msg)
end
local function Series(best)
    if Tools.StartSeries(best,currentPage) then SetNotice(true,"Manual series started. Scores are not verified.") end
end
local function Round(side)
    local ok,msg=Tools.MarkRound(side)
    SetNotice(ok,msg or "Round recorded MANUALLY.")
end
local function Draft()
    local ok,msg=Tools.DraftListing(currentPage)
    SetNotice(ok,msg)
end
local function Func(text,detail,action,disabled)
    return {text=text,detail=detail,action=action,disabled=disabled}
end
local function Data(page,tab)
    local captain=SelectedCaptain()
    local map=CurrentMap()
    if tab=="quick" then
        return Tools.Status(page),
            "MATCH • "..Tools.MatchCard(page),
            {
            Func("Reuse Last Setup","Restore your last outgoing request's setup. No automatic challenge.",Reuse,
                Tools.GetSnapshot(page)==nil),
            Func("Use Target","Select a targeted friend's character ONLY when uniquely verified in Battle.net. Players only.",UseTarget,
                page~="player"),
            Func("Recent Captains","Choose a previously selected captain.",function(b)PickCaptain(b,false,true)end),
            Func("Favorite Captain","Add or remove your chosen captain from account favorites.",ToggleCaptain,not captain),
            Func("Favorite Arena","Add or remove this arena from account favorites.",ToggleMap,not map),
            Func("Recent Arenas","Choose a recently used arena.",function(b)PickArena(b,false,true)end),
            Func("Favorite Captains","Browse your favorite Battle.net captains.",function(b)PickCaptain(b,true,false)end),
            Func("Favorite Arenas","Browse your favorite arenas.",function(b)PickArena(b,true,false)end),
            Func("All Arenas","Browse all available references with searchable list.",function(b)PickArena(b,false,false)end),
        }
    elseif tab=="series" then
        local s=Tools.GetSeries()
        local label=s.bestOf>0 and
            ("MANUAL BO"..s.bestOf.." • Team 1 "..s.score1.." : "..s.score2..
             " Team 2"..(s.finished and " • FINISHED" or "")) or
            "No series active — choose Best of 3 or Best of 5"
        return label,"Series scores are manual, never Blizzard-verified. Opponent: "..
            (s.opponent~="" and s.opponent or "not selected"),
            {
            Func("Start Best of 3","Reset the current local series and start a fresh Bo3.",function()Series(3)end),
            Func("Start Best of 5","Reset the current local series and start a fresh Bo5.",function()Series(5)end),
            Func("Reset Series","Clear the manual series scoreboard.",function()Tools.ResetSeries();SetNotice(true,"Series cleared.")end),
            Func("Team 1 Won","Manually count a round for Team 1.",function()Round(1)end,
                s.bestOf==0 or s.finished),
            Func("Team 2 Won","Manually count a round for Team 2.",function()Round(2)end,
                s.bestOf==0 or s.finished),
            Func("Manual History","Review the last 20 completed, manually recorded series.",History),
        }
    elseif tab=="veto" then
        local banned=Tools.GetVeto()
        return "LOCAL MAP VETO • "..#banned.." arena(s) removed",
            "Organizer-controlled only: no opponent sync or agreement is implied.",
            {
            Func("Ban an Arena","Mark an arena banned in your local veto list.",PickBan),
            Func("Restore Arena","Return a banned arena to the list.",PickRestore,#banned==0),
            Func("Use Remaining","Choose any arena not locally vetoed.",PickRemaining),
            Func("Clear Veto","Reset this session's local veto list.",function()Tools.ClearVeto();SetNotice(true,"Veto reset.")end,#banned==0),
            Func("Favorite Arena","Add/remove the selected arena from favorites.",ToggleMap,not map),
            Func("Favorite Arenas","Choose a favorite map.",function(b)PickArena(b,true,false)end),
        }
    end
    local library=Tools.GetLibrary()
    local latest=library.history[1]
    return Tools.Presence(),
        latest and ("LAST MANUAL SERIES • Bo"..latest.format.." "..
            latest.score1.."-"..latest.score2.." vs "..latest.opponent) or
            "No manual rivalry records yet. No automatic win/loss detection.",
        {
        Func("Favorite Captains","Pick from locally saved favorite Battle.net captains.",function(b)PickCaptain(b,true,false)end),
        Func("Recent Captains","Pick from recently selected friends.",function(b)PickCaptain(b,false,true)end),
        Func("Favorite Current","Add or remove the current opposing captain from favorites.",ToggleCaptain,not captain),
        Func("Manual History","Completed best-of series, entered by an organizer.",History),
        Func("Rival Records","Manually entered Players-series wins/losses only.",Rivalries),
        Func("Draft Match Post","Open Blizzard chat with a prepared War Games message. YOU choose where to send it.",Draft),
        Func("Match Summary","The selected format/map/rules are shown above in Quick Play.",function()
            SetNotice(true,Tools.MatchCard(page)) end),
        }
end
function frame:Refresh()
    currentPage=View.GetActivePage()
    local tab=selected[currentPage] or "quick"
    for i,b in ipairs(tabButtons) do
        b.studioSelected:SetAlpha(tabs[i][1]==tab and 0.40 or 0)
        b.label:SetTextColor(unpack(tabs[i][1]==tab and C.pale or C.text))
    end
    local headingText,detail,entries=Data(currentPage,tab)
    line1:SetText(headingText)
    line2:SetText(detail)
    notice:SetText(Tools.GetNotice() or "")
    functions=entries or {}
    for i,b in ipairs(buttons) do
        local entry=functions[i]
        b:SetShown(entry~=nil)
        if entry then
            b.label:SetText(entry.text)
            b:SetEnabled(not entry.disabled)
            b:SetAlpha(entry.disabled and 0.46 or 1)
        end
    end
end
function frame:LayoutStudio(w)
    local usable=w-36
    local col=(usable-20)/3
    local tabWidth=(usable-18)/4
    for i,b in ipairs(tabButtons) do
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT",frame,"TOPLEFT",18+(i-1)*(tabWidth+6),-59)
        b:SetWidth(tabWidth)
    end
    for i,b in ipairs(buttons) do
        local row=math.floor((i-1)/3)
        local column=(i-1)%3
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT",frame,"TOPLEFT",18+column*(col+10),-181-row*43)
        b:SetWidth(col)
    end
    line1:SetWidth(usable)
    line2:SetWidth(usable)
    notice:SetWidth(usable)
end
View.AttachStudio(frame)
local lastW
frame:HookScript("OnSizeChanged",function(_,w)
    if w~=lastW then lastW=w;frame:LayoutStudio(w) end
end)
frame:LayoutStudio(frame:GetWidth())
-- Every tool is discoverable; opening Search never activates a match request.
local function OpenTab(tab,page)
    if ns.Navigation then ns.Navigation.SelectKey("wargames",page) end
    selected[page]=tab
    View.Refresh()
    View.ScrollToStudio()
    if ns.Feedback then ns.Feedback.PulseTarget(frame) end
end
for _,item in ipairs({
    {"quick","War Games Quick Play","player","Rematch, readiness, target and favorites"},
    {"series","War Games Manual Series","player","Best of three and best of five manual rounds"},
    {"veto","War Games Map Veto","player","Local arena map bans and remaining maps"},
    {"community","War Games Community Tools","player","Addon presence, rivalry records and match listing"},
    {"quick","Spectator Match Tools","host","Ready status and team captain shortcuts"},
    {"series","Spectator Series Scorecard","host","Manual series for event hosts"},
    {"veto","Spectator Map Veto","host","Manual arena veto for hosts"},
    {"community","Spectator Community Tools","host","Favorite captains and manual match posts"},
}) do
    local tab,title,page,description=unpack(item)
    ns.Search.Register("wargames:studio:"..page..":"..tab,title,
        "War Games",description,function()OpenTab(tab,page)end,
        function()return ns.Client.IsRetail()end)
end
