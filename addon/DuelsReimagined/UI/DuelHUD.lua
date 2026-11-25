local _,ns=...
-- Read-only duel companion; never owns results, ranking, or peer transport.
local S,C,Settings=ns.Style,ns.Style.color,ns.Settings
local H={};ns.DuelHUD=H
local WIDTH,HEIGHT,FOLDED_HEIGHT=336,310,42
local folded=false
local tournamentActive,tournamentSuspended,switchingAnchor=false,false,false
local tournamentUnsubscribe,tournamentRetry,previewUnsubscribe
local tournamentKey
local HEIGHTS={idle=84,selected=248,pending=220,incoming=188,active=232,result=136}
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
local PREMIUM="Interface\\AddOns\\DuelsReimagined\\Media\\Skin\\DuelHUDPremiumParts.png"
local HEALTH_FILL="Interface\\AddOns\\DuelsReimagined\\Media\\Skin\\DuelHUDHealthFill.png"
local HEALTH_MASK="Interface\\AddOns\\DuelsReimagined\\Media\\Skin\\DuelHUDHealthMask.png"
-- Each cell contains ONE piece, not a flattened window. Chrome, content
-- and interactive controls have independent anchors and lifetimes.
local premiumArt={
    topLeft={2,2,70,74},topRight={76,2,70,74},
    bottomLeft={150,2,85,69},bottomRight={239,2,85,69},
    topEdge={330,2,160,17},sideEdge={2,82,20,320},bottomEdge={330,23,160,26},
    gem={496,2,130,57},headerFace={330,54,320,46},bodyFill={430,292,32,160},
    timerFace={26,82,142,76},timerBlade={172,82,103,32},statRow={26,163,619,56},
    normal={26,224,280,64},selected={310,224,280,64},red={594,224,280,64},
    healthTrack={26,292,284,38}}
local art={swords={410,0,30,30},
    playerRing={342,238,48,48},enemyRing={396,238,48,48}}
local function Place(f,x,y,w,h)
    f:ClearAllPoints();f:SetPoint("TOPLEFT",f:GetParent(),"TOPLEFT",x,-y);f:SetSize(w,h)
end
local function Region(t,key,flip)
    local premium=premiumArt[key]
    local a=premium or assert(art[key]);local atlasWidth=premium and 1024 or 512
    t:SetTexture(premium and PREMIUM or ATLAS)
    if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(false) end
    if t.SetTexelSnappingBias then t:SetTexelSnappingBias(0) end
    local left,right=(a[1]+.5)/atlasWidth,(a[1]+a[3]-.5)/atlasWidth
    t:SetTexCoord(flip and right or left,flip and left or right,(a[2]+.5)/512,(a[2]+a[4]-.5)/512)
end
local function Artwork(key,x,y,w,h,layer,flip)
    local t=surface:CreateTexture(nil,layer or "ARTWORK");Region(t,key,flip);Place(t,x,y,w,h);return t
end
-- Expanded body: independent plain material, left/right rails, bottom rail,
-- four corner pieces (upper pair on headerLayer) and lower jewel.
local fill=Artwork("bodyFill",8,29,WIDTH-16,273,"BACKGROUND")
local leftRail=Artwork("sideEdge",1,25,10,266,"BORDER")
local rightRail=Artwork("sideEdge",WIDTH-11,25,10,266,"BORDER",true)
local bottomRail=Artwork("bottomEdge",25,297,WIDTH-50,12,"BORDER")
local bottomLeft=Artwork("bottomLeft",0,278,38,31,"ARTWORK")
local bottomRight=Artwork("bottomRight",WIDTH-38,278,38,31,"ARTWORK")
local gem=Artwork("gem",WIDTH/2-20,294,40,16,"OVERLAY")
local content=CreateFrame("Frame",nil,body)
content:SetPoint("TOPLEFT",body,"TOPLEFT");content:SetSize(WIDTH,HEIGHT)
local timerGroup=CreateFrame("Frame",nil,content)
timerGroup:SetPoint("TOPLEFT",content,"TOPLEFT");timerGroup:SetSize(WIDTH,HEIGHT)
surface=timerGroup
Artwork("timerFace",121,93,94,36)
Artwork("timerBlade",69,101,48,15)
Artwork("timerBlade",219,101,48,15,nil,true)
local participants=CreateFrame("Frame",nil,content)
participants:SetPoint("TOPLEFT",content,"TOPLEFT");participants:SetSize(WIDTH,HEIGHT)
surface=participants
Artwork("swords",156,137,24,24)
surface=content
local function Rect(x,y,w,h,r,g,b,a)
    local t=surface:CreateTexture(nil,"BORDER")
    t:SetColorTexture(r,g,b,a or 1);Place(t,x,y,w,h);return t
end
-- Only the standalone mode separator is drawn here.
local modeDivider=Rect(14,74,308,1,.19,.15,.10,.85)
local function Label(value,size,color,x,y,w,h,align)
    local f=S.Text(surface,value,size,color or C.text)
    f:SetJustifyH(align or "CENTER");f:SetWordWrap(false);Place(f,x,y,w,h)
    S.ConstrainText(f,w,h,8);return f
end
local function Action(value,x,y,w,h,fn,red)
    local b=CreateFrame("Button",nil,surface);Place(b,x,y,w,h)
    b:RegisterForClicks("LeftButtonUp")
    local t=b:CreateTexture(nil,"BACKGROUND");t:SetAllPoints(b)
    local label=S.Text(b,value,12,C.text);label:SetAllPoints(b);label:SetJustifyH("CENTER");label:SetWordWrap(false)
    S.ConstrainText(label,w-8,h-4,8)
    b.label=label;b.selected=false;b.usable=true
    -- No alpha animation on the whole widget: the source art stays opaque.
    b.Paint=function()
        Region(t,b.selected and "selected" or not b.usable and "normal" or red and "red" or "normal")
        local v=not b.usable and not b.selected and .88 or b.pressed and .78 or b.hovered and b.usable and 1 or .98
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
-- Folded mode has its own continuous copper nine-slice, shared with the
-- main window. The expanded top corners are hidden, not cut in half.
surface=root
local foldedTrim=CreateFrame("Frame",nil,root)
Place(foldedTrim,0,0,WIDTH,FOLDED_HEIGHT)
foldedTrim:EnableMouse(false)
surface=foldedTrim
-- Opaque backing and uninterrupted burgundy face fill the entire copper rim.
-- Both belong to the folded frame, below its nine-slice, not to the title.
local foldedBacking=foldedTrim:CreateTexture(nil,"BACKGROUND")
foldedBacking:SetColorTexture(.10,.018,.010,1)
Place(foldedBacking,3,3,WIDTH-6,FOLDED_HEIGHT-6)
local foldedFace=Artwork("headerFace",3,3,WIDTH-6,FOLDED_HEIGHT-6,"ARTWORK")
foldedFace:SetDrawLayer("BACKGROUND",1)
S.Plate(foldedTrim,"shellCopper",{corner=12,layer="ARTWORK",sublevel=1})
foldedTrim:Hide()
surface=headerLayer
local expandedFace=Artwork("headerFace",8,6,WIDTH-16,28,"BACKGROUND")
local expandedTop={
    Artwork("topEdge",25,1,WIDTH-50,8,"BORDER"),
    Artwork("topLeft",0,0,28,30,"ARTWORK"),
    Artwork("topRight",WIDTH-28,0,28,30,"ARTWORK"),
}
local header=CreateFrame("Frame",nil,headerLayer)
Place(header,0,0,230,35);header:EnableMouse(true);header:RegisterForDrag("LeftButton")
-- Exact main-window silver/gold crossed swords, sampled independently.
local brand=headerLayer:CreateTexture(nil,"OVERLAY")
brand:SetTexture("Interface\\AddOns\\DuelsReimagined\\Media\\Skin\\DuelBrand.png")
brand:SetTexCoord(10/512,77/512,22/128,91/128)
ns.Chrome.Sharp(brand)
Place(brand,29,2,31,32)
local headerTitle=Label("Duels Reimagined",16,C.pale,64,4,163,26,"LEFT")
local function OpenOptions()
    if Combat() then return end
    if not ns.Window.frame:IsShown() then ns.Window.Toggle() end
    ns.Navigation.SelectKey("options","widget")
end
local gear=ns.Header.CreateHUDButton(headerLayer,"Options",22)
Place(gear,234,6,22,22)
gear:SetScript("OnClick",OpenOptions)
local foldButton=ns.Header.CreateHUDButton(headerLayer,"FoldUp",22)
Place(foldButton,258,6,22,22)
local close=ns.Header.CreateHUDButton(headerLayer,"Close",22)
Place(close,282,6,22,22)
close:SetScript("OnClick",function()Settings.Set("duelHUDEnabled",false)end)
local function PaintFold()
    local dy=folded and 4 or 0
    Place(brand,29,2+dy,31,32)
    Place(headerTitle,64,4+dy,163,26)
    Place(gear,234,6+dy,22,22)
    Place(foldButton,258,6+dy,22,22)
    Place(close,282,6+dy,22,22)
    Place(header,0,0,230,folded and FOLDED_HEIGHT or 35)
    expandedFace:SetShown(not folded)
    foldButton:SetGlyph(folded and "FoldDown" or "FoldUp")
    ns.Motion.Fade(foldButton.chosen,folded and .42 or 0,ns.Motion.Duration("quick"))
    for _,part in ipairs(expandedTop) do part:SetShown(not folded) end
end
PaintFold()
foldButton:SetScript("OnClick",function()H.Fold(not folded)end)
if ns.Tooltips then
    ns.Tooltips.Bind(gear,{title="Duel HUD options",detail="Open Widget settings."})
    ns.Tooltips.Bind(close,{title="Hide Duel HUD",detail="Also hides notifications. Show it again in Options or with /duels hud."})
    ns.Tooltips.Bind(foldButton,{title="Fold / unfold Duel HUD",detail="Collapse to the header while keeping notifications available."})
end
surface=content
local modeRank,modePractice
local snap,shownResult,activeID,acceptedAt,countdownUntil
local selectedTargetGuid
local ready,preview,dragging,rankDirty=false,false,false,true
local rankView,rankSeason
local function Mode(practice)
    if preview or Combat() or not snap or snap.state~="idle" then return end
    local target=Identity("target")
    if not target or target.guid~=selectedTargetGuid then return end
    if not practice then
        local _,_,selectable=ns.CompetitiveLifecycle.RankedAvailability(target and target.guid)
        if not selectable then return end
    end
    Settings.Set("practiceDuels",practice)
end
modeRank=Action("Ranked",38,40,124,30,function() Mode(false) end)
modePractice=Action("Unranked",174,40,124,30,function() Mode(true) end)
local state=Label("Select a player to duel",13,C.pale,10,77,WIDTH-20,18)
surface=timerGroup
local timer=Label("00:00",20,C.text,121,96,94,27)
surface=participants
local function Side(x,enemy)
    local side={}
    local ix=enemy and x+104 or x+2
    local tx=enemy and x or x+42
    local align=enemy and "RIGHT" or "LEFT"
    side.icon=participants:CreateTexture(nil,"ARTWORK")
    Place(side.icon,ix,126,36,36)
    if participants.CreateMaskTexture and side.icon.AddMaskTexture then
        pcall(function()
            local mask=participants:CreateMaskTexture()
            mask:SetTexture("Interface\\AddOns\\DuelsReimagined\\Media\\Skin\\DuelHUDPortraitMask.png","CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE")
            mask:SetAllPoints(side.icon);side.icon:AddMaskTexture(mask)
            side.mask=mask
        end)
    end
    Artwork(enemy and "enemyRing" or "playerRing",ix-4,122,44,44,"OVERLAY")
    side.name=Label("",13,C.pale,tx,127,100,20,align)
    side.rating=Label("",11,C.pale,tx,148,100,15,align)
    side.badge=ns.CompetitiveUI.CreateRankEmblem(participants,19,false)
    Place(side.badge,enemy and x+123 or x+2,163,19,19)
    side.rank=Label("Rank unknown",11,C.text,enemy and x or x+23,163,119,18,align)
    -- Pill-shaped track and alpha-shaped fill, driven by Blizzard's native
    -- StatusBar. Do not size textures from restricted health values.
    Artwork("healthTrack",x,181,142,19)
    side.hp=CreateFrame("StatusBar",nil,participants);Place(side.hp,x+3,184,136,13)
    side.hp:SetStatusBarTexture(HEALTH_FILL)
    side.hp:SetStatusBarColor(1,1,1);side.hp:SetMinMaxValues(0,1);side.hp:SetValue(0)
    -- The static mask clips the whole native fill to the rounded track.
    -- Alpha-shaped fill still renders when a client lacks mask support.
    if participants.CreateMaskTexture and side.hp.GetStatusBarTexture then
        pcall(function()
            local tex=side.hp:GetStatusBarTexture()
            if not tex or not tex.AddMaskTexture then return end
            local mask=participants:CreateMaskTexture()
            mask:SetTexture(HEALTH_MASK,"CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE")
            mask:SetAllPoints(side.hp);tex:AddMaskTexture(mask)
            side.healthMask=mask
        end)
    end
    local overlay=CreateFrame("Frame",nil,participants)
    overlay:SetFrameLevel(side.hp:GetFrameLevel()+1);Place(overlay,x,181,142,19)
    side.hpText=S.Text(overlay,"",11,{1,1,1,1});side.hpText:SetAllPoints(overlay);side.hpText:SetJustifyH("CENTER")
    if side.hpText.SetJustifyV then side.hpText:SetJustifyV("MIDDLE") end
    -- Health text may be client-restricted. It stays in the shared font
    -- registry but is never measured or fitted on text change.
    local click=CreateFrame("Button",nil,participants);Place(click,x,163,142,19)
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
surface=content
-- Damage is not available per duel on the supported clients. No empty rows.
local note=Label("",10,C.muted,16,251,WIDTH-32,15)
-- Match the existing Addon Status panel's confirmed/checking/unknown tones.
-- This is presentation only: eligibility remains CompetitiveLifecycle's.
local recognitionColors={confirmed={.46,.85,.44},checking={.96,.71,.25},
    unknown={.62,.64,.68},incompatible={1,.43,.38}}
local function OpponentStatus(guid,canRank,why,unranked)
    local d=ns.OpponentDiscovery.GetSnapshot()
    if not guid or not d or not d.opponent or d.opponent.guid~=guid then
        return "Opponent not checked",recognitionColors.unknown
    end
    if d.state=="checking" then return "Checking opponent...",recognitionColors.checking end
    if d.state=="incompatible" then return "Incompatible addon version",recognitionColors.incompatible end
    if d.state=="unknown" then
        if d.reason=="no_reply" then return "Addon not detected (no reply)",recognitionColors.unknown end
        if d.reason=="confirmation_expired" then return "Addon confirmation expired",recognitionColors.unknown end
        return "Addon check unavailable",recognitionColors.unknown
    end
    if d.state~="compatible" then return "Opponent not checked",recognitionColors.unknown end
    if canRank then
        return unranked and "Ranked available - Unranked selected" or "Ranked available",recognitionColors.confirmed
    end
    if why=="Opponent prefers Unranked" then
        return "Addon detected - Opponent prefers Unranked",recognitionColors.checking
    end
    if why=="Ranked compatibility not confirmed" then
        if type(d.rankOffer)=="string" then
            return "Incompatible ranked rules",recognitionColors.incompatible
        end
        return "Addon detected - Ranked unconfirmed",recognitionColors.checking
    end
    -- A successful discovery does not override consent, storage, season,
    -- communication, or other local ranked gates.
    return "Addon detected - "..(why or "Ranked unavailable"),recognitionColors.checking
end
local rankHelp="Select another player to check ranked availability."
if ns.Tooltips then
    ns.Tooltips.Bind(modeRank,{title="Ranked duels",outsideWindow=true,
        detail=function() return rankHelp end})
end
local challenge,forfeit
local lastRequest
local function Native(fn,unit)
    note:SetTextColor(unpack(C.muted))
    if type(fn)~="function" then note:SetText("Native action unavailable.");return false end
    local ok,result
    if unit then ok,result=pcall(fn,unit) else ok,result=pcall(fn) end
    if not ok or Secret(result) or result==false then
        note:SetText("Blizzard action unavailable; use native controls.");return false
    end
    note:SetText("Request sent to Blizzard; awaiting observation.");return true
end
challenge=Action("Challenge Target",38,268,124,25,function()
    if preview or ns.CompetitivePreview.IsActive() or Combat() or not snap or snap.state~="idle" then return end
    local id=Identity("target");local self=Identity("player")
    local now=Now()
    if not id or not self or id.guid==self.guid or id.guid~=selectedTargetGuid or not now or (lastRequest and now-lastRequest<5) then return end
    -- Do not silently downgrade an already displayed Ranked selection, or
    -- upgrade the displayed Unranked fallback when a reply just arrived.
    local ranked=modeRank.selected==true and modeRank.usable==true
    if ranked and (Settings.Get("practiceDuels") or not ns.CompetitiveLifecycle.RankedAvailability(id.guid)) then
        H.Refresh();return
    end
    lastRequest=now
    local ok,why=ns.DuelDetection.LaunchWidgetChallenge(ranked,id.guid)
    if not ok then
        note:SetTextColor(unpack(C.muted))
        if why=="range" then note:SetText("Move closer or range unavailable")
        else note:SetText("Request not confirmed; try again") end
    end
end,false)
forfeit=Action("Forfeit",174,268,124,25,function()
    if preview or ns.CompetitivePreview.IsActive() or not snap or snap.state=="finishing" then return end
    if snap.challenge and snap.challenge.direction=="outgoing" then
        if not snap.challenge.requestConfirmed then ns.DuelDetection.DismissUnconfirmed()
        elseif not Combat() then Native(CancelDuel) end
    elseif snap.active then Native(ForfeitDuel) end
end,true)
local function Enable(b,value) b.usable=value==true;b:SetEnabled(b.usable);b.Paint() end
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
    if not restricted then
        side.hpText:SetText(string.format("%d%%",math.floor(math.max(0,math.min(100,100*value/max))+.5)))
        return
    end
    -- Modern clients may calculate the percentage internally, even when
    -- the underlying health values are secret. Never inspect or compute on
    -- a secret percentage in Lua. Try native formatted text directly; if
    -- the API or sink refuses it, leave the native bar visible without text.
    side.hpText:SetText("")
    if type(UnitHealthPercent)~="function" or not CurveConstants or not CurveConstants.ScaleTo100 then return end
    local available,percent=pcall(UnitHealthPercent,unit,false,CurveConstants.ScaleTo100)
    if not available then return end
    if Secret(percent) then
        if side.hpText.SetFormattedText then pcall(side.hpText.SetFormattedText,side.hpText,"%.0f%%",percent) end
    elseif type(percent)=="number" and percent>=0 and percent<=100 then
        side.hpText:SetText(string.format("%.0f%%",percent))
    end
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
    if type(n)~="number" then return "—" end
    n=math.max(0,math.floor(n))
    return string.format("%02d:%02d",math.floor(n/60),n%60)
end
local layoutKey,layoutHeight,collapseTimer={},nil,nil
local function CancelCollapse()
    if collapseTimer then collapseTimer:Cancel();collapseTimer=nil end
end
local function StopLayout()
    CancelCollapse();ns.Motion.Stop(layoutKey);layoutHeight=nil
end
local function ApplyHeight(height)
    root:SetHeight(height);body:SetHeight(height)
    Place(fill,8,29,WIDTH-16,math.max(1,height-37))
    Place(leftRail,1,25,10,math.max(1,height-44))
    Place(rightRail,WIDTH-11,25,10,math.max(1,height-44))
    Place(bottomRail,25,height-13,WIDTH-50,12)
    Place(bottomLeft,0,height-32,38,31)
    Place(bottomRight,WIDTH-38,height-32,38,31)
    Place(gem,WIDTH/2-20,height-16,40,16)
    -- Hide content during growth until its bottom lane fits. On shrink the
    -- new, shorter content already fits. No clipping or protruding controls.
    content:SetShown(not folded and layoutHeight~=nil and height>=layoutHeight-.01)
    if ns.Notifications then ns.Notifications.Reanchor() end
end
local function Resize(height,quietIdle)
    if layoutHeight==height then return end
    local first=layoutHeight==nil
    CancelCollapse();ns.Motion.Stop(layoutKey);layoutHeight=height
    local function Move()
        if folded or not root:IsShown() or layoutHeight~=height then return end
        local from=root:GetHeight()
        if first then ApplyHeight(height);return end
        content:SetShown(from>=height)
        ns.Motion.Value(layoutKey,from,height,ns.Motion.Duration("normal"),function(_,v)
            ApplyHeight(v)
        end)
    end
    -- Clear unsafe controls immediately; delay only the idle resize, so a
    -- brief target gap cannot repeatedly collapse and expand the copper rim.
    if quietIdle and not first and root:GetHeight()>height and C_Timer and C_Timer.NewTimer then
        content:Show()
        collapseTimer=C_Timer.NewTimer(.18,function() collapseTimer=nil;Move() end)
    else Move() end
end
-- One optional panel; existing HUD resize owns its entire footprint.
local sessionPanel=CreateFrame("Frame",nil,content)
sessionPanel:SetSize(WIDTH,104);sessionPanel:Hide()
surface=sessionPanel
Rect(20,0,296,1,.48,.32,.16,.8)
local sessionHeading=Label("CURRENT SESSION",11,C.pale,20,5,296,17)
local sessionValues={}
for i,name in ipairs({"Duels","Wins","Losses","Rating"}) do
    local x=20+(i-1)*74
    sessionValues[i]=Label("—",17,C.text,x,24,74,25)
    Label(name,10,C.muted,x,50,74,15)
end
local sessionTrack=Rect(22,70,292,5,.44,.17,.13,1)
local sessionFill=Rect(22,70,1,5,.38,.64,.31,1)
local sessionNote=Label("",10,C.muted,20,79,296,15)
surface=content
local sessionPreview,sessionCache=false,nil
local function PaintSession()
    local v
    if sessionPreview then
        v={scope="SIMULATED",state="ready",total=12,wins=8,losses=4,unknown=0,rating=126,winRate=8/12}
    else
        if not sessionCache then
            local store=ns.CompetitiveStorage
            sessionCache=store and store.ReadSessionStats and store.ReadSessionStats(Plain(GetServerTime))
                or {state="unavailable"}
        end
        v=sessionCache
    end
    sessionHeading:SetText(sessionPreview and "SESSION PREVIEW - SIMULATED" or "CURRENT SESSION")
    local available=v.state=="ready"
    sessionValues[1]:SetText(available and tostring(v.total) or "—")
    sessionValues[2]:SetText(available and tostring(v.wins) or "—")
    sessionValues[3]:SetText(available and tostring(v.losses) or "—")
    sessionValues[4]:SetText(available and v.rating~=nil and string.format("%+d",v.rating) or "—")
    sessionValues[2]:SetTextColor(.46,.85,.44);sessionValues[3]:SetTextColor(1,.43,.38)
    sessionValues[4]:SetTextColor(unpack(C.text))
    if available and v.rating~=nil then
        if v.rating>0 then sessionValues[4]:SetTextColor(.46,.85,.44)
        elseif v.rating<0 then sessionValues[4]:SetTextColor(1,.43,.38) end
    end
    sessionTrack:SetShown(available and v.winRate~=nil)
    sessionFill:SetShown(available and v.winRate~=nil and v.winRate>0)
    if available and v.winRate then sessionFill:SetWidth(math.max(1,292*v.winRate)) end
    sessionNote:SetText(not available and (v.state=="disabled" and "Duel recording not enabled yet" or "Session data unavailable")
        or not v.winRate and (v.total==0 and "No duels recorded yet" or "No confirmed outcomes")
        or string.format("%.1f%% win rate%s",v.winRate*100,v.unknown>0 and (" · "..v.unknown.." unknown") or ""))
end
local function Layout(kind)
    local selected=kind=="selected"
    local pending=kind=="pending" or kind=="incoming"
    local active=kind=="active"
    local result=kind=="result"
    local sides=selected or pending or active
    modeRank:SetShown(selected);modePractice:SetShown(selected);modeDivider:SetShown(selected)
    participants:SetShown(sides)
    timerGroup:SetShown(active or result)
    challenge:SetShown(selected)
    forfeit:SetShown(kind=="pending" or active)
    note:SetShown(kind~="idle" and not active)
    Place(state,10,selected and 77 or 43,WIDTH-20,18)
    Place(participants,0,selected and -20 or pending and -48 or -15,WIDTH,HEIGHT)
    Place(timerGroup,0,-30,WIDTH,HEIGHT)
    Place(note,16,selected and 184 or pending and 156 or 102,WIDTH-32,15)
    Place(challenge,106,204,124,25)
    Place(forfeit,106,pending and 174 or 190,124,25)
    local adaptive=Settings.Get("duelHUDAdaptive")~=false
    local base=adaptive and HEIGHTS[kind] or HEIGHTS.selected
    if kind~="idle" and kind~="selected" then sessionPreview=false end
    local show=(kind=="idle" or kind=="selected") and (sessionPreview or Settings.Get("duelHUDSessionStats")==true)
    sessionPanel:SetShown(show)
    if show then Place(sessionPanel,0,base-18,WIDTH,104);PaintSession() end
    Resize(base+(show and 104 or 0),adaptive and kind=="idle")
end
local function Tick()
    if preview then return end
    local now=Now()
    if not now then return end
    if snap and snap.active then
        local remaining=countdownUntil and countdownUntil-now
        local mode=ns.CompetitiveLifecycle.GetSnapshot().duelMode
        local ranked=mode=="Ranked candidate"
        local label=ranked and "Ranked candidate" or mode=="Unranked" and "Unranked duel" or "Duel in progress"
        if snap.state=="finishing" then state:SetText("Awaiting observed result")
        elseif remaining and remaining>0 then state:SetText(ranked and "Ranked countdown" or "Duel countdown")
        else state:SetText(label) end
        timer:SetText(remaining and remaining>0 and tostring(math.ceil(remaining)) or TimeText(remaining and -remaining))
    elseif shownResult and now>=shownResult.untilTime then
        shownResult=nil;H.Refresh()
    end
end
-- Notifications have their own UIParent frame, not the HUD's alpha.
function H.ApplyOpacity(hovered)
    local engaged=snap and (snap.active or snap.challenge)
    local over=hovered==true or Plain(root.IsMouseOver,root)==true
    local opacity=Settings.Get("duelHUDOpacity") or 1
    root:SetAlpha((over or dragging or engaged or shownResult or preview or sessionPreview) and 1 or opacity)
end
local hoverGeneration=0
local function Enter()
    hoverGeneration=hoverGeneration+1;H.ApplyOpacity(true)
end
local function Leave()
    hoverGeneration=hoverGeneration+1
    local generation=hoverGeneration
    local function Apply()
        if generation==hoverGeneration and root:IsShown() then H.ApplyOpacity() end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0,Apply) else Apply() end
end
for _,f in ipairs({root,header,gear,foldButton,close,modeRank,modePractice,challenge,forfeit,me.click,other.click}) do
    f:HookScript("OnEnter",Enter);f:HookScript("OnLeave",Leave)
end
local lastRange,lastRangeReason
local function Paint()
    if not root:IsShown() or not snap then return end
    H.ApplyOpacity()
    if folded then return end
    note:SetTextColor(unpack(C.muted))
    if preview then
        rankHelp="Visual preview only."
        selectedTargetGuid=nil;Layout("active")
        modeRank.selected=true;modePractice.selected=false
        state:SetText("SOLO PREVIEW - SIMULATED");timer:SetText("00:32")
        PreviewSide(me,"Test Priest","PRIEST",{name="Contender",division=2,label="Contender II"},1660,76)
        PreviewSide(other,"Test Mage","MAGE",{name="Veteran",division=3,label="Veteran III"},1925,43)
        challenge.label:SetText("Challenge Ranked")
        note:SetText("Visual preview only - actions disabled")
        Enable(challenge,false);Enable(forfeit,false);Enable(modeRank,false);Enable(modePractice,false)
        return
    end
    local self=Identity("player")
    local engaged=snap.active or snap.challenge
    local target=not engaged and Identity("target") or nil
    if target and (not self or target.guid==self.guid) then target=nil end
    local opponent=engaged and engaged.opponent or target
    local now=Now()
    if shownResult and now and now>=shownResult.untilTime then shownResult=nil;H.ApplyOpacity() end
    local outgoing=snap.challenge and snap.challenge.direction=="outgoing"
    local kind=snap.active and "active" or snap.challenge and (outgoing and "pending" or "incoming") or shownResult and "result" or snap.state=="idle" and target and "selected" or "idle"
    selectedTargetGuid=kind=="selected" and target.guid or nil
    Layout(kind)
    if kind=="selected" or engaged then
        ReadRanks()
        PaintSide(me,self,"player",true)
        PaintSide(other,opponent,engaged and MatchUnit(opponent) or not engaged and target and "target" or nil,false)
    end
    local intent=Settings.Get("practiceDuels")==true
    local idle=snap.state=="idle"
    local canRank,why,selectable=ns.CompetitiveLifecycle.RankedAvailability(opponent and opponent.guid)
    rankHelp=canRank and "Both clients currently advertise ranked availability. The duel still requires agreement and confirmed results." or (why or "Ranked unavailable")..". A missing reply does not prove the addon is absent."
    local liveMode=ns.CompetitiveLifecycle.GetSnapshot().duelMode
    local effectiveRank=idle and canRank and not intent or not idle and liveMode=="Ranked candidate"
    -- The gold mode is the effective duel type, not an unconfirmed preference.
    modeRank.selected=effectiveRank==true;modePractice.selected=not effectiveRank
    Enable(modeRank,kind=="selected" and not Combat() and selectable and not ns.CompetitivePreview.IsActive())
    Enable(modePractice,kind=="selected" and not Combat() and not ns.CompetitivePreview.IsActive())
    challenge.label:SetText(effectiveRank and "Challenge Ranked" or "Challenge Unranked")
    lastRange,lastRangeReason=nil,nil
    if kind=="selected" and opponent and self and opponent.guid~=self.guid then
        lastRange,lastRangeReason=ns.DuelDetection.GetChallengeRange(opponent.guid)
    end
    Enable(challenge,kind=="selected" and not Combat() and lastRange==true and
        type(StartDuel)=="function" and not ns.CompetitivePreview.IsActive())
    forfeit.label:SetText(outgoing and (snap.challenge.requestConfirmed and "Cancel Request" or "Dismiss") or "Forfeit")
    Enable(forfeit,not ns.CompetitivePreview.IsActive() and
        ((snap.active~=nil and snap.state~="finishing" and type(ForfeitDuel)=="function")
        or (outgoing and (not snap.challenge.requestConfirmed or (not Combat() and type(CancelDuel)=="function")))) or false)
    if snap.active then
        Tick()
    elseif snap.challenge then
        local outgoing=snap.challenge.direction=="outgoing"
        state:SetText(snap.challenge.kind=="death_duel" and "Death duel - excluded" or
            outgoing and not snap.challenge.requestConfirmed and "Checking request" or "Challenge pending")
        timer:SetText("00:00")
        note:SetText(outgoing and not snap.challenge.requestConfirmed and "Waiting for client confirmation" or "Waiting for Blizzard countdown")
    elseif shownResult then
        state:SetText(shownResult.text);timer:SetText(shownResult.duration)
        note:SetText(shownResult.rating)
    else
        local refusal=snap.reason=="request_not_confirmed" or snap.reason=="request_refused" or snap.reason=="request_dismissed"
        state:SetText(snap.state=="unavailable" and "Duel detection unavailable" or
            kind=="selected" and (lastRange==true and (refusal and "Previous request not confirmed" or "Ready to challenge") or lastRangeReason or "Range unavailable") or "Select a player to duel")
        timer:SetText("00:00")
        if kind=="selected" then
            local text,color=OpponentStatus(selectedTargetGuid,canRank,why,intent)
            note:SetTextColor(unpack(color));note:SetText(text)
        else note:SetText("") end
    end
end
local function UpdateDriver()
    if folded or not root:IsShown() then root:SetScript("OnUpdate",nil);H.elapsed=0;return end
    -- Range changes while moving without a target-change event. A lightweight
    -- probe only while visible, idle and targeting another player; no full
    -- refresh unless the range state changes.
    local id=not preview and snap and snap.state=="idle" and Identity("target")
    local me=id and Identity("player")
    local checkRange=id and me and id.guid~=me.guid and not shownResult and not Combat()
    root:SetScript("OnUpdate",not preview and snap and (snap.active or shownResult or checkRange) and function(_,dt)
        H.elapsed=(H.elapsed or 0)+dt
        if H.elapsed<.25 then return end
        H.elapsed=0
        if snap.active or shownResult then Tick() end
        if snap.state=="idle" and selectedTargetGuid and not Combat() then
            local v,why=ns.DuelDetection.GetChallengeRange()
            if v~=lastRange or why~=lastRangeReason then Paint() end
        end
    end or nil)
end
local retryTimer
local function CancelProbeRetry()
    if retryTimer then retryTimer:Cancel();retryTimer=nil end
end
local function Receive(s)
    snap=s
    if s.active or s.challenge or s.state~="idle" then
        CancelProbeRetry()
        preview=false;sessionPreview=false
    end
    if s.active then
        if activeID~=s.active.id then
            activeID=s.active.id;acceptedAt=s.active.acceptedAt
            countdownUntil=nil;shownResult=nil
        end
        -- Use the detector's observed countdown event timestamps, never
        -- restart the countdown on a repaint, unfold or health event.
        if type(s.active.countdown)=="number" then
            local observedAt
            for i=#(s.trace or {}),1,-1 do
                local e=s.trace[i]
                if e.cycle==activeID and e.reason=="countdown_observed" and type(e.time)=="number" then
                    observedAt=e.time;break
                end
            end
            observedAt=observedAt or acceptedAt
            if type(observedAt)=="number" then
                local finish=observedAt+s.active.countdown
                if not countdownUntil or finish<countdownUntil then countdownUntil=finish end
            end
        end
    elseif activeID then
        if s.last and s.last.id==activeID and Now() then
            local labels={won="Victory",lost="Defeat",fled="You retreated",they_fled="Opponent retreated",unknown="Result unknown"}
            local confirmed=s.last.reason=="matching_result_and_finish" and s.last.outcomeObserved==true
                and s.last.finishObserved==true and s.last.resultObserved==true and s.last.conflict==false
            shownResult={text=confirmed and (labels[s.last.outcome] or "Result unknown") or "Result unknown",
                duration=TimeText(type(s.last.endedAt)=="number" and countdownUntil and s.last.endedAt-countdownUntil or nil),
                rating="Rating not confirmed",untilTime=Now()+6}
        end
        activeID,acceptedAt,countdownUntil=nil,nil,nil
    end
    if s.challenge then shownResult=nil end
    Paint()
    UpdateDriver()
    if tournamentSuspended and not switchingAnchor and s.state=="idle" and not s.active and not s.challenge and not Combat() then
        H.ScheduleTournamentRefresh()
    end
end
function H.IsTournamentHUDActive() return tournamentActive end
function H.IsSwitchingNotificationAnchor() return switchingAnchor end
function H.GetNotificationAnchor()
    return tournamentActive and ns.TournamentHUD.Frame() or root
end
function H.GetNotificationScale() return root:GetScale() end
function H.GetRegularNotificationAnchor() return root end
function H.ScheduleTournamentRefresh()
    if tournamentRetry or not C_Timer or not C_Timer.NewTimer then return end
    tournamentRetry=C_Timer.NewTimer(0,function()
        tournamentRetry=nil;H.Refresh()
    end)
end
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
    H.ApplyOpacity()
end
header:SetScript("OnDragStart",function()
    if Settings.Get("duelHUDLocked") or Combat() then return end
    dragging=true;root:StartMoving();H.ApplyOpacity(true)
end)
header:SetScript("OnDragStop",StopDrag)
local unsubscribe,unsubscribeDiscovery
local function ProbeSelected()
    CancelProbeRetry()
    if folded or preview or sessionPreview or not snap or snap.state~="idle" or Combat() then return end
    local id=Identity("target");local own=Identity("player")
    if not id or not own or id.guid==own.guid then return end
    -- One throttled retry on rapid target changes; no repeating network poll.
    local ok,reason=ns.OpponentDiscovery.ProbeTarget(true)
    if not ok and reason=="cooldown" and C_Timer and C_Timer.NewTimer then
        retryTimer=C_Timer.NewTimer(8.1,function()
            retryTimer=nil
            if not root:IsShown() or folded or preview or sessionPreview or Combat() or not snap or snap.state~="idle" then return end
            local current=Identity("target")
            if current and current.guid==id.guid then ns.OpponentDiscovery.ProbeTarget(true);Paint() end
        end)
    end
end
function H.IsFolded() return folded end
function H.Fold(value)
    local want=value==true
    if want==folded then return end
    StopDrag();StopLayout();CancelProbeRetry();folded=want
    if folded then sessionPreview=false end
    body:SetShown(not folded);foldedTrim:SetShown(folded)
    content:Hide()
    if folded then root:SetHeight(FOLDED_HEIGHT) end
    PaintFold();H.ApplyPosition()
    if not folded and root:IsShown() then rankDirty=true;Receive(ns.DuelDetection.GetSnapshot());ProbeSelected() end
    UpdateDriver()
end
local events={"PLAYER_TARGET_CHANGED","PLAYER_FOCUS_CHANGED","UPDATE_MOUSEOVER_UNIT","UNIT_HEALTH","UNIT_MAXHEALTH","UNIT_NAME_UPDATE","PLAYER_REGEN_ENABLED","PLAYER_REGEN_DISABLED","UI_SCALE_CHANGED","DISPLAY_SIZE_CHANGED"}
root:SetScript("OnEvent",function(_,event,unit)
    if event=="PLAYER_REGEN_DISABLED" then StopDrag();CancelProbeRetry();preview=false;sessionPreview=false end
    if event=="UI_SCALE_CHANGED" or event=="DISPLAY_SIZE_CHANGED" then H.ApplyPosition() end
    if event=="UNIT_HEALTH" or event=="UNIT_MAXHEALTH" then
        if folded or preview or not participants:IsShown() then return end
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
    if event=="PLAYER_REGEN_ENABLED" and tournamentSuspended then H.ScheduleTournamentRefresh() end
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
    StopDrag();StopLayout();hoverGeneration=hoverGeneration+1
    sessionPreview=false;sessionCache=nil
    if unsubscribe then unsubscribe();unsubscribe=nil end
    if unsubscribeDiscovery then unsubscribeDiscovery();unsubscribeDiscovery=nil end
    CancelProbeRetry()
    root:UnregisterAllEvents();root:SetScript("OnUpdate",nil)
    preview=false;activeID,acceptedAt,countdownUntil,shownResult=nil,nil,nil,nil
    snap,rankView,rankSeason,selectedTargetGuid=nil,nil,nil,nil;rankDirty=true
end)
local function StopTournament()
    if tournamentRetry then tournamentRetry:Cancel();tournamentRetry=nil end
    if tournamentUnsubscribe then tournamentUnsubscribe();tournamentUnsubscribe=nil end
    local f=ns.TournamentHUD.Frame()
    if f then f:UnregisterAllEvents();f:SetScript("OnEvent",nil) end
    ns.TournamentHUD.Hide()
    tournamentActive=false;tournamentKey=nil
end
function H.Refresh()
    if not ready or switchingAnchor then return end
    local B=ns.TournamentHUD
    if B.IsEditing() then return end
    sessionCache=nil
    local enabled=Settings.Get("duelHUDEnabled") and ns.Client.IsSupported()
    local d=ns.DuelDetection.GetSnapshot()
    local p=enabled and ns.TournamentRegistration.PreviewHasBracket() and ns.TournamentRegistration.PreviewSnapshot()
    local model=B.Project(p)
    local want=model and d.state=="idle" and not d.active and not d.challenge and not Combat()
    tournamentSuspended=not not (model and not want)
    local regularWasShown=root:IsShown()
    switchingAnchor=true
    local changed=false;local newMatch=false
    if want then
        newMatch=tournamentKey~=model.key
        local f=B.Show(model)
        if not tournamentActive then
            tournamentActive=true;changed=true
            -- Only one duel observer is active at a time. Defer switching out
            -- of a detector notification so its listener iteration stays safe.
            root:Hide()
            tournamentUnsubscribe=ns.DuelDetection.Subscribe(function(s)
                if s.state~="idle" or s.active or s.challenge then H.ScheduleTournamentRefresh() end
            end)
            for _,e in ipairs({"PLAYER_REGEN_DISABLED","PLAYER_ENTERING_WORLD","UI_SCALE_CHANGED","DISPLAY_SIZE_CHANGED"}) do f:RegisterEvent(e) end
            f:SetScript("OnEvent",function(_,e)
                if e=="UI_SCALE_CHANGED" or e=="DISPLAY_SIZE_CHANGED" then B.Relayout();if ns.Notifications then ns.Notifications.Reanchor() end
                else H.Refresh() end
            end)
        end
        tournamentKey=model.key
    else
        if tournamentActive then changed=true;StopTournament() end
        if not enabled then root:Hide()
        else
            if Settings.Get("duelHUDLocked") then StopDrag() end
            if not dragging then root:SetScale(Settings.Get("duelHUDScale"));H.ApplyPosition() end
            H.ApplyOpacity()
            if not root:IsShown() then root:Show()
            else Receive(d) end
        end
    end
    switchingAnchor=false
    if ns.Notifications then
        if changed and not tournamentActive then ns.Notifications.ClearTournamentPreview() end
        if changed or regularWasShown~=root:IsShown() then
            ns.Notifications.Reanchor();ns.Notifications.Refresh()
        end
        if newMatch then ns.Notifications.OnTournamentMatchReady(model.key) end
    end
end
function H.InvalidateRank()
    -- Lazy refresh avoids replaying the ledger on repeated Hall resizes.
    rankDirty=true;sessionCache=nil
    if root:IsShown() and not preview then Paint() end
end
function H.ToggleSessionPreview()
    if tournamentActive or not ready or Combat() or ns.DuelDetection.GetSnapshot().state~="idle" or preview then return false,"Finish your duel first" end
    if not Settings.Get("duelHUDEnabled") or folded then return false,"Show and unfold the Duel Widget first" end
    sessionPreview=not sessionPreview
    if sessionPreview then CancelProbeRetry() end
    H.Refresh();return true
end
function H.ResetSession()
    if Combat() or ns.DuelDetection.GetSnapshot().state~="idle" then return false,"Finish your duel first" end
    local ok,why=ns.CompetitiveStorage.StartSession(true)
    if not ok then return false,why=="disabled" and "Duel recording not enabled yet" or "Session reset unavailable" end
    sessionPreview=false;H.Refresh();return true
end
function H.GetDiagnosticResources()
    return {subscriptions=(unsubscribe and 1 or 0)+(unsubscribeDiscovery and 1 or 0)+(tournamentUnsubscribe and 1 or 0)+(previewUnsubscribe and 1 or 0),timers=(root:GetScript("OnUpdate") and 1 or 0)+(collapseTimer and 1 or 0)+(retryTimer and 1 or 0)+(tournamentRetry and 1 or 0)}
end
local PREVIEW_ENABLED=true
function H.TogglePreview()
    if tournamentActive or not PREVIEW_ENABLED or not ready or Combat() or ns.DuelDetection.GetSnapshot().state~="idle" then return end
    if not Settings.Get("duelHUDEnabled") then Settings.Set("duelHUDEnabled",true) end
    preview=not preview
    if preview then CancelProbeRetry();sessionPreview=false end
    H.Refresh()
end
local login=CreateFrame("Frame");login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent",function()
    login:UnregisterAllEvents();ready=true
    previewUnsubscribe=ns.TournamentRegistration.SubscribePreview(H.Refresh)
    H.Refresh()
end)
