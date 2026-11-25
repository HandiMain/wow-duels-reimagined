local _,ns=...
-- Passive screen overlay. The detector remains the sole owner of duel state.
local Settings,Motion=ns.Settings,ns.Motion
local V={};ns.DuelCountdown=V
local root=CreateFrame("Frame","DuelsReimaginedCountdown",UIParent)
root:SetSize(480,240);root:SetPoint("CENTER",UIParent,"CENTER",0,0)
root:SetFrameStrata("FULLSCREEN_DIALOG");root:EnableMouse(false);root:Hide()
if ns.DiagnosticAudit then ns.DiagnosticAudit.RegisterUIRoot("Duel countdown",root) end
local art="Interface\\AddOns\\DuelsReimagined\\Media\\Skin\\DuelCountdownEffects.tga"
local function Effect(left,right,r,g,b)
    local t=root:CreateTexture(nil,"ARTWORK")
    t:SetTexture(art);t:SetTexCoord(left,right,0,1)
    t:SetPoint("CENTER",root,"CENTER");t:SetVertexColor(r,g,b,1)
    t:SetBlendMode("ADD");return t
end
local glow=Effect(.5,1,1,.44,.12)
local ring=Effect(0,.5,1,.69,.27)
local sparks={}
for i=1,12 do
    local t=root:CreateTexture(nil,"OVERLAY")
    t:SetColorTexture(1,.72,.32,1);t:SetBlendMode("ADD")
    t:SetSize(3,3);t:Hide();sparks[i]=t
end
local glyph=CreateFrame("Frame",nil,root)
glyph:SetSize(440,200);glyph:SetPoint("CENTER",root,"CENTER");glyph:EnableMouse(false)
-- Display artwork uses Blizzard's fantasy font; Options controls remain
-- configurable. Layered real glyphs, not a flattened movie or text image.
local layers={}
local gold={{.19,.075,.025},{.33,.14,.045},{.53,.25,.075},{.76,.42,.16},{1,.81,.45}}
for i=1,5 do
    local f=glyph:CreateFontString(nil,"OVERLAY",nil,i)
    f:SetPoint("CENTER",glyph,"CENTER",0,-(5-i)*1.8)
    f:SetJustifyH("CENTER");f:SetJustifyV("MIDDLE")
    f:SetTextColor(unpack(gold[i]))
    layers[i]=f
end
local front=layers[5]
front:SetShadowColor(.27,.095,.015,1);front:SetShadowOffset(1,-2)
local previewLabel=root:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
previewLabel:SetPoint("TOP",root,"BOTTOM",0,12)
previewLabel:SetText("COUNTDOWN PREVIEW");previewLabel:Hide()
local animKey={}
local timer,cycle,deadline,shown,preview,ready,unsubscribe
local function Read(fn,...)
    if type(fn)~="function" then return nil end
    local ok,v=pcall(fn,...)
    if not ok then return nil end
    if type(issecretvalue)=="function" then
        local good,secret=pcall(issecretvalue,v)
        if not good or secret then return nil end
    end
    return v
end
local function Now()
    local n=Read(GetTime)
    return type(n)=="number" and n>=0 and n<math.huge and n or nil
end
local function StopTimer()
    if timer then timer:Cancel();timer=nil end
end
local function Hide()
    Motion.Stop(animKey);root:Hide()
end
local function Clear()
    StopTimer();Hide()
    cycle,deadline,shown,preview=nil,nil,nil,nil
end
local function Live(s,id)
    return s and s.scope=="LOCAL" and s.state=="accepted" and s.active and
        s.active.id==id and (s.active.kind=="standard" or s.active.kind=="unclassified") and
        not s.active.finishSeen and not s.active.result
end
local function Font(value)
    local size=value=="FIGHT!" and 100 or 156
    for _,f in ipairs(layers) do
        if not f:SetFont("Fonts\\MORPHEUS.TTF",size,"OUTLINE") then
            f:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",size,"OUTLINE")
        end
        f:SetText(value)
    end
end
local function Lerp(a,b,p) return a+(b-a)*math.max(0,math.min(1,p)) end
local function Render(p,fight)
    local scale,alpha
    if p<.19 then
        scale=Lerp(1.9,.89,p/.19);alpha=Lerp(0,1,p/.14)
    elseif p<.29 then scale=Lerp(.89,1.06,(p-.19)/.10);alpha=1
    elseif p<.38 then scale=Lerp(1.06,1,(p-.29)/.09);alpha=1
    elseif p<.74 then scale=1;alpha=1
    else scale=Lerp(1,1.13,(p-.74)/.26);alpha=Lerp(1,0,(p-.74)/.26) end
    glyph:SetScale(scale);glyph:SetAlpha(alpha)
    local shock=math.min(1,p/.65)
    local diameter=Lerp(55,fight and 365 or 285,shock)
    ring:SetSize(diameter,diameter);ring:SetAlpha((1-shock)*.74)
    local flare=math.max(0,1-p/.38)
    glow:SetSize(fight and 440 or 320,fight and 240 or 210)
    glow:SetAlpha(flare*(fight and .69 or .48))
    for i,t in ipairs(sparks) do
        local q=math.max(0,math.min(1,(p-.1)/.65))
        local angle=(i-1)*math.pi*2/#sparks+.27
        local distance=Lerp(34,fight and 172 or 118,q)
        t:ClearAllPoints();t:SetPoint("CENTER",root,"CENTER",math.cos(angle)*distance,math.sin(angle)*distance)
        t:SetAlpha(p<.1 and 0 or (1-q)*.8)
    end
end
local function ShowStage(value,seconds)
    Hide();Font(value);previewLabel:SetShown(preview==true)
    root:Show()
    if Settings.Get("reduceMotion") then
        glyph:SetScale(1);glyph:SetAlpha(1);glow:SetAlpha(0);ring:SetAlpha(0)
        for _,t in ipairs(sparks) do t:Hide() end
        return
    end
    for _,t in ipairs(sparks) do t:Show() end
    local fight=value=="FIGHT!"
    local span=math.max(.06,seconds)
    local start=Now()
    Render(0,fight)
    -- Shared driver only. Wall clock gives stage-local keyframes even
    -- though the common numeric tween uses smooth easing.
    Motion.Value(animKey,0,1,span,function(_,v)
        local now=Now()
        local p=v==1 and 1 or start and now and math.max(0,math.min(1,(now-start)/span)) or v
        Render(p,fight)
        if v==1 then root:Hide() end
    end)
end
local Tick
local function Arm(delay)
    StopTimer()
    if not C_Timer or type(C_Timer.NewTimer)~="function" then Clear();return end
    timer=C_Timer.NewTimer(math.max(.02,delay),function() timer=nil;Tick() end)
end
Tick=function()
    local now=Now()
    if not now or not deadline then Clear();return end
    if not preview and (not Settings.Get("duelCountdownVisual") or not Live(ns.DuelDetection.GetSnapshot(),cycle)) then Clear();return end
    if preview and Read(InCombatLockdown)==true then Clear();return end
    local remaining=deadline-now
    if remaining<=.012 then
        if shown=="FIGHT!" then Clear();return end
        -- Don't play an old fight cue after a long frame stall or reload.
        if remaining<-.5 then Clear();return end
        shown="FIGHT!";ShowStage(shown,.90);Arm(.94)
        return
    end
    local stage=math.ceil(remaining-.012)
    if stage>3 then Hide();Arm(remaining-3);return end
    stage=math.max(1,stage)
    local nextIn=math.max(.02,remaining-(stage-1))
    if shown~=stage then
        shown=stage
        ShowStage(tostring(stage),math.min(.95,nextIn))
    end
    Arm(nextIn)
end
local function Receive(s)
    if s.scope~="LOCAL" then return end
    if preview and (s.challenge or s.active or s.state~="idle") then Clear() end
    if cycle and not Live(s,cycle) then Clear() end
    if not Settings.Get("duelCountdownVisual") or not s.active or not Live(s,s.active.id)
        or s.reason~="countdown_observed" then return end
    local count=s.active.countdown
    local event=s.trace and s.trace[#s.trace]
    local now=Now()
    if type(count)~="number" or count<0 or count>10 or count~=math.floor(count)
        or not event or event.cycle~=s.active.id or event.reason~="countdown_observed"
        or type(event.time)~="number" or not now or now-event.time>1 or event.time>now+.1 then return end
    local candidate=event.time+count
    if cycle~=s.active.id then Clear();cycle=s.active.id;deadline=candidate
    elseif not deadline or candidate<deadline then deadline=candidate end
    if shown~="FIGHT!" then Tick() end
end
function V.Refresh()
    -- Do not replay a stage mid-duel when changing a setting.
    Clear()
end
function V.Preview()
    if not ready or not ns.Client.IsSupported() or not C_Timer or type(C_Timer.NewTimer)~="function" then return false,"Preview unavailable" end
    local s=ns.DuelDetection.GetSnapshot()
    if Read(InCombatLockdown)~=false or s.state~="idle" or s.active or s.challenge then return false,"Finish combat or your duel first" end
    local now=Now();if not now then return false,"Preview unavailable" end
    Clear();preview=true;deadline=now+3;Tick()
    return true
end
function V.GetDiagnosticResources()
    return {subscriptions=unsubscribe and 1 or 0,timers=timer and 1 or 0}
end
local events=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD","PLAYER_REGEN_DISABLED"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent",function(_,event)
    if event=="PLAYER_LOGIN" then
        events:UnregisterEvent("PLAYER_LOGIN")
        ready=ns.Client.IsSupported()
        if ready then unsubscribe=ns.DuelDetection.Subscribe(Receive) end
    elseif event=="PLAYER_ENTERING_WORLD" or event=="PLAYER_REGEN_DISABLED" and preview then Clear() end
end)
