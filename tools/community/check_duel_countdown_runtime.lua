-- Real countdown controller with a simulated clock. No live gameplay or data.
local frames={}
local noop=function()end
local function Frame(parent)
    local f={parent=parent,shown=true,scripts={},events={}}
    setmetatable(f,{__index=function(_,k)return type(k)=="string" and k:match("^[A-Z]") and noop or nil end})
    function f:SetScript(k,v)self.scripts[k]=v end
    function f:GetScript(k)return self.scripts[k] end
    function f:RegisterEvent(e)self.events[e]=true end
    function f:UnregisterEvent(e)self.events[e]=nil end
    function f:Show()self.shown=true end
    function f:Hide()self.shown=false end
    function f:SetShown(v)self.shown=v end
    function f:IsShown()return self.shown end
    function f:SetText(v)self.text=v end
    function f:SetFont(path,size)if path=="bad-font" then return false end;self.font=path;self.fontSize=size;return true end
    function f:SetScale(v)self.scale=v end
    function f:SetAlpha(v)self.alpha=v end
    function f:SetPoint(...)self.point={...} end
    function f:SetTextColor(...)self.color={...} end
    function f:SetSize(w,h)self.w=w;self.h=h end
    function f:CreateTexture()return Frame(self)end
    function f:CreateFontString()return Frame(self)end
    frames[#frames+1]=f;return f
end
UIParent=Frame()
CreateFrame=function(_,name,p)local f=Frame(p);if name then _G[name]=f end;return f end
local now=100
GetTime=function()return now end
local combat=false
InCombatLockdown=function()return combat end
local pending={}
C_Timer={NewTimer=function(delay,fn)
    local t={at=now+delay,fn=fn};function t:Cancel()self.cancelled=true end
    pending[#pending+1]=t;return t
end}
local function Advance(to)
    while true do
        local pick
        for _,t in ipairs(pending)do if not t.cancelled and t.at<=to and (not pick or t.at<pick.at) then pick=t end end
        if not pick then break end
        now=pick.at;pick.cancelled=true;pick.fn()
    end
    now=to
end
local prefs={duelCountdownVisual=true}
local snap={scope="LOCAL",state="idle"}
local callback
local ns={Settings={Get=function(k)return prefs[k] end},Client={IsSupported=function()return true end},
    DuelDetection={GetSnapshot=function()return snap end,Subscribe=function(fn)callback=fn;return noop end}}
local available=true
LibStub=function(name,silent)
    assert(name=="LibSharedMedia-3.0" and silent==true)
    if available then return {
        Fetch=function(_,kind,name) if kind=="font" then return ({["Shared Face"]="shared-face",["Bad Font"]="bad-font"})[name] end end,
        List=function()return {"Shared Face","Bad Font"} end,
    } end
end
assert(loadfile("addon/DuelsReimagined/UI/Fonts.lua"))("DuelsReimagined",ns)
assert(loadfile("addon/DuelsReimagined/UI/Motion.lua"))("DuelsReimagined",ns)
local driver=frames[#frames]
assert(loadfile("addon/DuelsReimagined/UI/DuelCountdown.lua"))("DuelsReimagined",ns)
local V=ns.DuelCountdown;local root=DuelsReimaginedCountdown
for _,f in ipairs(frames)do if f.events.PLAYER_LOGIN then f.scripts.OnEvent(f,"PLAYER_LOGIN") end end
local count=#frames
local function Text(s)
    for _,f in ipairs(frames)do if f.text==s and f.shown then return true end end
end
local function Observe(id,n)
    snap={scope="LOCAL",state="accepted",reason="countdown_observed",active={id=id,kind="standard",countdown=n},
        trace={{cycle=id,reason="countdown_observed",time=now}}};callback(snap)
end
assert(V.Preview() and root:IsShown() and Text("3") and Text("COUNTDOWN PREVIEW"))
now=100.2;driver.scripts.OnUpdate(driver,.2)
Advance(101.01);assert(Text("2"))
Advance(102.01);assert(Text("1"))
Advance(103.01);assert(Text("FIGHT!"))
Advance(104);assert(not root:IsShown() and V.GetDiagnosticResources().timers==0 and not ns.Motion.GetRuntimeState().driver)
Observe(1,3);assert(Text("3") and not Text("COUNTDOWN PREVIEW"))
Advance(105);Observe(1,2);assert(Text("2"))
Advance(106);Observe(1,1);assert(Text("1"))
Advance(107.01);assert(Text("FIGHT!"))
snap={scope="LOCAL",state="finishing",active={id=1,kind="standard"}};callback(snap)
assert(not root:IsShown() and V.GetDiagnosticResources().timers==0)
snap={scope="LOCAL",state="idle"};callback(snap)
assert(V.Preview());snap={scope="LOCAL",state="challenge",challenge={}};callback(snap);assert(not root:IsShown())
snap={scope="LOCAL",state="idle"};callback(snap)
prefs.reduceMotion=true;assert(V.Preview() and Text("3") and not ns.Motion.GetRuntimeState().driver)
Advance(108.02);assert(Text("2"))
V.Refresh();assert(not root:IsShown() and V.GetDiagnosticResources().timers==0)
prefs.duelCountdownVisual=false;Observe(2,3);assert(not root:IsShown())
assert(#frames==count)
print("Duel countdown: PASS (preview, observed countdown, fight timing, cancellation, reduced motion, disabled gate, bounded regions)")

-- Nine styles share the same regions and timer; verify different geometry,
-- palettes, stage sequence, reduced motion, cancellation and no frame growth.
snap={scope="LOCAL",state="idle"};callback(snap)
prefs.duelCountdownVisual=true;prefs.reduceMotion=false
local glyph,front
for _,f in ipairs(frames)do
    if f.parent==root and f.w==440 and f.h==200 then glyph=f end
end
assert(glyph)
for _,f in ipairs(frames)do if f.parent==glyph and f.color then front=f end end
assert(front)
local motionSignatures,paletteSignatures={},{}
for _,id in ipairs({"impact","slash","forge","arcane","thunder","cinematic","shatter","pulse","minimal"}) do
    prefs.duelCountdownStyle=id
    local start=now
    assert(V.Preview() and Text("3"))
    now=start+.08;driver.scripts.OnUpdate(driver,.08)
    local x,y=glyph.point[4],glyph.point[5]
    local signature=string.format("%.2f/%.2f/%.3f/%.3f",x,y,glyph.scale,glyph.alpha)
    assert(not motionSignatures[signature],"duplicate entrance: "..id);motionSignatures[signature]=true
    local color=table.concat(front.color,",")
    assert(not paletteSignatures[color],"duplicate palette: "..id);paletteSignatures[color]=true
    Advance(start+1.01);assert(Text("2"))
    Advance(start+2.01);assert(Text("1"))
    Advance(start+3.01);assert(Text("FIGHT!"))
    Advance(start+4);assert(not root:IsShown() and not ns.Motion.GetRuntimeState().driver and V.GetDiagnosticResources().timers==0)
    prefs.reduceMotion=true
    assert(V.Preview() and glyph.scale==1 and glyph.alpha==1 and not ns.Motion.GetRuntimeState().driver)
    V.Refresh();prefs.reduceMotion=false
end
assert(#frames==count,"styles must not allocate new frames")
print("Countdown presets: PASS (nine distinct palettes and entrances, stage timing, reduced motion, no frame growth)")

-- Direct scoped lookup: no theme calls, shared font fallback, and the
-- interface's unavailable selection does not leak into the countdown list.
prefs.fontChoice="lsm:Interface Only";prefs.matchFont=true
prefs.duelCountdownStyle="impact";prefs.duelCountdownFont="lsm:Shared Face"
ns.Theme={Font=function()error("theme should never resolve countdown glyphs")end}
STANDARD_TEXT_FONT="unwanted-global-override"
local choices=ns.Fonts.GetChoices(prefs.duelCountdownFont,true)
local shared=false
for _,choice in ipairs(choices) do
    assert(choice.key~="default" and choice.key~=prefs.fontChoice)
    if choice.key=="lsm:Shared Face" then shared=true end
end
assert(shared)
assert(V.Preview() and front.font=="shared-face" and front.fontSize==156)
prefs.fontChoice="builtin:Skurri"
Advance(now+3.01);assert(front.font=="shared-face" and front.fontSize==100)
V.Refresh()
available=false
local missing=false
for _,choice in ipairs(ns.Fonts.GetChoices(prefs.duelCountdownFont,true)) do
    if choice.key=="lsm:Shared Face" then missing=choice.label:find("unavailable",1,true)~=nil end
end
assert(missing and V.Preview() and front.font=="Fonts\\MORPHEUS.TTF")
V.Refresh()
available=true;prefs.duelCountdownFont="lsm:Bad Font"
assert(V.Preview() and front.font=="Fonts\\MORPHEUS.TTF");V.Refresh()
prefs.duelCountdownFont="builtin:Skurri"
assert(V.Preview() and front.font=="Fonts\\SKURRI.TTF");V.Refresh()
assert(#frames==count and not ns.Motion.GetRuntimeState().driver)
print("Countdown font: PASS (independent selection, shared discovery, missing/rejected media fallback, no theme override)")

-- Font sample rows are recycled; a missing/rejected face must never retain
-- the preceding entry's font. A wide name fits down to the readable floor.
local sample=Frame()
function sample:GetUnboundedStringWidth() return #(self.text or "")*self.fontSize*.7 end
ns.Fonts.PaintSample(sample,"lsm:Shared Face","Shared Face",16,194)
assert(sample.font=="shared-face" and sample.fontSize==16)
ns.Fonts.PaintSample(sample,"builtin:Skurri","Skurri",16,194)
assert(sample.font=="Fonts\\SKURRI.TTF")
ns.Fonts.PaintSample(sample,"lsm:Bad Font","Bad Font",16,194)
assert(sample.font=="Fonts\\FRIZQT__.TTF")
available=false
ns.Fonts.PaintSample(sample,"lsm:Shared Face","Shared Face (unavailable)",16,194)
assert(sample.font=="Fonts\\FRIZQT__.TTF")
available=true
ns.Fonts.PaintSample(sample,"lsm:Shared Face","A very very very long shared font name",16,106)
assert(sample.font=="shared-face" and sample.fontSize==10)
ns.Fonts.PaintSample(sample,"lsm:Shared Face","Shared Face",16,194)
assert(sample.fontSize==16)
print("Font samples: PASS (recycled faces, rejected/missing media, bounded fitting, size restored)")

-- Editor uses the actual countdown frame, not a second preview renderer.
ns.Settings.GetVisualLayout=function() return .5,.5,1 end
ns.Settings.ClampVisualLayout=function(x,y,scale,w,h) assert(w==1000 and h==600);return x,y,scale end
function UIParent:GetWidth()return 1000 end
function UIParent:GetHeight()return 600 end
V.SetLayoutDraft(.7,.3,1.5);V.ShowLayoutSample()
assert(root:IsShown() and Text("3") and root.scale==1.5)
assert(math.abs(root.point[4]-200/1.5)<.001 and math.abs(root.point[5]+120/1.5)<.001)
assert(not ns.Motion.GetRuntimeState().driver and V.GetDiagnosticResources().timers==0)
local restored=0
ns.EditMode={IsActive=function()return true end,RestoreSample=function()restored=restored+1;V.ShowLayoutSample()end,
    Cancel=function()V.EndLayoutDraft()end}
local start=now;assert(V.Preview());Advance(start+4)
assert(restored==1 and root:IsShown() and Text("3") and root.scale==1.5)
V.EndLayoutDraft();assert(not root:IsShown() and root.scale==1 and root.point[4]==0 and root.point[5]==0)
assert(#frames==count+1) -- only the earlier font sample test created a frame
print("Countdown layout: PASS (actual sample, scaled anchor, preview restore, saved layout restoration)")

-- Real sound owner driven solely by countdown stage transitions.
local played,stopped={},{}
PlaySoundFile=function(path,channel)played[#played+1]={path,channel};return true,#played end
StopSound=function(id)stopped[#stopped+1]=id end
DuelsReimaginedCountdownSoundPacks={version=1,groups={
    {label="Overwatch",packs={{key="Overwatch/Ana",label="Ana"},{key="../bad",label="Bad"}}},
    {label="Unreal Tournament",packs={{key="Unreal Tournament - 99",label="99"}}},
},fight={{key="mortal_kombat",label="Mortal Kombat",category="Voices",duration=1.358},
    {key="sword_slice1",label="Sword Slice 1",category="Sword effects",duration=.74}}}
assert(loadfile("addon/DuelsReimagined/Core/CountdownAudio.lua"))("DuelsReimagined",ns)
local A=ns.CountdownAudio
prefs.duelCountdownVisual=true;prefs.duelCountdownSounds=true
prefs.duelCountdownSoundPack="pack:Overwatch/Ana";prefs.duelCountdownAudioChannel="Dialog"
local choices=A.GetChoices(prefs.duelCountdownSoundPack)
assert(#choices==5 and choices[2].heading and choices[3].group==choices[2].key)
assert(A.IsAvailable("pack:Overwatch/Ana") and not A.IsAvailable("pack:../bad"))
local start=now
assert(V.Preview() and #played==1 and played[1][1]:find("Overwatch\\Ana\\3.ogg",1,true) and played[1][2]=="Dialog")
Advance(start+1.01);assert(#played==2 and played[2][1]:find("\\2.ogg",1,true))
Advance(start+2.01);assert(#played==3 and played[3][1]:find("\\1.ogg",1,true))
Advance(start+3.01);assert(#played==3 and #stopped==3)
Advance(start+4);assert(A.GetDiagnosticResources().handles==0)
prefs.duelCountdownSounds=false
assert(V.Preview());Advance(now+4);assert(#played==3)
prefs.duelCountdownSounds=true;prefs.duelCountdownVisual=false
assert(V.Preview());Advance(now+4);assert(#played==3)
prefs.duelCountdownVisual=true
prefs.duelCountdownSoundPack="pack:Missing"
assert(V.Preview() and played[4][1]:find("CountdownTick.mp3",1,true))
V.Refresh();assert(A.GetDiagnosticResources().handles==0)
local n=#played
V.SetLayoutDraft(.5,.5,1);V.ShowLayoutSample();assert(#played==n);V.EndLayoutDraft()
print("Countdown audio: PASS (3/2/1 only, category grouping, channel, disabled gates, fallback, cleanup, silent edit sample)")

-- FIGHT cue is independent of the three number sounds and uses the same handle.
prefs.duelCountdownVisual=true;prefs.duelCountdownSounds=false
prefs.duelFightSounds=true;prefs.duelFightSoundPack="fight:mortal_kombat";prefs.duelFightAudioChannel="Master"
local c=A.GetFightChoices("fight:mortal_kombat")
assert(#c==5 and c[2].heading and c[3].key=="fight:mortal_kombat")
local before=#played
local start=now
assert(V.Preview() and #played==before)
Advance(start+3.01)
assert(#played==before+1 and played[#played][1]:find("Fight\\mortal_kombat.ogg",1,true) and played[#played][2]=="Master")
Advance(start+3.96);assert(A.GetDiagnosticResources().handles==1 and not root:IsShown())
A.Stop("countdown");assert(A.GetDiagnosticResources().handles==1)
Advance(start+4.5);assert(A.GetDiagnosticResources().handles==0)
prefs.duelFightSounds=false;prefs.duelCountdownSounds=true;prefs.duelCountdownSoundPack="pack:Overwatch/Ana"
before=#played;assert(V.Preview());Advance(now+4);assert(#played==before+3)
prefs.duelCountdownSounds=false;prefs.duelFightSounds=true;prefs.duelCountdownVisual=false
before=#played;assert(V.Preview());Advance(now+4);assert(#played==before)
prefs.duelCountdownVisual=true;prefs.duelFightSoundPack="fight:sword_slice1"
start=now;assert(V.Preview());Advance(start+3.01)
assert(played[#played][1]:find("Fight\\sword_slice1.ogg",1,true))
V.Refresh();assert(A.GetDiagnosticResources().handles==0)
print("FIGHT audio: PASS (independent gates/channel, grouped choices, one handle, full tail, cleanup)")
