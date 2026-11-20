local _, ns = ...
-- One optional entry in Blizzard's Escape menu. We own only our button;
-- the menu's button pool, layout, other addons, and protected controls
-- are never moved or rewritten here.
local GameMenu = {}
ns.GameMenu = GameMenu
local Settings = ns.Settings

local button, reference
local look, nativeTextures, nativeFont
local hooked, managed = false, false
local SECTION, GAP, MIN_GAP = 20, 4, 2

local function Wanted()
    return Settings.Get("showGameMenuButton") == true
end
local function HideOwn()
    if button then button:Hide() end
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

-- Reserve exactly one real, visible button in Blizzard's native Layout.
-- No invisible spacer and no timer-delayed button appearance. Other addons
-- can reserve their own places without leaving two gaps for our one button.
local placementState = "not-open"

local function Number(v)
    -- Check secrecy BEFORE any comparison; Midnight/Forever clients may
    -- forbid branching or arithmetic on protected layout values in combat.
    if issecretvalue and issecretvalue(v) then return false end
    return type(v) == "number" and v == v and
        v ~= math.huge and v ~= -math.huge
end
local function MenuButtons(menu)
    local pool = menu and menu.buttonPool
    if not (pool and pool.EnumerateActive) then return end
    local shop, options, addons
    for b in pool:EnumerateActive() do
        if b.GetText then
            local name = b:GetText()
            if name == _G.BLIZZARD_STORE then shop = b end
            if name == _G.GAMEMENU_OPTIONS then options = b end
            if name == _G.ADDONS then addons = b end
        end
    end
    return shop or options, addons
end
local function FindSlot(menu, upper, addons)
    local first, last = upper.layoutIndex, addons.layoutIndex
    if not (Number(first) and Number(last) and first < last) then return end

    -- A plain Frame in this range can be another addon's visible layout
    -- reservation for a manually anchored button. Insert AFTER the first
    -- such reservation; otherwise insert BEFORE the first addon button.
    -- No special cases for individual addons or fixed button indices.
    local reserved
    for _, child in ipairs({menu:GetChildren()}) do
        local idx = child.layoutIndex
        if child ~= button and child.IsShown and child:IsShown()
            and Number(idx) and idx > first and idx < last
            and child.GetObjectType and child:GetObjectType() == "Frame"
            and (not reserved or idx < reserved) then
            reserved = idx
        end
    end
    local start = reserved or first
    local nextIndex = last
    for _, child in ipairs({menu:GetChildren()}) do
        local idx = child.layoutIndex
        if child ~= button and child.IsShown and child:IsShown()
            and Number(idx) and idx > start and idx < nextIndex then
            nextIndex = idx
        end
    end
    if nextIndex <= start then return end
    return start + (nextIndex - start) * 0.5, reserved ~= nil
end

local function Reserve(menu)
    if not Wanted() then HideOwn(); placementState = "disabled"; return end
    if InCombatLockdown and InCombatLockdown() then
        HideOwn(); placementState = "combat"; return
    end
    local upper, addons = MenuButtons(menu)
    if not (upper and addons) then
        HideOwn(); placementState = "native-anchors-missing"; return
    end
    local index, afterReservation = FindSlot(menu, upper, addons)
    if not index then
        HideOwn(); placementState = "native-layout-unsupported"; return
    end
    local template = type(menu.buttonTemplate) == "string" and
        menu.buttonTemplate or "MainMenuFrameButtonTemplate"
    local b = EnsureButton(menu, template)
    reference = upper
    MatchAppearance(b, upper)
    b:ClearAllPoints()
    b.layoutIndex = index
    b.topPadding = afterReservation and GAP or SECTION
    b:Show()
    placementState = "native-layout"
end

-- All visible Menu Button CHILDREN are considered, not just Polestar/Horizon
-- or Ellesmere. A button may be manually anchored and have no layoutIndex.
-- Source: Horizon Suite's geometry-based approach, strengthened to refuse
-- any slot that cannot accommodate our full button without intersection.
local function FindGap(menu, b, upper, lower)
    if not (upper and lower) then return end
    local upperBottom, lowerTop = upper:GetBottom(), lower:GetTop()
    local height = b:GetHeight()
    if not (Number(upperBottom) and Number(lowerTop) and
        Number(height) and height > 0 and upperBottom > lowerTop) then return end

    local list = {upper, lower}
    local upperTop = upper:GetTop()
    local lowerBottom = lower:GetBottom()
    if not (Number(upperTop) and Number(lowerBottom)) then return end
    local left, right = lower:GetLeft(), lower:GetRight()
    if not (Number(left) and Number(right)) then return end
    for _, child in ipairs({menu:GetChildren()}) do
        if child ~= b and child ~= upper and child ~= lower and
            child.IsShown and child:IsShown() and
            child.GetObjectType and child:GetObjectType() == "Button" then
            local t, bottom = child:GetTop(), child:GetBottom()
            local l, r = child:GetLeft(), child:GetRight()
            if Number(t) and Number(bottom) and Number(l) and Number(r)
                and t <= upperBottom + 1 and bottom >= lowerTop - 1
                and l < right and r > left then
                list[#list + 1] = child
            end
        end
    end
    table.sort(list, function(a, b)
        return a:GetTop() > b:GetTop()
    end)
    -- Fill the first safe gap. Late-loading addons may choose their anchor
    -- from the closest button above AddOns, so avoid moving below them.
    for i = 1, #list - 1 do
        local above, below = list[i], list[i + 1]
        local space = above:GetBottom() - below:GetTop()
        if Number(space) and space >= height + MIN_GAP * 2 then
            return above, space
        end
    end
end

local function Settle(menu)
    if not Wanted() or not menu or not menu:IsShown() or not button then return end
    if InCombatLockdown and InCombatLockdown() then
        HideOwn(); placementState = "combat"; return
    end
    local upper, addons = MenuButtons(menu)
    if not (upper and addons) then
        HideOwn(); placementState = "native-anchors-missing"; return
    end
    MatchAppearance(button, upper)
    local above, space = FindGap(menu, button, upper, addons)
    local top = menu:GetTop()
    local bottomOfAbove = above and above:GetBottom()
    if not (above and Number(space) and Number(top)
        and Number(bottomOfAbove)) then
        -- Refuse a position that would overlap another addon. Drop our
        -- layout index too, so future layouts cannot reserve a ghost slot.
        button:Hide()
        button.layoutIndex, button.topPadding = nil, nil
        placementState = "crowded"
        return
    end

    -- Never anchor to a foreign button. Horizon and similar addons can
    -- anchor to ours; a reciprocal anchor causes a circular dependency.
    -- This menu-relative anchor stays stable without additional timers.
    local targetTop = bottomOfAbove - (space - button:GetHeight()) * 0.5
    local offset = top - targetTop
    if not Number(offset) then
        button:Hide()
        button.layoutIndex, button.topPadding = nil, nil
        placementState = "invalid-geometry"
        return
    end
    button:ClearAllPoints()
    button:SetPoint("TOP", menu, "TOP", 0, -offset)
    button:Show()
    placementState = "visible"
end

-- Fallback for clients without the dynamic Blizzard GameMenu layout. Keep a
-- Blizzard-native button outside the bottom of the fixed menu, but fail closed
-- if a visible menu button would occupy the same rectangle.
local function Legacy(menu)
    if not Wanted() then HideOwn(); return end
    if InCombatLockdown and InCombatLockdown() then return end
    local b = EnsureButton(menu, "UIPanelButtonTemplate")
    reference = _G.GameMenuButtonContinue
    b.layoutIndex, b.topPadding = nil, nil
    b:ClearAllPoints()
    b:SetPoint("TOP", menu, "BOTTOM", 0, -4)
    MatchAppearance(b, reference)
    b:Show()
    local l, r, t, bottom = b:GetLeft(), b:GetRight(), b:GetTop(), b:GetBottom()
    if not (Number(l) and Number(r) and Number(t) and Number(bottom)) then
        b:Hide(); return
    end
    for _, child in ipairs({menu:GetChildren()}) do
        if child ~= b and child.IsShown and child:IsShown() and
            child.GetObjectType and child:GetObjectType() == "Button" then
            local cl, cr, ct, cb = child:GetLeft(), child:GetRight(),
                child:GetTop(), child:GetBottom()
            if Number(cl) and Number(cr) and Number(ct) and Number(cb) and
                l < cr and r > cl and t > cb and bottom < ct then
                b:Hide()
                placementState="legacy-crowded"
                return
            end
        end
    end
    placementState="legacy-visible"
end

function GameMenu.GetPlacementStatus() return placementState end
function GameMenu.Refresh()
    local menu = _G.GameMenuFrame
    if not Wanted() then
        HideOwn(); placementState = "disabled"; return
    end
    if menu and menu:IsShown() then
        if managed then
            -- The next Blizzard InitButtons will reserve the native slot.
            -- Do not call Blizzard Layout ourselves from addon settings.
            Settle(menu)
        else
            Legacy(menu)
        end
    end
end

local function Install()
    local menu = _G.GameMenuFrame
    if not menu or hooked then return end
    hooked = true
    if type(menu.InitButtons) == "function" then
        managed = true
        hooksecurefunc(menu, "InitButtons", function(m) Reserve(m) end)
        if type(menu.Layout) == "function" then
            hooksecurefunc(menu, "Layout", function(m)
                if Wanted() then Settle(m) end
            end)
        end
        menu:HookScript("OnShow", function() Settle(menu) end)
        menu:HookScript("OnHide", function()
            if button then button:Hide() end
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
