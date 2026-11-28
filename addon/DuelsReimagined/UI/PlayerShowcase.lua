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
function P.PaintPortrait(texture,id,scope,info)
    local class=info and info.class
    texture:SetTexture(type(class)=="string" and class:match("^[A-Z]+$") and
        "Interface\\Icons\\ClassIcon_"..class or "Interface\\Icons\\INV_Misc_QuestionMark")
    texture:SetTexCoord(.07,.93,.07,.93)
    local unit=UnitFor(id,scope)
    return unit and type(SetPortraitTexture)=="function" and pcall(SetPortraitTexture,texture,unit)
end
function P.Race(id,scope)
    local unit=UnitFor(id,scope)
    local race=unit and Call(UnitRace,unit)
    return type(race)=="string" and race or nil
end
-- One painter for the native game art in the gallery and model panel.
-- SetTexture's boolean is not a file-existence check. Resolve native paths
-- through the client when possible and validate its returned texture value.
local nativeIds={}
local function NativeTexture(texture,path)
    if type(path)~="string" then return false end
    local id=nativeIds[path]
    if not id then
        local file=Call(GetFileIDFromPath,path..".blp") or Call(GetFileIDFromPath,path)
        if type(file)=="number" and file>0 then id=file;nativeIds[path]=id end
    end
    if not Method(texture,"SetTexture",id or path) then return false end
    local resolved=Call(texture.GetTexture,texture)
    if type(resolved)=="number" then return resolved>0 end
    if type(resolved)=="string" then return resolved~="" and resolved~="?" and resolved~="Solid Texture" end
    return id~=nil and type(texture.GetTexture)~="function"
end
local function FitUV(texture,w,h,sourceAspect,l,r,t,b)
    l,r,t,b=l or 0,r or 1,t or 0,b or 1
    local target=type(w)=="number" and type(h)=="number" and w>0 and h>0 and w/h or sourceAspect
    if target<sourceAspect then
        local inset=(r-l)*(1-target/sourceAspect)/2;l=l+inset;r=r-inset
    elseif target>sourceAspect then
        local inset=(b-t)*(1-sourceAspect/target)/2;t=t+inset;b=b-inset
    end
    texture:SetTexCoord(l,r,t,b)
end
function P.FactionForArt(art,faction)
    if not art then return nil end
    if art.faction=="Alliance" or art.faction=="Horde" then return art.faction end
    if art.autoFaction or art.id=="faction" then return faction end
end
function P.PaintBackdrop(texture,art,faction,w,h)
    texture:SetVertexColor(1,1,1,1)
    if art and art.atlas then
        local info=Call(C_Texture and C_Texture.GetAtlasInfo,art.atlas)
        if type(info)=="table" and Method(texture,"SetAtlas",art.atlas,false) then
            local fields={info.width,info.height,info.leftTexCoord,info.rightTexCoord,info.topTexCoord,info.bottomTexCoord}
            local valid=true
            for i=1,6 do if not Read(fields[i]) or type(fields[i])~="number" then valid=false;break end end
            if valid and fields[1]>0 and fields[2]>0 and fields[3]<fields[4] and fields[5]<fields[6] then
                FitUV(texture,w,h,fields[1]/fields[2],fields[3],fields[4],fields[5],fields[6])
            end
            texture:SetVertexColor(.78,.78,.78,1);return "native"
        end
    end
    if art and art.native then
        for _,path in ipairs(art.native) do
            if NativeTexture(texture,path) then
                FitUV(texture,w,h,art.spec and 1 or 1.5)
                texture:SetVertexColor(.76,.76,.76,1)
                return "native"
            end
        end
    end
    -- Explicit custom texture compatibility; the Warcraft catalogue itself
    -- uses client artwork and does not ship copies of Blizzard textures.
    if art and art.texture then
        texture:SetTexture(art.texture);FitUV(texture,w,h,1);return "native"
    end
    if art and art.icon and NativeTexture(texture,art.icon) then
        FitUV(texture,w,h,1);texture:SetVertexColor(.42,.42,.42,1);return "alternate"
    end
    local color=art and art.color or {.065,.055,.048}
    local heraldry=P.FactionForArt(art,faction)
    if heraldry=="Horde" then color={.13,.045,.035}
    elseif heraldry=="Alliance" then color={.045,.07,.12} end
    texture:SetTexCoord(0,1,0,1)
    texture:SetColorTexture(color[1],color[2],color[3],1)
    return art and (art.native or art.atlas or art.icon) and "alternate" or "default"
end
function P.PaintFactionCrest(crest,faction)
    if faction~="Alliance" and faction~="Horde" then crest:Hide();return 1 end
    local name="talenttree-"..string.lower(faction).."-cornerlogo"
    local info=Call(C_Texture and C_Texture.GetAtlasInfo,name)
    local aspect=1
    local painted=false
    if type(info)=="table" and Read(info.width) and Read(info.height)
        and type(info.width)=="number" and type(info.height)=="number"
        and info.width>0 and info.height>0 then
        painted=Method(crest,"SetAtlas",name,false)
        if painted then aspect=info.width/info.height end
    end
    if not painted then
        crest:SetTexture("Interface\\Timer\\"..faction.."-Logo")
        crest:SetTexCoord(0,1,0,1)
    end
    if faction=="Alliance" then crest:SetVertexColor(.83,.69,.43)
    else crest:SetVertexColor(.88,.52,.40) end
    crest:Show();return aspect
end
-- A real encounter-journal character portrait may be layered above the
-- scene, or the native faction crest for the faction defaults.
function P.PaintBackdropMark(mark,art,faction,thumbnail)
    mark:Hide()
    local heraldry=P.FactionForArt(art,faction)
    if heraldry=="Alliance" or heraldry=="Horde" then
        local aspect=P.PaintFactionCrest(mark,heraldry)
        mark:SetAlpha(thumbnail and .6 or .14)
        return aspect
    end
    if art and art.figure and NativeTexture(mark,art.figure) then
        mark:SetTexCoord(0,1,0,1);mark:SetVertexColor(.85,.85,.85,1)
        mark:SetAlpha(thumbnail and .92 or .66);mark:Show()
        return 1.5
    end
end
function P.CreateBorder(parent)
    local skin=S.Skin(parent,C.body,{corner=8,edge=C.goldDim,shine=.10,shade=.10,rim=.82})
    local inner=S.SkinMask and S.SkinMask(parent,C.goldDim,"rim","BORDER",1,7,3)
    if inner then inner:SetAlpha(0) end
    return {skin=skin,inner=inner}
end
function P.PaintBorder(border,art)
    if not border then return end
    local rim=border.skin and border.skin.groups and border.skin.groups[4]
    local color=art and art.color or C.goldDim
    if rim then for _,texture in ipairs(rim.regions) do texture:SetVertexColor(color[1],color[2],color[3],1) end end
    if border.inner then
        local accent=art and art.accent or color
        for _,texture in ipairs(border.inner.regions) do texture:SetVertexColor(accent[1],accent[2],accent[3],1) end
        border.inner:SetAlpha(art and art.id~="bronze" and .85 or 0)
    end
end
function P.Create(parent)
    local panel=CreateFrame("Frame",nil,parent)
    local border=P.CreateBorder(panel)
    local backdrop=panel:CreateTexture(nil,"BACKGROUND",nil,2)
    backdrop:SetPoint("TOPLEFT",panel,"TOPLEFT",6,-6);backdrop:SetPoint("BOTTOMRIGHT",panel,"BOTTOMRIGHT",-6,38)
    backdrop:SetColorTexture(.065,.055,.048,1)
    -- Native faction heraldry, not the battleground/portrait badge.
    local crest=panel:CreateTexture(nil,"ARTWORK",nil,0)
    local crestAspect=1
    local function FitCrest()
        local w,h=panel:GetWidth(),panel:GetHeight()
        if not Read(w) or not Read(h) or type(w)~="number" or type(h)~="number" or w<=0 or h<=0 then return end
        local width=math.min(w*.86,math.max(1,h-64)*crestAspect)
        crest:SetSize(width,width/crestAspect)
        crest:ClearAllPoints()
        crest:SetPoint("TOP",panel,"TOP",0,-math.max(20,h*.12))
    end
    panel:HookScript("OnSizeChanged",FitCrest)
    crest:SetAlpha(.14);crest:Hide()
    local art,artFaction,artMode
    local function PaintMark()
        local aspect=P.PaintBackdropMark(crest,art,artFaction,false)
        if aspect then crestAspect=aspect;FitCrest() end
        if art and art.figure and not aspect then artMode="alternate" end
    end
    local function FitBackdrop()
        local w,h=panel:GetWidth(),panel:GetHeight()
        if art and Read(w) and Read(h) and type(w)=="number" and type(h)=="number" then
            artMode=P.PaintBackdrop(backdrop,art,artFaction,w-12,h-44)
        end
    end
    panel:HookScript("OnSizeChanged",FitBackdrop)
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
        local hasPortrait=P.PaintPortrait(portrait,identity,scope,metadata)
        portrait:Show()
        caption:SetText(hasPortrait and "Character portrait" or "Character model unavailable")
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
    function panel.Reparent(host)
        if panel:GetParent()==host then return end
        panel:SetParent(host);panel:SetFrameLevel(host:GetFrameLevel()+1)
        if model then model:SetFrameLevel(panel:GetFrameLevel()+1) end
        if overlay then overlay:SetFrameLevel(model:GetFrameLevel()+1) end
    end
    function panel.Paint(id,kind,info,appearance)
        if id~=identity or kind~=scope then Clear();unit=nil;facing=0;zoom=0 end
        identity,scope,metadata=id,kind,info
        local faction=info and info.faction
        local tint=not ns.Settings or ns.Settings.Get("profileFactionBackdrop")~=false
        art=appearance and appearance.background or {id=tint and "faction" or "bronze"}
        artFaction=faction
        FitBackdrop()
        PaintMark()
        P.PaintBorder(border,appearance and appearance.border)
        if panel:IsVisible() then
            if kind=="LOCAL" then Register() end
            Refresh(false)
        end
        return artMode
    end
    panel:Hide()
    return panel
end
