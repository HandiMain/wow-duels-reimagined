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
-- The page heading now belongs to Window.content, not the subcategory bar.
local sectionTitle = Style.Text(Window.nav, "HALL", 1, C.pale)
sectionTitle:Hide()

local currentSection, currentPage
local history, backButton = {}, nil
-- The last real page persists, but Back history stays session-only.
-- Scroll ownership remains with the actual Options/Community/Patch Notes page.
local workspaceReady = false
local scrollMemory = {}
local function ScrollOwner(page)
    if not page then return nil end
    if page.key == "options" or page.key == "interface" then return ns.Options end
    if page.community then return ns.Community end
    if page.patchNotes then return ns.PatchNotes end
end
local function PageId(sectionIndex, pageIndex)
    local section = sections[sectionIndex]
    local page = section and section.pages[pageIndex]
    return section, page, section and page and (section.key .. ":" .. page.key)
end
local function CapturePage()
    local section, page, id = PageId(currentSection, currentPage)
    if not id then return end
    local owner = ScrollOwner(page)
    local offset = owner and owner.GetPageScroll and owner.GetPageScroll(page.key) or 0
    if type(offset) ~= "number" or offset ~= offset then offset = 0 end
    scrollMemory[id] = offset
    if workspaceReady then
        ns.Settings.SetWorkspace(section.key, page.key, offset)
    end
end
local function RestoreScroll(sectionIndex, pageIndex)
    local _, page, id = PageId(sectionIndex, pageIndex)
    if not id then return end
    local owner = ScrollOwner(page)
    if owner and owner.SetPageScroll then
        owner.SetPageScroll(page.key, scrollMemory[id] or 0)
    end
end

-- Only the navigation owner moves this small selection indicator. The
-- existing per-button hover/selection controls and their hitboxes stay put.
local movingBar = Style.Fill(Window.nav, C.gold, "OVERLAY")
movingBar:SetSize(80, 2)
movingBar:Hide()
local movingIndex
local function PlaceBar(_, index)
    local section = sections[currentSection]
    local count = section and #section.pages or 1
    local w = math.max(80, Window.nav:GetWidth() - 12)
    local tabWidth = math.min(174, (w - (count - 1) * 8) / math.max(1, count))
    movingBar:ClearAllPoints()
    movingBar:SetPoint("BOTTOMLEFT", Window.nav, "BOTTOMLEFT",
        6 + (index - 1) * (tabWidth + 8) + 14, 0)
    movingBar:SetWidth(math.max(24, tabWidth - 28))
end
local sweep = Style.Fill(Window.nav, C.gold, "OVERLAY")
sweep:SetSize(48, 2)
sweep:Hide()
local function SweepPage()
    if ns.Settings.Get("reduceMotion") or not Window.frame:IsShown() then return end
    Motion.Stop(sweep, 0)
    sweep:Show()
    Motion.Value(sweep, 0, 1, 0.35, function(region, progress)
        region:ClearAllPoints()
        region:SetPoint("BOTTOMLEFT", Window.nav, "BOTTOMLEFT",
            6 + progress * math.max(40, Window.nav:GetWidth() - 70), 0)
        region:SetAlpha(math.sin(math.pi * progress) * 0.55)
        if progress >= 1 then region:Hide() end
    end)
end

local function FadeSelection(item, active)
    Motion.Fade(item.selected, active and (item.activeAlpha or 0.94) or 0, 0.18)
    Motion.Fade(item.hover, 0, 0.13)
end

local function Select(sectionIndex, pageIndex, noMotion, repaintOnly, isBack)
    local section = sections[sectionIndex]
    if not section or not section.pages[pageIndex] then return end
    local priorSection, priorPage = currentSection, currentPage
    local changed = priorSection ~= sectionIndex or priorPage ~= pageIndex
    if not repaintOnly and priorSection then CapturePage() end
    if changed and not repaintOnly and not isBack and priorSection then
        if #history >= 12 then table.remove(history, 1) end
        history[#history + 1] = { section = priorSection, page = priorPage }
    end
    currentSection, currentPage = sectionIndex, pageIndex
    if backButton then backButton:SetShown(#history > 0) end
    -- A theme repaint must NOT close Search, modal dialogs or reset pages.
    if not repaintOnly and ns.Header and ns.Header.CloseSearch then
        ns.Header.CloseSearch(true)
    end
    local section, page = sections[sectionIndex], sections[sectionIndex].pages[pageIndex]
    sectionTitle:SetText(string.upper(section.label))
    Window.nav:SetShown(#section.pages > 1)

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
            if item.plate then item.plate:SetStyle(active and "gold" or "dark") end
            item.label:SetTextColor(unpack(active and C.tabText or C.text))
        end
    end
    -- Animate on genuine page changes only, never for theme repaints or
    -- initial loading. Switching a section snaps the bar into its new list.
    if changed or not movingIndex then
        local duration = (not noMotion and priorSection == sectionIndex)
            and 0.19 or 0
        Motion.Value(movingBar, movingIndex or pageIndex, pageIndex,
            duration, PlaceBar)
        movingIndex = pageIndex
    end
    movingBar:SetShown(#section.pages > 0)
    if repaintOnly then return end
    if changed and not noMotion then SweepPage() end
    if ns.Feedback then ns.Feedback.HidePreview() end
    if ns.Footer and ns.Footer.ClosePopup then ns.Footer.ClosePopup() end
    if ns.Tooltips then ns.Tooltips.Hide(nil, true) end
    Window.ShowPage(page)
    RestoreScroll(sectionIndex, pageIndex)
    if workspaceReady then
        local _, _, id = PageId(sectionIndex, pageIndex)
        ns.Settings.SetWorkspace(section.key, page.key,
            id and scrollMemory[id] or 0)
    end
end

local function AddOverlay(button, primary)
    -- Both types use the same tintable premium masks and Motion engine.
    local selected = Style.Skin(button, primary and C.button or C.tabActive, {
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
local HALL_BUTTON_WIDTH = 205
local utilityIndex, previousUtilityButton = 0, nil
for index, section in ipairs(sections) do
    local isPrimary = primaryKeys[section.key] == true
    local parent = isPrimary and Window.rail or Window.utility
    local button = CreateFrame("Button", nil, parent)

    if isPrimary then
        -- Game destinations stack vertically; later pages never displace the
        -- secondary footer links or Options subcategories.
        button:SetSize(HALL_BUTTON_WIDTH, 84)
        button:SetPoint("TOP", Window.rail, "TOP", 0, -31)
    else
        utilityIndex = utilityIndex + 1
        button:SetSize(104, 30)
        button:SetPoint("LEFT", Window.utility, "LEFT",
            (utilityIndex - 1) * 112, 0)
        previousUtilityButton = button
    end

    -- Even when Hall is not selected its raised outline reads as a button.
    -- It uses the existing shared tintable premium masks; hover and selected
    -- layers remain independent and retain their current animations.
    if isPrimary then
        Style.Skin(button, C.button, {
            corner=9, edge=C.gold, shine=0.57, shade=0.43, rim=0.98,
        })
        Style.ForgedEdge(button, { inset=5, alpha=0.76 })
        -- Original guild-hall styled bitmap, nine-sliced beneath actual
        -- interactive controls. No screenshots or baked text.
        Style.Plate(button, "hall", { corner=21 })
        local leaves = "Interface\\AddOns\\DuelsReimagined\\Media\\Skin\\DuelHallLaurel.tga"
        local laurelL = button:CreateTexture(nil, "ARTWORK", nil, 1)
        laurelL:SetTexture(leaves)
        laurelL:SetSize(58, 70)
        laurelL:SetPoint("CENTER", button, "CENTER", -61, -1)
        local laurelR = button:CreateTexture(nil, "ARTWORK", nil, 1)
        laurelR:SetTexture(leaves)
        laurelR:SetSize(58, 70)
        laurelR:SetTexCoord(1, 0, 0, 1)
        laurelR:SetPoint("CENTER", button, "CENTER", 61, -1)
    else
        Style.Skin(button, C.nav, {
            corner=7, edge=C.goldDim, shine=0.18, shade=0.20, rim=0.86,
        })
        Style.Plate(button, "dark", { corner=9 })
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
    icon:SetSize(isPrimary and 48 or 20, isPrimary and 48 or 20)
    local label = Style.Text(button, isPrimary and "HALL" or section.label,
        isPrimary and 23 or 12, C.tabMuted, nil,
        isPrimary and "display" or nil)
    if isPrimary then
        icon:SetPoint("TOP", button, "TOP", 0, -4)
        label:SetPoint("BOTTOM", button, "BOTTOM", 0, 6)
        label:SetJustifyH("CENTER")
        label:SetShadowColor(0, 0, 0, 0.95)
        label:SetShadowOffset(1, -1)
    else
        icon:SetPoint("LEFT", button, "LEFT", 9, 0)
        label:SetPoint("LEFT", icon, "RIGHT", 6, 0)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)
    end

    if section.key == "patchnotes" then
        -- Preserve the unread animation, not the old mismatched bitmap.
        label:SetText("Patch Notes")
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
        activeAlpha = isPrimary and 0.88 or 0.35,
        selected = selected, hover = hover, bar = bar, icon = icon, label = label,
    }
    railButtons[index] = item
    if isPrimary then primaryButtons[#primaryButtons + 1] = item end

    local pages = {}
    for pageIndex, page in ipairs(section.pages) do
        local sub = CreateFrame("Button", nil, Window.nav)
        sub:SetSize(174, 35)
        sub:SetPoint("LEFT", Window.nav, "LEFT", 6 + (pageIndex - 1) * 182, 0)
        Style.Skin(sub, C.nav, {
            corner=6, edge=C.goldDim, shine=0.19, shade=0.21, rim=0.89,
        })
        local plate = Style.Plate(sub, "dark", { corner=10 })
        local subSelected, subHover = AddOverlay(sub, false)
        local subBar = sub:CreateTexture(nil, "OVERLAY")
        subBar:SetColorTexture(unpack(C.gold))
        subBar:SetPoint("BOTTOMLEFT", sub, "BOTTOMLEFT", 8, 0)
        subBar:SetPoint("BOTTOMRIGHT", sub, "BOTTOMRIGHT", -8, 0)
        subBar:SetHeight(2)
        local text = Style.Text(sub, page.label, 14, C.text)
        text:SetWordWrap(false)
        if page.key == "options" or page.key == "interface" then
            -- Individually drawn 32-bit icon atlas, not rectangles or a
            -- screenshot cutout. Labels and click targets remain real.
            local glyph = sub:CreateTexture(nil, "OVERLAY", nil, 4)
            glyph:SetTexture("Interface\\AddOns\\DuelsReimagined\\Media\\Skin\\DuelCategoryIcons.tga")
            glyph:SetSize(22, 22)
            glyph:SetPoint("LEFT", sub, "LEFT", 15, 0)
            if page.key == "options" then
                glyph:SetTexCoord(0, .5, 0, 1)
            else
                glyph:SetTexCoord(.5, 1, 0, 1)
            end
            text:SetPoint("LEFT", glyph, "RIGHT", 9, 0)
            text:SetJustifyH("LEFT")
        else
            text:SetPoint("CENTER", sub, "CENTER", 0, 0)
            text:SetJustifyH("CENTER")
        end
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
            button = sub, selected = subSelected, hover = subHover, bar = subBar, label = text, plate = plate
        }
    end
    subButtons[index] = pages
end

-- Compact Back control belongs to the footer beside Close, not the Hall rail.
-- Navigation remains the sole owner of its state and history.
backButton = Style.Action(Window.content, "Back", "footer", {
    fill=C.nav, hover=C.selected, edge=C.goldDim,
    light=C.goldDim, dark=C.window, text=C.text,
})
backButton:SetSize(60, 24)
backButton:SetPoint("TOPRIGHT", Window.content, "TOPRIGHT", -24, -25)
backButton:SetFrameLevel(Window.content:GetFrameLevel() + 9)
ns.Tooltips.Bind(backButton, { title = "Back",
    detail = "Return to the previous page. History clears when you close Duels." })
backButton:SetScript("OnClick", function()
    local previous = table.remove(history)
    if not previous then return end
    Select(previous.section, previous.page, false, false, true)
    if ns.Feedback then ns.Feedback.Acknowledge("navigation-back-v1") end
end)
if ns.Feedback then
    ns.Feedback.NewBadge(backButton, "navigation-back-v1")
end
backButton:Hide()
Window.frame:HookScript("OnHide", function()
    if workspaceReady then CapturePage() end
    -- Back history is ephemeral presentation state, not SavedVariables.
    for i = #history, 1, -1 do history[i] = nil end
    backButton:Hide()
    Motion.Stop(movingBar)
    Motion.Stop(sweep, 0)
    sweep:Hide()
end)

-- Both geometry passes are event-driven; nothing polls an idle window.
-- Primary gameplay destinations remain independent of the footer and tabs.
local function FitTabs(self, width)
    local w = (type(width) == "number" and width > 0) and width or self:GetWidth()
    local buttonWidth = math.max(112, math.min(HALL_BUTTON_WIDTH, w - 28))
    for i, item in ipairs(primaryButtons) do
        item.button:ClearAllPoints()
        item.button:SetPoint("TOP", self, "TOP", 0, -31 - (i - 1) * 99)
        item.button:SetWidth(buttonWidth)
    end
end
-- The divider tracks the last gameplay button, leaving the rest of the rail
-- available to future primary destinations without a fixed overlap.
local railDivider = Chrome.Divider(Window.rail, 170, 14)
if #primaryButtons > 0 then
    railDivider:SetPoint("TOP", primaryButtons[#primaryButtons].button,
        "BOTTOM", 0, -18)
else
    railDivider:Hide()
end
Window.rail:SetScript("OnSizeChanged", FitTabs)
FitTabs(Window.rail, Window.rail:GetWidth())

local function FitSubTabs(self, width)
    local w = (type(width) == "number" and width > 0) and width or self:GetWidth()
    for _, group in ipairs(subButtons) do
        local count = #group
        if count > 0 then
            local tabWidth = math.max(76, math.min(174,
                (math.max(80, w) - 12 - 8 * (count - 1)) / count))
            for j, item in ipairs(group) do
                item.button:ClearAllPoints()
                item.button:SetPoint("LEFT", self, "LEFT",
                    6 + (j - 1) * (tabWidth + 8), 0)
                item.button:SetWidth(tabWidth)
            end
        end
    end
    if movingIndex then PlaceBar(nil, movingIndex) end
end
Window.nav:SetScript("OnSizeChanged", FitSubTabs)
FitSubTabs(Window.nav, Window.nav:GetWidth())

-- A subdued crossed-swords watermark lives in the *primary* rail only.
local railMark = Chrome.Icon(Window.rail, "Hall")
railMark:SetSize(145, 145)
railMark:SetPoint("BOTTOM", Window.rail, "BOTTOM", 0, 48)
railMark:SetAlpha(0.10)
railMark:EnableMouse(false)

ns.Navigation = {
    Back = function()
        if #history == 0 then return false end
        local previous = table.remove(history)
        Select(previous.section, previous.page, false, false, true)
        if ns.Feedback then ns.Feedback.Acknowledge("navigation-back-v1") end
        return true
    end,
    CanGoBack = function() return #history > 0 end,
    ResumeWorkspace = function()
        -- ADDON_LOADED has already seeded SavedVariables when the player
        -- opens Duels; don't mark a hidden Patch Notes page read on login.
        if workspaceReady then return end
        workspaceReady = true
        local sectionKey, pageKey, offset = ns.Settings.GetWorkspace()
        if sectionKey and pageKey then
            for i, section in ipairs(sections) do
                if section.key == sectionKey then
                    for j, page in ipairs(section.pages) do
                        if page.key == pageKey then
                            scrollMemory[sectionKey .. ":" .. pageKey] = offset
                            Select(i, j, true, false, true)
                            return
                        end
                    end
                end
            end
        end
        Select(currentSection or 1, currentPage or 1, true, false, true)
    end,
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

-- Like every other real action, Back participates in the ONE Search registry.
-- It is unavailable until the player actually has somewhere to return.
ns.Search.Register("navigation:back", "Back", "Navigation",
    "Return to your previous Duels page", function()
        return ns.Navigation.Back()
    end, function()
        return ns.Navigation.CanGoBack()
    end)

-- Persist the current scroll on /reload/relog even if the user didn't
-- navigate away or close the window before the interface was torn down.
local logout = CreateFrame("Frame")
logout:RegisterEvent("PLAYER_LOGOUT")
logout:SetScript("OnEvent", function()
    if workspaceReady then CapturePage() end
end)

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
