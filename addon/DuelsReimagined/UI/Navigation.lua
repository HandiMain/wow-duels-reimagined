local _, ns = ...
local Style = ns.Style
local C = Style.color
local Window = ns.Window

-- These entries exercise navigation and empty states only. No duel systems exist yet.
local sections = {
    { key = "hall", label = "Hall", icon = "Interface\\Icons\\INV_Sword_04", pages = {
        { key = "overview", label = "Overview", title = "Welcome to the Hall", subtitle = "Your dueling journey starts here.", emptyTitle = "No duels recorded yet", emptyDetail = "Your recent activity will appear here.", action = true },
    } },
    { key = "record", label = "Record", icon = "Interface\\Icons\\INV_Misc_Book_09", pages = {
        { key = "personal", label = "My Record", title = "My Record", subtitle = "Your dueling record.", emptyTitle = "No duels recorded yet", emptyDetail = "Your results will appear here." },
        { key = "recent", label = "Recent Duels", title = "Recent Duels", subtitle = "Your latest encounters.", emptyTitle = "No recent duels", emptyDetail = "Completed duels will appear here." },
    } },
    { key = "community", label = "Community", icon = "Interface\\Icons\\INV_Misc_GroupLooking", pages = {
        { key = "community", label = "Community", title = "Community", subtitle = "The people behind the duels.", emptyTitle = "Nothing to show yet", emptyDetail = "Community features will arrive later." },
    } },
    { key = "options", label = "Options", icon = "Interface\\Buttons\\UI-OptionsButton", pages = {
        { key = "options", label = "Appearance", title = "Appearance", subtitle = "Make the interface your own.", emptyTitle = "Options coming later", emptyDetail = "We'll design the controls together." },
    } },
}

local railButtons = {}
local subButtons = {}
local sectionTitle = Style.Text(Window.nav, "THE HALL", 17, C.gold)
sectionTitle:SetPoint("TOPLEFT", Window.nav, "TOPLEFT", 21, -114)
local subtitleRule = Window.nav:CreateTexture(nil, "ARTWORK")
subtitleRule:SetColorTexture(unpack(C.goldDim))
subtitleRule:SetPoint("TOPLEFT", sectionTitle, "BOTTOMLEFT", 0, -11)
subtitleRule:SetSize(188, 1)

local currentSection, currentPage
local function Select(sectionIndex, pageIndex)
    currentSection, currentPage = sectionIndex, pageIndex
    local section = sections[sectionIndex]
    local page = section.pages[pageIndex]
    sectionTitle:SetText(string.upper(section.label))
    for i, entry in ipairs(railButtons) do
        entry.bg:SetColorTexture(unpack(i == sectionIndex and C.selected or C.rail))
        entry.side:SetShown(i == sectionIndex)
        entry.label:SetTextColor(unpack(i == sectionIndex and C.pale or C.muted))
    end
    for i, entries in ipairs(subButtons) do
        for j, entry in ipairs(entries) do
            local visible = i == sectionIndex
            entry.button:SetShown(visible)
            local active = visible and j == pageIndex
            entry.bg:SetColorTexture(unpack(active and C.selected or C.nav))
            entry.side:SetShown(active)
            entry.label:SetTextColor(unpack(active and C.pale or C.text))
        end
    end
    Window.ShowPage(page)
end

for index, section in ipairs(sections) do
    local button = CreateFrame("Button", nil, Window.rail)
    button:SetSize(104, 76)
    if section.key == "options" then
        button:SetPoint("BOTTOM", Window.rail, "BOTTOM", 0, 24)
    else
        button:SetPoint("TOP", Window.rail, "TOP", 0, -(110 + (index - 1) * 90))
    end
    local bg = Style.Fill(button, C.rail)
    local side = button:CreateTexture(nil, "ARTWORK")
    side:SetColorTexture(unpack(C.red))
    side:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    side:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
    side:SetWidth(3)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(section.icon)
    icon:SetSize(27, 27)
    icon:SetPoint("TOP", button, "TOP", 0, -10)
    local label = Style.Text(button, string.upper(section.label), 12, C.muted)
    label:SetPoint("TOP", icon, "BOTTOM", 0, -7)
    button:SetScript("OnClick", function() Select(index, 1) end)
    button:SetScript("OnEnter", function()
        if currentSection ~= index then bg:SetColorTexture(unpack(C.hover)) end
    end)
    button:SetScript("OnLeave", function()
        if currentSection ~= index then bg:SetColorTexture(unpack(C.rail)) end
    end)
    railButtons[index] = { bg = bg, side = side, label = label }

    local pages = {}
    for pageIndex, page in ipairs(section.pages) do
        local sub = CreateFrame("Button", nil, Window.nav)
        sub:SetSize(219, 39)
        sub:SetPoint("TOPLEFT", Window.nav, "TOPLEFT", 9, -(163 + (pageIndex - 1) * 43))
        local subBg = Style.Fill(sub, C.nav)
        local subSide = sub:CreateTexture(nil, "ARTWORK")
        subSide:SetColorTexture(unpack(C.gold))
        subSide:SetPoint("TOPLEFT", sub, "TOPLEFT", 0, 0)
        subSide:SetPoint("BOTTOMLEFT", sub, "BOTTOMLEFT", 0, 0)
        subSide:SetWidth(2)
        local subText = Style.Text(sub, page.label, 15, C.text)
        subText:SetPoint("LEFT", sub, "LEFT", 14, 0)
        sub:SetScript("OnClick", function() Select(index, pageIndex) end)
        sub:SetScript("OnEnter", function()
            if currentSection ~= index or currentPage ~= pageIndex then subBg:SetColorTexture(unpack(C.hover)) end
        end)
        sub:SetScript("OnLeave", function()
            if currentSection ~= index or currentPage ~= pageIndex then subBg:SetColorTexture(unpack(C.nav)) end
        end)
        pages[#pages + 1] = { button = sub, bg = subBg, side = subSide, label = subText }
    end
    subButtons[index] = pages
end

Window.action:SetScript("OnClick", function() Select(2, 1) end)
Select(1, 1)
