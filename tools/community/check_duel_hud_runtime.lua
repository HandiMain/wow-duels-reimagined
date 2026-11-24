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
function methods:SetTexture(t)self.texture=t end
function methods:SetScale(v)self.scale=v end
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
GetTime=function()return 100 end
InCombatLockdown=function()return false end
local C=setmetatable({}, {__index=function(t,k)local v={1,1,1,1};rawset(t,k,v);return v end})
local prefs={duelHUDEnabled=true,duelHUDLocked=false,duelHUDScale=1}
local px,py=.4,.5
local fits,anchors,subscribers=0,0,0
local snap={state="idle"}
local function Subscribe()subscribers=subscribers+1;return function()subscribers=subscribers-1 end end
local ns={
    Style={color=C,Text=function(p,t)local f=Frame(p);f:SetText(t);return f end,
        ConstrainText=function(_,w,h)assert(w>0 and h>0);fits=fits+1 end,
        Plate=noop,FeedbackOverlay=function(p)return Frame(p)end},
    Settings={Get=function(k)return prefs[k] end,GetDuelHUDPosition=function()return px,py end,
        SetDuelHUDPosition=function(x,y)px,py=x,y end},
    Motion={Fade=noop,Duration=function()return .1 end},Widgets={PressFeedback=noop},
    Client={IsSupported=function()return true end},
    Group={ReadCompetitiveIdentity=function(unit)return {guid="Player-1-"..unit,name=unit}end},
    CompetitiveLifecycle={RankedAvailability=function()return false,"Unranked only",false end,GetSnapshot=function()return {}end},
    CompetitivePreview={IsActive=function()return false end},
    CompetitiveUI={CreateRankEmblem=function(p)local f=Frame(p);f.Paint=noop;return f end},
    DuelDetection={GetSnapshot=function()return snap end,Subscribe=Subscribe,GetChallengeRange=function()return true end},
    OpponentDiscovery={Subscribe=Subscribe,ProbeTarget=function()return true end},
    Notifications={Reanchor=function()anchors=anchors+1 end}
}
assert(loadfile("addon/DuelsReimagined/UI/DuelHUD.lua"))("DuelsReimagined",ns)
local H=ns.DuelHUD;local root=H.GetNotificationAnchor()
for _,f in ipairs(frames)do if f.events.PLAYER_LOGIN then f.scripts.OnEvent(f,"PLAYER_LOGIN");break end end
assert(root:IsShown() and root:GetHeight()==310 and not H.IsFolded() and subscribers==2)
assert(root:GetScript("OnUpdate") and fits>=15)
local arrow,ranked,header
for _,f in ipairs(frames)do
    if f.texture and f.texture:find("FoldUp.png",1,true)then arrow=f.parent end
    if f.text=="Ranked"then ranked=f end
    if f.scripts.OnDragStart then header=f end
end
assert(arrow and ranked and ranked:IsVisible() and header)
local top=root.point[5];local frameCount=#frames
arrow.scripts.OnClick()
assert(H.IsFolded() and root:IsShown() and root:GetHeight()==42 and root.point[5]==top)
assert(not ranked:IsVisible() and arrow:IsVisible() and not root:GetScript("OnUpdate") and subscribers==2)
-- Moving while folded stores the expanded centre, not the tiny header centre.
header.scripts.OnDragStart();root.point[4]=720;root.point[5]=650
header.scripts.OnDragStop()
assert(math.abs(px-.5)<.0001 and math.abs(py-(650-155)/900)<.0001)
arrow.scripts.OnClick()
assert(not H.IsFolded() and root:GetHeight()==310 and math.abs(root.point[5]-650)<.001)
assert(ranked:IsVisible() and root:GetScript("OnUpdate") and subscribers==2)
H.Fold(true);prefs.duelHUDEnabled=false;H.Refresh()
assert(not root:IsShown() and subscribers==0 and not root:GetScript("OnUpdate"))
prefs.duelHUDEnabled=true;H.Refresh()
assert(root:IsShown() and H.IsFolded() and root:GetHeight()==42 and subscribers==2)
H.Fold(false)
assert(#frames==frameCount and anchors>3 and ranked:IsVisible())
print("Duel HUD fold mock: PASS (stable top, body visibility, dragging, polling, subscriptions and font registration)")
