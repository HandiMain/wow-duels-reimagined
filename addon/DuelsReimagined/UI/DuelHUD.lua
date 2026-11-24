local _,ns=...
-- Read-only duel companion; never owns results, ranking, or peer transport.
local S,C,Settings=ns.Style,ns.Style.color,ns.Settings
local H={};ns.DuelHUD=H
local WIDTH,HEIGHT,FOLDED_HEIGHT=336,310,42
local folded=false
local root=CreateFrame("Frame","DuelsReimaginedDuelHUD",UIParent)
root:SetSize(WIDTH,HEIGHT);root:SetFrameStrata("MEDIUM")
if ns.DiagnosticAudit then ns.DiagnosticAudit.RegisterUIRoot("Duel HUD",root) end
root:SetClampedToScreen(true);root:SetMovable(true);root:EnableMouse(true);root:Hide()
local body=CreateFrame("Frame",nil,root)
body:SetPoint("TOPLEFT",root,"TOPLEFT");body:SetSize(WIDTH,HEIGHT)
local headerLayer=CreateFrame("Frame",nil,root)
headerLayer:SetPoint("TOPLEFT",root,"TOPLEFT");headerLayer:SetSize(WIDTH,FOLDED_HEIGHT)
headerLayer:SetFrameLevel(root:GetFrameLevel()+3)
local surface=body
-- One authored skin owner. In particular, do not use Style.Fill followed
-- by a second anchor: its original opposing anchors stretch the region.
local ATLAS="Interface\\AddOns\\DuelsReimagined\\Media\\Skin\\DuelHUDArt.png"
local art={shell={0,0,336,310},crest={342,0,60,56},selected={342,64,140,32},
    normal={342,100,140,32},red={342,136,140,30},disabled={342,170,140,30},
    timer={0,316,190,38},stats={0,361,310,59},gear={342,205,24,24},
    close={372,205,24,24},swords={410,0,30,30},playerRing={342,238,48,48},enemyRing={396,238,48,48}}
local function Place(f,x,y,w,h)
    f:ClearAllPoints();f:SetPoint("TOPLEFT",f:GetParent(),"TOPLEFT",x,-y);f:SetSize(w,h)
end
local function Region(t,key)
    local a=art[key];t:SetTexture(ATLAS)
    t:SetTexCoord((a[1]+.25)/512,(a[1]+a[3]-.25)/512,(a[2]+.25)/512,(a[2]+a[4]-.25)/512)
end
local function Artwork(key,x,y,w,h,layer)
    local t=surface:CreateTexture(nil,layer or "ARTWORK");Region(t,key);Place(t,x,y,w,h);return t
end
Artwork("shell",0,0,WIDTH,HEIGHT,"BACKGROUND")
Artwork("stats",10,202,316,54)
Artwork("timer",73,91,190,38)
Artwork("swords",156,137,24,24)
local function Rect(x,y,w,h,r,g,b,a)
    local t=surface:CreateTexture(nil,"BORDER")
    t:SetColorTexture(r,g,b,a or 1);Place(t,x,y,w,h);return t
end
Rect(9,35,318,1,.50,.35,.16,.8)
Rect(14,74,308,1,.19,.15,.10,.85)
Rect(16,229,304,1,.27,.22,.15,.75)
local function Label(value,size,color,x,y,w,h,align)
    local f=S.Text(surface,value,size,color or C.text)
    f:SetJustifyH(align or "CENTER");f:SetWordWrap(false);Place(f,x,y,w,h)
    S.ConstrainText(f,w,h,8);return f
end
local function Action(value,x,y,w,h,fn,red,icon)
    local b=CreateFrame("Button",nil,surface);Place(b,x,y,w,h)
    b:RegisterForClicks("LeftButtonUp")
    local t=b:CreateTexture(nil,"BACKGROUND");t:SetAllPoints(b)
    local label=S.Text(b,value,12,C.text);label:SetAllPoints(b);label:SetJustifyH("CENTER");label:SetWordWrap(false)
    S.ConstrainText(label,w-8,h-4,8)
    b.label=label;b.selected=false;b.usable=true
    -- No alpha animation on the whole widget: the source art stays opaque.
    b.Paint=function()
        Region(t,icon or (b.selected and "selected" or not b.usable and "disabled" or red and "red" or "normal"))
        local v=b.pressed and .73 or b.hovered and b.usable and 1 or .90
        t:SetVertexColor(v,v,v,1)
        label:SetTextColor(unpack((b.usable or b.selected) and C.text or C.muted))
    end
    b:SetScript("OnEnter",function() b.hovered=true;b.Paint() end)
    b:SetScript("OnLeave",function() b.hovered=false;b.pressed=false;b.Paint() end)
    b:SetScript("OnMouseDown",function() b.pressed=true;b.Paint() end)
    b:SetScript("OnMouseUp",function() b.pressed=false;b.Paint() end)
    b:SetScript("OnClick",fn);b.Paint();return b
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
-- The expanded shell belongs to the body. The folded shell samples only
-- the original header and lower rim, so no body artwork leaks below it.
surface=root
art.foldedTop={0,0,336,38};art.foldedBottom={0,305,336,5}
local foldedTop=Artwork("foldedTop",0,0,WIDTH,38,"BACKGROUND")
local foldedBottom=Artwork("foldedBottom",0,38,WIDTH,4,"BACKGROUND")
foldedTop:Hide();foldedBottom:Hide()
surface=headerLayer
local header=CreateFrame("Frame",nil,headerLayer)
Place(header,0,0,WIDTH-87,35);header:EnableMouse(true);header:RegisterForDrag("LeftButton")
Artwork("crest",-4,-11,56,52,"OVERLAY")
Label("Duels Reimagined",17,C.pale,52,4,WIDTH-145,26,"LEFT")
local function OpenOptions()
    if Combat() then return end
    if not ns.Window.frame:IsShown() then ns.Window.Toggle() end
    ns.Navigation.SelectKey("options","interface")
end
local gear=Action("",WIDTH-84,5,23,23,OpenOptions,false,"gear")
local foldButton=CreateFrame("Button",nil,headerLayer);Place(foldButton,WIDTH-57,5,23,23)
S.Plate(foldButton,"dark",{corner=6})
local foldArt=foldButton:CreateTexture(nil,"ARTWORK");foldArt:SetSize(15,15);foldArt:SetPoint("CENTER")
local function PaintFold()
    foldArt:SetTexture("Interface\\AddOns\\DuelsReimagined\\Media\\Artwork\\Header\\"..(folded and "FoldDown" or "FoldUp")..".png")
end
PaintFold()
foldButton:SetScript("OnClick",function()H.Fold(not folded)end)
local foldHover=S.FeedbackOverlay(foldButton,{corner=6,inset=1,fill=C.gold,edge=C.gold,shine=.4,rim=.6})
foldHover:SetAlpha(0)
foldButton:SetScript("OnEnter",function()ns.Motion.Fade(foldHover,.34,ns.Motion.Duration("quick"))end)
foldButton:SetScript("OnLeave",function()ns.Motion.Fade(foldHover,0,ns.Motion.Duration("gentle"))end)
ns.Widgets.PressFeedback(foldButton,foldHover,{corner=6})
local close=Action("",WIDTH-30,5,23,23,function() Settings.Set("duelHUDEnabled",false) end,false,"close")
if ns.Tooltips then
    ns.Tooltips.Bind(gear,{title="Duel HUD options",detail="Open Interface settings."})
    ns.Tooltips.Bind(close,{title="Hide Duel HUD",detail="Also hides notifications. Show it again in Options or with /duels hud."})
    ns.Tooltips.Bind(foldButton,{title="Fold / unfold Duel HUD",detail="Collapse to the header while keeping notifications available."})
end
surface=body
local modeRank,modePractice
local snap,shownResult,activeID,acceptedAt,countdownUntil,damageSession
local ready,preview,dragging,rankDirty=false,false,false,true
local rankView,rankSeason
local function Mode(practice)
    if preview or Combat() or not snap or snap.state~="idle" then return end
    local target=Identity("target")
    if not practice then
        local _,_,selectable=ns.CompetitiveLifecycle.RankedAvailability(target and target.guid)
        if not selectable then return end
    end
    Settings.Set("practiceDuels",practice)
end
modeRank=Action("Ranked",66,40,101,30,function() Mode(false) end)
modePractice=Action("Unranked",174,40,101,30,function() Mode(true) end)
local state=Label("Select a player to duel",13,C.pale,10,77,WIDTH-20,18)
local timer=Label("00:00",20,C.text,114,96,108,27)
local function Side(x,enemy)
    local side={}
    local ix=enemy and x+104 or x+2
    local tx=enemy and x or x+42
    local align=enemy and "RIGHT" or "LEFT"
    side.icon=body:CreateTexture(nil,"ARTWORK")
    Place(side.icon,ix,126,36,36)
    if body.CreateMaskTexture and side.icon.AddMaskTexture then
        pcall(function()
            local mask=body:CreateMaskTexture()
            mask:SetTexture("Interface\\AddOns\\DuelsReimagined\\Media\\Skin\\DuelHUDPortraitMask.png","CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE")
            mask:SetAllPoints(side.icon);side.icon:AddMaskTexture(mask)
            side.mask=mask
        end)
    end
    Artwork(enemy and "enemyRing" or "playerRing",ix-4,122,44,44,"OVERLAY")
    side.name=Label("",13,C.pale,tx,127,100,20,align)
    side.rating=Label("",11,C.pale,tx,148,100,15,align)
    side.badge=ns.CompetitiveUI.CreateRankEmblem(body,19,false)
    Place(side.badge,enemy and x+123 or x+2,163,19,19)
    side.rank=Label("Rank unknown",11,C.text,enemy and x or x+23,163,119,18,align)
    -- Exactly anchored dark track and thin bronze edge; no Fill helper.
    Rect(x,182,142,17,.38,.27,.12)
    Rect(x+1,183,140,15,.04,.045,.04)
    side.hp=CreateFrame("StatusBar",nil,body);Place(side.hp,x+2,184,138,13)
    side.hp:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    side.hp:SetStatusBarColor(.19,.72,.16);side.hp:SetMinMaxValues(0,1);side.hp:SetValue(0)
    local overlay=CreateFrame("Frame",nil,body)
    overlay:SetFrameLevel(side.hp:GetFrameLevel()+1);Place(overlay,x,181,142,19)
    side.hpText=S.Text(overlay,"",11,C.text);side.hpText:SetAllPoints(overlay);side.hpText:SetJustifyH("CENTER");S.ConstrainText(side.hpText,138,17,8)
    local click=CreateFrame("Button",nil,body);Place(click,x,163,142,19)
    click:SetScript("OnClick",function()
        if Combat() or preview or not side.profile or not side.id or ns.CompetitivePreview.IsActive() then return end
        if not ns.Window.frame:IsShown() then ns.Window.Toggle() end
        ns.Navigation.SelectKey("hall","overview")
        ns.CompetitiveUI.OpenPlayerCard(side.id)
    end)
    side.click=click
    return side
end
local me,other=Side(12,false),Side(182,true)
Label("Damage Done",12,C.text,24,205,180,23,"LEFT")
Label("Damage Received",12,C.text,24,230,180,23,"LEFT")
local done=Label("—",13,C.pale,207,205,104,23,"RIGHT")
local taken=Label("—",13,C.pale,207,230,104,23,"RIGHT")
local note=Label("",10,C.muted,12,258,WIDTH-24,17)
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
challenge=Action("Challenge Target",18,277,157,27,function()
    if preview or ns.CompetitivePreview.IsActive() or Combat() or not snap or snap.state~="idle" then return end
    local id=Identity("target");local self=Identity("player")
    local now=Now()
    if not id or not self or id.guid==self.guid or not now or (lastRequest and now-lastRequest<5) then return end
    -- Do not silently downgrade an already displayed Ranked selection, or
    -- upgrade the displayed Unranked fallback when a reply just arrived.
    local ranked=modeRank.selected==true and modeRank.usable==true
    if ranked and (Settings.Get("practiceDuels") or not ns.CompetitiveLifecycle.RankedAvailability(id.guid)) then
        H.Refresh();return
    end
    lastRequest=now
    local ok,why=ns.DuelDetection.LaunchWidgetChallenge(ranked,id.guid)
    if not ok then
        if why=="range" then note:SetText("Move closer or range unavailable")
        else note:SetText("Request not confirmed; try again") end
    end
end,false)
forfeit=Action("Forfeit",187,277,131,27,function()
    if preview or ns.CompetitivePreview.IsActive() or not snap or snap.state=="finishing" then return end
    if snap.challenge and snap.challenge.direction=="outgoing" then
        if not snap.challenge.requestConfirmed then ns.DuelDetection.DismissUnconfirmed()
        elseif not Combat() then Native(CancelDuel) end
    elseif snap.active then Native(ForfeitDuel) end
end,true)
local function Enable(b,value) b.usable=value==true;b:SetEnabled(b.usable);b.Paint() end
local function ResetDamage(id)
    -- New duel = new private display session. Never clear Blizzard's
    -- shared sessions: they may contain other combat and other addons' data.
    damageSession={cycle=id}
    done:SetText("—");taken:SetText("—")
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
    side.name:SetText(id and (v.name or id.display or id.fullName) or (own and "You" or "No target"))
    local icon=v and v.class and "Interface\\Icons\\ClassIcon_"..v.class or "Interface\\Icons\\INV_Misc_QuestionMark"
    if type(SetPortraitToTexture)~="function" or not pcall(SetPortraitToTexture,side.icon,icon) then side.icon:SetTexture(icon) end
    local p
    if rankView and side.id and rankSeason then p=rankView.ProfileSummary(side.id,rankSeason) end
    side.profile=p~=nil
    side.badge:SetShown(p~=nil or own)
    side.badge.Paint(p and p.rank)
    side.rank:SetText(p and p.rank and p.rank.label or (not id and "—" or own and not rankView and "No active rank" or "Rank unknown"))
    side.rating:SetText(p and p.rating and tostring(p.rating) or "")
    Health(side,unit)
end
local function PreviewSide(side,name,class,rank,value,health)
    side.id,side.profile=nil,false
    side.name:SetText(name)
    local icon="Interface\\Icons\\ClassIcon_"..class
    if type(SetPortraitToTexture)~="function" or not pcall(SetPortraitToTexture,side.icon,icon) then side.icon:SetTexture(icon) end
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
        local mode=ns.CompetitiveLifecycle.GetSnapshot().duelMode
        local ranked=mode=="Ranked candidate"
        modeRank.selected=ranked;modePractice.selected=not ranked;modeRank.Paint();modePractice.Paint()
        if snap.state=="finishing" then state:SetText("Awaiting observed result")
        elseif remaining>0 then state:SetText((ranked and "Ranked" or "Unranked").." countdown")
        else state:SetText(ranked and "Ranked candidate" or "Unranked duel") end
        timer:SetText(remaining>0 and tostring(math.ceil(remaining)) or TimeText(now-(acceptedAt or now)))
    elseif shownResult and now>=shownResult.untilTime then
        shownResult=nil;H.Refresh()
    end
end
local lastRange,lastRangeReason
local function Paint()
    if folded or not root:IsShown() or not snap then return end
    if preview then
        modeRank.selected=true;modePractice.selected=false
        state:SetText("SOLO PREVIEW - SIMULATED");timer:SetText("00:32")
        PreviewSide(me,"Test Priest","PRIEST",{name="Contender",division=2,label="Contender II"},1660,76)
        PreviewSide(other,"Test Mage","MAGE",{name="Veteran",division=3,label="Veteran III"},1925,43)
        done:SetText("52.7K");taken:SetText("48.1K")
        challenge.label:SetText("Challenge Ranked")
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
    local idle=snap.state=="idle"
    local canRank,why,selectable=ns.CompetitiveLifecycle.RankedAvailability(opponent and opponent.guid)
    local liveMode=ns.CompetitiveLifecycle.GetSnapshot().duelMode
    local effectiveRank=idle and canRank and not intent or not idle and liveMode=="Ranked candidate"
    -- The gold mode is the effective duel type, not an unconfirmed preference.
    modeRank.selected=effectiveRank==true;modePractice.selected=not effectiveRank
    Enable(modeRank,idle and not Combat() and selectable and not ns.CompetitivePreview.IsActive())
    Enable(modePractice,idle and not Combat() and not ns.CompetitivePreview.IsActive())
    challenge.label:SetText(effectiveRank and "Challenge Ranked" or "Challenge Unranked")
    lastRange,lastRangeReason=nil,nil
    if idle and opponent and self and opponent.guid~=self.guid then
        lastRange,lastRangeReason=ns.DuelDetection.GetChallengeRange(opponent.guid)
    end
    Enable(challenge,idle and not Combat() and lastRange==true and
        type(StartDuel)=="function" and not ns.CompetitivePreview.IsActive())
    local outgoing=snap.challenge and snap.challenge.direction=="outgoing"
    forfeit.label:SetText(outgoing and (snap.challenge.requestConfirmed and "Cancel Request" or "Dismiss") or "Forfeit")
    Enable(forfeit,not ns.CompetitivePreview.IsActive() and
        ((snap.active~=nil and snap.state~="finishing" and type(ForfeitDuel)=="function")
        or (outgoing and (not snap.challenge.requestConfirmed or (not Combat() and type(CancelDuel)=="function")))) or false)
    done:SetText("—");taken:SetText("—")
    if snap.active then
        note:SetText("Duel damage unavailable")
        Tick()
    elseif snap.challenge then
        local outgoing=snap.challenge.direction=="outgoing"
        state:SetText(snap.challenge.kind=="death_duel" and "Death duel - excluded" or
            outgoing and not snap.challenge.requestConfirmed and "Checking request" or "Challenge pending")
        timer:SetText("00:00")
        note:SetText(outgoing and not snap.challenge.requestConfirmed and "Waiting for client confirmation" or "Waiting for Blizzard countdown")
    elseif shownResult then
        state:SetText(shownResult.text);timer:SetText(shownResult.duration)
        note:SetText("Rating not confirmed")
    else
        local refusal=snap.reason=="request_not_confirmed" or snap.reason=="request_refused" or snap.reason=="request_dismissed"
        state:SetText(snap.state=="unavailable" and "Duel detection unavailable" or
            opponent and (lastRange==true and "Ready to challenge" or lastRangeReason or "Range unavailable") or "Select a player to duel")
        timer:SetText("00:00")
        note:SetText(refusal and "Previous request not confirmed" or
            canRank and (intent and "Unranked selected" or "Ranked available") or why or "Unranked only")
    end
end
local function UpdateDriver()
    if folded or not root:IsShown() then root:SetScript("OnUpdate",nil);H.elapsed=0;return end
    -- Range changes while moving without a target-change event. A lightweight
    -- probe only while visible, idle and targeting another player; no full
    -- refresh unless the range state changes.
    local id=not preview and snap and snap.state=="idle" and Identity("target")
    local me=id and Identity("player")
    local checkRange=id and me and id.guid~=me.guid and not Combat()
    root:SetScript("OnUpdate",not preview and snap and (snap.active or shownResult or checkRange) and function(_,dt)
        H.elapsed=(H.elapsed or 0)+dt
        if H.elapsed<.25 then return end
        H.elapsed=0
        if snap.active or shownResult then Tick() end
        if snap.state=="idle" and not Combat() then
            local v,why=ns.DuelDetection.GetChallengeRange()
            if v~=lastRange or why~=lastRangeReason then Paint() end
        end
    end or nil)
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
    UpdateDriver()
end
function H.GetNotificationAnchor() return root end
function H.ApplyPosition()
    if dragging then return end
    local x,y=Settings.GetDuelHUDPosition()
    local ratio=UIParent:GetEffectiveScale()/root:GetEffectiveScale()
    root:ClearAllPoints()
    -- Store the expanded centre as before, but anchor the actual top edge.
    -- Folding therefore never moves the title or its notification anchor.
    root:SetPoint("TOP",UIParent,"BOTTOMLEFT",UIParent:GetWidth()*x*ratio,UIParent:GetHeight()*y*ratio+HEIGHT/2)
    if ns.Notifications then ns.Notifications.Reanchor() end
end
local function StopDrag()
    if not dragging then return end
    dragging=false;root:StopMovingOrSizing()
    local x,y=root:GetCenter()
    if y then y=y+(root:GetHeight()-HEIGHT)/2 end
    local ratio=root:GetEffectiveScale()/UIParent:GetEffectiveScale()
    if x and y and UIParent:GetWidth()>0 and UIParent:GetHeight()>0 then
        Settings.SetDuelHUDPosition(x*ratio/UIParent:GetWidth(),y*ratio/UIParent:GetHeight())
    end
    if ns.Notifications then ns.Notifications.Reanchor() end
end
header:SetScript("OnDragStart",function()
    if Settings.Get("duelHUDLocked") or Combat() then return end
    dragging=true;root:StartMoving()
end)
header:SetScript("OnDragStop",StopDrag)
local unsubscribe,unsubscribeDiscovery
local probeGeneration=0
local function ProbeSelected()
    probeGeneration=probeGeneration+1
    local generation=probeGeneration
    if folded or preview or not snap or snap.state~="idle" or Combat() then return end
    local id=Identity("target");local own=Identity("player")
    if not id or not own or id.guid==own.guid then return end
    -- One throttled retry on rapid target changes; no repeating network poll.
    local ok,reason=ns.OpponentDiscovery.ProbeTarget(true)
    if not ok and reason=="cooldown" and C_Timer and C_Timer.After then
        C_Timer.After(8.1,function()
            if generation~=probeGeneration or not root:IsShown() or folded or preview or Combat() or not snap or snap.state~="idle" then return end
            local current=Identity("target")
            if current and current.guid==id.guid then ns.OpponentDiscovery.ProbeTarget(true);Paint() end
        end)
    end
end
function H.IsFolded() return folded end
function H.Fold(value)
    local want=value==true
    if want==folded then return end
    StopDrag();folded=want;probeGeneration=probeGeneration+1
    body:SetShown(not folded);foldedTop:SetShown(folded);foldedBottom:SetShown(folded)
    root:SetHeight(folded and FOLDED_HEIGHT or HEIGHT);PaintFold();H.ApplyPosition()
    if not folded and root:IsShown() then rankDirty=true;Receive(ns.DuelDetection.GetSnapshot());ProbeSelected() end
    UpdateDriver()
end
local events={"PLAYER_TARGET_CHANGED","PLAYER_FOCUS_CHANGED","UPDATE_MOUSEOVER_UNIT","UNIT_HEALTH","UNIT_MAXHEALTH","UNIT_NAME_UPDATE","PLAYER_REGEN_ENABLED","PLAYER_REGEN_DISABLED","UI_SCALE_CHANGED","DISPLAY_SIZE_CHANGED"}
root:SetScript("OnEvent",function(_,event,unit)
    if event=="PLAYER_REGEN_DISABLED" then StopDrag() end
    if event=="UI_SCALE_CHANGED" or event=="DISPLAY_SIZE_CHANGED" then H.ApplyPosition() end
    if event=="UNIT_HEALTH" or event=="UNIT_MAXHEALTH" then
        if folded or preview then return end
        if unit=="player" then Health(me,"player")
        elseif snap then
            local engaged=snap.active or snap.challenge
            local id=engaged and engaged.opponent or not engaged and Identity("target") or nil
            local expected=engaged and MatchUnit(id) or not engaged and id and "target" or nil
            if expected and unit==expected then Health(other,expected) end
        end
        return
    end
    if event=="PLAYER_TARGET_CHANGED" then
        local c=snap and snap.challenge
        local id=Identity("target")
        if c and c.direction=="outgoing" and not c.requestConfirmed and
            (not id or not c.opponent or id.guid~=c.opponent.guid) then ns.DuelDetection.DismissUnconfirmed() end
    end
    if event=="PLAYER_TARGET_CHANGED" or event=="PLAYER_REGEN_ENABLED" then ProbeSelected() end
    Paint();UpdateDriver()
end)
root:SetScript("OnShow",function()
    rankDirty=true
    for _,event in ipairs(events) do pcall(root.RegisterEvent,root,event) end
    unsubscribe=ns.DuelDetection.Subscribe(Receive)
    unsubscribeDiscovery=ns.OpponentDiscovery.Subscribe(Paint)
    Receive(ns.DuelDetection.GetSnapshot());ProbeSelected();Paint()
end)
root:SetScript("OnHide",function()
    StopDrag()
    if unsubscribe then unsubscribe();unsubscribe=nil end
    if unsubscribeDiscovery then unsubscribeDiscovery();unsubscribeDiscovery=nil end
    probeGeneration=probeGeneration+1
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
    return {subscriptions=(unsubscribe and 1 or 0)+(unsubscribeDiscovery and 1 or 0),timers=root:GetScript("OnUpdate") and 1 or 0}
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
