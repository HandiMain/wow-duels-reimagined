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
    function f:SetFont()return true end
    function f:SetScale(v)self.scale=v end
    function f:SetAlpha(v)self.alpha=v end
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
