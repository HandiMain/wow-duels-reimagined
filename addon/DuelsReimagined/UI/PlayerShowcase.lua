local _,ns=...
local P={};ns.PlayerShowcase=P
local S,C=ns.Style,ns.Style.color
local function Read(v)
    return not (type(issecretvalue)=="function" and issecretvalue(v))
end
local function Call(fn,...)
    if type(fn)~="function" then return nil end
    local ok,v=pcall(fn,...)
    if ok and Read(v) then return v end
end
local function Method(object,key,...)
    if not object or type(object[key])~="function" then return false end
    return pcall(object[key],object,...)
end
local function Safe()
    if type(InCombatLockdown)~="function" then return true end
    local ok,v=pcall(InCombatLockdown)
    return ok and Read(v) and not v
end
local function UnitFor(id,scope)
    if scope~="LOCAL" or type(id)~="string" or not Safe() then return nil end
    for _,unit in ipairs({"player","target","focus"}) do
        if Call(UnitGUID,unit)==id and Call(UnitIsPlayer,unit)==true then return unit end
    end
end
function P.Race(id,scope)
    local unit=UnitFor(id,scope)
    local race=unit and Call(UnitRace,unit)
    return type(race)=="string" and race or nil
end
function P.Create(parent)
    local panel=CreateFrame("Frame",nil,parent)
    S.Skin(panel,C.body,{corner=8,edge=C.goldDim,shine=.10,shade=.10,rim=.65})
    local backdrop=panel:CreateTexture(nil,"BACKGROUND",nil,2)
    backdrop:SetPoint("TOPLEFT",panel,"TOPLEFT",6,-6);backdrop:SetPoint("BOTTOMRIGHT",panel,"BOTTOMRIGHT",-6,38)
    backdrop:SetColorTexture(.065,.055,.048,1)
    local crest=panel:CreateTexture(nil,"ARTWORK",nil,0)
    crest:SetSize(112,112);crest:SetPoint("TOP",panel,"TOP",0,-28);crest:SetAlpha(.14)
    local portrait=panel:CreateTexture(nil,"ARTWORK",nil,1)
    portrait:SetSize(118,118);portrait:SetPoint("CENTER",panel,"CENTER",0,16)
    local caption=S.Text(panel,"Character display",11,C.muted)
    caption:SetPoint("BOTTOMLEFT",panel,"BOTTOMLEFT",7,10);caption:SetPoint("BOTTOMRIGHT",panel,"BOTTOMRIGHT",-7,10)
    caption:SetJustifyH("CENTER");caption:SetWordWrap(false)
    local model,overlay,dragging,lastX,facing,zoom=nil,nil,false,nil,0,0
    local identity,scope,metadata,unit,requestedModel
    local ready=false
    local events=CreateFrame("Frame",nil,panel)
    local function StopDrag()
        dragging=false;lastX=nil
        if overlay then overlay:SetScript("OnUpdate",nil) end
    end
    local function Clear()
        ready=false;requestedModel=nil;StopDrag()
        if model then model:SetAlpha(0);Method(model,"ClearModel");model:Hide() end
        if overlay then overlay:Hide() end
    end
    local function Current()
        return unit and UnitFor(identity,scope)==unit
    end
    local function Camera()
        if not model or not Current() then return end
        Method(model,"RefreshCamera")
        Method(model,"SetPortraitZoom",zoom)
        Method(model,"SetFacing",facing)
        Method(model,"SetPosition",0,0,0)
    end
    local function CreateModel()
        if model then return true end
        local ok,frame=pcall(CreateFrame,"PlayerModel",nil,panel)
        if not ok or not frame then return false end
        model=frame
        model:SetPoint("TOPLEFT",panel,"TOPLEFT",8,-8)
        model:SetPoint("BOTTOMRIGHT",panel,"BOTTOMRIGHT",-8,40)
        model:SetFrameLevel(panel:GetFrameLevel()+1)
        model:SetAlpha(0);model:Hide()
        overlay=CreateFrame("Frame",nil,panel)
        overlay:SetAllPoints(model);overlay:SetFrameLevel(model:GetFrameLevel()+1)
        overlay:EnableMouse(true);overlay:EnableMouseWheel(true);overlay:Hide()
        model:SetScript("OnModelLoaded",function()
            if not panel:IsVisible() or not requestedModel or not Current() then return end
            ready=true;Camera();portrait:Hide();model:SetAlpha(1);overlay:Show()
            caption:SetText("Drag to rotate - Scroll to zoom")
        end)
        overlay:SetScript("OnMouseDown",function(self,button)
            if button~="LeftButton" or not ready or not Current() then return end
            local x=Call(GetCursorPosition)
            if type(x)~="number" then return end
            dragging=true;lastX=x
            self:SetScript("OnUpdate",function()
                if not dragging or not Current() or Call(IsMouseButtonDown,"LeftButton")==false then StopDrag();return end
                local cx=Call(GetCursorPosition)
                if type(cx)~="number" then StopDrag();return end
                local scale=Call(self.GetEffectiveScale,self) or 1
                if type(scale)~="number" or scale<=0 then scale=1 end
                facing=(facing+(cx-lastX)/scale*.012)%(2*math.pi);lastX=cx
                Method(model,"SetFacing",facing)
            end)
        end)
        overlay:SetScript("OnMouseUp",StopDrag);overlay:SetScript("OnHide",StopDrag)
        overlay:SetScript("OnMouseWheel",function(_,delta)
            if not ready or not Current() or not Read(delta) or type(delta)~="number" then return end
            zoom=math.max(0,math.min(1,zoom+delta*.1));Method(model,"SetPortraitZoom",zoom)
        end)
        return true
    end
    local function Refresh(force)
        if not panel:IsVisible() then return end
        local nextUnit=UnitFor(identity,scope)
        local useModel=nextUnit and (not ns.Settings or ns.Settings.Get("profileShowModel")~=false)
        if nextUnit==unit and requestedModel==useModel and ready and not force then return end
        Clear();unit=nextUnit
        local class=metadata and metadata.class
        portrait:SetTexture(type(class)=="string" and class:match("^[A-Z]+$") and
            "Interface\\Icons\\ClassIcon_"..class or "Interface\\Icons\\INV_Misc_QuestionMark")
        portrait:SetTexCoord(.07,.93,.07,.93);portrait:Show()
        caption:SetText("Character model unavailable")
        if unit and type(SetPortraitTexture)=="function" then
            if pcall(SetPortraitTexture,portrait,unit) then caption:SetText("Character portrait") end
        end
        if useModel and CreateModel() then
            requestedModel=useModel
            model:Show()
            if not Method(model,"SetUnit",unit) then Clear() end
        end
    end
    local registered=false
    local function Register()
        if registered then return end
        registered=true
        for _,event in ipairs({"PLAYER_EQUIPMENT_CHANGED","UNIT_MODEL_CHANGED","UPDATE_SHAPESHIFT_FORM","PLAYER_TARGET_CHANGED","PLAYER_FOCUS_CHANGED","PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED"}) do
            pcall(events.RegisterEvent,events,event)
        end
    end
    local function Stop()
        Clear();unit=nil;registered=false;events:UnregisterAllEvents()
    end
    events:SetScript("OnEvent",function(_,event,changed)
        if event=="UNIT_MODEL_CHANGED" and changed~=unit then return end
        if event=="PLAYER_EQUIPMENT_CHANGED" or event=="UPDATE_SHAPESHIFT_FORM" then
            if unit~="player" then return end
        end
        Refresh(true)
    end)
    panel:SetScript("OnHide",Stop)
    function panel.Stop() Stop() end
    function panel.Paint(id,kind,info)
        if id~=identity or kind~=scope then Clear();unit=nil;facing=0;zoom=0 end
        identity,scope,metadata=id,kind,info
        local faction=info and info.faction
        local tint=not ns.Settings or ns.Settings.Get("profileFactionBackdrop")~=false
        if tint and faction=="Alliance" then backdrop:SetColorTexture(.045,.07,.12,1)
        elseif tint and faction=="Horde" then backdrop:SetColorTexture(.13,.045,.035,1)
        else backdrop:SetColorTexture(.065,.055,.048,1) end
        crest:SetShown(tint and (faction=="Alliance" or faction=="Horde"))
        if faction=="Alliance" or faction=="Horde" then crest:SetTexture("Interface\\TargetingFrame\\UI-PVP-"..faction) end
        if panel:IsVisible() then
            if kind=="LOCAL" then Register() end
            Refresh(false)
        end
    end
    panel:Hide()
    return panel
end
