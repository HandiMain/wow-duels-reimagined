local _, ns = ...
local Style, Chrome, Motion = ns.Style, ns.Chrome, ns.Motion
local C, Window = Style.color, ns.Window

-- Navigation is a visual shell prototype, not a gameplay or record engine.
local sections = {
    { key = "hall", label = "Hall", icon = "Hall", pages = {
        { key = "overview", label = "Overview", title = "Welcome to the Hall",
          subtitle = "Your dueling journey starts here.",
          emptyTitle = "No duels recorded yet",
          emptyDetail = "Your recent activity will appear here." },
    } },
    { key = "community", label = "Community", icon = "Community", pages = {
        { key = "community", label = "The Duelist's Circle", community = true,
          title = "The Duelist's Circle", subtitle = "The people shaping Duels Reimagined." },
        { key = "contributors", label = "Contributors", community = true,
          title = "Contributors", subtitle = "Merged GitHub pull requests." },
        { key = "bug-hunters", label = "Bug Hunters", community = true,
          title = "Bug Hunters", subtitle = "Reports that led to verified fixes." },
        { key = "community-ideas", label = "Community Ideas", community = true,
          title = "Community Ideas", subtitle = "Suggestions that made it into the addon." },
        { key = "special-thanks", label = "Special Thanks", community = true,
          title = "Special Thanks", subtitle = "People we appreciate." },
    } },
    { key = "patchnotes", label = "Patch Notes", icon = "PatchNotes", pages = {} },
    { key = "options", label = "Options", icon = "Options", pages = {
        { key = "options", label = "Appearance", title = "Appearance",
          subtitle = "Make the interface your own." },
        { key = "interface", label = "Interface", title = "Interface",
          subtitle = "Control how the window behaves while you play." },
    } },
}

-- The version list is authored once in PatchNotesData.lua. Adding a version
-- creates a searchable sidebar subcategory without editing this module.
for _, section in ipairs(sections) do
    if section.key == "patchnotes" then
        for index, release in ipairs(ns.PatchNotesData or {}) do
            section.pages[#section.pages + 1] = {
                key = release.key,
                label = release.version .. " — " .. release.navTitle,
                patchNotes = true, title = release.title,
                subtitle = "DEMO: " .. release.summary,
                newest = index == 1,
            }
        end
    end
end

-- Only primary gameplay destinations live in the expandable upper strip.
-- Secondary utility sections remain in the narrow left rail. New gameplay
-- sections can be promoted here only when their real pages are implemented.
local primaryKeys = { hall = true }
local railButtons, primaryButtons, subButtons = {}, {}, {}
local patchDot, patchPulse
local sectionTitle = Style.Text(Window.nav, "HALL", 18, C.pale)
sectionTitle:SetPoint("TOPLEFT", Window.nav, "TOPLEFT", 20, -24)
local subtitleRule = Chrome.Divider(Window.nav, 166, 12)
subtitleRule:SetPoint("TOPLEFT", Window.nav, "TOPLEFT", 19, -56)

local currentSection, currentPage

local function FadeSelection(item, active)
    Motion.Fade(item.selected, active and (item.activeAlpha or 0.94) or 0, 0.18)
    Motion.Fade(item.hover, 0, 0.13)
end

local function Select(sectionIndex, pageIndex, noMotion, repaintOnly)
    currentSection, currentPage = sectionIndex, pageIndex
    -- A theme repaint must NOT close Search, modal dialogs or reset pages.
    if not repaintOnly and ns.Header and ns.Header.CloseSearch then
        ns.Header.CloseSearch(true)
    end
    local section, page = sections[sectionIndex], sections[sectionIndex].pages[pageIndex]
    sectionTitle:SetText(string.upper(section.label))

    for i, item in ipairs(railButtons) do
        local on = i == sectionIndex
        if noMotion then
            item.selected:SetAlpha(on and (item.activeAlpha or 0.94) or 0)
        else
            FadeSelection(item, on)
        end
        item.bar:SetColorTexture(unpack(item.primary and C.gold or C.goldDim))
        item.bar:SetShown(on)
        item.label:SetTextColor(unpack(on and C.tabText or C.tabMuted))
        -- Keep the Hall's blue/red faction accents intact.
        if item.icon.SetVertexColor then item.icon:SetVertexColor(1, 1, 1, 1) end
        item.icon:SetAlpha(on and 1 or 0.92)
    end
    for i, group in ipairs(subButtons) do
        for j, item in ipairs(group) do
            local visible = i == sectionIndex
            item.button:SetShown(visible)
            local active = visible and j == pageIndex
            if noMotion then
                item.selected:SetAlpha(active and 0.94 or 0)
            else
                FadeSelection(item, active)
            end
            item.bar:SetColorTexture(unpack(C.red))
            item.bar:SetShown(active)
            item.label:SetTextColor(unpack(active and C.tabText or C.text))
        end
    end
    if repaintOnly then return end
    if ns.Footer and ns.Footer.ClosePopup then ns.Footer.ClosePopup() end
    if ns.Tooltips then ns.Tooltips.Hide(nil, true) end
    Window.ShowPage(page)
end

local function AddOverlay(button, primary)
    -- Both types use the same tintable premium masks and Motion engine.
    local selected = Style.Skin(button, C.tabActive, {
        corner=primary and 11 or 9,
        edge=primary and C.gold or C.goldDim,
        shine=primary and 0.58 or 0.30,
        shade=0.40, rim=0.92, alpha=0,
    })
    local hover = Style.Skin(button, C.tabActive, {
        corner=primary and 11 or 9, edge=C.goldDim,
        shine=0.22, shade=0.22, rim=0.56, alpha=0,
    })
    return selected, hover
end

-- Keep the gameplay tab compact; primary tabs can still shrink if the
-- available width becomes constrained.
local HALL_BUTTON_WIDTH = 156
local utilityIndex, previousUtilityButton = 0, nil
for index, section in ipairs(sections) do
    local isPrimary = primaryKeys[section.key] == true
    local parent = isPrimary and Window.rail or Window.utility
    local button = CreateFrame("Button", nil, parent)

    if isPrimary then
        -- Hall is the sole primary tab for now; leave the rest of this row
        -- available for real dueling, ranking or tournament features later.
        button:SetSize(HALL_BUTTON_WIDTH, 44)
        button:SetPoint("LEFT", Window.rail, "LEFT", 24, 0)
    else
        utilityIndex = utilityIndex + 1
        button:SetSize(90, 90)
        button:SetPoint("TOP", Window.utility, "TOP",
            0, -12 - (utilityIndex - 1) * 98)
        if previousUtilityButton then
            -- The 8-unit gap belongs to the rail, never to either button.
            -- Anchor to the actual prior button rather than a guessed row
            -- offset, keeping dividers consistent after future resizing.
            local separator = Chrome.Divider(Window.utility, 44, 8)
            separator:SetPoint("TOP", previousUtilityButton, "BOTTOM", 0, 0)
            separator:SetAlpha(0.50)
        end
        previousUtilityButton = button
    end

    -- Even when Hall is not selected its raised outline reads as a button.
    -- It uses the existing shared tintable premium masks; hover and selected
    -- layers remain independent and retain their current animations.
    if isPrimary then
        Style.Skin(button, C.rail, {
            corner=11, edge=C.goldDim, shine=0.22, shade=0.26, rim=0.82,
        })
    end
    local selected, hover = AddOverlay(button, isPrimary)
    local bar = button:CreateTexture(nil, "OVERLAY")
    bar:SetColorTexture(unpack(C.gold))
    if isPrimary then
        bar:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 3, 0)
        bar:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 0)
        bar:SetHeight(3)
    else
        bar:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -12)
        bar:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 1, 12)
        bar:SetWidth(2)
    end

    -- All navigation glyphs use the same untinted icon atlas. This removes
    -- Patch Notes' individually colored Lua strokes and preserves the four
    -- original icon meanings while theme skins remain on the buttons.
    local icon = Chrome.Icon(button, section.icon)
    icon:SetSize(isPrimary and 34 or 50, isPrimary and 34 or 50)
    local label = Style.Text(button, string.upper(section.label),
        isPrimary and 18 or 12, C.tabMuted)
    if isPrimary then
        -- Anchor the icon/text pair around the button center regardless of
        -- width; FitTabs still hides only the icon on very narrow windows.
        icon:SetPoint("RIGHT", button, "CENTER", -11, 0)
        label:SetPoint("LEFT", icon, "RIGHT", 12, 0)
        label:SetJustifyH("LEFT")
    else
        -- The Community icon atlas has a small baked-in gold line above the
        -- figures. Chrome crops the line; compensate the texture height and
        -- top anchor so the actual figures stay at their EXACT former scale
        -- and position, without shifting the label or changing the hit area.
        if section.key == "community" then
            local trim = 19 / 64
            icon:SetHeight(50 * (1 - trim))
            icon:SetPoint("TOP", button, "TOP", 0, -4 - 50 * trim)
        else
            icon:SetPoint("TOP", button, "TOP", 0, -4)
        end
        label:SetPoint("TOP", icon, "BOTTOM", 0, 0)
        label:SetWidth(88)
        label:SetHeight(30)
        label:SetJustifyH("CENTER")
        label:SetJustifyV("MIDDLE")
    end

    if section.key == "patchnotes" then
        -- Preserve the unread animation, not the old mismatched bitmap.
        label:SetText("PATCH\nNOTES")
        patchDot = CreateFrame("Frame", nil, button)
        patchDot:SetSize(9, 9)
        patchDot:SetPoint("TOPRIGHT", button, "TOPRIGHT", -6, -5)
        Style.Fill(patchDot, C.gold, "OVERLAY")
        patchPulse = patchDot:CreateAnimationGroup()
        patchPulse:SetLooping("BOUNCE")
        local breathe = patchPulse:CreateAnimation("Alpha")
        breathe:SetFromAlpha(0.46)
        breathe:SetToAlpha(1)
        breathe:SetDuration(0.92)
        patchDot:SetScript("OnShow", function()
            if ns.Settings.Get("reduceMotion") then
                patchPulse:Stop()
                patchDot:SetAlpha(1)
            else
                patchPulse:Play()
            end
        end)
        patchDot:SetScript("OnHide", function()
            patchPulse:Stop()
            patchDot:SetAlpha(1)
        end)
        patchDot:Hide()
    end

    button:SetScript("OnClick", function() Select(index, 1) end)
    button:SetScript("OnEnter", function()
        if currentSection ~= index then Motion.Fade(hover, 0.58, 0.17) end
    end)
    button:SetScript("OnLeave", function() Motion.Fade(hover, 0, 0.21) end)
    ns.Widgets.PressFeedback(button, hover)
    ns.Tooltips.Bind(button, { title = section.label,
        detail = "Open the " .. section.label .. " section." })

    local item = {
        button = button, primary = isPrimary,
        activeAlpha = isPrimary and 0.94 or 0.56,
        selected = selected, hover = hover, bar = bar, icon = icon, label = label,
    }
    railButtons[index] = item
    if isPrimary then primaryButtons[#primaryButtons + 1] = item end

    local pages = {}
    for pageIndex, page in ipairs(section.pages) do
        local sub = CreateFrame("Button", nil, Window.nav)
        sub:SetSize(230, 38)
        sub:SetPoint("TOPLEFT", Window.nav, "TOPLEFT", 12, -(79 + (pageIndex - 1) * 41))
        sub:SetPoint("RIGHT", Window.nav, "RIGHT", -12, 0)
        local subSelected, subHover = AddOverlay(sub, false)
        local subBar = sub:CreateTexture(nil, "OVERLAY")
        subBar:SetColorTexture(unpack(C.red))
        subBar:SetPoint("TOPLEFT", sub, "TOPLEFT", 0, -5)
        subBar:SetPoint("BOTTOMLEFT", sub, "BOTTOMLEFT", 0, 5)
        subBar:SetWidth(3)
        local text = Style.Text(sub, page.label, 14, C.text)
        text:SetPoint("LEFT", sub, "LEFT", 16, 0)
        sub:SetScript("OnClick", function() Select(index, pageIndex) end)
        sub:SetScript("OnEnter", function()
            if currentSection ~= index or currentPage ~= pageIndex then
                Motion.Fade(subHover, 0.48, 0.16)
            end
        end)
        sub:SetScript("OnLeave", function() Motion.Fade(subHover, 0, 0.20) end)
        ns.Widgets.PressFeedback(sub, subHover)
        ns.Tooltips.Bind(sub, {
            title = page.label,
            detail = page.subtitle or ("Open the " .. page.label .. " page.")
        })
        pages[#pages + 1] = {
            button = sub, selected = subSelected, hover = subHover, bar = subBar, label = text
        }
    end
    subButtons[index] = pages
end

-- Only primary gameplay tabs occupy the expandable horizontal strip.
-- Secondary utility rail buttons never consume primary navigation space.
-- When real future gameplay sections are registered as primary, this
-- geometry automatically shares the available width without polling.
local function FitTabs(self, width)
    local w = (type(width) == "number" and width > 0) and width or self:GetWidth()
    if not w or w <= 0 or #primaryButtons == 0 then return end
    local pad, gutter = 24, 12
    local slot = math.min(HALL_BUTTON_WIDTH + gutter,
        math.max(112, (w - 2 * pad) / #primaryButtons))
    for i, item in ipairs(primaryButtons) do
        item.button:ClearAllPoints()
        item.button:SetPoint("LEFT", self, "LEFT", pad + (i - 1) * slot, 0)
        item.button:SetWidth(slot - gutter)
        local tiny = slot < 160
        item.icon:SetShown(not tiny)
        item.label:ClearAllPoints()
        if tiny then
            item.label:SetPoint("CENTER", item.button, "CENTER")
        else
            item.label:SetPoint("LEFT", item.icon, "RIGHT", 12, 0)
        end
    end
end
Window.rail:SetScript("OnSizeChanged", FitTabs)
FitTabs(Window.rail, Window.rail:GetWidth())

ns.Navigation = {
    SetPatchUnread = function(unread)
        if not patchDot then return end
        patchDot:SetShown(unread == true)
        if unread and patchDot:IsVisible() then
            if ns.Settings.Get("reduceMotion") then
                patchPulse:Stop()
                patchDot:SetAlpha(1)
            elseif not patchPulse:IsPlaying() then
                patchPulse:Play()
            end
        end
    end,
    RefreshSelection = function()
        if currentSection and currentPage then
            Select(currentSection, currentPage, true, true)
        end
    end,
    SelectKey = function(sectionKey, pageKey)
        for sectionIndex, section in ipairs(sections) do
            if section.key == sectionKey then
                for pageIndex, page in ipairs(section.pages) do
                    if page.key == pageKey then
                        Select(sectionIndex, pageIndex)
                        return true
                    end
                end
            end
        end
        return false
    end,
}

-- Every visible page registers itself, so new pages join search automatically.
for sectionIndex, section in ipairs(sections) do
    for pageIndex, page in ipairs(section.pages) do
        local si, pi = sectionIndex, pageIndex
        ns.Search.Register("page:" .. section.key .. ":" .. page.key,
            page.label, section.label,
            (page.title or "") .. " " .. (page.subtitle or ""),
            function() Select(si, pi) end)
    end
end

Select(1, 1, true)
