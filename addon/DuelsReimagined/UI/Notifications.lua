local _,ns=...
-- Shared, bounded presentation queue. Update producer and simulated promotion preview.
-- No gameplay, network, patch-catalogue or ranking writes.
local N={};ns.Notifications=N
local S,C,M,Settings=ns.Style,ns.Style.color,ns.Motion,ns.Settings
local WIDTH,BODY,CONNECTOR=410,183,35
local ART="Interface\\AddOns\\DuelsReimagined\\Media\\Skin\\NotificationArt.png"
local SOUND="Interface\\AddOns\\DuelsReimagined\\Media\\Sounds\\Notifications\\General.mp3"
local PROMOTION_SOUND="Interface\\AddOns\\DuelsReimagined\\Media\\Sounds\\Notifications\\RankPromotion.mp3"
local PROMOTION_ART="Interface\\AddOns\\DuelsReimagined\\Media\\Skin\\RankPromotionArt.tga"
-- Duration will be set from the original MP3 once available.
local PROMOTION_SOUND_SECONDS=nil
local PROMOTION_FALLBACK_SECONDS=8
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
-- Ornaments have their own alpha cells, no rectangular backdrop baked into
-- the frame. Reserve a clean centered text lane between their inner tips.
local ornamentLeft=Region(panel,"ARTWORK",32,14,88,20,820,112,192,44)
local ornamentRight=Region(panel,"ARTWORK",290,14,88,20,820,168,192,44)
local connector=Region(card,"ARTWORK",0,BODY,WIDTH,CONNECTOR,8,372,792,66)
local glow=Region(panel,"OVERLAY",WIDTH/2-88,-38,176,58,820,8,192,88)
glow:SetAlpha(0)
local emblem=panel:CreateTexture(nil,"ARTWORK")
emblem:SetTexture("Interface\\AddOns\\DuelsReimagined\\Media\\Icons\\DuelsDRIcon.png")
SmoothTexture(emblem)
Position(emblem,panel,37,53,69,69)
local function Label(text,size,color,x,y,w,h)
    local v=S.Text(panel,text,size,color);v:SetJustifyH("CENTER");Position(v,panel,x,y,w,h);return v
end
local category=Label("Addon update",13,C.pale,118,12,174,24)
local heading=Label("",18,C.pale,120,48,264,32)
local description=Label("",12,C.text,120,82,264,56)
description:SetWordWrap(true)
-- The approved rank card is a distinct content layer inside the SAME card.
-- Text and the shared rank emblem remain live, never baked into artwork.
local promotion=CreateFrame("Frame",nil,panel);promotion:SetAllPoints(panel);promotion:Hide()
local function PromotionArt(x,y,w,h,u1,u2,v1,v2,layer,sub)
    local t=promotion:CreateTexture(nil,layer or "ARTWORK",nil,sub or 0)
    t:SetTexture(PROMOTION_ART);SmoothTexture(t);t:SetTexCoord(u1,u2,v1,v2)
    Position(t,promotion,x,y,w,h);return t
end
-- The promotion's glows must be visible above the parent card's artwork.
local rankHeaderGlow=PromotionArt(64,-58,282,94,0,1,352/512,1,"BACKGROUND")
PromotionArt(37,12,125,158,0,.5,96/512,352/512,"ARTWORK")
local rankHalo=PromotionArt(28,25,143,143,.5,1,96/512,352/512,"ARTWORK",1)
rankHeaderGlow:SetAlpha(0);rankHalo:SetAlpha(0)
PromotionArt(55,-20,300,47,0,1,0,96/512,"ARTWORK",2)
local rankArt=ns.CompetitiveUI.CreateRankEmblem(promotion,113,false)
Position(rankArt,promotion,43,39,113,113)
local function RankLabel(value,size,color,x,y,w,h)
    local t=S.Text(promotion,value,size,color);t:SetJustifyH("CENTER")
    Position(t,promotion,x,y,w,h);return t
end
local rankCategory=RankLabel("",13,C.pale,76,-9,258,27)
local congrats=RankLabel("Congratulations!",15,C.text,169,38,222,24)
local newRank=RankLabel("",25,C.pale,166,65,228,36)
local transition=RankLabel("",13,C.pale,155,107,243,24)
local ratingGain=RankLabel("",16,{.49,.92,.30,1},164,137,232,25)
local rankColors={Aspirant={.76,.53,.32,1},Contender={.77,.81,.86,1},
    Veteran={.97,.77,.36,1},Duelist={.45,.79,1,1},
    Master={.58,.81,1,1},Grandmaster={1,.65,.28,1}}
local current,closing,shownSound,handle,animationKey
local queue,seen={},{}
local ready,loginDone=false,false
local unsubscribePresence,unsubscribeDuel
local delayCount=0
local expiryTimer,expiryAt,expiryRemaining
local rankGlowKey,promotionCelebrated
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
    local path=current and current.kind=="promotion" and PROMOTION_SOUND or SOUND
    local ok,played,id
    if path==SOUND then ok,played,id=pcall(PlaySoundFile,SOUND,"SFX")
    else ok,played,id=pcall(PlaySoundFile,PROMOTION_SOUND,"SFX") end
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
        offset=(1-v)*18;card:SetAlpha(v)
        if current and current.kind=="promotion" then
            glow:SetAlpha(0);rankHeaderGlow:SetAlpha(v*.82);rankHalo:SetAlpha(v*.68)
        else glow:SetAlpha(v*.85) end
        Place()
        if v==to then animationKey=nil;if done then done() end end
    end
    Apply(key,from)
    if animationKey==key then M.Value(key,from,to,duration,Apply) end
end
local function CancelExpiry(pause)
    if expiryTimer then
        if pause then
            local now=Plain(GetTime)
            if type(now)=="number" and expiryAt then expiryRemaining=math.max(0,expiryAt-now) end
        end
        expiryTimer:Cancel();expiryTimer=nil;delayCount=delayCount-1
    end
    expiryAt=nil
    if not pause then expiryRemaining=nil end
end
local function StopRankGlow()
    if rankGlowKey then M.Stop(rankGlowKey);rankGlowKey=nil end
end
local function Clear()
    CancelExpiry(false);StopRankGlow();promotionCelebrated=nil
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
    CancelExpiry(false);StopRankGlow()
    Animate(card:GetAlpha(),0,.19,function()
        Clear();Later(Pump)
    end)
end
local function Button(text,x,w,gold,fn)
    local b=CreateFrame("Button",nil,panel);Position(b,panel,x,142,w,27)
    b:RegisterForClicks("LeftButtonUp")
    local tx=b:CreateTexture(nil,"BACKGROUND");tx:SetAllPoints(b);tx:SetTexture(ART);SmoothTexture(tx)
    local function Paint()
        -- Derived from the existing HUD buttons; independent alpha padding
        -- eliminates the abrupt opaque rectangle around the gold face.
        local ax=gold and 320 or 8
        tx:SetTexCoord((ax+.5)/1024,(ax+279.5)/1024,448.5/512,503.5/512)
        local v=b.down and .74 or b.hover and 1 or .91;tx:SetVertexColor(v,v,v,1)
    end
    local label=S.Text(b,text,12,C.text);label:SetAllPoints(b);label:SetJustifyH("CENTER")
    if label.SetJustifyV then label:SetJustifyV("MIDDLE") end
    b:SetScript("OnEnter",function() b.hover=true;Paint() end)
    b:SetScript("OnLeave",function() b.hover=false;b.down=false;Paint() end)
    b:SetScript("OnMouseDown",function() b.down=true;Paint() end)
    b:SetScript("OnMouseUp",function() b.down=false;Paint() end)
    b:SetScript("OnClick",fn);Paint();return b
end
local updateAction=Button("What's new",62,147,false,function()
    if Blocked() or not current then return end
    -- Even preview opens only the real, fixed repository releases page.
    if not ns.Window.frame:IsShown() then ns.Window.Toggle() end
    if ns.Footer.ShowReleaseLink() then Dismiss(false) end
end)
local updateDismiss=Button("Got it",224,140,true,function() Dismiss(true) end)
local close=CreateFrame("Button",nil,panel);Position(close,panel,WIDTH-35,12,18,18)
local closeText=S.Text(close,"×",14,C.pale);closeText:SetAllPoints(close);closeText:SetJustifyH("CENTER")
close:SetScript("OnClick",function() Dismiss(false) end)
local function Visible(region,show) if show then region:Show() else region:Hide() end end
local rankClose=close:CreateTexture(nil,"BACKGROUND")
rankClose:SetAllPoints(close);rankClose:SetTexture("Interface\\AddOns\\DuelsReimagined\\Media\\Skin\\DuelHUDArt.png")
rankClose:SetTexCoord(372.25/512,395.75/512,205.25/512,228.75/512)
SmoothTexture(rankClose);rankClose:Hide()
local function Paint(m)
    local ranked=m.kind=="promotion"
    for _,region in ipairs({ornamentLeft,ornamentRight,emblem,category,heading,description,updateAction,updateDismiss,closeText}) do
        Visible(region,not ranked)
    end
    Visible(promotion,ranked);Visible(rankClose,ranked)
    if ranked then
        Position(close,panel,WIDTH-29,8,23,23)
        rankCategory:SetText(m.preview and "PREVIEW: Rank promotion" or "RANK PROMOTION")
        rankArt.Paint(m.newRank)
        newRank:SetText(m.newRank.label)
        local color=rankColors[m.newRank.name] or C.pale
        newRank:SetTextColor(unpack(color))
        rankHalo:SetVertexColor(color[1],color[2],color[3],1)
        transition:SetText(m.oldRank.label.." > "..m.newRank.label)
        ratingGain:SetText("+"..m.gain.." rating")
    else
        Position(close,panel,WIDTH-35,12,18,18)
        category:SetText(m.preview and "PREVIEW: Addon update" or "Addon update")
        heading:SetText(m.title)
        description:SetText(m.body)
    end
end
local function StartExpiry()
    if not current or current.kind~="promotion" or not C_Timer or not C_Timer.NewTimer then return end
    local seconds=expiryRemaining or (PROMOTION_SOUND_SECONDS and PROMOTION_SOUND_SECONDS+2 or PROMOTION_FALLBACK_SECONDS)
    local now=Plain(GetTime)
    expiryAt=type(now)=="number" and now+seconds or nil
    local m=current
    delayCount=delayCount+1
    expiryTimer=C_Timer.NewTimer(seconds,function()
        expiryTimer=nil;expiryAt=nil;expiryRemaining=nil;delayCount=delayCount-1
        if current==m and card:IsShown() then Dismiss(false) end
    end)
end
local function Celebrate()
    StopRankGlow()
    local key={};rankGlowKey=key
    M.Value(key,1,0,.95,function(_,v)
        if rankGlowKey~=key then return end
        rankHeaderGlow:SetAlpha(.72+.28*v)
        rankHalo:SetAlpha(.58+.42*v)
        if v==0 then rankGlowKey=nil end
    end)
end
local function ShowCurrent()
    if not current or card:IsShown() then return end
    Paint(current);offset=18;Place();card:SetAlpha(0);card:Show()
    if not current.preview then seen[current.id]=true end
    local isPromotion=current.kind=="promotion"
    local firstAppearance=not promotionCelebrated
    if isPromotion then promotionCelebrated=true end
    -- The shared entrance owns the glow until complete; celebration owns
    -- it only afterwards and never replays on a combat resume.
    Animate(0,1,.32,isPromotion and firstAppearance and Celebrate or nil);Play()
    if isPromotion then StartExpiry() end
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
            else CancelExpiry(true);StopRankGlow();StopAnimation();StopAudio();card:Hide() end
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
function N.PreviewPromotion()
    if not PREVIEW_ENABLED or not ready then return false,"Preview unavailable" end
    if Blocked() then return false,"Finish your duel or combat first" end
    if not Settings.Get("notificationEnabled") then return false,"Notifications are disabled" end
    if current or #queue>0 then return false,"Dismiss the current notification first" end
    -- Fictional values through the existing read-only rank policy. Never insert
    -- a ledger result, mutate rating, or expose a live promotion producer.
    local rules=ns.SeasonRules
    local previous=rules.Rank(2188,rules.PLACEMENT_CREDIT,rules.MIN_RIVALS)
    local nextRank=rules.Rank(2212,rules.PLACEMENT_CREDIT,rules.MIN_RIVALS)
    return Enqueue({id="preview:promotion",kind="promotion",preview=true,
        oldRank=previous,newRank=nextRank,gain=24})
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
