local _, ns = ...
-- One optional entry in Blizzard's Escape menu. We own only our button and
-- spacer; the menu's button pool, layout, other addons, and protected controls
-- are never moved or rewritten here.
local GameMenu = {}
ns.GameMenu = GameMenu
local Settings = ns.Settings

local button, spacer, reference
local look, nativeTextures, nativeFont
local hooked, managed = false, false
local SECTION, GAP = 20, 4

local function Wanted()
    return Settings.Get("showGameMenuButton") == true
end
local function HideOwn()
    if button then button:Hide() end
    if spacer then spacer:Hide() end
end
local function MenuSkinActive()
    local addons = _G.C_AddOns
    local enabled = addons and type(addons.IsAddOnLoaded) == "function"
        and addons.IsAddOnLoaded("EllesmereUIBlizzardSkin")
    if not enabled and type(_G.IsAddOnLoaded) == "function" then
        enabled = _G.IsAddOnLoaded("EllesmereUIBlizzardSkin")
    end
    local db = _G.EllesmereUIDB
    return enabled and type(_G.EllesmereUI) == "table" and
        not (type(db) == "table" and db.reskinGameMenu == false)
end

local function PaintFont(b, source)
    local mine = b:GetFontString()
    local other = source and source.GetFontString and source:GetFontString()
    if not mine or not other then return end
    local file, size, flags = other:GetFont()
    if file and size then mine:SetFont(file, size, flags or "") end
end
local function ColorCode(r, g, b)
    if type(r) ~= "number" or type(g) ~= "number" or
        type(b) ~= "number" then return nil end
    r = math.floor(math.max(0, math.min(1, r)) * 255 + 0.5)
    g = math.floor(math.max(0, math.min(1, g)) * 255 + 0.5)
    b = math.floor(math.max(0, math.min(1, b)) * 255 + 0.5)
    return string.format("|cff%02x%02x%02x", r, g, b)
end
local function AccentLabel()
    local eui = _G.EllesmereUI
    local rgb
    if type(eui._getPopupMenuButtonTextColor) == "function" then
        local ok, r, g, b = pcall(eui._getPopupMenuButtonTextColor)
        if ok then
            local safe, result = pcall(ColorCode, r, g, b)
            if safe then rgb = result end
        end
    end
    if not rgb and type(eui.ELLESMERE_GREEN) == "table" then
        local c = eui.ELLESMERE_GREEN
        local safe, result = pcall(ColorCode, c.r, c.g, c.b)
        if safe then rgb = result end
    end
    return rgb and (rgb .. "Duels|r |cffffffffReimagined|r")
        or "Duels Reimagined"
end

local function Inset(b)
    if look then return look end
    local f = CreateFrame("Frame", nil, b)
    f:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
    f:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
    f:SetFrameLevel(b:GetFrameLevel())
    f:EnableMouse(false)
    local bg = f:CreateTexture(nil, "BACKGROUND", nil, -6)
    bg:SetAllPoints(f)
    local lines = {}
    for i, pair in ipairs({
        {"TOPLEFT", "TOPRIGHT"}, {"BOTTOMLEFT", "BOTTOMRIGHT"},
        {"TOPLEFT", "BOTTOMLEFT"}, {"TOPRIGHT", "BOTTOMRIGHT"},
    }) do
        local edge = f:CreateTexture(nil, "OVERLAY", nil, 7)
        edge:SetPoint(pair[1], f, pair[1], 0, 0)
        edge:SetPoint(pair[2], f, pair[2], 0, 0)
        if i < 3 then edge:SetHeight(1) else edge:SetWidth(1) end
        edge:SetColorTexture(1, 1, 1, 0.08)
        lines[#lines + 1] = edge
    end
    local highlight = b:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(f)
    highlight:SetColorTexture(1, 1, 1, 0.10)
    look = { frame = f, bg = bg, lines = lines, highlight = highlight }
    return look
end

local function MatchAppearance(b, other)
    if not b then return end
    if other and other.GetWidth and other.GetHeight then
        local w, h = other:GetWidth(), other:GetHeight()
        if type(w) == "number" and type(h) == "number"
            and w > 0 and h > 0 then b:SetSize(w, h) end
    end
    local skinned = MenuSkinActive()
    if nativeTextures then
        for tex, opacity in pairs(nativeTextures) do
            tex:SetAlpha(skinned and 0 or opacity)
        end
    end
    if not skinned then
        if look then look.frame:Hide(); look.highlight:Hide() end
        -- Do not tint the button with Duels colors. This is exactly the
        -- client's own button template when Ellesmere skinning is off.
        b:SetText("Duels Reimagined")
        if nativeFont then
            local fs = b:GetFontString()
            if fs and nativeFont[1] and nativeFont[2] then
                fs:SetFont(nativeFont[1], nativeFont[2], nativeFont[3])
                fs:SetTextColor(unpack(nativeFont[4]))
            end
        end
        return
    end

    local eui = _G.EllesmereUI
    local f = Inset(b)
    local db = _G.EllesmereUIDB
    local c = type(db) == "table" and db.popupMenuButtonBackgroundColor
    if type(c) ~= "table" then c = nil end
    f.bg:SetColorTexture(c and c.r or 0.1, c and c.g or 0.1,
        c and c.b or 0.1, c and c.a ~= nil and c.a or 0.8)
    local borderFn = eui and eui._applyBlizzardConfiguredBorder
    local ok = false
    if type(borderFn) == "function" then
        ok = pcall(borderFn, f.frame, "popupMenuButton", 1)
    end
    for _, line in ipairs(f.lines) do line:SetShown(not ok) end
    f.frame:Show()
    f.highlight:Show()
    local referenceFont = _G.EllesmereUI_GameMenuButton or other
    PaintFont(b, referenceFont)
    b:SetText(AccentLabel())
end

local function EnsureButton(menu, template)
    if button then return button end
    button = CreateFrame("Button", "DuelsReimaginedGameMenuButton",
        UIParent, template or "MainMenuFrameButtonTemplate")
    button:SetParent(menu)
    button:SetSize(144, 21)
    button:SetText("Duels Reimagined")
    button:RegisterForClicks("LeftButtonUp")
    nativeTextures = {}
    for _, region in ipairs({ button:GetRegions() }) do
        if region and region.IsObjectType and region:IsObjectType("Texture") then
            nativeTextures[region] = region:GetAlpha()
        end
    end
    local fs = button:GetFontString()
    if fs then
        local path, size, flags = fs:GetFont()
        local r, g, b, a = fs:GetTextColor()
        nativeFont = { path, size, flags or "", { r, g, b, a or 1 } }
    end
    button:SetScript("OnClick", function()
        if menu:IsShown() then
            if type(_G.HideUIPanel) == "function" then
                _G.HideUIPanel(menu)
            else
                menu:Hide()
            end
        end
        local window = ns.Window
        if window and window.frame then
            if not window.frame:IsShown() then window.Toggle()
            else window.frame:Raise() end
        end
    end)
    button:Hide()
    return button
end

-- The native pool identifies the section after Blizzard's Store button,
-- or after Options when the Store is unavailable on this client.
local function NativeReference(menu)
    if not menu.buttonPool or not menu.buttonPool.EnumerateActive then
        return nil
    end
    local options, shop, nextIndex = nil, nil, nil
    for b in menu.buttonPool:EnumerateActive() do
        local name = b.GetText and b:GetText()
        if name and name == _G.BLIZZARD_STORE then shop = b end
        if name and name == _G.GAMEMENU_OPTIONS then options = b end
    end
    local after = shop or options
    local index = after and after.layoutIndex
    if type(index) ~= "number" then return nil end
    nextIndex = index + 1
    for b in menu.buttonPool:EnumerateActive() do
        local i = b.layoutIndex
        if type(i) == "number" and i > index and i < nextIndex then
            nextIndex = i
        end
    end
    return after, index, nextIndex
end
local function EllesmereLast()
    local root = _G.EllesmereUI
    if type(root) ~= "table" or
        (InCombatLockdown and InCombatLockdown()) then return end
    local db = _G.EllesmereUIDB
    local unlock = _G.EllesmereUI_UnlockMenuButton
    if unlock and type(db) == "table" and
        db.hideUnlockMenuButton == false then return unlock end
    if _G.EllesmereUI_GameMenuButton and
        not (type(db) == "table" and db.hideGameMenuButton) then
        return _G.EllesmereUI_GameMenuButton
    end
end

local function Place(menu)
    if not Wanted() then HideOwn(); return end
    local after, index, nextIndex = NativeReference(menu)
    if not after then HideOwn(); return end
    local template = type(menu.buttonTemplate) == "string"
        and menu.buttonTemplate or "MainMenuFrameButtonTemplate"
    local b = EnsureButton(menu, template)
    reference = after
    -- Reserve the correct height BEFORE creating the spacer; a skinned
    -- Ellesmere menu may use a taller Blizzard button than our template.
    MatchAppearance(b, after)
    local polestar = _G.PolestarGameMenuButton
    local withPolestar = polestar and polestar:IsShown()
    local lastEui = EllesmereLast()
    local location = index + (nextIndex - index) * 0.75
    b:ClearAllPoints()
    if lastEui then
        if not spacer then
            spacer = CreateFrame("Frame", nil, UIParent)
            spacer:SetParent(menu)
        end
        spacer:SetSize(1, b:GetHeight() + GAP)
        spacer.layoutIndex = location
        spacer.topPadding = nil
        spacer:Show()
        b.layoutIndex, b.topPadding = nil, nil
        local anchor = withPolestar and polestar or lastEui
        b:SetPoint("TOP", anchor, "BOTTOM", 0, -GAP)
    else
        if spacer then spacer:Hide() end
        b.layoutIndex = location
        b.topPadding = withPolestar and GAP or SECTION
    end
    b:Show()
end

-- Pre-pool Forever/older clients have no dynamic InitButtons layout.
local function Legacy(menu)
    if not Wanted() then HideOwn(); return end
    local b = EnsureButton(menu, "UIPanelButtonTemplate")
    reference = _G.GameMenuButtonContinue
    b.layoutIndex, b.topPadding = nil, nil
    b:ClearAllPoints()
    b:SetPoint("TOP", menu, "BOTTOM", 0, -4)
    MatchAppearance(b, reference)
    b:Show()
end

function GameMenu.Refresh()
    local menu = _G.GameMenuFrame
    if not Wanted() then HideOwn(); return end
    if menu and menu:IsShown() then
        if managed then Place(menu) else Legacy(menu) end
    end
end

local function Install()
    local menu = _G.GameMenuFrame
    if not menu or hooked then return end
    hooked = true
    if type(menu.InitButtons) == "function" then
        managed = true
        -- Create the optional template early, outside combat, when possible.
        if Wanted() then
            local template = type(menu.buttonTemplate) == "string"
                and menu.buttonTemplate or "MainMenuFrameButtonTemplate"
            EnsureButton(menu, template)
        end
        hooksecurefunc(menu, "InitButtons", function(m) Place(m) end)
        if type(menu.Layout) == "function" then
            hooksecurefunc(menu, "Layout", function()
                if button and button:IsShown() then
                    MatchAppearance(button, reference)
                end
            end)
        end
        menu:HookScript("OnShow", function()
            if button and button:IsShown() then
                MatchAppearance(button, reference)
            end
        end)
    else
        menu:HookScript("OnShow", Legacy)
    end
end
local load = CreateFrame("Frame")
load:RegisterEvent("PLAYER_LOGIN")
load:RegisterEvent("ADDON_LOADED")
load:SetScript("OnEvent", function(self, event, name)
    if event == "PLAYER_LOGIN" or name == "Blizzard_GameMenu" then
        Install()
        if hooked then self:UnregisterAllEvents() end
    end
end)
