local _,ns=...
-- Read-only duel companion; never owns results, ranking, or peer transport.
local S,C,Settings=ns.Style,ns.Style.color,ns.Settings
local H={};ns.DuelHUD=H
local WIDTH,HEIGHT=372,326
local root=CreateFrame("Frame","DuelsReimaginedDuelHUD",UIParent)
root:SetSize(WIDTH,HEIGHT);root:SetFrameStrata("MEDIUM")
root:SetClampedToScreen(true);root:SetMovable(true);root:EnableMouse(true);root:Hide()
S.Skin(root,C.window,{corner=10,edge=C.shellEdge,shine=.16,shade=.24,rim=1,smooth=true})
local function Place(f,x,y,w,h)
    f:SetPoint("TOPLEFT",root,"TOPLEFT",x,-y);f:SetSize(w,h)
end
local function Label(value,size,color,x,y,w,h,align)
    local f=S.Text(root,value,size,color or C.text)
    f:SetJustifyH(align or "CENTER");f:SetWordWrap(false);Place(f,x,y,w,h);return f
end
local function Action(value,x,y,w,h,fn,red)
    local b=S.Action(root,value,"footer",red and {plate="hall",hover=C.red,text=C.buttonText} or
        {fill=C.nav,hover=C.selected,edge=C.goldDim,light=C.goldDim,dark=C.window,text=C.text,tooltip=false})
    Place(b,x,y,w,h);b:SetScript("OnClick",fn);return b
end
local function Rule(y)
    local f=S.Fill(root,C.goldDim,"ARTWORK");Place(f,11,y,WIDTH-22,1);f:SetAlpha(.7)
end
local function Secret(v)
    if type(issecretvalue)~="function" then return false end
    local ok,flag=pcall(issecretvalue,v)
    return not ok or flag==true
end
local function Plain(fn,...)
    if type(fn)~="function" then return nil end
    local ok,v=pcall(fn,...)
    if ok and not Secret(v) then return v end
end
local function Now() return Plain(GetTime) end
local function Combat() return type(InCombatLockdown)=="function" and Plain(InCombatLockdown)~=false end
local function Identity(unit)
    return ns.Group.ReadCompetitiveIdentity(unit)
end
local function MatchUnit(id)
    if not id or not id.guid then return nil end
    for _,unit in ipairs({"target","focus","mouseover"}) do
        if Plain(UnitGUID,unit)==id.guid then return unit end
    end
end
local header=CreateFrame("Frame",nil,root)
Place(header,0,0,WIDTH-64,38);header:EnableMouse(true);header:RegisterForDrag("LeftButton")
local mark=root:CreateTexture(nil,"ARTWORK")
mark:SetTexture("Interface\\AddOns\\DuelsReimagined\\Media\\Icons\\DuelsDRIcon.png")
Place(mark,6,3,31,31)
Label("Duels Reimagined",20,C.pale,39,5,WIDTH-112,29,"LEFT")
local function OpenOptions()
    if Combat() then return end
    if not ns.Window.frame:IsShown() then ns.Window.Toggle() end
    ns.Navigation.SelectKey("options","interface")
end
local gear=Action("Options",WIDTH-75,7,65,25,OpenOptions)
local modeRank,modePractice
local snap,shownResult,activeID,acceptedAt,countdownUntil,damageSession
local ready,preview,dragging,rankDirty=false,false,false,true
local rankView,rankSeason
local function Mode(practice)
    if preview or Combat() or not snap or snap.state~="idle" then return end
    Settings.Set("practiceDuels",practice)
end
modeRank=Action("Ranked",12,44,170,30,function() Mode(false) end)
modePractice=Action("Practice",190,44,170,30,function() Mode(true) end)
Rule(82)
local state=Label("Select a player to duel",14,C.pale,10,86,WIDTH-20,19)
local timer=Label("00:00",24,C.text,10,106,WIDTH-20,29)
local function Side(x)
    local side={}
    side.icon=root:CreateTexture(nil,"ARTWORK")
    Place(side.icon,x+4,144,31,31)
    side.name=Label("",14,C.text,x+40,142,126,23,"LEFT")
    side.badge=ns.CompetitiveUI.CreateRankEmblem(root,32,false)
    Place(side.badge,x+2,178,32,32)
    side.rank=Label("Rank unknown",12,C.muted,x+40,173,126,18,"LEFT")
    side.rating=Label("",12,C.pale,x+40,191,126,18,"LEFT")
    side.bg=S.Fill(root,C.track,"ARTWORK");Place(side.bg,x,215,166,15)
    side.hp=CreateFrame("StatusBar",nil,root);Place(side.hp,x,215,166,15)
    side.hp:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    side.hp:SetStatusBarColor(.22,.69,.24);side.hp:SetMinMaxValues(0,1);side.hp:SetValue(0)
    local overlay=CreateFrame("Frame",nil,root)
    overlay:SetFrameLevel(side.hp:GetFrameLevel()+1);Place(overlay,x,213,166,19)
    side.hpText=S.Text(overlay,"",11,C.text);side.hpText:SetAllPoints(overlay);side.hpText:SetJustifyH("CENTER")
    local click=CreateFrame("Button",nil,root);Place(click,x,174,166,37)
    click:SetScript("OnClick",function()
        if Combat() or preview or not side.profile or not side.id or ns.CompetitivePreview.IsActive() then return end
        if not ns.Window.frame:IsShown() then ns.Window.Toggle() end
        ns.Navigation.SelectKey("hall","overview")
        ns.CompetitiveUI.OpenPlayerCard(side.id)
    end)
    side.click=click
    return side
end
local me,other=Side(12),Side(194)
Label("VS",13,C.gold,177,163,18,21)
Rule(237)
local done=Label("Damage Done: —",13,C.muted,12,243,170,22)
local taken=Label("Damage Taken: —",13,C.muted,190,243,170,22)
local note=Label("",11,C.muted,12,267,WIDTH-24,18)
local challenge,forfeit
local lastRequest
local function Native(fn,unit)
    if type(fn)~="function" then note:SetText("Native action unavailable.");return false end
    local ok,result
    if unit then ok,result=pcall(fn,unit) else ok,result=pcall(fn) end
    if not ok or Secret(result) or result==false then
        note:SetText("Blizzard action unavailable; use native controls.");return false
    end
    note:SetText("Request sent to Blizzard; awaiting observation.");return true
end
challenge=Action("Challenge Target",12,290,170,28,function()
    if preview or ns.CompetitivePreview.IsActive() or Combat() or not snap or snap.state~="idle" then return end
    local id=Identity("target");local self=Identity("player")
    local now=Now()
    if not id or not self or id.guid==self.guid or not now or (lastRequest and now-lastRequest<5) then return end
    lastRequest=now
    Native(StartDuel,"target")
end,true)
forfeit=Action("Forfeit",190,290,170,28,function()
    if preview or ns.CompetitivePreview.IsActive() or not snap or not snap.active or snap.state=="finishing" then return end
    Native(ForfeitDuel)
end,true)
local function Enable(b,value) b:SetEnabled(value==true);b:SetAlpha(value and 1 or .42) end
local function ResetDamage(id)
    -- New duel = new private display session. Never clear Blizzard's
    -- shared sessions: they may contain other combat and other addons' data.
    damageSession={cycle=id}
    done:SetText("Damage Done: —");taken:SetText("Damage Taken: —")
end
local function Health(side,unit)
    side.hp:Hide()
    side.hpText:SetText("Unavailable")
    if not unit or type(UnitHealth)~="function" or type(UnitHealthMax)~="function" then return end
    -- Readable numbers can be formatted; secret values go directly to native
    -- statusbar setters, not into arithmetic, comparisons or SavedVariables.
    local ok,value,max=pcall(function() return UnitHealth(unit),UnitHealthMax(unit) end)
    if not ok then return end
    local restricted=Secret(value) or Secret(max)
    if not restricted and (type(value)~="number" or type(max)~="number" or max<=0) then return end
    local painted=pcall(function()
        side.hp:SetMinMaxValues(0,max);side.hp:SetValue(value)
    end)
    if not painted then return end
    side.hp:Show()
    if restricted then side.hpText:SetText("")
    else side.hpText:SetText(string.format("%d%%",math.floor(100*value/max+.5))) end
end
local function ReadRanks()
    if not rankDirty then return end
    rankDirty=false;rankView,rankSeason=nil,nil
    local time=Plain(GetServerTime)
    if type(time)~="number" then return end
    local ok,data=pcall(ns.CompetitiveStorage.ReadPeerView,time)
    if ok and data and data.view and data.replay then rankView,rankSeason=data.view,data.replay.season end
end
local function PaintSide(side,id,unit,own)
    side.id=id and id.guid;side.profile=false
    local v=id and (id.metadata or id)
    side.name:SetText(id and (v.name or id.display or id.fullName) or (own and "You" or "No player target"))
    side.icon:SetTexture(v and v.class and "Interface\\Icons\\ClassIcon_"..v.class or "Interface\\Icons\\INV_Misc_QuestionMark")
    local p
    if rankView and side.id and rankSeason then p=rankView.ProfileSummary(side.id,rankSeason) end
    side.profile=p~=nil
    side.badge:SetShown(p~=nil or own)
    side.badge.Paint(p and p.rank)
    side.rank:SetText(p and p.rank and p.rank.label or (own and not rankView and "No active rank" or "Rank unknown"))
    side.rating:SetText(p and p.rating and tostring(p.rating) or "")
    Health(side,unit)
end
local function PreviewSide(side,name,class,rank,value,health)
    side.id,side.profile=nil,false
    side.name:SetText(name)
    side.icon:SetTexture("Interface\\Icons\\ClassIcon_"..class)
    side.badge:Show();side.badge.Paint(rank)
    side.rank:SetText(rank.label);side.rating:SetText(tostring(value))
    side.hp:SetMinMaxValues(0,100);side.hp:SetValue(health);side.hp:Show();side.hpText:SetText(health.."%")
end
local function TimeText(n)
    n=math.max(0,math.floor(n or 0))
    return string.format("%02d:%02d",math.floor(n/60),n%60)
end
local function Tick()
    if preview then return end
    local now=Now()
    if not now then return end
    if snap and snap.active then
        local remaining=countdownUntil and countdownUntil-now or 0
        if snap.state=="finishing" then state:SetText("Awaiting observed result")
        elseif remaining>0 then state:SetText("Countdown (estimated)")
        else state:SetText("Duel observed") end
        timer:SetText(remaining>0 and tostring(math.ceil(remaining)) or TimeText(now-(acceptedAt or now)))
    elseif shownResult and now>=shownResult.untilTime then
        shownResult=nil;H.Refresh()
    end
end
local function Paint()
    if not root:IsShown() or not snap then return end
    if preview then
        modeRank.label:SetText("Ranked (preview)");modePractice.label:SetText("Practice")
        state:SetText("SOLO PREVIEW - SIMULATED");timer:SetText("00:32")
        PreviewSide(me,"Test Priest","PRIEST",{name="Contender",division=2,label="Contender II"},1660,76)
        PreviewSide(other,"Test Mage","MAGE",{name="Veteran",division=3,label="Veteran III"},1925,43)
        done:SetText("Damage Done: 52.7K");taken:SetText("Damage Taken: 48.1K")
        note:SetText("Visual preview only - actions disabled")
        Enable(challenge,false);Enable(forfeit,false);Enable(modeRank,false);Enable(modePractice,false)
        return
    end
    ReadRanks()
    local self=Identity("player")
    local engaged=snap.active or snap.challenge
    local opponent=engaged and engaged.opponent or not engaged and Identity("target") or nil
    PaintSide(me,self,"player",true)
    PaintSide(other,opponent,engaged and MatchUnit(opponent) or not engaged and opponent and "target" or nil,false)
    local intent=Settings.Get("practiceDuels")==true
    modeRank.label:SetText(intent and "Ranked" or "Ranked (selected)")
    modePractice.label:SetText(intent and "Practice (selected)" or "Practice")
    local idle=snap.state=="idle"
    Enable(modeRank,idle and not Combat());Enable(modePractice,idle and not Combat())
    Enable(challenge,idle and not Combat() and opponent~=nil and self~=nil and opponent.guid~=self.guid and
        type(StartDuel)=="function" and not ns.CompetitivePreview.IsActive())
    Enable(forfeit,snap.active~=nil and snap.state~="finishing" and type(ForfeitDuel)=="function" and not ns.CompetitivePreview.IsActive())
    done:SetText("Damage Done: —");taken:SetText("Damage Taken: —")
    if snap.active then
        note:SetText("Since countdown | Duel damage unavailable")
        Tick()
    elseif snap.challenge then
        state:SetText(snap.challenge.kind=="death_duel" and "Death duel - excluded" or "Challenge pending")
        timer:SetText("00:00");note:SetText("Waiting for Blizzard countdown")
    elseif shownResult then
        state:SetText(shownResult.text);timer:SetText(shownResult.duration)
        note:SetText("Local observation - rating not confirmed")
    else
        state:SetText(snap.state=="unavailable" and "Duel detection unavailable" or opponent and "Ready to challenge" or "Select a player to duel")
        timer:SetText("00:00")
        note:SetText("Preferred mode only - ranked agreement required")
    end
end
local function Receive(s)
    snap=s
    if s.active and preview then preview=false end
    if s.active then
        local now=Now()
        if activeID~=s.active.id then
            activeID=s.active.id;acceptedAt=s.active.acceptedAt or now
            ResetDamage(activeID);shownResult=nil
        end
        if now and type(s.active.countdown)=="number" then
            local finish=now+s.active.countdown
            if not countdownUntil or finish<countdownUntil then countdownUntil=finish end
        end
    elseif activeID then
        if s.last and s.last.id==activeID and Now() then
            local labels={won="Victory",lost="Defeat",fled="You retreated",they_fled="Opponent retreated",unknown="Result unknown"}
            shownResult={text=labels[s.last.outcome] or "Result unknown",
                duration=TimeText(s.last.endedAt and acceptedAt and s.last.endedAt-acceptedAt),
                untilTime=Now()+6}
        end
        activeID,acceptedAt,countdownUntil=nil,nil,nil
    elseif s.challenge then shownResult=nil end
    Paint()
    root:SetScript("OnUpdate",not preview and (s.active or shownResult) and function(_,dt)
        H.elapsed=(H.elapsed or 0)+dt
        if H.elapsed>=.2 then H.elapsed=0;Tick() end
    end or nil)
end
function H.ApplyPosition()
    if dragging then return end
    local x,y=Settings.GetDuelHUDPosition()
    local ratio=UIParent:GetEffectiveScale()/root:GetEffectiveScale()
    root:ClearAllPoints()
    root:SetPoint("CENTER",UIParent,"BOTTOMLEFT",UIParent:GetWidth()*x*ratio,UIParent:GetHeight()*y*ratio)
end
local function StopDrag()
    if not dragging then return end
    dragging=false;root:StopMovingOrSizing()
    local x,y=root:GetCenter()
    local ratio=root:GetEffectiveScale()/UIParent:GetEffectiveScale()
    if x and y and UIParent:GetWidth()>0 and UIParent:GetHeight()>0 then
        Settings.SetDuelHUDPosition(x*ratio/UIParent:GetWidth(),y*ratio/UIParent:GetHeight())
    end
end
header:SetScript("OnDragStart",function()
    if Settings.Get("duelHUDLocked") or Combat() then return end
    dragging=true;root:StartMoving()
end)
header:SetScript("OnDragStop",StopDrag)
local unsubscribe
local events={"PLAYER_TARGET_CHANGED","PLAYER_FOCUS_CHANGED","UPDATE_MOUSEOVER_UNIT","UNIT_HEALTH","UNIT_MAXHEALTH","UNIT_NAME_UPDATE","PLAYER_REGEN_ENABLED","PLAYER_REGEN_DISABLED","UI_SCALE_CHANGED","DISPLAY_SIZE_CHANGED"}
root:SetScript("OnEvent",function(_,event,unit)
    if event=="PLAYER_REGEN_DISABLED" then StopDrag() end
    if event=="UI_SCALE_CHANGED" or event=="DISPLAY_SIZE_CHANGED" then H.ApplyPosition() end
    if event=="UNIT_HEALTH" or event=="UNIT_MAXHEALTH" then
        if preview then return end
        if unit=="player" then Health(me,"player")
        elseif snap then
            local engaged=snap.active or snap.challenge
            local id=engaged and engaged.opponent or not engaged and Identity("target") or nil
            local expected=engaged and MatchUnit(id) or not engaged and id and "target" or nil
            if expected and unit==expected then Health(other,expected) end
        end
        return
    end
    Paint()
end)
root:SetScript("OnShow",function()
    rankDirty=true
    for _,event in ipairs(events) do pcall(root.RegisterEvent,root,event) end
    unsubscribe=ns.DuelDetection.Subscribe(Receive)
    Receive(ns.DuelDetection.GetSnapshot())
end)
root:SetScript("OnHide",function()
    StopDrag()
    if unsubscribe then unsubscribe();unsubscribe=nil end
    root:UnregisterAllEvents();root:SetScript("OnUpdate",nil)
    preview=false;activeID,acceptedAt,countdownUntil,shownResult=nil,nil,nil,nil
    snap,damageSession,rankView,rankSeason=nil,nil,nil,nil;rankDirty=true
end)
function H.Refresh()
    if not ready then return end
    if not Settings.Get("duelHUDEnabled") or not ns.Client.IsSupported() then root:Hide();return end
    if Settings.Get("duelHUDLocked") then StopDrag() end
    if not dragging then root:SetScale(Settings.Get("duelHUDScale"));H.ApplyPosition() end
    if not root:IsShown() then root:Show()
    else Receive(ns.DuelDetection.GetSnapshot()) end
end
function H.InvalidateRank()
    -- Lazy refresh avoids replaying the ledger on repeated Hall resizes.
    rankDirty=true
    if root:IsShown() and not preview then Paint() end
end
function H.GetDiagnosticResources()
    return {subscriptions=unsubscribe and 1 or 0,timers=root:GetScript("OnUpdate") and 1 or 0}
end
local PREVIEW_ENABLED=true
function H.TogglePreview()
    if not PREVIEW_ENABLED or not ready or Combat() or ns.DuelDetection.GetSnapshot().state~="idle" then return end
    if not Settings.Get("duelHUDEnabled") then Settings.Set("duelHUDEnabled",true) end
    preview=not preview
    if not preview then ResetDamage(nil) end
    H.Refresh()
end
local login=CreateFrame("Frame");login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent",function()
    login:UnregisterAllEvents();ready=true;H.Refresh()
end)
