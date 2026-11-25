local _,ns=...
-- Local result presentation only. No gameplay decisions, persistence,
-- combat-log interpretation or peer/rating writes.
local R={};ns.DuelResult=R
local S,Style,M=ns.Settings,ns.Style,ns.Motion
local C=Style.color
local MEDIA="Interface\\AddOns\\DuelsReimagined\\Media\\Skin\\"
local W,H=800,345
local root,edge,card,crest,heading,subtitle,meta,rank,detail,strip,statValues
local timer,unsubscribe,pending,current,tracked,deadline
local lastSeen,visibleProgress=0,0
local animation={}
local function Read(fn,...)
    if type(fn)~="function" then return nil end
    local ok,v=pcall(fn,...)
    if not ok then return nil end
    if type(issecretvalue)=="function" then
        local safe,secret=pcall(issecretvalue,v)
        if not safe or secret then return nil end
    end
    return v
end
local function Number(n)
    return type(n)=="number" and n==n and n~=math.huge and n~=-math.huge
end
local function Now() local n=Read(GetTime);return Number(n) and n or nil end
local function Idle() return Read(InCombatLockdown)==false end
local function Label(parent,value,size,w,h,y,color,role)
    local t=Style.Text(parent,value,size,color or C.text,false,role)
    t:SetSize(w,h);t:SetPoint("TOP",parent,"TOP",0,y)
    t:SetJustifyH("CENTER");t:SetWordWrap(false)
    if Style.ConstrainText then Style.ConstrainText(t,w,h,10) end
    return t
end
local function Build()
    if root then return end
    edge=CreateFrame("Frame","DuelsReimaginedResultVignette",UIParent)
    edge:SetAllPoints(UIParent);edge:SetFrameStrata("LOW");edge:EnableMouse(false);edge:Hide()
    local tex=edge:CreateTexture(nil,"BACKGROUND")
    tex:SetAllPoints(edge);tex:SetTexture(MEDIA.."DuelResultVignette.tga")
    if ns.Chrome.Sharp then ns.Chrome.Sharp(tex) end
    edge.texture=tex
    root=CreateFrame("Frame","DuelsReimaginedResult",UIParent)
    root:SetSize(W,H);root:SetFrameStrata("FULLSCREEN_DIALOG");root:EnableMouse(false);root:Hide()
    card=CreateFrame("Frame",nil,root);card:SetAllPoints(root);card:EnableMouse(false)
    local background=card:CreateTexture(nil,"BACKGROUND")
    background:SetSize(W,230);background:SetPoint("TOP",card,"TOP",0,-45)
    background:SetTexture(MEDIA.."DuelResultBanner.tga")
    if ns.Chrome.Sharp then ns.Chrome.Sharp(background) end
    crest=ns.Chrome.Icon(card,"Hall");crest:SetSize(64,64);crest:SetPoint("TOP",card,"TOP",0,-1)
    heading=Label(card,"VICTORY",48,590,58,-74,C.pale,"display")
    subtitle=Label(card,"",21,600,36,-133,C.text)
    local metaRow=CreateFrame("Frame",nil,card)
    metaRow:SetSize(490,38);metaRow:SetPoint("TOP",card,"TOP",0,-172)
    meta=Style.Text(metaRow,"",15,C.pale);meta:SetSize(238,30);meta:SetPoint("LEFT")
    meta:SetJustifyH("CENTER");meta:SetWordWrap(false)
    rank=CreateFrame("Frame",nil,metaRow);rank:SetSize(236,29);rank:SetPoint("RIGHT")
    Style.Skin(rank,C.nav,{corner=10,edge=C.goldDim,shine=.26,shade=.24,rim=.9})
    rank.label=Label(rank,"Rating not confirmed",14,224,26,-1,C.pale)
    detail=Label(card,"",14,610,28,-214,C.muted)
    strip=CreateFrame("Frame",nil,card);strip:SetSize(540,60);strip:SetPoint("TOP",card,"TOP",0,-279)
    strip:EnableMouse(false)
    Style.Skin(strip,C.nav,{corner=13,edge=C.goldDim,shine=.32,shade=.26,rim=.95})
    Style.Plate(strip,"shellCopper",{corner=13,layer="BORDER",sublevel=4})
    -- Transparent gold artwork: crossed swords, shield, healing pulse.
    local icons={{0,.5,0,.5},{.5,1,0,.5},{0,.5,.5,1}}
    local labels={"Damage done","Damage taken","Healing done"}
    statValues={}
    for i=1,3 do
        local cell=CreateFrame("Frame",nil,strip)
        cell:SetSize(176,52);cell:SetPoint("LEFT",strip,"LEFT",6+(i-1)*176,0)
        local icon=cell:CreateTexture(nil,"ARTWORK");icon:SetSize(34,34);icon:SetPoint("LEFT",cell,"LEFT",7,0)
        icon:SetTexture(MEDIA.."DuelResultStatIcons.tga");icon:SetTexCoord(unpack(icons[i]))
        if ns.Chrome.Sharp then ns.Chrome.Sharp(icon) end
        local name=Style.Text(cell,labels[i],11,C.muted);name:SetSize(128,18);name:SetPoint("TOPLEFT",cell,"TOPLEFT",45,-7)
        local value=Style.Text(cell,"Not observed",15,C.text);value:SetSize(128,23);value:SetPoint("TOPLEFT",cell,"TOPLEFT",45,-25)
        statValues[i]=value
        if i>1 then
            local rule=cell:CreateTexture(nil,"ARTWORK");rule:SetColorTexture(.55,.37,.16,.58)
            rule:SetSize(1,34);rule:SetPoint("LEFT",cell,"LEFT",0,0)
        end
    end
    if ns.DiagnosticAudit then
        ns.DiagnosticAudit.RegisterUIRoot("Duel Result",root)
        ns.DiagnosticAudit.RegisterUIRoot("Duel Result Vignette",edge)
    end
end
local function CancelTimer()
    if timer then timer:Cancel();timer=nil end
end
local function Clear()
    CancelTimer();pending=nil;current=nil;visibleProgress=0
    M.Stop(animation)
    if ns.CountdownAudio then ns.CountdownAudio.Stop("victory");ns.CountdownAudio.Stop("defeat") end
    if root then root:Hide();edge:Hide() end
end
local function Arm(seconds,fn)
    CancelTimer()
    if not C_Timer or type(C_Timer.NewTimer)~="function" then Clear();return end
    timer=C_Timer.NewTimer(seconds,function()timer=nil;fn()end)
end
local function Layout()
    if not root then return end
    local w,h=Read(UIParent.GetWidth,UIParent),Read(UIParent.GetHeight,UIParent)
    if not Number(w) or not Number(h) or w<=0 or h<=0 then return end
    local scale=math.min(1,w*.84/W,h*.6/H)
    root:SetScale(scale);root:ClearAllPoints()
    root:SetPoint("TOP",UIParent,"TOP",0,-h*(current and current.tournament and .20 or .09)/scale)
end
local function Progress(v)
    local p=math.max(0,math.min(1,v))
    visibleProgress=p
    root:SetAlpha(p)
    crest:SetAlpha(math.min(1,p*1.8))
    heading:SetAlpha(math.min(1,p*1.6))
    subtitle:SetAlpha(math.max(0,math.min(1,(p-.12)*1.7)))
    strip:SetAlpha(math.max(0,math.min(1,(p-.34)*1.6)))
    edge:SetAlpha(S.Get("duelResultVignette") and p*.28 or 0)
end
local function Show(data)
    if not S.Get("duelResultVisual") or not Idle() then return false end
    Clear();Build();current=data;Layout()
    local win=data.outcome=="won" or data.outcome=="they_fled"
    heading:SetText(data.champion and "CHAMPION" or data.spectated and "MATCH WINNER" or win and "VICTORY" or "DEFEAT")
    if win then heading:SetTextColor(1,.79,.37);edge.texture:SetVertexColor(.95,.58,.14)
    else heading:SetTextColor(1,.53,.42);edge.texture:SetVertexColor(.66,.09,.07) end
    local opponent=data.opponent or "your opponent"
    if data.champion then subtitle:SetText(data.champion.." wins the tournament")
    elseif data.spectated then subtitle:SetText((data.winnerName or "Winner").." defeated "..opponent)
    elseif data.outcome=="they_fled" then subtitle:SetText(opponent.." retreated")
    elseif data.outcome=="fled" then subtitle:SetText("You retreated from "..opponent)
    else subtitle:SetText(win and "You defeated "..opponent or "You were defeated by "..opponent) end
    local duration=data.duration
    meta:SetText(duration and string.format("Duel duration: %02d:%02d",math.floor(duration/60),math.floor(duration%60)) or "Duration not observed")
    if data.tournament then
        rank.label:SetText("Series: "..data.score.." - "..data.opponentScore)
        detail:SetText("LOCAL TEST  •  "..(data.champion and "Tournament complete" or data.spectated and (data.complete and "Series complete" or "Tournament game") or data.complete and (data.advanced and "Series won" or "Series lost") or "Tournament game"))
    else
        rank.label:SetText(data.preview and (win and "+10 Rating" or "-9 Rating") or "Rating not confirmed")
        detail:SetText(data.preview and "PREVIEW  •  SAMPLE DATA" or "Locally observed result")
    end
    local stats=data.preview and not data.tournament and {"124.6K","37.2K","18.9K"} or {"Not observed","Not observed","Not observed"}
    for i,v in ipairs(statValues) do v:SetText(stats[i]) end
    root:Show();edge:SetShown(S.Get("duelResultVignette")==true)
    Progress(0)
    if ns.CountdownAudio then ns.CountdownAudio.PlayResult(win and "victory" or "defeat") end
    -- One reveal, one hold, one exit on the existing shared driver.
    M.Value(animation,0,1,.68,function(_,p)Progress(p)end)
    Arm(5.3,function()
        M.Value(animation,1,0,.55,function(_,p)
            Progress(p)
            if p<=0 then Clear() end
        end)
    end)
    return true
end
local function CaptureDuration(s)
    local a=s.active
    if not a then return end
    if tracked~=a.id then tracked=a.id;deadline=nil end
    if s.reason=="countdown_observed" and Number(a.countdown) and a.countdown>=0 and a.countdown<=10 then
        local e=s.trace and s.trace[#s.trace]
        if e and e.cycle==a.id and e.reason=="countdown_observed" and Number(e.time) then
            local start=e.time+a.countdown
            deadline=deadline and math.min(deadline,start) or start
        end
    end
end
local function Receive(s)
    if s.scope~="LOCAL" then return end
    if s.challenge or s.active then
        if current or pending then Clear() end
        if s.active then CaptureDuration(s) end
        return
    end
    local l=s.last
    if not l or not Number(l.id) or l.id<=lastSeen then return end
    lastSeen=l.id
    local start=tracked==l.id and deadline or nil
    tracked,deadline=nil,nil
    if not S.Get("duelResultVisual") or s.state~="idle" or
        (l.kind~="standard" and l.kind~="unclassified") or
        l.reason~="matching_result_and_finish" or l.outcomeObserved~=true or
        l.finishObserved~=true or l.resultObserved~=true or l.conflict~=false or
        (l.outcome~="won" and l.outcome~="lost" and l.outcome~="fled" and l.outcome~="they_fled") then return end
    local n=Now()
    if not n or not Number(l.endedAt) or n-l.endedAt>2 or l.endedAt>n+.1 then return end
    local opponent=l.opponent and l.opponent.display
    if type(opponent)~="string" or #opponent>128 or #opponent==0 then opponent=nil end
    local duration=start and l.endedAt>=start and l.endedAt-start or nil
    local data={outcome=l.outcome,opponent=opponent,duration=duration}
    if Idle() then Show(data)
    else
        Clear();pending=data
        Arm(5,function()pending=nil end)
    end
end
function R.Preview(outcome)
    if not ns.Client.IsSupported() or not Idle() then return false,"Finish combat first" end
    local snap=ns.DuelDetection.GetSnapshot()
    if snap.state~="idle" or snap.challenge or snap.active then return false,"Finish your duel first" end
    if ns.EditMode and ns.EditMode.IsActive() then return false,"Exit Edit Mode first" end
    if not S.Get("duelResultVisual") then return false,"Enable the duel result first" end
    if ns.DuelCountdown then ns.DuelCountdown.Refresh() end
    return Show({preview=true,outcome=outcome=="lost" and "lost" or "won",opponent="Thornblade",duration=28})
end
function R.ClearTournamentPreview()
    if current and current.tournament then Clear() end
end
function R.ShowTournamentPreview(data)
    if type(data)~="table" or data.scope~="SIMULATED" or not Idle() or not ns.Client.IsSupported() then return false end
    local s=ns.DuelDetection.GetSnapshot()
    if not s or s.state~="idle" or s.active or s.challenge or ns.EditMode and ns.EditMode.IsActive() then return false end
    if (data.outcome~="won" and data.outcome~="lost") or type(data.opponent)~="string" or
        not Number(data.score) or not Number(data.opponentScore) or data.score<0 or data.opponentScore<0 or data.score>3 or data.opponentScore>3 then return false end
    return Show({tournament=true,outcome=data.outcome,opponent=data.opponent,score=data.score,opponentScore=data.opponentScore,
        complete=data.complete==true,advanced=data.advanced==true,spectated=data.spectated==true,
        winnerName=type(data.winnerName)=="string" and data.winnerName or nil,
        champion=type(data.champion)=="string" and data.champion or nil,
        duration=Number(data.duration) and data.duration>=0 and data.duration<=60 and data.duration or nil})
end
function R.Refresh()
    if not S.Get("duelResultVisual") then Clear();return end
    if edge then
        edge:SetShown(current~=nil and S.Get("duelResultVignette")==true)
        if current and S.Get("duelResultVignette") then edge:SetAlpha(visibleProgress*.28) end
    end
end
function R.GetDiagnosticResources()
    return {subscriptions=unsubscribe and 1 or 0,timers=timer and 1 or 0}
end
local events=CreateFrame("Frame")
for _,e in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD","PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED","UI_SCALE_CHANGED","DISPLAY_SIZE_CHANGED"}) do events:RegisterEvent(e) end
events:SetScript("OnEvent",function(self,event)
    if event=="PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")
        if ns.Client.IsSupported() then
            local s=ns.DuelDetection.GetSnapshot()
            lastSeen=s.last and s.last.id or 0
            unsubscribe=ns.DuelDetection.Subscribe(Receive)
        end
    elseif event=="PLAYER_REGEN_ENABLED" then
        if pending then
            local data=pending
            local s=ns.DuelDetection.GetSnapshot()
            if Idle() and s.state=="idle" and not s.active and not s.challenge then Show(data) else Clear() end
        end
    elseif event=="PLAYER_REGEN_DISABLED" or event=="PLAYER_ENTERING_WORLD" then Clear()
    else Layout() end
end)
