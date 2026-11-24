-- Isolated mock for evidence and notification presentation. No WoW/network.
local root="addon/DuelsReimagined/"
local frames,buttons,timers={}, {}, {}
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
_G.C_Timer={After=function(_,fn)timers[#timers+1]=fn end}
local played,stopped=0,0
_G.PlaySoundFile=function(path,channel)
    assert(path:find("General.mp3",1,true) and channel=="SFX")
    played=played+1;return true,played
end
_G.StopSound=function()stopped=stopped+1 end
local prefs={notificationEnabled=true,notificationSounds=true}
local snoozed,pc,dc,links
links=0
local ns={
    Client={IsSupported=function()return true end},
    Style={color={pale={1,1,1},text={1,1,1}},Text=function(parent,value)
        local f=Frame("Text");f.text=value
        if parent.kind=="Button" then buttons[value]=parent end
        return f
    end},
    Motion={Stop=function()end,Value=function(key,_,to,_,apply)apply(key,to)end},
    Settings={Get=function(k)return prefs[k] end,GetDuelHUDPosition=function()return .3,.52 end,
        IsUpdateSnoozed=function(v)return snoozed==v end,SnoozeUpdate=function(v)snoozed=v end},
    DuelHUD={GetNotificationAnchor=function()return hud end},
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
hud:Hide();N.Reanchor();assert(card.point[2]==UIParent)
buttons["Got it"].scripts.OnClick();flush();assert(snoozed=="0.1.1" and not card:IsShown())
pc(R("0.1.1","0.1.1"));assert(not card:IsShown())
now=120;prefs.notificationSounds=false;assert(N.Preview() and played==2)
prefs.notificationEnabled=false;N.Refresh();assert(not card:IsShown() and not N.Preview())
print("Update notification mock: PASS (versions, queue, preview, SFX, defer, snooze, anchor, disable)")
