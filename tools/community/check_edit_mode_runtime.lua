-- Shared editor UI/session harness; real Settings geometry, mocked frames.
local frames={}
local noop=function()end
local function Frame(_,name,parent)
    local f={name=name,parent=parent,shown=true,scripts={},events={},w=1,h=1}
    setmetatable(f,{__index=function(_,k)return type(k)=="string" and k:match("^[A-Z]") and noop or nil end})
    function f:SetScript(k,v) self.scripts[k]=v end
    function f:GetScript(k)return self.scripts[k] end
    function f:HookScript()end
    function f:RegisterEvent(e)self.events[e]=true end
    function f:UnregisterEvent(e)self.events[e]=nil end
    function f:UnregisterAllEvents()self.events={}end
    function f:Show()self.shown=true end
    function f:Hide()self.shown=false;if self.scripts.OnHide then self.scripts.OnHide(self) end end
    function f:IsShown()return self.shown end
    function f:SetShown(v)self.shown=v end
    function f:SetSize(w,h)self.w=w;self.h=h end
    function f:GetWidth()return self.w end
    function f:GetHeight()return self.h end
    function f:GetEffectiveScale()return 1 end
    function f:GetFrameLevel()return 1 end
    function f:SetText(v)self.text=v end
    function f:SetChecked(v)self.checked=v end
    function f:GetChecked()return self.checked end
    function f:SetValue(v)self.value=v;if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self,v) end end
    function f:CreateTexture()return Frame("Texture",nil,self) end
    function f:CreateFontString()return Frame("FontString",nil,self) end
    frames[#frames+1]=f;if name then _G[name]=f end
    return f
end
CreateFrame=Frame;UIParent=Frame();UIParent:SetSize(1000,700)
UISpecialFrames={}
DuelsReimaginedDB={}
local combat=false
InCombatLockdown=function()return combat end
local cursorX,cursorY=500,350
GetCursorPosition=function()return cursorX,cursorY end
IsMouseButtonDown=function()return true end
local state={state="idle"}
local draft,committed,samples,previews,finishes= nil,nil,0,0,0
local ns={Client={IsSupported=function()return true end},DuelDetection={GetSnapshot=function()return state end}}
assert(loadfile("addon/DuelsReimagined/Core/Settings.lua"))("DuelsReimagined",ns)
local S=ns.Settings
local colors={gold={1,1,0},pale={1,1,1},goldDim={.5,.5,0},nav={.1,.1,.1},shellEdge={.7,.5,.3},window={.05,.05,.05},hover={.2,.15,.1},button={.6,0,0},buttonText={1,.9,.7}}
ns.Style={color=colors,Fill=function(parent)return Frame("Texture",nil,parent) end,Border=noop,Plate=noop,Skin=noop,
    Text=function(parent,txt)local f=Frame("FontString",nil,parent);f:SetText(txt);return f end,ConstrainText=noop,
    Action=function(parent,txt,variant,palette)local f=Frame("Button",nil,parent);f:SetText(txt);f.palette=palette;return f end}
ns.Chrome={Icon=function(parent)return Frame("Texture",nil,parent)end}
ns.Widgets={CloseChoices=noop}
ns.Window={frame=Frame()}
ns.Window.Toggle=function()ns.Window.frame:Show()end
ns.DuelCountdown={LayoutSize=function()return 480,240 end,
    SetLayoutDraft=function(x,y,s)draft={x,y,s}end,
    ShowLayoutSample=function()samples=samples+1 end,
    Preview=function()previews=previews+1 end,
    EndLayoutDraft=function()draft=nil;finishes=finishes+1 end}
ns.TournamentHUD={LayoutSize=function()return 480,240 end,SetLayoutDraft=noop,ShowLayoutSample=noop,EndLayoutDraft=noop}
local count=#frames
assert(loadfile("addon/DuelsReimagined/UI/EditMode.lua"))("DuelsReimagined",ns)
local M=ns.EditMode
assert(#frames==count,"editor must be lazy")
combat=true;assert(not M.Open("countdown"));combat=false
assert(M.Open("countdown") and M.IsActive() and draft[3]==1 and not ns.Window.frame:IsShown())
local root=DuelsReimaginedEditMode
assert(root:IsShown() and not root.scripts.OnUpdate)
local function Control(text)
    for _,f in ipairs(frames)do if f.text==text and f.scripts.OnClick then return f end end
end
assert(Control("Cancel").palette.fill==colors.hover and Control("Save & Exit").palette.fill==colors.button)
assert(Control("Preview").palette.fill==colors.hover and Control("Reset").palette.fill==colors.hover)
assert(Control("Save & Exit").parent.w==640 and Control("Save & Exit").parent.h==46)
assert(Control("Preview").parent.w==444 and Control("Preview").parent.h==42)
local function Slider()
    for _,f in ipairs(frames)do if f.scripts.OnValueChanged then return f end end
end
local function DragBox()
    for _,f in ipairs(frames)do if f.parent==root and f.scripts.OnMouseDown then return f end end
end
local function Grip()
    local box=DragBox()
    for _,f in ipairs(frames)do if f.parent==box and f.scripts.OnMouseDown then return f end end
end
local bx=DragBox();assert(bx)
bx.scripts.OnMouseDown(bx,"LeftButton");cursorX=600;cursorY=430;root.scripts.OnUpdate()
assert(draft[1]>.5 and draft[2]>.5)
bx.scripts.OnMouseUp();assert(not root.scripts.OnUpdate)
local grip=Grip();assert(grip)
local before=draft[3];grip.scripts.OnMouseDown(grip,"LeftButton");cursorX=cursorX+50;cursorY=cursorY-20;root.scripts.OnUpdate()
assert(draft[3]>before);grip.scripts.OnMouseUp()
Slider():SetValue(1.5);assert(draft[3]==1.5)
Control("Preview").scripts.OnClick();assert(previews==1)
assert(DuelsReimaginedDB.visualLayouts==nil,"draft must not persist")
M.Cancel(true);assert(not M.IsActive() and not root:IsShown() and ns.Window.frame:IsShown() and draft==nil)
local built=#frames
assert(M.Open("countdown"));Slider():SetValue(1.5);M.Save()
local x,y,s=S.GetVisualLayout("countdown");assert(s==1.5 and x==.5 and y==.5)
assert(M.Open("countdown") and draft[3]==1.5)
Control("Reset").scripts.OnClick();assert(draft[3]==1)
combat=true;root.scripts.OnEvent(root,"PLAYER_REGEN_DISABLED")
assert(not M.IsActive() and not root:IsShown() and not root.scripts.OnUpdate and not ns.Window.frame:IsShown())
x,y,s=S.GetVisualLayout("countdown");assert(s==1.5,"combat discards unsaved draft")
combat=false;assert(M.Open("countdown"));root:Hide();assert(not M.IsActive(),"Escape/hidden root closes edit")
assert(#frames==built,"reopening must reuse frames and grid")
local sx,sy,ss=M.SnapPosition(.504,.505,1,1000,700,480,240,true,true)
assert(sx==.5 and sy==.5 and ss==1)
state={state="accepted",active={}};assert(not M.Open("countdown"))
assert(M.GetDiagnosticResources().dragDrivers==0 and not next(root.events))
print("Edit Mode: PASS (lazy UI, drag, resize, preview, transactional save/cancel, combat, Escape, snap, bounded frames)")
