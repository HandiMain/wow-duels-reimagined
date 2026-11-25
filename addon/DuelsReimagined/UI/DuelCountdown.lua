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
local selectedStyle="impact"
local layoutDraft
local BASE_W,BASE_H=480,240
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
local function ApplyLayout()
    if not Settings.GetVisualLayout or not Settings.ClampVisualLayout then return end
    local x,y,scale
    if layoutDraft then x,y,scale=unpack(layoutDraft)
    else x,y,scale=Settings.GetVisualLayout("countdown") end
    local w,h=Read(UIParent.GetWidth,UIParent),Read(UIParent.GetHeight,UIParent)
    x,y,scale=Settings.ClampVisualLayout(x,y,scale,w,h,BASE_W,BASE_H)
    if not x then return end
    root:SetScale(scale);root:ClearAllPoints()
    root:SetPoint("CENTER",UIParent,"CENTER",(x-.5)*w/scale,(y-.5)*h/scale)
end
local function StopTimer()
    if timer then timer:Cancel();timer=nil end
end
local function Hide()
    Motion.Stop(animKey);root:Hide()
end
local function Clear()
    StopTimer();Hide()
    if ns.CountdownAudio then ns.CountdownAudio.Stop() end
    cycle,deadline,shown,preview=nil,nil,nil,nil
end
local function Live(s,id)
    return s and s.scope=="LOCAL" and s.state=="accepted" and s.active and
        s.active.id==id and (s.active.kind=="standard" or s.active.kind=="unclassified") and
        not s.active.finishSeen and not s.active.result
end
local function Font(value)
    local size=value=="FIGHT!" and 100 or 156
    -- These private display glyphs are not registered with Style/Theme.
    -- Resolve the player's explicit choice directly; never use the global
    -- theme or a provider's automatic font override (even as fallback).
    local key=Settings.Get("duelCountdownFont") or "builtin:Morpheus"
    local original="Fonts\\MORPHEUS.TTF"
    local path=ns.Fonts.Resolve(key) or original
    local function Apply(face,pt)
        for _,f in ipairs(layers) do
            local ok,result=pcall(f.SetFont,f,face,pt,"OUTLINE")
            if not ok or not result then return false end
        end
        return true
    end
    if not Apply(path,size) then
        path=original
        if not Apply(path,size) then path="Fonts\\FRIZQT__.TTF";Apply(path,size) end
    end
    for _,f in ipairs(layers) do f:SetText(value) end
    -- Preserve the approved Morpheus dimensions. Exceptionally wide
    -- alternate fonts fit within the original 440-unit lettering region.
    if path~=original then
        local width=Read(front.GetStringWidth,front)
        if type(width)=="number" and width>420 and width<math.huge then
            Apply(path,math.max(12,math.floor(size*420/width)))
        end
    end
end
local function Lerp(a,b,p) return a+(b-a)*math.max(0,math.min(1,p)) end
local function RenderGladiator(p,fight)
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
-- One palette/choreography catalogue, same stage clock and motion owner.
-- Original Gladiator remains the exact approved renderer.
local palettes={
    slash={.32,1,.66}, forge={1,.39,.09}, arcane={.69,.43,1},
    thunder={.24,.63,1}, cinematic={1,.65,.79}, shatter={.49,.94,1},
    pulse={1,.22,.26}, minimal={.98,.98,.98},
}
local function MoveGlyph(x,y,scale,alpha)
    glyph:ClearAllPoints();glyph:SetPoint("CENTER",root,"CENTER",x,y)
    glyph:SetScale(scale);glyph:SetAlpha(alpha)
end
local function ResetLayers(style)
    MoveGlyph(0,0,1,1)
    local color=palettes[style]
    for i,f in ipairs(layers) do
        f:ClearAllPoints();f:SetPoint("CENTER",glyph,"CENTER",0,-(5-i)*1.8)
        if color then
            local tone=({.18,.32,.48,.72,1})[i]
            f:SetTextColor(color[1]*tone,color[2]*tone,color[3]*tone)
        else f:SetTextColor(unpack(gold[i])) end
        f:SetAlpha(style=="minimal" and i<5 and 0 or 1)
    end
    if color then
        front:SetShadowColor(color[1]*.2,color[2]*.2,color[3]*.2,1)
        glow:SetVertexColor(color[1],color[2],color[3],1)
        ring:SetVertexColor(color[1],color[2],color[3],1)
    else
        front:SetShadowColor(.27,.095,.015,1)
        glow:SetVertexColor(1,.44,.12,1);ring:SetVertexColor(1,.69,.27,1)
    end
    glow:ClearAllPoints();glow:SetPoint("CENTER",root,"CENTER")
    ring:ClearAllPoints();ring:SetPoint("CENTER",root,"CENTER")
    for _,t in ipairs(sparks) do
        if color then t:SetColorTexture(color[1],color[2],color[3],1)
        else t:SetColorTexture(1,.72,.32,1) end
        t:SetSize(3,3);t:SetAlpha(0)
    end
    glow:SetAlpha(0);ring:SetAlpha(0)
end
local function Spark(t,x,y,w,h,alpha)
    t:ClearAllPoints();t:SetPoint("CENTER",root,"CENTER",x,y)
    t:SetSize(w,h);t:SetAlpha(math.max(0,math.min(1,alpha)))
end
local function Ring(p,size,alpha)
    ring:SetSize(size,size);ring:SetAlpha(math.max(0,alpha))
end
local function Flare(w,h,alpha)
    glow:SetSize(w,h);glow:SetAlpha(math.max(0,alpha))
end
local function Ease(p) p=math.max(0,math.min(1,p));return 1-(1-p)^3 end
local function Envelope(p,entry,exit)
    return p<entry and Ease(p/entry) or p>exit and 1-(p-exit)/(1-exit) or 1
end
local function RenderPreset(p,fight,value)
    local style=selectedStyle
    if style=="impact" or not palettes[style] then RenderGladiator(p,fight);return end
    local a=Envelope(p,.20,.75)
    local q=math.min(1,p/.7)
    local x,y,scale=0,0,1
    local strength=fight and 1.25 or 1
    if style=="slash" then
        local dir=(value=="3" or value=="1") and 1 or -1
        x=p<.22 and Lerp(dir*270,0,Ease(p/.22)) or p>.75 and Lerp(0,-dir*230,(p-.75)/.25) or 0
        scale=p<.22 and Lerp(1.12,1,Ease(p/.22)) or 1
        Flare(410,34,math.max(0,1-p/.32)*.84)
        for i,t in ipairs(sparks) do
            Spark(t,dir*(Lerp(25,210,q)-i*13),(i%4-1.5)*11,18,2,(1-q)*.8)
        end
    elseif style=="forge" then
        scale=p<.32 and Lerp(.58,1.03,Ease(p/.32)) or Lerp(1.03,1.14,math.max(0,(p-.76)/.24))
        y=Lerp(-19,6,Ease(p/.34))
        Flare(270,210,(1-q)*.72)
        for i,t in ipairs(sparks) do
            local drift=math.sin(i*2.7)*Lerp(20,125,q)
            Spark(t,drift,Lerp(-65,122,q)+(i%4)*11,3+(i%3),6,(1-q)*.93)
        end
    elseif style=="arcane" then
        scale=p<.3 and Lerp(.12,1.08,Ease(p/.3)) or p>.72 and Lerp(1,.12,(p-.72)/.28) or Lerp(1.08,1,(p-.3)/.14)
        Ring(p,Lerp(55,240,q)*strength,(1-q)*.82)
        Flare(220,220,(1-q)*.42)
        local radius=Lerp(24,134,q)*strength
        for i,t in ipairs(sparks) do
            local angle=i*math.pi/6+p*math.pi*2
            Spark(t,math.cos(angle)*radius,math.sin(angle)*radius,4,4,(1-q)*.92)
        end
    elseif style=="thunder" then
        y=p<.17 and Lerp(210,-12,Ease(p/.17)) or p<.26 and Lerp(-12,6,(p-.17)/.09) or p<.38 and Lerp(6,0,(p-.26)/.12) or 0
        scale=p<.17 and Lerp(1.3,.95,Ease(p/.17)) or p<.3 and Lerp(.95,1,(p-.17)/.13) or 1
        Ring(p,Lerp(35,310,q)*strength,math.max(0,1-p/.5)*.85)
        Flare(145,370,math.max(0,1-p/.27)*.75)
        for i,t in ipairs(sparks) do
            Spark(t,math.cos(i*2.4)*Lerp(20,145,q),math.sin(i*2.4)*Lerp(15,95,q),2,14,(1-q)*.87)
        end
    elseif style=="cinematic" then
        scale=Lerp(.78,1.22,p)
        a=Envelope(p,.28,.7)
        Flare(290,180,math.sin(p*math.pi)*.18)
    elseif style=="shatter" then
        scale=p<.25 and Lerp(1.28,1,Ease(p/.25)) or p>.74 and Lerp(1,1.24,(p-.74)/.26) or 1
        local disperse=p<.22 and 1-Ease(p/.22) or p>.73 and (p-.73)/.27 or 0
        -- Four embossed text layers converge/separate; shards are independent
        -- reusable regions, not a claim of true per-pixel glyph destruction.
        for i,f in ipairs(layers) do
            local angle=(i-1)*math.pi/2
            local spread=i==5 and 0 or 31*disperse
            f:ClearAllPoints();f:SetPoint("CENTER",glyph,"CENTER",math.cos(angle)*spread,-(5-i)*1.8+math.sin(angle)*spread)
        end
        Ring(p,Lerp(60,245,q),.38*(1-q))
        for i,t in ipairs(sparks) do
            local angle=i*math.pi/6
            local dist=disperse*(fight and 185 or 145)
            Spark(t,math.cos(angle)*dist,math.sin(angle)*dist,5+(i%3)*3,8+(i%4)*3,disperse*.95)
        end
    elseif style=="pulse" then
        local beat=math.max(0,1-math.abs(p-.17)/.15)+math.max(0,1-math.abs(p-.43)/.14)
        scale=1+.23*beat*strength
        a=Envelope(p,.1,.76)
        local wave=p<.3 and p/.3 or math.min(1,(p-.3)/.36)
        Ring(p,Lerp(62,220,wave)*strength,math.max(0,1-wave)*.7)
        Flare(300,220,.58*beat)
    elseif style=="minimal" then
        scale=Lerp(.96,1,Ease(p/.13));a=Envelope(p,.13,.84)
    end
    MoveGlyph(x,y,scale,a)
end
local function ShowStage(value,seconds)
    Hide();ApplyLayout();Font(value);ResetLayers(selectedStyle);previewLabel:SetShown(preview==true and not layoutDraft)
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
    RenderPreset(0,fight,value)
    -- Shared driver only. Wall clock gives stage-local keyframes even
    -- though the common numeric tween uses smooth easing.
    Motion.Value(animKey,0,1,span,function(_,v)
        local now=Now()
        local p=v==1 and 1 or start and now and math.max(0,math.min(1,(now-start)/span)) or v
        RenderPreset(p,fight,value)
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
        if shown=="FIGHT!" then
            local editing=preview and layoutDraft
            Clear()
            if editing and ns.EditMode and ns.EditMode.IsActive() then ns.EditMode.RestoreSample() end
            return
        end
        -- Don't play an old fight cue after a long frame stall or reload.
        if remaining<-.5 then Clear();return end
        if ns.CountdownAudio then ns.CountdownAudio.Stop() end
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
        if ns.CountdownAudio then ns.CountdownAudio.Play(stage) end
    end
    Arm(nextIn)
end
local function Receive(s)
    if s.scope~="LOCAL" then return end
    if layoutDraft and (s.challenge or s.active or s.state~="idle") and ns.EditMode then
        ns.EditMode.Cancel(false)
    end
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
    if cycle~=s.active.id then Clear();cycle=s.active.id;deadline=candidate;selectedStyle=Settings.Get("duelCountdownStyle") or "impact"
    elseif not deadline or candidate<deadline then deadline=candidate end
    if shown~="FIGHT!" then Tick() end
end
-- Layout editing uses the real renderer and a private temporary position.
function V.LayoutSize() return BASE_W,BASE_H end
function V.SetLayoutDraft(x,y,scale)
    layoutDraft={x,y,scale};ApplyLayout()
end
function V.ShowLayoutSample()
    if not layoutDraft then return end
    Clear();ApplyLayout()
    selectedStyle=Settings.Get("duelCountdownStyle") or "impact"
    Font("3");ResetLayers(selectedStyle)
    previewLabel:Hide()
    for _,t in ipairs(sparks) do t:Hide() end
    root:Show()
end
function V.EndLayoutDraft()
    if not layoutDraft then return end
    Clear();layoutDraft=nil;ApplyLayout()
end
function V.Refresh()
    -- Do not replay a stage mid-duel when changing a setting.
    Clear()
    if layoutDraft then V.ShowLayoutSample() end
end
function V.Preview()
    if not ready or not ns.Client.IsSupported() or not C_Timer or type(C_Timer.NewTimer)~="function" then return false,"Preview unavailable" end
    local s=ns.DuelDetection.GetSnapshot()
    if Read(InCombatLockdown)~=false or s.state~="idle" or s.active or s.challenge then return false,"Finish combat or your duel first" end
    local now=Now();if not now then return false,"Preview unavailable" end
    Clear();preview=true;deadline=now+3;selectedStyle=Settings.Get("duelCountdownStyle") or "impact";Tick()
    return true
end
function V.GetDiagnosticResources()
    return {subscriptions=unsubscribe and 1 or 0,timers=timer and 1 or 0}
end
local events=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD","PLAYER_REGEN_DISABLED","UI_SCALE_CHANGED","DISPLAY_SIZE_CHANGED"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent",function(_,event)
    if event=="PLAYER_LOGIN" then
        events:UnregisterEvent("PLAYER_LOGIN")
        ready=ns.Client.IsSupported()
        if ready then unsubscribe=ns.DuelDetection.Subscribe(Receive);ApplyLayout() end
    elseif event=="UI_SCALE_CHANGED" or event=="DISPLAY_SIZE_CHANGED" then ApplyLayout()
    elseif event=="PLAYER_ENTERING_WORLD" or event=="PLAYER_REGEN_DISABLED" and preview then Clear() end
end)
