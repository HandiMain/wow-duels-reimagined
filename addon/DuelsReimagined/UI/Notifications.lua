local _,ns=...
-- Shared, bounded presentation queue. Only the update producer is enabled.
-- No gameplay, network, patch-catalogue or ranking writes.
local N={};ns.Notifications=N
local S,C,M,Settings=ns.Style,ns.Style.color,ns.Motion,ns.Settings
local WIDTH,BODY,CONNECTOR=410,183,35
local ART="Interface\\AddOns\\DuelsReimagined\\Media\\Skin\\NotificationArt.png"
local HUD_ART="Interface\\AddOns\\DuelsReimagined\\Media\\Skin\\DuelHUDArt.png"
local SOUND="Interface\\AddOns\\DuelsReimagined\\Media\\Sounds\\Notifications\\General.mp3"
local card=CreateFrame("Frame","DuelsReimaginedNotificationCard",UIParent)
card:SetSize(WIDTH,BODY+CONNECTOR);card:SetFrameStrata("HIGH")
card:SetClampedToScreen(true);card:EnableMouse(true);card:Hide()
if ns.DiagnosticAudit then ns.DiagnosticAudit.RegisterUIRoot("Notifications",card) end
local panel=CreateFrame("Frame",nil,card);panel:SetSize(WIDTH,BODY)
local function Position(f,parent,x,y,w,h)
    f:ClearAllPoints();f:SetPoint("TOPLEFT",parent,"TOPLEFT",x,-y);f:SetSize(w,h)
end
-- Padded, 2x notification art and clean shared HUD buttons. Do not sample
-- neighbouring atlas cells or baked-over text from the original mockup.
local function SmoothTexture(t)
    if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(false) end
    if t.SetTexelSnappingBias then t:SetTexelSnappingBias(0) end
end
local function Region(parent,layer,x,y,w,h,ax,ay,aw,ah)
    local t=parent:CreateTexture(nil,layer);t:SetTexture(ART);SmoothTexture(t)
    t:SetTexCoord((ax+.5)/1024,(ax+aw-.5)/1024,(ay+.5)/512,(ay+ah-.5)/512)
    Position(t,parent,x,y,w,h);return t
end
Region(panel,"BACKGROUND",0,0,WIDTH,BODY,8,8,792,356)
local connector=Region(card,"ARTWORK",0,BODY,WIDTH,CONNECTOR,8,372,792,66)
local glow=Region(panel,"OVERLAY",WIDTH/2-88,-34,176,58,820,8,192,88)
glow:SetAlpha(0)
local emblem=panel:CreateTexture(nil,"ARTWORK")
emblem:SetTexture("Interface\\AddOns\\DuelsReimagined\\Media\\Icons\\DuelsDRIcon.png")
SmoothTexture(emblem)
Position(emblem,panel,37,53,69,69)
local function Label(text,size,color,x,y,w,h)
    local v=S.Text(panel,text,size,color);v:SetJustifyH("CENTER");Position(v,panel,x,y,w,h);return v
end
local category=Label("Addon update",14,C.pale,106,6,198,25)
local heading=Label("",18,C.pale,119,45,270,32)
local description=Label("",12,C.text,119,79,270,60)
description:SetWordWrap(true)
local current,closing,shownSound,handle,animationKey
local queue,seen={},{}
local ready,loginDone=false,false
local unsubscribePresence,unsubscribeDuel
local delayCount=0
local lastSound=-math.huge
local function Plain(fn,...)
    if type(fn)~="function" then return nil end
    local ok,v=pcall(fn,...);if not ok then return nil end
    if type(issecretvalue)=="function" then
        local good,secret=pcall(issecretvalue,v)
        if not good or secret then return nil end
    end
    return v
end
local function Blocked()
    if not ns.Client.IsSupported() then return true end
    if type(InCombatLockdown)=="function" and Plain(InCombatLockdown)~=false then return true end
    if type(IsInInstance)=="function" and Plain(IsInInstance)~=false then return true end
    local d=ns.DuelDetection.GetSnapshot()
    return not d or d.state~="idle"
end
local function Later(fn)
    if C_Timer and C_Timer.After then
        delayCount=delayCount+1
        C_Timer.After(0,function() delayCount=delayCount-1;fn() end)
    end
end
local function StopAudio()
    if handle and type(StopSound)=="function" then pcall(StopSound,handle,100) end
    handle=nil
end
local function Play()
    if shownSound or not Settings.Get("notificationSounds") then return end
    shownSound=true
    local now=Plain(GetTime)
    -- Prevent overlap even when the client does not return a sound handle.
    if type(now)~="number" or now-lastSound<4.1 or type(PlaySoundFile)~="function" then return end
    local ok,played,id=pcall(PlaySoundFile,SOUND,"SFX")
    if ok and played==true then lastSound=now;handle=id end
end
local offset=0
local function Place()
    local hud=ns.DuelHUD and ns.DuelHUD.GetNotificationAnchor()
    local scale=hud and hud:GetScale() or 1
    card:SetScale(scale)
    local factor=card:GetEffectiveScale()/UIParent:GetEffectiveScale()
    local below=false
    if hud and hud:IsShown() and hud:GetTop() and hud:GetBottom() then
        local hf=hud:GetEffectiveScale()/UIParent:GetEffectiveScale()
        local top=hud:GetTop()*hf
        below=UIParent:GetHeight()-top<(BODY+CONNECTOR+8)*factor and hud:GetBottom()*hf>(BODY+CONNECTOR+8)*factor
        card:ClearAllPoints()
        if below then card:SetPoint("TOP",hud,"BOTTOM",0,-2+offset)
        else card:SetPoint("BOTTOM",hud,"TOP",0,2-offset) end
    else
        -- HUD hidden: separate screen anchor at the last saved HUD area.
        local x,y=Settings.GetDuelHUDPosition()
        card:ClearAllPoints()
        card:SetPoint("BOTTOM",UIParent,"BOTTOMLEFT",UIParent:GetWidth()*x/factor,
            math.min(UIParent:GetHeight()*y/factor,(UIParent:GetHeight()/factor)-BODY-CONNECTOR-8)-offset)
    end
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT",card,"TOPLEFT",0,below and -CONNECTOR or 0)
    Position(connector,card,0,below and 0 or BODY,WIDTH,CONNECTOR)
    if below then connector:SetTexCoord(8.5/1024,799.5/1024,437.5/512,372.5/512)
    else connector:SetTexCoord(8.5/1024,799.5/1024,372.5/512,437.5/512) end
end
function N.Reanchor() if card:IsShown() then Place() end end
local function StopAnimation()
    if animationKey then M.Stop(animationKey);animationKey=nil end
end
local function Animate(from,to,duration,done)
    StopAnimation();local key={};animationKey=key
    local function Apply(_,v)
        if animationKey~=key then return end
        offset=(1-v)*18;card:SetAlpha(v);glow:SetAlpha(v*.85);Place()
        if v==to then animationKey=nil;if done then done() end end
    end
    Apply(key,from)
    if animationKey==key then M.Value(key,from,to,duration,Apply) end
end
local function Clear()
    StopAnimation();StopAudio();card:Hide()
    current,closing,shownSound=nil,false,false;offset=0
end
local Pump
local function Dismiss(snooze)
    if not current or closing then return end
    local m=current
    if snooze and not m.preview and m.version then
        local now=Plain(GetServerTime)
        if type(now)=="number" then Settings.SnoozeUpdate(m.version,now) end
    end
    closing=true
    Animate(card:GetAlpha(),0,.19,function()
        Clear();Later(Pump)
    end)
end
local function Button(text,x,w,gold,fn)
    local b=CreateFrame("Button",nil,panel);Position(b,panel,x,142,w,27)
    b:RegisterForClicks("LeftButtonUp")
    local tx=b:CreateTexture(nil,"BACKGROUND");tx:SetAllPoints(b);tx:SetTexture(HUD_ART);SmoothTexture(tx)
    local function Paint()
        local ay=gold and 64 or 100
        tx:SetTexCoord(342.25/512,481.75/512,(ay+.25)/512,(ay+31.75)/512)
        local v=b.down and .74 or b.hover and 1 or .91;tx:SetVertexColor(v,v,v,1)
    end
    local label=S.Text(b,text,12,C.text);label:SetAllPoints(b);label:SetJustifyH("CENTER")
    b:SetScript("OnEnter",function() b.hover=true;Paint() end)
    b:SetScript("OnLeave",function() b.hover=false;b.down=false;Paint() end)
    b:SetScript("OnMouseDown",function() b.down=true;Paint() end)
    b:SetScript("OnMouseUp",function() b.down=false;Paint() end)
    b:SetScript("OnClick",fn);Paint();return b
end
Button("What's new",58,151,false,function()
    if Blocked() or not current then return end
    -- Even preview opens only the real, fixed repository releases page.
    if not ns.Window.frame:IsShown() then ns.Window.Toggle() end
    if ns.Footer.ShowReleaseLink() then Dismiss(false) end
end)
Button("Got it",224,142,true,function() Dismiss(true) end)
local close=CreateFrame("Button",nil,panel);Position(close,panel,WIDTH-31,10,18,18)
local closeText=S.Text(close,"×",14,C.pale);closeText:SetAllPoints(close);closeText:SetJustifyH("CENTER")
close:SetScript("OnClick",function() Dismiss(false) end)
local function Paint(m)
    category:SetText(m.preview and "PREVIEW: Addon update" or "Addon update")
    heading:SetText(m.title)
    description:SetText(m.body)
end
local function ShowCurrent()
    if not current or card:IsShown() then return end
    Paint(current);offset=18;Place();card:SetAlpha(0);card:Show()
    if not current.preview then seen[current.id]=true end
    Animate(0,1,.32);Play()
end
local function Snoozed(m)
    local now=Plain(GetServerTime)
    return not m.preview and m.version and type(now)=="number" and Settings.IsUpdateSnoozed(m.version,now)
end
Pump=function()
    if not ready then return end
    if not Settings.Get("notificationEnabled") then Clear();queue={};return end
    if Blocked() then
        if current and card:IsShown() then
            if closing then Clear()
            else StopAnimation();StopAudio();card:Hide() end
        end
        return
    end
    if current then
        if not closing then ShowCurrent() end
        return
    end
    while #queue>0 do
        local m=table.remove(queue,1)
        if (m.preview or not seen[m.id]) and not Snoozed(m) then
            current=m;shownSound=false;ShowCurrent();return
        end
    end
end
local function Enqueue(m)
    if not Settings.Get("notificationEnabled") or not ready or seen[m.id] or Snoozed(m) then return false end
    if current and current.id==m.id then return false end
    for _,v in ipairs(queue) do if v.id==m.id then return false end end
    if #queue>=8 then return false end
    queue[#queue+1]=m;Pump();return true
end
local function Update()
    if not ready or not loginDone then return end
    local n=ns.UpdateNotices.GetNotice()
    if n then
        -- A newer hint replaces queued older update hints, not other categories.
        for i=#queue,1,-1 do
            if not queue[i].preview and queue[i].version and
                ns.UpdateNotices.Compare(n.version,queue[i].version)==1 then table.remove(queue,i) end
        end
        Enqueue({id="update:"..n.version,version=n.version,title="Version "..n.version.." reported",
            body="You have "..n.mine..". Two peers report a newer version.\nCheck the official release page."})
    end
    Pump()
end
function N.Refresh()
    if not Settings.Get("notificationSounds") then StopAudio() end
    Pump();Update()
end
local PREVIEW_ENABLED=true
function N.Preview()
    if not PREVIEW_ENABLED or not ready then return false,"Preview unavailable" end
    if Blocked() then return false,"Finish your duel or combat first" end
    if not Settings.Get("notificationEnabled") then return false,"Notifications are disabled" end
    if current or #queue>0 then return false,"Dismiss the current notification first" end
    return Enqueue({id="preview:update",preview=true,title="New update available",
        body="Example version 0.2.0.\nSimulated preview — not a real release."})
end
function N.GetDiagnosticResources()
    return {subscriptions=(unsubscribePresence and 1 or 0)+(unsubscribeDuel and 1 or 0),
        timers=delayCount,queued=#queue}
end
local events=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_LOGIN","PLAYER_REGEN_ENABLED","PLAYER_REGEN_DISABLED","PLAYER_ENTERING_WORLD","UI_SCALE_CHANGED","DISPLAY_SIZE_CHANGED"}) do
    pcall(events.RegisterEvent,events,event)
end
events:SetScript("OnEvent",function(_,event)
    if event=="PLAYER_LOGIN" then
        ready=true;events:UnregisterEvent("PLAYER_LOGIN")
        unsubscribePresence=ns.Presence.Subscribe(function(snapshot) ns.UpdateNotices.Observe(snapshot);Update() end)
        unsubscribeDuel=ns.DuelDetection.Subscribe(function() Pump() end)
        local hud=ns.DuelHUD.GetNotificationAnchor()
        hud:HookScript("OnShow",N.Reanchor);hud:HookScript("OnHide",N.Reanchor)
        ns.UpdateNotices.Observe(ns.Presence.GetSnapshot())
        if C_Timer and C_Timer.After then
            delayCount=delayCount+1;C_Timer.After(10,function()
                delayCount=delayCount-1;loginDone=true;Update()
            end)
        else loginDone=true;Update() end
    else
        Pump();N.Reanchor()
    end
end)
