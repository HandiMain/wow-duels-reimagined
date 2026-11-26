-- Mock the actual HUD controller, no live game APIs or saved data.
local frames={}
local noop=function()end
local methods={}
function methods:SetSize(w,h)self.w=w;self.h=h end
function methods:SetHeight(h)self.h=h end
function methods:GetWidth()return self.w or 0 end
function methods:GetHeight()return self.h or 0 end
function methods:GetParent()return self.parent end
function methods:SetPoint(...)self.point={...}end
function methods:ClearAllPoints()self.point=nil end
function methods:SetScript(k,f)self.scripts[k]=f end
function methods:GetScript(k)return self.scripts[k] end
function methods:HookScript(k,f)local old=self.scripts[k];self.scripts[k]=function(...)if old then old(...)end;f(...)end end
function methods:SetShown(v)if v then self:Show()else self:Hide()end end
function methods:Show()local old=self.shown;self.shown=true;if not old and self.scripts.OnShow then self.scripts.OnShow(self)end end
function methods:Hide()local old=self.shown;self.shown=false;if old and self.scripts.OnHide then self.scripts.OnHide(self)end end
function methods:IsShown()return self.shown end
function methods:IsVisible()return self.shown and (not self.parent or self.parent:IsVisible())end
function methods:SetText(t)self.text=t end
function methods:SetTextColor(...)self.textColor={...}end
function methods:SetAlpha(v)self.alpha=v end
function methods:GetAlpha()return self.alpha or 1 end
function methods:IsMouseOver()return self.mouseOver==true end
function methods:SetStatusBarTexture(t)self.barTexture=t end
function methods:SetMinMaxValues(lo,hi)self.low,self.high=lo,hi end
function methods:SetValue(v)self.value=v end
function methods:SetTexture(t)self.texture=t end
function methods:SetColorTexture(...)self.color={...}end
function methods:SetScale(v)self.scale=v end
function methods:GetScale()return self.scale or 1 end
function methods:GetEffectiveScale()return self.scale or 1 end
function methods:GetFrameLevel()return 1 end
function methods:GetCenter()return self.point[4],self.point[5]-self.h/2 end
function methods:RegisterEvent(e)self.events[e]=true end
function methods:UnregisterAllEvents()self.events={}end
local function Frame(parent)
    local f=setmetatable({parent=parent,scripts={},events={},shown=true}, {__index=function(_,k)return methods[k] or (type(k)=="string" and k:match("^[A-Z]") and noop or nil) end})
    frames[#frames+1]=f;return f
end
function methods:CreateTexture()return Frame(self)end
function methods:CreateFontString()return Frame(self)end
CreateFrame=function(_,name,parent)local f=Frame(parent);if name then _G[name]=f end;return f end
UIParent=Frame(nil);UIParent:SetSize(1440,900)
local now=100
GetTime=function()return now end
local pendingTimers={}
C_Timer={NewTimer=function(delay,fn)local t={delay=delay,fn=fn};function t:Cancel()self.cancelled=true end;pendingTimers[#pendingTimers+1]=t;return t end}
local function FlushTimers()local list=pendingTimers;pendingTimers={};for _,t in ipairs(list)do if not t.cancelled then t.fn() end end end
InCombatLockdown=function()return false end
local C=setmetatable({}, {__index=function(t,k)local v={1,1,1,1};rawset(t,k,v);return v end})
local prefs={duelHUDEnabled=true,duelHUDLocked=false,duelHUDScale=1}
local px,py=.4,.5
local fits,anchors,subscribers=0,0,0
local fitted={}
local snap={state="idle"}
local target="target"
local duelListener,discoveryListener
local discovery={state="idle"}
local rankAvailable,rankReason,rankSelectable=false,"Ranked testing disabled",false
local probes=0
local probeCooldown=false
local function ID(unit)
    local name=unit=="target" and target or unit~="target" and unit or nil
    if not name or name=="NPC" then return nil end
    return {guid="Player-1-"..name,name=name}
end
UnitGUID=function(unit)local id=ID(unit);return id and id.guid end
local function Subscribe()subscribers=subscribers+1;return function()subscribers=subscribers-1 end end
local ns={
    Style={color=C,Text=function(p,t)local f=Frame(p);f:SetText(t);return f end,
        ConstrainText=function(label,w,h)assert(w>0 and h>0);fits=fits+1;fitted[label]=true end,
        Plate=noop,FeedbackOverlay=function(p)return Frame(p)end},
    Settings={Get=function(k)return prefs[k] end,GetDuelHUDPosition=function()return px,py end,
        SetDuelHUDPosition=function(x,y)px,py=x,y end},
    Motion={Fade=function(f,a)f.alpha=a end,Duration=function()return .1 end,Stop=noop,Value=function(key,from,to,_,apply)apply(key,(from+to)/2);apply(key,to)end},Widgets={PressFeedback=noop},
    Chrome={Sharp=function(t)return t end},
    Header={CreateHUDButton=function(p,name,size)
        local b=Frame(p);b:SetSize(size,size);b.art=Frame(b);b.chosen=Frame(b)
        b.headerControl=name
        function b:SetGlyph(glyph)self.art:SetTexture(glyph..".png")end
        b:SetGlyph(name)
        return b
    end},
    Client={IsSupported=function()return true end},
    Group={ReadCompetitiveIdentity=ID},
    CompetitiveLifecycle={RankedAvailability=function()return rankAvailable,rankReason,rankSelectable end,GetSnapshot=function()return {}end},
    CompetitivePreview={IsActive=function()return false end},
    CompetitiveUI={CreateRankEmblem=function(p)local f=Frame(p);f.Paint=noop;return f end},
    DuelDetection={GetSnapshot=function()return snap end,Subscribe=function(fn)duelListener=fn;return Subscribe()end,GetChallengeRange=function()return true end},
    OpponentDiscovery={Subscribe=function(fn)discoveryListener=fn;return Subscribe()end,GetSnapshot=function()return discovery end,ProbeTarget=function()probes=probes+1;if probeCooldown then return false,"cooldown" end;return true end},
    TournamentRegistration={PreviewHasBracket=function()return false end,SubscribePreview=function()return noop end},
    TournamentHUD={IsEditing=function()return false end,Project=function()return nil end,GetDiagnosticResources=function()return {timers=0} end},
    Notifications={Reanchor=function()anchors=anchors+1 end,Refresh=noop,OnTournamentProgress=noop,ClearTournamentPreview=noop}
}
assert(loadfile("addon/DuelsReimagined/UI/DuelHUD.lua"))("DuelsReimagined",ns)
local H=ns.DuelHUD;local root=H.GetNotificationAnchor()
for _,f in ipairs(frames)do if f.events.PLAYER_LOGIN then f.scripts.OnEvent(f,"PLAYER_LOGIN");break end end
assert(root:IsShown() and root:GetHeight()==248 and not H.IsFolded() and subscribers==2)
assert(root:GetScript("OnUpdate") and fits>=12)
local arrow,ranked,header
local upper,foldTrim,controls={},nil,0
local title,foldBacking,foldFace,expandedFace
for _,f in ipairs(frames)do
    if f.texture and f.texture:find("FoldUp.png",1,true)then arrow=f.parent end
    if f.text=="Ranked"then ranked=f end
    if f.scripts.OnDragStart then header=f end
    if f.headerControl then controls=controls+1 end
    if f.parent==root and f.h==42 and f~=arrow and f.scripts.OnDragStart==nil and not f:IsShown() then foldTrim=f end
end
assert(arrow and ranked and ranked:IsVisible() and header and controls==3 and foldTrim)
for _,f in ipairs(frames) do
    if f.text=="Duels Reimagined" then title=f end
    if f.parent==foldTrim and f.color and f.color[4]==1 then foldBacking=f end
    if f.parent==foldTrim and f.texture and f.w==330 and f.h==36 then foldFace=f end
    if f.parent==arrow.parent and f.texture and f.w==320 and f.h==28 then expandedFace=f end
end
assert(title and foldBacking and foldFace and expandedFace)
for _,f in ipairs(frames) do if f.headerControl then assert(f.w==22 and f.h==22 and f.point[5]==-6) end end
assert(foldBacking.w==330 and foldBacking.h==36 and not foldBacking:IsVisible())
assert(expandedFace:IsVisible() and title.point[5]==-4)
local top=root.point[5];local frameCount=#frames
arrow.scripts.OnClick()
assert(H.IsFolded() and root:IsShown() and root:GetHeight()==42 and root.point[5]==top)
assert(not ranked:IsVisible() and arrow:IsVisible() and not root:GetScript("OnUpdate") and subscribers==2)
assert(foldTrim:IsVisible() and arrow.chosen.alpha==.42)
assert(foldBacking:IsVisible() and foldFace:IsVisible() and not expandedFace:IsShown())
assert(title.point[5]==-8 and arrow.point[5]==-10)
for _,f in ipairs(frames) do if f.headerControl then assert(f.point[5]==-10) end end
assert(arrow.art.texture=="FoldDown.png")
-- Moving while folded stores the expanded centre, not the tiny header centre.
header.scripts.OnDragStart();root.point[4]=720;root.point[5]=650
header.scripts.OnDragStop()
assert(math.abs(px-.5)<.0001 and math.abs(py-(650-155)/900)<.0001)
arrow.scripts.OnClick()
assert(not H.IsFolded() and root:GetHeight()==248 and math.abs(root.point[5]-650)<.001)
assert(ranked:IsVisible() and root:GetScript("OnUpdate") and subscribers==2)
assert(not foldTrim:IsShown() and arrow.chosen.alpha==0)
assert(expandedFace:IsVisible() and title.point[5]==-4 and arrow.point[5]==-6)
assert(arrow.art.texture=="FoldUp.png")
H.Fold(true);prefs.duelHUDEnabled=false;H.Refresh()
assert(not root:IsShown() and subscribers==0 and not root:GetScript("OnUpdate"))
prefs.duelHUDEnabled=true;H.Refresh()
assert(root:IsShown() and H.IsFolded() and root:GetHeight()==42 and subscribers==2)
H.Fold(false)
assert(#frames==frameCount and anchors>3 and ranked:IsVisible())
print("Duel HUD fold mock: PASS (stable top, body visibility, dragging, polling, subscriptions and font registration)")
local function VisibleText(t)
    for _,f in ipairs(frames)do if f.text==t and f:IsVisible() then return true end end
end
local function Select(name)
    target=name;root.scripts.OnEvent(root,"PLAYER_TARGET_CHANGED")
end
local function Publish(s)snap=s;duelListener(s)end
local top=root.point[5]
Select(nil);assert(not ranked:IsVisible() and VisibleText("Select a player to duel"))
assert(root:GetHeight()==248,"idle resize is debounced")
Select("second");FlushTimers();assert(root:GetHeight()==248 and ranked:IsVisible())
Select("NPC");FlushTimers();assert(root:GetHeight()==84 and root.point[5]==top and not root:GetScript("OnUpdate"))
Select("player");assert(root:GetHeight()==84)
Select("rival");assert(root:GetHeight()==248 and ranked:IsVisible())
local rival=ID("target")
Publish({state="requested",challenge={direction="outgoing",opponent=rival,requestConfirmed=true}})
assert(root:GetHeight()==220 and VisibleText("Challenge pending") and VisibleText("Cancel Request") and not ranked:IsVisible())
Select("bystander");assert(VisibleText("rival") and not VisibleText("bystander"))
Publish({state="idle"});assert(root:GetHeight()==248)
Publish({state="requested",challenge={direction="incoming",opponent=rival}})
assert(root:GetHeight()==188 and not VisibleText("Cancel Request") and VisibleText("rival"))
now=110
Publish({state="accepted",active={id=1,opponent=rival,acceptedAt=110,countdown=3},trace={{cycle=1,reason="countdown_observed",time=110}}})
assert(root:GetHeight()==232 and VisibleText("3") and VisibleText("rival") and not VisibleText("Damage Done"))
now=115;root:GetScript("OnUpdate")(root,.3);assert(VisibleText("00:02"))
H.Fold(true);Select(nil);assert(root:GetHeight()==42 and not root:GetScript("OnUpdate"))
now=117;H.Fold(false);assert(root:GetHeight()==232 and VisibleText("00:04") and VisibleText("rival"))
now=120;Publish({state="idle",last={id=1,outcome="won",outcomeObserved=true,finishObserved=true,resultObserved=true,conflict=false,reason="matching_result_and_finish",endedAt=120}})
assert(root:GetHeight()==136 and VisibleText("Victory") and VisibleText("00:07") and VisibleText("Rating not confirmed"))
Select("newtarget");assert(root:GetHeight()==136 and VisibleText("Victory"))
now=127;root:GetScript("OnUpdate")(root,.3);assert(root:GetHeight()==248 and VisibleText("newtarget"))
Select(nil);H.Fold(true);FlushTimers();assert(root:GetHeight()==42)
H.Fold(false);assert(root:GetHeight()==84)
Select("target");assert(root:GetHeight()==248 and root.point[5]==top and #frames==frameCount)
print("Adaptive HUD mock: PASS (idle/invalid/selected/pending/incoming/active/result, debounce, target lock, timer, fold, anchor, no new frames)")
local function Recognition(t,color)
    for _,f in ipairs(frames) do
        if f.text==t and f:IsVisible() then
            assert(f.textColor and math.abs(f.textColor[1]-color[1])<.001 and math.abs(f.textColor[2]-color[2])<.001 and math.abs(f.textColor[3]-color[3])<.001,t)
            return true
        end
    end
    error("Missing recognition label: "..t)
end
local green,amber,grey,red={.46,.85,.44},{.96,.71,.25},{.62,.64,.68},{1,.43,.38}
local function Reply(status,reason,who,offer)
    discovery={state=status,reason=reason,opponent=who,rankOffer=offer};discoveryListener()
end
local peer=ID("target")
local before=probes
assert(Recognition("Opponent not checked",grey))
Reply("checking","request_sent",peer);assert(Recognition("Checking opponent...",amber))
Reply("unknown","no_reply",peer);assert(Recognition("Addon not detected (no reply)",grey))
Reply("unknown","confirmation_expired",peer);assert(Recognition("Addon confirmation expired",grey))
Reply("unknown","restricted",peer);assert(Recognition("Addon check unavailable",grey))
Reply("incompatible","protocol_or_client_mismatch",peer);assert(Recognition("Incompatible addon version",red))
Reply("compatible","matching_reply",peer);assert(Recognition("Addon detected - Ranked testing disabled",amber))
rankReason="Ranked compatibility not confirmed"
Reply("compatible","matching_reply",peer);assert(Recognition("Addon detected - Ranked unconfirmed",amber))
Reply("compatible","matching_reply",peer,"R|1000|"..string.rep("a",64));assert(Recognition("Incompatible ranked rules",red))
rankReason="Opponent prefers Unranked";rankSelectable=true
Reply("compatible","preference_updated",peer,"U|1000|"..string.rep("a",64))
assert(Recognition("Addon detected - Opponent prefers Unranked",amber))
rankAvailable=true;rankReason="Ranked available"
Reply("compatible","preference_updated",peer,"R|1000|"..string.rep("a",64))
assert(Recognition("Ranked available",green))
prefs.practiceDuels=true;H.Refresh();assert(Recognition("Ranked available - Unranked selected",green))
prefs.practiceDuels=false
assert(probes==before and root:GetHeight()==248 and #frames==frameCount,"status paint must not probe, resize or create frames")
rankAvailable=false;rankReason="Checking opponent";rankSelectable=false
Select("different");assert(Recognition("Opponent not checked",grey))
Reply("compatible","matching_reply",peer);assert(Recognition("Opponent not checked",grey))
Select(nil);FlushTimers();assert(not VisibleText("Opponent not checked") and root:GetHeight()==84)
rankReason="Ranked testing disabled";Select("target");assert(Recognition("Addon detected - Ranked testing disabled",amber))
Reply("compatible","matching_reply",peer)
Publish({state="challenge",challenge={direction="incoming",opponent=peer}})
assert(not VisibleText("Addon detected - Ranked testing disabled") and VisibleText("Waiting for Blizzard countdown"))
Publish({state="idle"})
assert(root:GetHeight()==248 and #frames==frameCount)
print("Opponent recognition mock: PASS (exact peer, no reply, expiry, local gates, incompatibility, mutual preference, no extra probes or frames)")
prefs.duelHUDAdaptive=false;H.Refresh();Select(nil);FlushTimers()
assert(root:GetHeight()==248 and not ranked:IsVisible() and VisibleText("Select a player to duel"))
H.Fold(true);assert(root:GetHeight()==42);H.Fold(false);assert(root:GetHeight()==248)
prefs.duelHUDAdaptive=true;H.Refresh();FlushTimers();assert(root:GetHeight()==84)
prefs.duelHUDOpacity=.4;H.ApplyOpacity();assert(root.alpha==.4)
root.scripts.OnEnter(root);assert(root.alpha==1)
root.scripts.OnLeave(root);assert(root.alpha==.4)
Select("target")
local opponent=ID("target")
Publish({state="challenge",challenge={direction="incoming",opponent=opponent}})
assert(root.alpha==1)
Publish({state="idle"});assert(root.alpha==.4)
prefs.duelHUDOpacity=1;H.ApplyOpacity();assert(root.alpha==1)
assert(root:GetHeight()==248 and #frames==frameCount)
print("HUD customization mock: PASS (fixed/adaptive layout, manual fold, idle opacity, hover, engaged opacity, same frames)")
prefs.duelHUDSessionStats=true;H.Refresh()
assert(root:GetHeight()==352 and VisibleText("CURRENT SESSION") and VisibleText("Session data unavailable"))
Select(nil);FlushTimers();assert(root:GetHeight()==188 and VisibleText("CURRENT SESSION"))
assert(H.ToggleSessionPreview() and VisibleText("SESSION PREVIEW - SIMULATED") and VisibleText("+126"))
Select("target");assert(root:GetHeight()==352 and VisibleText("SESSION PREVIEW - SIMULATED"))
Publish({state="challenge",challenge={direction="incoming",opponent=ID("target")}})
assert(root:GetHeight()==188 and not VisibleText("SESSION PREVIEW - SIMULATED") and not VisibleText("CURRENT SESSION"))
Publish({state="idle"});assert(root:GetHeight()==352 and VisibleText("CURRENT SESSION"))
prefs.duelHUDSessionStats=false;H.Refresh()
assert(root:GetHeight()==248 and not VisibleText("CURRENT SESSION") and #frames==frameCount)
print("Session HUD mock: PASS (opt-in, resize, explicit simulation, pending cancellation, no added frames during play)")
-- Rapid target changes keep at most one retry and cancel it on fold/hide.
probeCooldown=true
for i=1,25 do Select("peer"..i) end
local liveRetries=0
for _,timer in ipairs(pendingTimers) do if not timer.cancelled and timer.delay==8.1 then liveRetries=liveRetries+1 end end
assert(liveRetries==1 and H.GetDiagnosticResources().timers==2)
local beforeRetry=probes
H.Fold(true);FlushTimers();assert(probes==beforeRetry and H.GetDiagnosticResources().timers==0)
probeCooldown=false;H.Fold(false)
assert(H.ToggleSessionPreview() and VisibleText("SESSION PREVIEW - SIMULATED"))
root.scripts.OnEvent(root,"PLAYER_REGEN_DISABLED")
assert(not VisibleText("SESSION PREVIEW - SIMULATED"))
H.TogglePreview();assert(VisibleText("SOLO PREVIEW - SIMULATED"))
Publish({state="challenge",challenge={direction="incoming",opponent=ID("target")}})
assert(not VisibleText("SOLO PREVIEW - SIMULATED") and VisibleText("Challenge pending"))
Publish({state="accepted",active={id=2,opponent=ID("target"),acceptedAt=now}})
Publish({state="idle",last={id=2,outcome="won",outcomeObserved=true,endedAt=now+1}})
assert(VisibleText("Result unknown") and not VisibleText("Victory"))
now=now+8;root:GetScript("OnUpdate")(root,.3)
assert(root:GetHeight()==248 and #frames==frameCount)
print("HUD lifecycle regression: PASS (bounded retry, fold cleanup, combat preview exit, incoming challenge, incomplete result)")

local function HealthText(t)
    for _,f in ipairs(frames) do
        if f.text==t and f:IsVisible() then assert(not fitted[f],"health text must not have measurement hook");return true end
    end
end
local barCount=0
for _,f in ipairs(frames) do
    if f.barTexture and f.barTexture:find("DuelHUDHealthFill.png",1,true) then barCount=barCount+1 end
end
assert(barCount==2)
local hp,max=73,100
UnitHealth=function()return hp end;UnitHealthMax=function()return max end
root.scripts.OnEvent(root,"UNIT_HEALTH","player")
assert(HealthText("73%"))
hp=0;root.scripts.OnEvent(root,"UNIT_HEALTH","player");assert(HealthText("0%"))
hp=100;root.scripts.OnEvent(root,"UNIT_HEALTH","player");assert(HealthText("100%"))
-- Mock protected values that cannot be treated as numbers in Lua.
local secretHealth,secretMax,secretPct={},{},{}
issecretvalue=function(v)return v==secretHealth or v==secretMax or v==secretPct end
hp,max=secretHealth,secretMax
CurveConstants={ScaleTo100={}}
UnitHealthPercent=function(unit,predicted,curve)
    assert(unit=="player" and predicted==false and curve==CurveConstants.ScaleTo100)
    return 62
end
root.scripts.OnEvent(root,"UNIT_HEALTH","player");assert(HealthText("62%"))
function methods:SetFormattedText(format,v)
    assert(format=="%.0f%%" and v==secretPct)
    self.text="48%"
end
UnitHealthPercent=function()return secretPct end
root.scripts.OnEvent(root,"UNIT_HEALTH","player");assert(HealthText("48%"))
UnitHealthPercent=function()error("restricted percent unavailable")end
root.scripts.OnEvent(root,"UNIT_HEALTH","player");assert(not HealthText("48%"))
for _,f in ipairs(frames) do
    if f.barTexture and f.value==secretHealth then assert(f:IsShown() and f.high==secretMax) end
end
max=0;hp=0;root.scripts.OnEvent(root,"UNIT_HEALTH","player")
assert(HealthText("Unavailable"))
print("Duel HUD health mock: PASS (two native pill bars, readable percent, protected display, refusal and empty state)")
-- Execute the actual shared Style helper through its public font registration.
-- A secret-like object would throw on comparison, matching the reported fault.
local sf={}
local widthSecret=setmetatable({}, {__lt=function()error("secret comparison")end,__le=function()error("secret comparison")end})
issecretvalue=function(v)return v==widthSecret end
local onSetText,fitHooks=nil,0
hooksecurefunc=function(label,key,fn)if key=="SetText" then onSetText=fn;fitHooks=fitHooks+1 end end
local measured=widthSecret
local fontSize
local label={}
function label:SetFont(_,size)fontSize=size;return true end
function label:GetFont()return "mock",fontSize,"" end
function label:SetText()if onSetText then onSetText()end end
function label:GetUnboundedStringWidth()if measured=="refuse" then error("measurement refused")end;return measured end
function label:SetTextColor()end
function label:SetJustifyH()end
function label:SetJustifyV()end
local parent={CreateFontString=function()return label end}
local sty={Settings={Get=function()return 1 end}}
assert(loadfile("addon/DuelsReimagined/UI/Style.lua"))("DuelsReimagined",sty)
-- Identical skin group/alpha contract with no invisible native slices.
local skinParent=Frame(nil)
local nativeBefore=#frames
local skin=sty.Style.Skin(skinParent,sty.Style.color.body,{shine=0,shade=0,rim=0})
assert(#frames-nativeBefore==9 and #skin.groups==4)
skin:SetAlpha(.4);assert(skin:GetAlpha()==.4 and skin.groups[1]:GetAlpha()==.4)
assert(skin.groups[2]:GetAlpha()==0 and skin.groups[3]:GetAlpha()==0 and skin.groups[4]:GetAlpha()==0)
nativeBefore=#frames
local normal=sty.Style.Skin(skinParent,sty.Style.color.body,{})
assert(#frames-nativeBefore==36)
normal:SetAlpha(.5);assert(math.abs(normal.groups[2]:GetAlpha()-.2)<.0001)
nativeBefore=#frames
local smooth=sty.Style.Skin(skinParent,sty.Style.color.body,{smooth=true})
assert(#frames-nativeBefore==20 and smooth.groups[2]:GetAlpha()==0 and smooth.groups[3]:GetAlpha()==0)
print("Shared skin resource regression: PASS (invisible masks omitted, live layer alpha retained)")
sty.Style.Text(parent,"x",11)
sty.Style.ConstrainText(label,100,20,8)
assert(fontSize==11)
label:SetText("restricted")
assert(fontSize==11)
measured="refuse";label:SetText("refused");assert(fontSize==11)
measured=130;label:SetText("long");assert(fontSize==8)
measured=30;label:SetText("short");assert(fontSize==11)
measured=130;sty.Style.ConstrainText(label,70,20,8);assert(fontSize==8)
sty.Style.ConstrainText(label,200,20,8);assert(fontSize==11)
for _=1,20 do sty.Style.ConstrainText(label,200,20,8) end
assert(fitHooks==1,"responsive bounds must not stack SetText hooks")
print("Shared font fitting: PASS (secret width, refusal, shrink/restore, repeatable responsive bounds)")

-- Exercise the actual animation owner, including same-key retargeting from completion.
local driver
local oldCreate=CreateFrame
CreateFrame=function(...)driver=oldCreate(...);return driver end
local animNS={Settings={Get=function()return false end}}
assert(loadfile("addon/DuelsReimagined/UI/Motion.lua"))("DuelsReimagined",animNS)
CreateFrame=oldCreate
local Motion=animNS.Motion
local key,last={},nil
Motion.Value(key,0,1,.1,function(_,v)if v==1 then Motion.Value(key,1,2,.1,function(_,n)last=n end) end end)
driver.scripts.OnUpdate(driver,.1)
assert(Motion.GetRuntimeState().active==1)
driver.scripts.OnUpdate(driver,.1)
assert(last==2 and not Motion.GetRuntimeState().driver)
print("Shared motion regression: PASS (completion retarget survives and driver releases)")
