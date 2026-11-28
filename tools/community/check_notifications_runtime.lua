-- Isolated mock for evidence and notification presentation. No WoW/network.
local root="addon/DuelsReimagined/"
local frames,buttons,timers,expiry={}, {}, {}, {}
local function Frame(kind,name,parent)
    local f={kind=kind,name=name,parent=parent,shown=true,alpha=1,scale=1,scripts={},events={},width=410,height=218}
    local function noop() end
    function f:SetSize(w,h) self.width,self.height=w,h end
    function f:GetHeight() return self.height end
    function f:GetWidth() return self.width end
    function f:SetScale(v) self.scale=v end
    function f:GetScale() return self.scale end
    function f:GetEffectiveScale() return self.scale end
    function f:GetTop() return 600 end
    function f:GetBottom() return 290 end
    function f:SetAlpha(v) self.alpha=v end
    function f:GetAlpha() return self.alpha end
    function f:SetPoint(...) self.point={...} end
    function f:ClearAllPoints() self.point=nil end
    function f:Show() self.shown=true end
    function f:Hide() self.shown=false end
    function f:IsShown() return self.shown end
    function f:SetScript(k,v) self.scripts[k]=v end
    function f:HookScript(k,v) local old=self.scripts[k];self.scripts[k]=function(...) if old then old(...) end;v(...) end end
    function f:RegisterEvent(k) self.events[k]=true end
    function f:UnregisterEvent(k) self.events[k]=nil end
    function f:CreateTexture() return Frame("Texture") end
    function f:SetText(v) self.text=v end
    function f:SetTextColor(...) self.color={...} end
    for _,k in ipairs({"SetFrameStrata","SetClampedToScreen","EnableMouse","SetTexture","SetTexCoord",
        "SetVertexColor","SetAllPoints","SetJustifyH","SetWordWrap","RegisterForClicks"}) do f[k]=noop end
    frames[#frames+1]=f
    return f
end
_G.CreateFrame=Frame
_G.UIParent=Frame("Root");UIParent:SetSize(1920,1080)
local hud=Frame("HUD")
local now,combat,duel,version=100,false,"idle",nil
_G.GetTime=function()return now end
_G.GetServerTime=function()return 1700000000+now end
_G.InCombatLockdown=function()return combat end
_G.IsInInstance=function()return false end
_G.C_AddOns={GetAddOnMetadata=function()return version end}
_G.C_Timer={After=function(_,fn)timers[#timers+1]=fn end,NewTimer=function(seconds,fn)
    local t={seconds=seconds,fn=fn};function t:Cancel() self.cancelled=true end
    expiry[#expiry+1]=t;return t
end}
local played,stopped,lastPlayedPath=0,0,nil
_G.PlaySoundFile=function(path,channel)
    assert((path:find("General.mp3",1,true) or path:find("RankPromotion.mp3",1,true) or path:find("Achievement.mp3",1,true) or path:find("Warning.mp3",1,true)) and channel=="SFX")
    lastPlayedPath=path;played=played+1;return true,played
end
_G.StopSound=function()stopped=stopped+1 end
local prefs={notificationEnabled=true,notificationSounds=true}
local simulation=false;local simulatedMatches={}
local localEnabled=false;local localMatches={}
local snoozed,pc,dc,links
links=0
local ns={
    Client={IsSupported=function()return true end},
    AchievementUI={PaintAchievementIcon=function(f,id)f.achievementID=id end},
    CompetitiveStorage={LocalRecordingEnabled=function()return localEnabled end},
    CompetitivePreview={IsActive=function()return simulation end,Get=function()return {scope=simulation and "SIMULATED" or "LOCAL",matches=simulation and simulatedMatches or localMatches}end},
    CompetitiveUI={CreateRankEmblem=function(parent)
        local f=Frame("Rank",nil,parent);f.Paint=function(r)f.rank=r end;return f
    end},
    Style={color={pale={1,1,1},text={1,1,1}},Text=function(parent,value)
        local f=Frame("Text");f.text=value
        if parent.kind=="Button" then buttons[value]=parent end
        return f
    end},
    Motion={Stop=function()end,Value=function(key,_,to,_,apply)apply(key,to)end},
    Settings={Get=function(k)return prefs[k] end,GetDuelHUDPosition=function()return .3,.52 end,
        IsUpdateSnoozed=function(v)return snoozed==v end,SnoozeUpdate=function(v)snoozed=v end},
    DuelHUD={GetNotificationAnchor=function()return hud end,
        GetRegularNotificationAnchor=function()return hud end,GetNotificationScale=function()return hud:GetScale() end,
        IsTournamentHUDActive=function()return false end,IsSwitchingNotificationAnchor=function()return false end},
    DuelDetection={GetSnapshot=function()return {state=duel} end,
        Subscribe=function(fn)dc=fn;return function()end end},
    Presence={Subscribe=function(fn)pc=fn;return function()end end,
        GetSnapshot=function()return {complete=true,members={}} end},
    Window={frame=Frame("Main"),Toggle=function()end},
    Footer={ShowReleaseLink=function()links=links+1;return true end}
}
assert(loadfile(root.."Core/UpdateNotices.lua"))("DuelsReimagined",ns)
local U=ns.UpdateNotices
local function R(a,b,id)
    return {complete=true,members={{guid="A",status="confirmed",version=a},{guid=id or "B",status="confirmed",version=b}}}
end
assert(U.Compare("0.1.10","0.1.9")==1)
for _,v in ipairs({"dev","0.1.1-rc1","01.1.0","1.2","99.1000.0","1.2.3.4"}) do assert(not U.Parse(v)) end
assert(U.Select("0.1.0",R("0.1.1","0.1.1"))=="0.1.1")
assert(not U.Select("0.1.0",R("0.1.1","0.1.1","A")))
assert(not U.Select("0.1.0",R("0.1.1","0.1.2")))
assert(not U.Select("0.1.0",R("9.9.9","9.9.9")))
local stale=R("0.1.1","0.1.1");stale.stale=true;assert(not U.Select("0.1.0",stale))
U.Observe(R("0.1.1","0.1.1"));assert(not U.GetNotice())
assert(loadfile(root.."Core/SeasonRules.lua"))("DuelsReimagined",ns)
assert(loadfile(root.."Core/Achievements.lua"))("DuelsReimagined",ns)
assert(loadfile(root.."Core/DuelistTitles.lua"))("DuelsReimagined",ns)
assert(loadfile(root.."UI/Notifications.lua"))("DuelsReimagined",ns)
local card,events
for _,f in ipairs(frames) do
    if f.name=="DuelsReimaginedNotificationCard" then card=f end
    if f.events.PLAYER_LOGIN then events=f end
end
local function fire(event) events.scripts.OnEvent(events,event) end
local function flush() while #timers>0 do table.remove(timers,1)() end end
fire("PLAYER_LOGIN");flush()
local N=ns.Notifications
assert(N.Preview() and card:IsShown() and played==1)
assert(card.point[2]==hud and card.point[3]=="TOP")
assert(not N.Preview())
buttons["What's new"].scripts.OnClick();flush()
assert(not card:IsShown() and links==1 and not snoozed)
now=110;combat=true;version="0.1.0"
pc(R("0.1.1","0.1.1"));assert(not card:IsShown() and played==1)
combat=false;fire("PLAYER_REGEN_ENABLED");assert(card:IsShown() and played==2)
duel="accepted";dc();assert(not card:IsShown())
duel="idle";dc();assert(card:IsShown() and played==2)
buttons["Got it"].scripts.OnClick();flush();assert(snoozed=="0.1.1" and not card:IsShown())
hud:Hide();hud.scripts.OnHide();assert(not N.Preview() and not N.PreviewPromotion())
assert(not card:IsShown() and N.GetDiagnosticResources().queued==0)
hud:Show();hud.scripts.OnShow()
pc(R("0.1.1","0.1.1"));assert(not card:IsShown())
now=120;prefs.notificationSounds=false;assert(N.Preview() and played==2)
prefs.notificationEnabled=false;N.Refresh();assert(not card:IsShown() and not N.Preview())
print("Update notification mock: PASS (versions, queue, preview, SFX, defer, snooze, anchor, disable)")
prefs.notificationEnabled=true;prefs.notificationSounds=true;hud:Show();now=130
assert(N.PreviewPromotion() and card:IsShown() and played==3)
assert(lastPlayedPath:find("RankPromotion.mp3",1,true))
assert(card.point[2]==hud and card.point[3]=="TOP")
assert(not buttons["Got it"]:IsShown() and not buttons["What's new"]:IsShown())
assert(math.abs(expiry[#expiry].seconds-10.04)<.001 and not N.Preview())
local rank
for _,f in ipairs(frames) do if f.kind=="Rank" then rank=f.rank end end
assert(rank.label=="Duelist IV")
local foundTransition,foundColor=false,false
for _,f in ipairs(frames) do
    if f.text=="Veteran I > Duelist IV" then foundTransition=true end
    if f.text=="Duelist IV" and f.color and f.color[3]==1 and f.color[1]<.6 then foundColor=true end
end
assert(foundTransition and foundColor)
now=133;combat=true;fire("PLAYER_REGEN_DISABLED")
assert(not card:IsShown() and expiry[#expiry].cancelled)
combat=false;fire("PLAYER_REGEN_ENABLED")
assert(card:IsShown() and played==3 and math.abs(expiry[#expiry].seconds-7.04)<.001)
expiry[#expiry].fn();flush()
assert(not card:IsShown() and snoozed=="0.1.1")
now=145;assert(N.Preview() and card:IsShown() and played==4)
assert(buttons["Got it"]:IsShown() and buttons["What's new"]:IsShown())
buttons["Got it"].scripts.OnClick();flush()
assert(not card:IsShown() and N.GetDiagnosticResources().timers==0)
now=160;assert(N.PreviewPromotion() and card:IsShown())
local activeExpiry=expiry[#expiry];local previousStops=stopped
hud:SetSize(336,42);N.Reanchor();assert(card:IsShown() and card.point[2]==hud)
assert(not activeExpiry.cancelled)
hud:Hide();hud.scripts.OnHide()
assert(not card:IsShown() and activeExpiry.cancelled and stopped==previousStops+1)
assert(N.GetDiagnosticResources().queued==0 and not N.Preview())
hud:Show();hud.scripts.OnShow();assert(not card:IsShown())
assert(N.PreviewPromotion() and card:IsShown())
prefs.notificationEnabled=false;N.Refresh();assert(not card:IsShown())
print("Rank promotion mock: PASS (shared folded anchor, hide clears queue/audio/expiry, no stale preview, update restoration)")

prefs.notificationEnabled=true;now=180;assert(N.PreviewAchievement() and card:IsShown())
assert(lastPlayedPath:find("Achievement.mp3",1,true) and math.abs(expiry[#expiry].seconds-8.426094)<.001)
assert(card:GetHeight()==172 and not buttons["Got it"]:IsShown())
local foundIcon,foundPoints=false,false
for _,f in ipairs(frames) do
    if f.achievementID=="first" then foundIcon=true end
    if f.text=="+5" then foundPoints=true end
end
assert(foundIcon and foundPoints)
expiry[#expiry].fn();flush();assert(not card:IsShown())
simulation=true;simulatedMatches={};N.ResetAchievementPreview();N.CheckAchievements()
now=190;simulatedMatches={{id="a",kind="standard",outcome="won"}}
N.CheckAchievements();assert(card:IsShown() and N.GetDiagnosticResources().queued==1)
N.CheckAchievements();assert(N.GetDiagnosticResources().queued==1)
now=199;expiry[#expiry].fn();flush();assert(card:IsShown() and N.GetDiagnosticResources().queued==0)
N.ResetAchievementPreview();assert(not card:IsShown())
simulation=false
localEnabled=true;localMatches={{id="old",kind="standard",outcome="won"}}
N.CheckAchievements();assert(not card:IsShown(),"existing achievements must not replay")
now=210;table.insert(localMatches,1,{id="new",kind="standard",outcome="won"});N.CheckAchievements()
assert(card:IsShown() and N.GetDiagnosticResources().queued==1)
expiry[#expiry].fn();flush();assert(card:IsShown() and N.GetDiagnosticResources().queued==0)
local unlocked=false
for _,f in ipairs(frames) do if f.text=="NEW TITLE UNLOCKED" then unlocked=true end end
assert(unlocked,"live title reward notification missing")
hud:Hide();hud.scripts.OnHide();assert(not card:IsShown() and N.GetDiagnosticResources().queued==0)
hud:Show();hud.scripts.OnShow();N.CheckAchievements();assert(not card:IsShown())
now=230;assert(N.PreviewPromotion() and card:GetHeight()==218);prefs.notificationEnabled=false;N.Refresh()
assert(not card:IsShown() and N.GetDiagnosticResources().timers==0)
print("Achievement notification mock: PASS (asset selection, duration, queue, baseline, reset, visibility, shared size restore)")

prefs.notificationEnabled=true;now=250;local beforeWarningSound=played
assert(N.PreviewWarning() and card:IsShown())
assert(card:GetWidth()==320 and card:GetHeight()==86 and card.point[2]==hud)
assert(not buttons["Got it"]:IsShown() and not buttons["What's new"]:IsShown())
assert(played==beforeWarningSound+1 and lastPlayedPath:find("Warning.mp3",1,true))
assert(math.abs(expiry[#expiry].seconds-3.227750)<.001 and not N.PreviewWarning())
now=252;combat=true;fire("PLAYER_REGEN_DISABLED")
assert(not card:IsShown() and expiry[#expiry].cancelled)
combat=false;fire("PLAYER_REGEN_ENABLED")
assert(card:IsShown() and played==beforeWarningSound+1 and math.abs(expiry[#expiry].seconds-1.227750)<.001)
hud:Hide();hud.scripts.OnHide();assert(not card:IsShown() and not N.PreviewWarning())
hud:Show();hud.scripts.OnShow()
now=260;assert(N.PreviewWarning() and card:IsShown())
assert(played==beforeWarningSound+2 and lastPlayedPath:find("Warning.mp3",1,true))
expiry[#expiry].fn();flush();assert(not card:IsShown())
now=264;prefs.notificationSounds=false;assert(N.PreviewWarning() and card:IsShown())
assert(played==beforeWarningSound+2 and math.abs(expiry[#expiry].seconds-3.227750)<.001)
expiry[#expiry].fn();flush();assert(not card:IsShown())
prefs.notificationSounds=true
now=270;assert(N.PreviewAchievement() and card:GetWidth()==410 and card:GetHeight()==172)
prefs.notificationEnabled=false;N.Refresh();assert(not card:IsShown() and N.GetDiagnosticResources().timers==0)
print("Warning notification mock: PASS (compact layout, original SFX, sound preference, expiry, no replay on resume, visibility, shared size restore)")


-- Organizer-reported interruption clears only the matching outstanding warning.
prefs.notificationEnabled=true;now=300
local projection={event={id="test-cup"},names={["Player-1-00000001"]="Test participant"}}
ns.TournamentSession={GetProjection=function()return projection end}
local grace={scope="PRIVATE_TEST",event="test-cup",match="R1M1",player="Player-1-00000001",sequence=1700000300,notice="started",reported=true}
N.OnPrivateTournamentGrace(grace);assert(card:IsShown())
N.ClearPrivateTournamentGrace("other-cup",grace.match,grace.sequence);assert(card:IsShown())
projection=nil;grace.notice="interrupted"
N.OnPrivateTournamentGrace(grace);assert(not card:IsShown() and N.GetDiagnosticResources().queued==0)
now=310;assert(N.PreviewWarning() and card:IsShown())
N.ClearPrivateTournamentGrace(grace.event,grace.match,grace.sequence);assert(card:IsShown())
prefs.notificationEnabled=false;N.Refresh();assert(not card:IsShown() and N.GetDiagnosticResources().timers==0)
print("Private tournament grace notification mock: PASS (exact dismissal, no projection required, unrelated popup preserved)")
