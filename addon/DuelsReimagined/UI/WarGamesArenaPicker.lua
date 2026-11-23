local _, ns = ...

-- Retail-only visual War Games arena picker. Presentation and temporary
-- selection live here; Core/WarGames is still the only request/gameplay owner.
-- Blizzard's own client textures are the ONLY map art. Never show generated
-- approximations or a different arena when a texture is missing.
local Engine, Window, Style = ns.WarGames, ns.Window, ns.Style
local Motion, Widgets, Settings = ns.Motion, ns.Widgets, ns.Settings
local C = Style.color
local Picker = {}
ns.WarGamesArenaPicker = Picker

-- These paths are documented by Details!' arena-info list and Blizzard's
-- legacy PVPFrame/LFG frame. Each refers to the NAMED arena, not its region.
-- Paths are validated against this Retail client's file index before use.
local LOAD = "Interface\\Glues\\LoadingScreens\\"
local LFG = "Interface\\LFGFrame\\"
local visuals = {
    ["Nagrand Arena"] = {
        {LOAD.."LoadScreenNagrandArenaBattlegrounds", {0,1,0.341796875,1}},
        {LFG.."LFGIcon-NagrandArena"},
    },
    ["Blade's Edge Arena"] = {
        {LOAD.."LoadScreenBladesEdgeArena", {0,1,0.29296875,0.9375}},
        {LFG.."LFGIcon-BladesEdgeArena"},
    },
    ["Ruins of Lordaeron"] = {
        {LOAD.."LoadScreenRuinsofLordaeronBattlegrounds", {0,1,0.341796875,1}},
        {LFG.."LFGIcon-RuinsofLordaeron"},
    },
    ["Dalaran Sewers"] = {
        {LOAD.."LoadScreenDalaranSewersArena", {0,1,0.29296875,0.857421875}},
        {LFG.."LFGIcon-DalaranSewers"},
    },
    ["Tol'viron Arena"] = {
        {LOAD.."LoadScreenTolvirArena", {0,1,0.29296875,0.857421875}},
    },
    ["The Tiger's Peak"] = {
        {LOAD.."LoadingScreen_Shadowpan_bg", {0,1,0.29296875,0.857421875}},
    },
    ["Ashamane's Fall"] = {
        {LOAD.."LoadingScreen_ArenaValSharah_wide", {0,1,0.29296875,0.857421875}},
    },
    ["Black Rook Hold Arena"] = {
        {LOAD.."LoadingScreen_BlackrookHoldArena_wide", {0,1,0.29296875,0.857421875}},
    },
}
local resolved = {}
local function FileID(path)
    if type(GetFileIDFromPath) == "function" then
        local ok,id=pcall(GetFileIDFromPath,path)
        if ok and type(id)=="number" and id>0 then return id end
    end
    local fn=C_UIFileAsset and C_UIFileAsset.GetFileID
    if type(fn)=="function" then
        local ok,id=pcall(fn,path)
        if ok and type(id)=="number" and id>0 then return id end
    end
end
local function Art(name)
    if resolved[name] then return unpack(resolved[name]) end
    local candidates = visuals[name]
    if not candidates then return nil end
    for _, item in ipairs(candidates) do
        -- Legacy client art can be indexed with or without the BLP extension.
        for _, path in ipairs({item[1]..".blp", item[1]}) do
            local id = FileID(path)
            if id then
                local entry = {id, item[2] or {0,1,0,1}}
                resolved[name] = entry
                return unpack(entry)
            end
        end
    end
end
local function PaintArt(image, missing, name, wide)
    local id, coords = Art(name)
    if id then
        image:SetTexture(id)
        if wide then
            -- Extra vertical crop for narrow 3:1 gallery cards, avoiding
            -- distortion of the game's original arena environment geometry.
            local top,bottom=coords[3],coords[4]
            local mid=(top+bottom)/2
            local half=(bottom-top)*0.34
            image:SetTexCoord(coords[1],coords[2],mid-half,mid+half)
        else
            image:SetTexCoord(unpack(coords))
        end
    else
        image:SetColorTexture(unpack(C.nav))
        image:SetTexCoord(0,1,0,1)
    end
    missing:SetShown(id == nil)
    return id ~= nil
end

-- The collapsed arena control stays modest in both original setup cards.
-- It has one large hit target; the 'Change Arena' relief is decorative, not a
-- nested button that could steal focus or cause a double selection.
function Picker.CreatePreview(parent, page)
    local button = CreateFrame("Button", nil, parent)
    button:RegisterForClicks("LeftButtonUp")
    button:SetSize(235,72)
    Style.Skin(button,C.body,{
        corner=9,edge=C.border,light=C.goldDim,shine=0.22,shade=0.19,
    })
    local art = button:CreateTexture(nil,"ARTWORK")
    art:SetPoint("LEFT",button,"LEFT",4,0)
    art:SetSize(90,56)
    local missing = Style.Text(button,"NO PREVIEW",10,C.muted)
    missing:SetJustifyH("CENTER")
    missing:SetPoint("CENTER",art,"CENTER")
    missing:SetWidth(78)
    local title = Style.Text(button,"Choose arena",12,C.pale)
    title:SetPoint("TOPLEFT",button,"TOPLEFT",103,-10)
    title:SetPoint("TOPRIGHT",button,"TOPRIGHT",-7,-10)
    title:SetHeight(17)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    local relief = CreateFrame("Frame",nil,button)
    relief:SetPoint("BOTTOMLEFT",button,"BOTTOMLEFT",102,6)
    relief:SetPoint("BOTTOMRIGHT",button,"BOTTOMRIGHT",-6,6)
    relief:SetHeight(25)
    Style.Skin(relief,C.selected,{
        corner=7,edge=C.goldDim,light=C.goldDim,shine=0.22,shade=0.12,
    })
    local caption = Style.Text(relief,"Change Arena  ›",11,C.pale)
    caption:SetPoint("CENTER",relief,"CENTER",0,0)
    local hover = Style.Fill(button,C.goldDim,"OVERLAY")
    hover:SetAlpha(0)
    button:SetScript("OnEnter",function()
        Motion.Fade(hover,0.17,Motion.Duration("quick"))
    end)
    button:SetScript("OnLeave",function()
        Motion.Fade(hover,0,Motion.Duration("quick"))
    end)
    Widgets.PressFeedback(button,hover)
    button:SetScript("OnClick",function() Picker.Open(page) end)
    function button:Refresh(map)
        local name = map and map.name or "Choose arena"
        self.mapName = name
        title:SetText(name)
        PaintArt(art,missing,name)
    end
    function button:Resize(width)
        self:SetWidth(width)
        local imageWidth = math.max(68,math.min(120,width*0.44))
        art:SetSize(imageWidth,math.min(64,imageWidth*0.59))
        missing:SetWidth(imageWidth-4)
        title:ClearAllPoints()
        title:SetPoint("TOPLEFT",self,"TOPLEFT",imageWidth+13,-10)
        title:SetPoint("TOPRIGHT",self,"TOPRIGHT",-7,-10)
        relief:ClearAllPoints()
        relief:SetPoint("BOTTOMLEFT",self,"BOTTOMLEFT",imageWidth+12,6)
        relief:SetPoint("BOTTOMRIGHT",self,"BOTTOMRIGHT",-6,6)
        -- At minimum width, a short caption avoids overflowing the button.
        caption:SetText(width<194 and "Change" or "Change Arena  ›")
    end
    ns.Tooltips.Bind(button,function()
        return {title=button.mapName or "Choose arena",
            detail="Open the arena gallery. Only genuine, client-provided arena art is displayed; a missing preview does not disable an arena.",
            anchor="RIGHT"}
    end)
    button:Refresh()
    return button
end

local shade = CreateFrame("Button",nil,Window.frame)
shade:SetAllPoints(Window.frame)
shade:SetFrameLevel(Window.frame:GetFrameLevel()+57)
shade:EnableMouse(true)
local tint = Style.Fill(shade,C.window,"BACKGROUND")
tint:SetAlpha(0.22)
shade:Hide()
local popup = CreateFrame("Frame","DuelsReimaginedArenaPicker",shade)
popup:SetSize(484,453)
popup:SetPoint("CENTER",Window.content,"CENTER",0,-6)
popup:SetFrameLevel(shade:GetFrameLevel()+1)
popup:EnableMouse(true)
popup:SetClampedToScreen(true)
Style.Skin(popup,C.nav,{
    corner=11,edge=C.gold,light=C.goldDim,shine=0.28,shade=0.20,rim=0.92,
})
local heading = Style.Text(popup,"CHOOSE ARENA",21,C.pale,nil,"display")
heading:SetPoint("TOP",popup,"TOP",0,-13)
local rule = Style.Fill(popup,C.goldDim,"BORDER")
rule:SetPoint("TOPLEFT",popup,"TOPLEFT",13,-42)
rule:SetPoint("TOPRIGHT",popup,"TOPRIGHT",-13,-42)
rule:SetHeight(1)
rule:SetAlpha(0.55)

local function Action(text,width)
    local b = Style.Action(popup,text,"footer",{
        fill=C.button,edge=C.goldDim,light=C.goldDim,
        dark=C.window,hover=C.selected,text=C.pale,
    })
    b:SetSize(width,30)
    return b
end
local close = Action("X",27)
close:SetPoint("TOPRIGHT",popup,"TOPRIGHT",-10,-9)
local search = CreateFrame("EditBox",nil,popup)
search:SetSize(213,29)
search:SetPoint("TOPLEFT",popup,"TOPLEFT",16,-53)
search:SetAutoFocus(false)
search:SetMaxLetters(72)
search:SetFontObject(GameFontHighlightSmall)
search:SetTextInsets(9,8,0,0)
Style.Skin(search,C.body,{corner=9,edge=C.border,shine=0.18,shade=0.19})
local hint = Style.Text(search,"Search arenas...",12,C.muted)
hint:SetPoint("LEFT",search,"LEFT",9,0)
local all = Action("All Arenas",101)
all:SetPoint("TOPLEFT",search,"TOPRIGHT",9,0)
local favorites = Action("★ Favorites",108)
favorites:SetPoint("TOPLEFT",all,"TOPRIGHT",7,0)
local allSelected=Style.Fill(all,C.selected,"ARTWORK")
allSelected:SetAllPoints(all)
local favoritesSelected=Style.Fill(favorites,C.selected,"ARTWORK")
favoritesSelected:SetAllPoints(favorites)

local scroll = CreateFrame("ScrollFrame",nil,popup)
scroll:SetPoint("TOPLEFT",popup,"TOPLEFT",16,-96)
scroll:SetPoint("BOTTOMRIGHT",popup,"BOTTOMRIGHT",-29,63)
scroll:EnableMouseWheel(true)
local canvas = CreateFrame("Frame",nil,scroll)
canvas:SetSize(423,296)
scroll:SetScrollChild(canvas)
local empty = Style.Text(scroll,"No matching arenas. Clear search or switch to All Arenas.",13,C.muted)
empty:SetPoint("TOP",scroll,"TOP",0,-18)
empty:SetWidth(380)
empty:SetJustifyH("CENTER")
empty:SetWordWrap(true)
empty:Hide()

local cancel = Action("Cancel",142)
cancel:SetPoint("BOTTOMRIGHT",popup,"BOTTOM",-6,14)
local confirm = Action("Select Arena",142)
confirm:SetPoint("BOTTOMLEFT",popup,"BOTTOM",6,14)

local currentPage, pending, onlyFavorite = nil, nil, false
local entries, cards = {}, {}
local function Close()
    if not popup:IsShown() then shade:Hide(); return end
    search:ClearFocus()
    popup:Hide()
    shade:Hide()
end
function Picker.Close() Close() end
shade:SetScript("OnClick",Close)
close:SetScript("OnClick",Close)
cancel:SetScript("OnClick",Close)
popup:SetScript("OnHide",function()
    shade:Hide()
    search:ClearFocus()
    ns.Tooltips.Hide(nil,true)
end)
shade:SetScript("OnHide",function()
    popup:Hide()
end)
if type(UISpecialFrames)=="table" then
    table.insert(UISpecialFrames,"DuelsReimaginedArenaPicker")
end

local function Card()
    local b=CreateFrame("Button",nil,canvas)
    b:RegisterForClicks("LeftButtonUp")
    b:SetSize(205,91)
    Style.Skin(b,C.body,{corner=9,edge=C.goldDim,shine=0.15,shade=0.12})
    local art=b:CreateTexture(nil,"ARTWORK")
    art:SetPoint("TOPLEFT",b,"TOPLEFT",3,-3)
    art:SetPoint("BOTTOMRIGHT",b,"BOTTOMRIGHT",-3,23)
    local missing=Style.Text(b,"PREVIEW UNAVAILABLE",10,C.muted)
    missing:SetPoint("CENTER",art,"CENTER")
    local bar=Style.Fill(b,C.nav,"ARTWORK")
    bar:SetPoint("BOTTOMLEFT",b,"BOTTOMLEFT",3,3)
    bar:SetPoint("BOTTOMRIGHT",b,"BOTTOMRIGHT",-3,3)
    bar:SetHeight(21)
    bar:SetAlpha(0.92)
    local label=Style.Text(b,"",12,C.pale)
    label:SetPoint("BOTTOMLEFT",b,"BOTTOMLEFT",7,6)
    label:SetPoint("BOTTOMRIGHT",b,"BOTTOMRIGHT",-7,6)
    label:SetJustifyH("CENTER")
    label:SetWordWrap(false)
    local selected=Style.Fill(b,C.selected,"ARTWORK")
    selected:SetAllPoints(b)
    selected:SetAlpha(0)
    -- Gold edges are separate so the selection never becomes a square
    -- opaque tint that conceals the real arena thumbnail.
    local rim={}
    for i=1,4 do
        rim[i]=Style.Fill(b,C.gold,"OVERLAY")
        rim[i]:Hide()
    end
    rim[1]:SetPoint("TOPLEFT",b,"TOPLEFT",0,0)
    rim[1]:SetPoint("TOPRIGHT",b,"TOPRIGHT",0,0)
    rim[1]:SetHeight(2)
    rim[2]:SetPoint("BOTTOMLEFT",b,"BOTTOMLEFT",0,0)
    rim[2]:SetPoint("BOTTOMRIGHT",b,"BOTTOMRIGHT",0,0)
    rim[2]:SetHeight(2)
    rim[3]:SetPoint("TOPLEFT",b,"TOPLEFT",0,0)
    rim[3]:SetPoint("BOTTOMLEFT",b,"BOTTOMLEFT",0,0)
    rim[3]:SetWidth(2)
    rim[4]:SetPoint("TOPRIGHT",b,"TOPRIGHT",0,0)
    rim[4]:SetPoint("BOTTOMRIGHT",b,"BOTTOMRIGHT",0,0)
    rim[4]:SetWidth(2)
    local check=Style.Text(b,"✓",20,C.gold)
    check:SetPoint("TOPRIGHT",b,"TOPRIGHT",-7,-3)
    check:Hide()
    local star=CreateFrame("Button",nil,b)
    star:SetSize(24,24)
    star:SetPoint("TOPLEFT",b,"TOPLEFT",3,-3)
    star:RegisterForClicks("LeftButtonUp")
    local starLabel=Style.Text(star,"☆",18,C.gold)
    starLabel:SetPoint("CENTER",star,"CENTER",0,0)
    local hover=Style.Fill(b,C.goldDim,"OVERLAY")
    hover:SetAllPoints(b)
    hover:SetAlpha(0)
    b:SetScript("OnEnter",function()
        Motion.Fade(hover,0.16,Motion.Duration("quick"))
    end)
    b:SetScript("OnLeave",function()
        Motion.Fade(hover,0,Motion.Duration("quick"))
    end)
    Widgets.PressFeedback(b,hover)
    b:SetScript("OnClick",function()
        if b.index then pending=b.index; Picker.Refresh() end
    end)
    star:SetScript("OnClick",function()
        if b.name and Settings.ToggleWarGamesArenaFavorite then
            Settings.ToggleWarGamesArenaFavorite(b.name)
            Picker.Refresh()
        end
    end)
    b:EnableMouseWheel(true)
    b:SetScript("OnMouseWheel",function(_,delta)
        local handler=scroll:GetScript("OnMouseWheel")
        if handler then handler(scroll,delta) end
    end)
    ns.Tooltips.Bind(b,function()
        return {title=b.name or "Arena",
            detail=(b.hasArt and "Genuine World of Warcraft client arena artwork. "
                or "No verified client artwork for this arena. ")..
                "A reference listing does not guarantee live War Game availability.",
            anchor="RIGHT"}
    end)
    ns.Tooltips.Bind(star,function()
        return {title="Arena favorite",
            detail="Save or remove this arena from your favorite list. Favorites are account-wide.",
            anchor="RIGHT"}
    end)
    return {button=b,image=art,missing=missing,label=label,star=starLabel,
        selected=selected,rim=rim,check=check}
end
local scrollbar=Widgets.ScrollBar(scroll,function()
    return scroll:GetHeight(),canvas:GetHeight(),scroll:GetVerticalScroll()
end,function(offset)scroll:SetVerticalScroll(offset)end)
scroll:SetScript("OnMouseWheel",function(self,delta)
    local max=math.max(0,canvas:GetHeight()-self:GetHeight())
    self:SetVerticalScroll(math.max(0,math.min(max,
        self:GetVerticalScroll()-(delta>0 and 103 or -103))))
    scrollbar:Refresh()
end)
scroll:SetScript("OnVerticalScroll",function()scrollbar:Refresh()end)

function Picker.Refresh()
    if not popup:IsShown() then return end
    local q=(search:GetText() or ""):lower()
    local known=Engine.GetMaps()
    entries={}
    for index,item in ipairs(known) do
        local favorite=Settings.IsWarGamesArenaFavorite and
            Settings.IsWarGamesArenaFavorite(item.name)
        if (not onlyFavorite or favorite) and
            (q=="" or item.name:lower():find(q,1,true)) then
            entries[#entries+1]={index=index,name=item.name,favorite=favorite}
        end
    end
    local colWidth=math.max(160,(scroll:GetWidth()-11)/2)
    local count=#entries
    for i,item in ipairs(entries) do
        if not cards[i] then cards[i]=Card() end
        local card=cards[i]
        local button=card.button
        button.index,button.name=item.index,item.name
        button.hasArt=PaintArt(card.image,card.missing,item.name,true)
        card.label:SetText(item.name)
        card.star:SetText(item.favorite and "★" or "☆")
        local on=item.index==pending
        card.selected:SetAlpha(on and 0.14 or 0)
        card.check:SetShown(on)
        for _,line in ipairs(card.rim) do line:SetShown(on) end
        button:ClearAllPoints()
        local col=(i-1)%2
        local row=math.floor((i-1)/2)
        button:SetPoint("TOPLEFT",canvas,"TOPLEFT",col*(colWidth+10),
            -row*100)
        button:SetWidth(colWidth)
        button:Show()
    end
    for i=#entries+1,#cards do cards[i].button:Hide() end
    canvas:SetSize(scroll:GetWidth(),math.max(scroll:GetHeight(),
        math.ceil(count/2)*100))
    local max=math.max(0,canvas:GetHeight()-scroll:GetHeight())
    scroll:SetVerticalScroll(math.max(0,math.min(max,scroll:GetVerticalScroll())))
    empty:SetShown(count==0)
    confirm:SetEnabled(count>0 and pending~=nil)
    confirm:SetAlpha(count>0 and pending~=nil and 1 or 0.48)
    allSelected:SetAlpha(not onlyFavorite and 0.36 or 0)
    favoritesSelected:SetAlpha(onlyFavorite and 0.36 or 0)
    all.label:SetTextColor(unpack(not onlyFavorite and C.pale or C.text))
    favorites.label:SetTextColor(unpack(onlyFavorite and C.gold or C.text))
    scrollbar:Refresh()
end
search:SetScript("OnTextChanged",function(self)
    hint:SetShown((self:GetText() or "")=="")
    Picker.Refresh()
end)
search:SetScript("OnEscapePressed",function(self)
    self:ClearFocus()
    Close()
end)
search:SetScript("OnEnterPressed",function(self)self:ClearFocus()end)
all:SetScript("OnClick",function()
    onlyFavorite=false
    scroll:SetVerticalScroll(0)
    Picker.Refresh()
end)
favorites:SetScript("OnClick",function()
    onlyFavorite=true
    scroll:SetVerticalScroll(0)
    Picker.Refresh()
end)
confirm:SetScript("OnClick",function()
    local page,index=currentPage,pending
    -- Another action might have changed the reference map catalogue.
    if page and index and Engine.GetMaps()[index] and
        Engine.SelectMap(page,index) then Close()
    end
end)
function Picker.Open(page)
    if page~="player" and page~="host" then return end
    if Engine.InArena() then return end
    local cfg=Engine.GetConfig(page)
    if not cfg then return end
    Widgets.CloseChoices()
    currentPage,pending,onlyFavorite=page,cfg.map,false
    search:SetText("")
    scroll:SetVerticalScroll(0)
    shade:Show()
    popup:Show()
    Picker.Refresh()
end
-- Both match pages expose their arena picker through the one addon Search.
-- Selecting a search result navigates first; it never sends a challenge.
for _, page in ipairs({"player","host"}) do
    local pageKey=page
    ns.Search.Register("wargames:arena:"..pageKey,
        "Choose Arena — "..(pageKey=="player" and "Players" or "Host"),
        "War Games / "..(pageKey=="player" and "Players" or "Host"),
        "Open the visual arena browser and search for a real arena.",
        function()
            if ns.Navigation then ns.Navigation.SelectKey("wargames",pageKey) end
            Picker.Open(pageKey)
        end,
        function() return ns.Client.IsRetail() end)
end
Window.frame:HookScript("OnHide",Close)
popup:Hide()
shade:Hide()
