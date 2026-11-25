local _,ns=...
-- One optional, lazily built layout editor. A registered visual supplies its
-- own size and renderer; only Settings commits normalized layout coordinates.
local M={};ns.EditMode=M
local Settings,Style=ns.Settings,ns.Style
local C=Style.color
local specs={}
local root,bar,box,tools,scaleText,slider,gridButton,snapButton,boxTitle
local gridLines={}
local session,drag,painting
local function Number(n)
    if type(issecretvalue)=="function" then
        local ok,secret=pcall(issecretvalue,n)
        if not ok or secret then return nil end
    end
    if type(n)=="number" and n==n and n~=math.huge and n~=-math.huge then return n end
end
local function Read(fn,...)
    if type(fn)~="function" then return nil end
    local ok,v=pcall(fn,...)
    return ok and Number(v) or nil
end
local function Idle()
    if type(InCombatLockdown)~="function" then return false end
    local ok,combat=pcall(InCombatLockdown)
    if not ok or (issecretvalue and issecretvalue(combat)) or combat~=false then return false end
    local s=ns.DuelDetection.GetSnapshot()
    return s and s.state=="idle" and not s.active and not s.challenge
end
local function Screen()
    local w,h=Read(UIParent.GetWidth,UIParent),Read(UIParent.GetHeight,UIParent)
    if w and h and w>0 and h>0 then return w,h end
end
local function Cursor()
    local ratio=Read(UIParent.GetEffectiveScale,UIParent)
    if not ratio or ratio<=0 or type(GetCursorPosition)~="function" then return end
    local ok,x,y=pcall(GetCursorPosition)
    if ok then x,y=Number(x),Number(y);if x and y then return x/ratio,y/ratio end end
end
local function Clamp(x,y,s,w,h,bw,bh)
    return Settings.ClampVisualLayout(x,y,s,w,h,bw,bh)
end
local function GridStep(w,h)
    return math.max(32,math.ceil(math.max(w,h)/96/8)*8)
end
-- Snap centers and edges before the optional grid, in UIParent coordinates.
local function SnapAxis(center,half,total,grid)
    local best
    for _,target in ipairs({0,total/2,total}) do
        for _,edge in ipairs({-half,0,half}) do
            local delta=target-(center+edge)
            if math.abs(delta)<=8 and (not best or math.abs(delta)<math.abs(best)) then best=delta end
        end
    end
    if best then return center+best end
    if grid then return total/2+math.floor((center-total/2)/grid+.5)*grid end
    return center
end
function M.SnapPosition(x,y,s,w,h,bw,bh,grid,snap)
    if snap then
        local step=grid and GridStep(w,h) or nil
        x=SnapAxis(x*w,bw*s/2,w,step)/w
        y=SnapAxis(y*h,bh*s/2,h,step)/h
    end
    return Clamp(x,y,s,w,h,bw,bh)
end
function M.Register(spec)
    if type(spec)~="table" or type(spec.key)~="string" or specs[spec.key] then return false end
    if type(spec.size)~="function" or type(spec.draft)~="function" or type(spec.sample)~="function"
        or type(spec.preview)~="function" or type(spec.finish)~="function" then return false end
    specs[spec.key]=spec
    return true
end
function M.IsActive() return session~=nil end
local function StopDrag()
    drag=nil
    if root then root:SetScript("OnUpdate",nil) end
end
local function DrawGrid(w,h)
    for _,line in ipairs(gridLines) do line:Hide() end
    if not session.grid then return end
    local count=0
    local function Line(vertical,offset,major)
        count=count+1
        local t=gridLines[count]
        if not t then t=root:CreateTexture(nil,"BACKGROUND");gridLines[count]=t end
        t:ClearAllPoints()
        t:SetColorTexture(1,.79,.37,major and .54 or .13)
        if vertical then
            t:SetPoint("CENTER",root,"CENTER",offset,0)
            t:SetSize(major and 1.5 or 1,h)
        else
            t:SetPoint("CENTER",root,"CENTER",0,offset)
            t:SetSize(w,major and 1.5 or 1)
        end
        t:Show()
    end
    local step=GridStep(w,h)
    for i=-math.floor(w/step/2),math.floor(w/step/2) do Line(true,i*step,i==0) end
    for i=-math.floor(h/step/2),math.floor(h/step/2) do Line(false,i*step,i==0) end
end
local function Paint()
    if not session then return end
    local w,h=Screen();if not w then return end
    local bw,bh=session.spec.size()
    local x,y,s=Clamp(session.x,session.y,session.scale,w,h,bw,bh)
    if not x then return end
    session.x,session.y,session.scale=x,y,s
    session.spec.draft(x,y,s)
    box:ClearAllPoints();box:SetPoint("CENTER",root,"CENTER",(x-.5)*w,(y-.5)*h)
    box:SetSize(bw*s,bh*s)
    local barScale=math.min(1,(w-24)/760)
    bar:SetScale(barScale)
    tools:SetScale(math.min(1,(w-24)/510))
    tools:ClearAllPoints()
    if y*h-bh*s/2>66 then tools:SetPoint("TOP",box,"BOTTOM",0,-15)
    else tools:SetPoint("BOTTOM",box,"TOP",0,15) end
    scaleText:SetText(string.format("Scale: %d%%",math.floor(s*100+.5)))
    painting=true;slider:SetValue(s);painting=false
end
function M.RestoreSample()
    if session and Idle() then session.spec.sample() end
end
local function Finish(save,reopen)
    if not session then return end
    local old=session
    StopDrag()
    session=nil
    if save then Settings.SetVisualLayout(old.spec.key,old.x,old.y,old.scale) end
    old.spec.finish()
    root:UnregisterAllEvents()
    root:Hide()
    if reopen and old.wasOpen and Idle() and ns.Window and not ns.Window.frame:IsShown() then
        ns.Window.Toggle()
    end
end
function M.Cancel(reopen) Finish(false,reopen~=false) end
function M.Save()
    if session and Idle() then Finish(true,true)
    elseif session then M.Cancel(false) end
end
local function DragTick()
    if not session or not drag then StopDrag();return end
    if not Idle() then M.Cancel(false);return end
    if type(IsMouseButtonDown)=="function" and not IsMouseButtonDown("LeftButton") then StopDrag();return end
    local x,y=Cursor();local w,h=Screen()
    if not x or not w then StopDrag();return end
    local bw,bh=session.spec.size()
    local dx,dy=x-drag.cx,y-drag.cy
    if drag.resize then
        local change=2*(dx*bw-dy*bh)/(bw*bw+bh*bh)
        session.scale=math.floor((drag.scale+change)*100+.5)/100
    else
        session.x,session.y,session.scale=M.SnapPosition(drag.x+dx/w,drag.y+dy/h,drag.scale,w,h,bw,bh,session.grid,session.snap)
    end
    Paint()
end
local function BeginDrag(resize,button)
    if button~="LeftButton" or not session or not Idle() then return end
    local x,y=Cursor();if not x then return end
    StopDrag();M.RestoreSample()
    drag={cx=x,cy=y,x=session.x,y=session.y,scale=session.scale,resize=resize}
    root:SetScript("OnUpdate",DragTick)
end
local function Button(parent,label,width,fn)
    local b=Style.Action(parent,label,"footer")
    b:SetSize(width,32);b:SetScript("OnClick",fn)
    return b
end
local function Check(parent,text,x,handler)
    local b=CreateFrame("CheckButton",nil,parent,"UICheckButtonTemplate")
    b:SetSize(24,24);b:SetPoint("LEFT",parent,"LEFT",x,0)
    local label=Style.Text(parent,text,14,C.pale)
    label:SetPoint("LEFT",b,"RIGHT",2,0)
    b:SetScript("OnClick",function(self) if session then handler(self:GetChecked() and true or false) end end)
    return b
end
local function Build()
    if root then return end
    root=CreateFrame("Frame","DuelsReimaginedEditMode",UIParent)
    root:SetAllPoints(UIParent);root:SetFrameStrata("FULLSCREEN_DIALOG");root:SetFrameLevel(50)
    root:EnableMouse(false);root:Hide()
    if type(UISpecialFrames)=="table" then table.insert(UISpecialFrames,"DuelsReimaginedEditMode") end
    if ns.DiagnosticAudit then ns.DiagnosticAudit.RegisterUIRoot("Duels Edit Mode",root) end
    box=CreateFrame("Frame",nil,root)
    box:SetFrameLevel(root:GetFrameLevel()+2)
    local tint=Style.Fill(box,{.68,.42,.13,.045});tint:SetAlpha(.045)
    Style.Border(box,C.gold,2)
    box:EnableMouse(true);box:SetScript("OnMouseDown",function(_,button)BeginDrag(false,button)end)
    box:SetScript("OnMouseUp",StopDrag)
    local titlePlate=CreateFrame("Frame",nil,box)
    titlePlate:SetSize(214,25);titlePlate:SetPoint("CENTER",box,"TOP",0,0)
    titlePlate:EnableMouse(false);Style.Plate(titlePlate,"hall",{corner=8})
    boxTitle=Style.Text(titlePlate,"DUEL COUNTDOWN",13,C.pale,false,"display")
    boxTitle:SetAllPoints(titlePlate);boxTitle:SetJustifyH("CENTER")
    local grip=CreateFrame("Button",nil,box)
    grip:SetSize(32,32);grip:SetPoint("BOTTOMRIGHT",box,"BOTTOMRIGHT",5,-5)
    grip:SetFrameLevel(box:GetFrameLevel()+4)
    local icon=grip:CreateTexture(nil,"ARTWORK")
    icon:SetAllPoints(grip);icon:SetTexture("Interface\\AddOns\\DuelsReimagined\\Media\\Skin\\DuelResizeCopper.png")
    local glow=grip:CreateTexture(nil,"OVERLAY")
    glow:SetAllPoints(grip);glow:SetTexture("Interface\\AddOns\\DuelsReimagined\\Media\\Skin\\DuelResizeHover.png")
    glow:SetAlpha(0);glow:SetBlendMode("ADD")
    grip:SetScript("OnEnter",function()glow:SetAlpha(.8)end)
    grip:SetScript("OnLeave",function()glow:SetAlpha(0)end)
    grip:SetScript("OnMouseDown",function(_,button)BeginDrag(true,button)end)
    grip:SetScript("OnMouseUp",StopDrag)
    if ns.Tooltips then ns.Tooltips.Bind(grip,{title="Resize countdown",detail="Drag to resize the entire effect proportionally."}) end

    bar=CreateFrame("Frame",nil,root)
    bar:SetSize(760,56);bar:SetPoint("TOP",root,"TOP",0,-22)
    bar:SetFrameLevel(root:GetFrameLevel()+15);bar:EnableMouse(true)
    Style.Plate(bar,"hall",{corner=12})
    local crest=ns.Chrome.Icon(bar,"Hall");crest:SetSize(46,46);crest:SetPoint("LEFT",bar,"LEFT",10,0)
    local name=Style.Text(bar,"DUELS EDIT MODE",23,C.pale,false,"display")
    name:SetPoint("LEFT",bar,"LEFT",66,0);name:SetWidth(235)
    name:SetWordWrap(false);Style.ConstrainText(name,235,38,12)
    gridButton=Check(bar,"Grid",305,function(v)
        session.grid=v;local w,h=Screen();if w then DrawGrid(w,h) end
    end)
    snapButton=Check(bar,"Snap",386,function(v)session.snap=v end)
    local cancel=Button(bar,"Cancel",108,function()M.Cancel(true)end)
    cancel:SetPoint("LEFT",bar,"LEFT",478,0)
    local save=Button(bar,"Save & Exit",145,function()M.Save()end)
    save:SetPoint("RIGHT",bar,"RIGHT",-12,0)

    tools=CreateFrame("Frame",nil,root)
    tools:SetSize(510,48);tools:SetClampedToScreen(true)
    tools:SetFrameLevel(root:GetFrameLevel()+12);tools:EnableMouse(true)
    Style.Plate(tools,"hall",{corner=11})
    scaleText=Style.Text(tools,"Scale: 100%",14,C.pale)
    scaleText:SetPoint("LEFT",tools,"LEFT",13,0);scaleText:SetWidth(106)
    scaleText:SetWordWrap(false);Style.ConstrainText(scaleText,106,28,10)
    slider=CreateFrame("Slider",nil,tools)
    slider:SetSize(148,25);slider:SetPoint("LEFT",tools,"LEFT",124,0)
    slider:SetOrientation("HORIZONTAL");slider:SetMinMaxValues(.5,2);slider:SetValueStep(.01)
    if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
    local track=slider:CreateTexture(nil,"BACKGROUND")
    track:SetPoint("LEFT",slider,"LEFT");track:SetPoint("RIGHT",slider,"RIGHT")
    track:SetHeight(3);track:SetColorTexture(unpack(C.goldDim))
    local thumb=slider:CreateTexture(nil,"OVERLAY")
    thumb:SetSize(16,16);thumb:SetTexture("Interface\\AddOns\\DuelsReimagined\\Media\\Textures\\SliderThumb.tga")
    slider:SetThumbTexture(thumb)
    slider:SetScript("OnValueChanged",function(_,v)
        if painting or not session then return end
        v=Number(v);if not v or not Idle() then return end
        session.scale=v;Paint();M.RestoreSample()
    end)
    local preview=Button(tools,"Preview",100,function()
        if session and Idle() then StopDrag();session.spec.preview() end
    end)
    preview:SetPoint("LEFT",tools,"LEFT",288,0)
    local reset=Button(tools,"Reset",94,function()
        if not session then return end
        StopDrag();session.x,session.y,session.scale=.5,.5,1;Paint();M.RestoreSample()
    end)
    reset:SetPoint("RIGHT",tools,"RIGHT",-12,0)
    root:SetScript("OnHide",function()if session then M.Cancel(true)end end)
    root:SetScript("OnEvent",function(_,event)
        if not session then return end
        if event=="PLAYER_REGEN_DISABLED" or event=="PLAYER_ENTERING_WORLD" then M.Cancel(false)
        else
            StopDrag();local w,h=Screen();if w then DrawGrid(w,h);Paint();M.RestoreSample() end
        end
    end)
end
function M.Open(key)
    if not ns.Client.IsSupported() or not Idle() then return false,"Finish combat or your duel first" end
    local spec=specs[key]
    local w,h=Screen()
    if not spec or not w then return false,"Layout unavailable" end
    if session then return true end
    Build()
    local x,y,s=Settings.GetVisualLayout(key)
    local wasOpen=ns.Window and ns.Window.frame:IsShown()
    session={spec=spec,x=x,y=y,scale=s,grid=true,snap=true,wasOpen=wasOpen}
    if ns.Widgets then ns.Widgets.CloseChoices() end
    if wasOpen then ns.Window.frame:Hide() end
    gridButton:SetChecked(true);snapButton:SetChecked(true)
    boxTitle:SetText(spec.label)
    for _,e in ipairs({"PLAYER_REGEN_DISABLED","PLAYER_ENTERING_WORLD","UI_SCALE_CHANGED","DISPLAY_SIZE_CHANGED"}) do root:RegisterEvent(e) end
    root:Show();DrawGrid(w,h);Paint();M.RestoreSample()
    return true
end
function M.GetDiagnosticResources()
    return {subscriptions=0,timers=0,dragDrivers=drag and 1 or 0}
end
local V=ns.DuelCountdown
M.Register({key="countdown",label="DUEL COUNTDOWN",size=V.LayoutSize,draft=V.SetLayoutDraft,
    sample=V.ShowLayoutSample,preview=V.Preview,finish=V.EndLayoutDraft})
