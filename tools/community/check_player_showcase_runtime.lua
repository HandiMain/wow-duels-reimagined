-- Execute the actual character display owner with mocked WoW APIs.
local ns={}
local frames,models={},{}
local noop=function()end
local methods={}
function methods:SetScript(key,fn) self.scripts[key]=fn end
function methods:SetShown(on) if on then self:Show() else self:Hide() end end
function methods:Show() self.shown=true end
function methods:Hide()
    local was=self.shown;self.shown=false
    if was and self.scripts.OnHide then self.scripts.OnHide(self) end
end
function methods:IsVisible() local parent=rawget(self,"parent");return self.shown and (not parent or parent:IsVisible()) end
function methods:HookScript(key,fn)
    local old=self.scripts[key]
    self.scripts[key]=function(...) if old then old(...) end;fn(...) end
end
function methods:GetWidth()return 240 end
function methods:GetHeight()return 470 end
function methods:SetSize(w,h)self.width,self.height=w,h end
function methods:SetAtlas(name)self.atlas=name;self.texture=nil end
function methods:SetTexture(t)self.texture=t;self.atlas=nil end
function methods:SetAlpha(a) self.alpha=a end
function methods:GetAlpha() return rawget(self,"alpha") or 1 end
function methods:GetFrameLevel() return self.level or 1 end
function methods:SetFrameLevel(v)self.level=v end
function methods:GetParent()return self.parent end
function methods:SetParent(p)self.parent=p end
function methods:SetTexCoord(...)self.uv={...}end
function methods:GetEffectiveScale() return 1 end
function methods:SetText(t) self.text=t end
function methods:RegisterEvent(e) self.events[e]=true end
function methods:UnregisterAllEvents() self.events={} end
function methods:SetUnit(unit)
    self.unit=unit
    if self.scripts.OnModelLoaded then self.scripts.OnModelLoaded(self) end
end
function methods:ClearModel() self.unit=nil end
function methods:SetFacing(v) self.facing=v end
function methods:SetPortraitZoom(v) self.zoom=v end
local function Frame(parent,kind)
    local f=setmetatable({parent=parent,shown=true,scripts={},events={},kind=kind},{__index=function(_,k)return methods[k] or (type(k)=="string" and k:match("^[A-Z]") and noop or nil) end})
    frames[#frames+1]=f
    if kind=="PlayerModel" then models[#models+1]=f end
    return f
end
function methods:CreateTexture()return Frame(self,"texture")end
CreateFrame=function(kind,_,parent)return Frame(parent,kind)end
local root=Frame(nil,"Frame")
ns.Style={color={body={},goldDim={},muted={}},Skin=noop,Text=function(parent,text)local f=Frame(parent,"text");f:SetText(text);return f end}
local mode,tint=true,true
ns.Settings={Get=function(key)if key=="profileShowModel" then return mode elseif key=="profileFactionBackdrop" then return tint end end}
local combat,target,mouse,x=false,"Player-1-RIVAL",true,10
InCombatLockdown=function()return combat end
UnitGUID=function(unit)if unit=="player" then return "Player-1-ME" elseif unit=="target" then return target end end
UnitIsPlayer=function(unit)return UnitGUID(unit)~=nil end
UnitRace=function()return "Human" end
SetPortraitTexture=function(t,unit)t.texture="portrait:"..unit end
GetCursorPosition=function()return x,0 end
IsMouseButtonDown=function()return mouse end
assert(loadfile("addon/DuelsReimagined/UI/PlayerShowcase.lua"))("DuelsReimagined",ns)
local P=ns.PlayerShowcase
local pane=P.Create(root)
assert(#models==0)
local identity={class="WARRIOR",faction="Alliance"}
local function Crest()
    for _,f in ipairs(frames) do
        if f.kind=="texture" and f:GetAlpha()==.14 then return f end
    end
end
local crest=Crest()
assert(crest and not crest:IsVisible())
C_Texture={GetAtlasInfo=function(name)
    if name=="talenttree-alliance-cornerlogo" then return {width=82,height=92}
    elseif name=="talenttree-horde-cornerlogo" then return {width=88,height=101} end
end}
local function Event(e,unit)
    for _,f in ipairs(frames) do
        if f.events[e] and f.scripts.OnEvent then f.scripts.OnEvent(f,e,unit) end
    end
end
local function HasTexture(t)
    for _,f in ipairs(frames) do if f.texture==t and f:IsVisible() then return true end end
end
pane:Show();pane.Paint("Player-1-ME","SIMULATED",identity)
assert(#models==0 and HasTexture("Interface\\Icons\\ClassIcon_WARRIOR"))
assert(crest:IsVisible() and crest.atlas=="talenttree-alliance-cornerlogo" and crest.width>190 and crest.height>crest.width)
pane.Paint("Player-1-ME","SIMULATED",{class="WARRIOR",faction="Horde"})
assert(crest.atlas=="talenttree-horde-cornerlogo")
tint=false;pane.Paint("Player-1-ME","SIMULATED",identity);assert(not crest:IsVisible())
tint=true;C_Texture=nil
pane.Paint("Player-1-ME","SIMULATED",identity)
assert(crest:IsVisible() and crest.texture=="Interface\\Timer\\Alliance-Logo")
pane.Paint("Player-1-ME","SIMULATED",{class="WARRIOR",faction="Horde"})
assert(crest.texture=="Interface\\Timer\\Horde-Logo")
pane.Paint("Player-1-ME","SIMULATED",{class="WARRIOR",faction="Neutral"})
assert(not crest:IsVisible())
pane.Paint("Player-1-ME","LOCAL",identity)
assert(#models==1 and models[1].unit=="player" and models[1]:GetAlpha()==1)
assert(P.Race("Player-1-ME","LOCAL")=="Human" and not P.Race("Player-1-ME","SIMULATED"))
local overlay
for _,f in ipairs(frames) do if f.scripts.OnMouseWheel then overlay=f end end
assert(overlay and overlay:IsVisible())
overlay.scripts.OnMouseDown(overlay,"LeftButton");assert(overlay.scripts.OnUpdate)
x=50;overlay.scripts.OnUpdate();assert(models[1].facing>0)
overlay.scripts.OnMouseWheel(overlay,4);assert(models[1].zoom==.4)
mouse=false;overlay.scripts.OnUpdate();assert(not overlay.scripts.OnUpdate)
mode=false;pane.Paint("Player-1-ME","LOCAL",identity)
assert(models[1].unit==nil and HasTexture("portrait:player"))
mode=true;pane.Paint("Player-1-RIVAL","LOCAL",identity)
assert(models[1].unit=="target")
target="Player-1-OTHER";Event("PLAYER_TARGET_CHANGED")
assert(models[1].unit==nil and HasTexture("Interface\\Icons\\ClassIcon_WARRIOR"))
target="Player-1-RIVAL";Event("PLAYER_TARGET_CHANGED");assert(models[1].unit=="target")
combat=true;Event("PLAYER_REGEN_DISABLED");assert(models[1].unit==nil)
combat=false;Event("PLAYER_REGEN_ENABLED");assert(models[1].unit=="target")
pane:Hide()
assert(models[1].unit==nil and not overlay.scripts.OnUpdate)
for _,f in ipairs(frames) do assert(not next(f.events)) end
pane:Show();pane.Paint("Player-1-ME","LOCAL",identity);assert(#models==1 and models[1].unit=="player")
local preview=Frame(root,"Frame")
pane.Reparent(preview)
pane.Paint("Player-1-ME","LOCAL",identity,{background={id="blood",texture="scene.png"}})
assert(#models==1 and pane:GetParent()==preview and HasTexture("scene.png") and not crest:IsVisible())
pane.Reparent(root);pane.Paint("Player-1-ME","LOCAL",identity)
assert(#models==1 and crest:IsVisible())
pane:Hide()
print("Duelist character display: PASS (scope, unit identity, model fallback, input and hidden lifecycle)")
