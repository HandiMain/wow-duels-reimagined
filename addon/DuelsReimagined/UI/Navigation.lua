local _, ns = ...
local Style, Chrome, Motion = ns.Style, ns.Chrome, ns.Motion
local C, Window = Style.color, ns.Window

-- Navigation is a visual shell prototype, not a gameplay or record engine.
local sections = {
    { key = "hall", label = "Hall", icon = "Hall", pages = {
        { key = "overview", label = "Overview", title = "Welcome to the Hall", subtitle = "Your dueling journey starts here.", emptyTitle = "No duels recorded yet", emptyDetail = "Your recent activity will appear here.", action = true },
        { key = "personal", label = "My Record", title = "My Record", subtitle = "Your dueling record.", emptyTitle = "No duels recorded yet", emptyDetail = "Your results will appear here." },
        { key = "recent", label = "Recent Duels", title = "Recent Duels", subtitle = "Your latest encounters.", emptyTitle = "No recent duels", emptyDetail = "Completed duels will appear here." },
    } },
    { key = "community", label = "Community", icon = "Community", pages = {
        { key = "community", label = "Community", title = "Community", subtitle = "The people behind the duels.", emptyTitle = "Nothing to show yet", emptyDetail = "Community features will arrive later." },
    } },
    { key = "options", label = "Options", icon = "Options", pages = {
        { key = "options", label = "Appearance", title = "Appearance", subtitle = "Make the interface your own.", emptyTitle = "Options coming later", emptyDetail = "We'll design the controls together." },
    } },
}

local railButtons, subButtons = {}, {}
local sectionTitle = Style.Text(Window.nav, "THE HALL", 18, C.gold, true)
sectionTitle:SetPoint("TOPLEFT", Window.nav, "TOPLEFT", 20, -24)
local subtitleRule = Chrome.Divider(Window.nav, 201, 12)
subtitleRule:SetPoint("TOPLEFT", Window.nav, "TOPLEFT", 19, -56)

local currentSection, currentPage

local function FadeSelection(item, active)
    Motion.Fade(item.selected, active and 0.94 or 0, 0.18)
    Motion.Fade(item.hover, 0, 0.13)
end

local function Select(sectionIndex, pageIndex, noMotion)
    currentSection, currentPage = sectionIndex, pageIndex
    local section, page = sections[sectionIndex], sections[sectionIndex].pages[pageIndex]
    sectionTitle:SetText(string.upper(section.label))

    for i, item in ipairs(railButtons) do
        local on = i == sectionIndex
        if noMotion then
            item.selected:SetAlpha(on and 0.94 or 0)
        else
            FadeSelection(item, on)
        end
        item.bar:SetShown(on)
        item.label:SetTextColor(unpack(on and C.pale or C.muted))
        -- Keep the Hall's blue/red faction accents intact.
        item.icon:SetVertexColor(1, 1, 1, 1)
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
            item.bar:SetShown(active)
            item.label:SetTextColor(unpack(active and C.pale or C.text))
        end
    end
    Window.ShowPage(page)
end

local function AddOverlay(button)
    local selected = Chrome.Texture(button, "Selection", 0, "BACKGROUND")
    local hover = Chrome.Texture(button, "Selection", 0, "ARTWORK")
    return selected, hover
end

for index, section in ipairs(sections) do
    local button = CreateFrame("Button", nil, Window.rail)
    button:SetSize(124, 96)
    if section.key == "options" then
        button:SetPoint("BOTTOM", Window.rail, "BOTTOM", 0, 19)
    elseif section.key == "community" then
        button:SetPoint("BOTTOM", Window.rail, "BOTTOM", 0, 122)
    else
        button:SetPoint("TOP", Window.rail, "TOP", 0, -17)
    end
    local selected, hover = AddOverlay(button)
    local bar = button:CreateTexture(nil, "OVERLAY")
    bar:SetColorTexture(unpack(C.red))
    bar:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 3)
    bar:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, -3)
    bar:SetWidth(3)
    local icon = Chrome.Icon(button, section.icon)
    -- Each 128px square asset has the same transparent margin; none is stretched.
    icon:SetSize(61, 61)
    icon:SetPoint("TOP", button, "TOP", 0, -4)
    local label = Style.Text(button, string.upper(section.label), 12, C.muted, true)
    label:SetPoint("TOP", icon, "BOTTOM", 0, -1)
    label:SetJustifyH("CENTER")
    button:SetScript("OnClick", function() Select(index, 1) end)
    button:SetScript("OnEnter", function()
        if currentSection ~= index then Motion.Fade(hover, 0.58, 0.17) end
    end)
    button:SetScript("OnLeave", function() Motion.Fade(hover, 0, 0.21) end)
    railButtons[index] = {
        selected = selected, hover = hover, bar = bar, icon = icon, label = label
    }

    local pages = {}
    for pageIndex, page in ipairs(section.pages) do
        local sub = CreateFrame("Button", nil, Window.nav)
        sub:SetSize(230, 43)
        sub:SetPoint("TOPLEFT", Window.nav, "TOPLEFT", 9, -(82 + (pageIndex - 1) * 46))
        local subSelected, subHover = AddOverlay(sub)
        local subBar = sub:CreateTexture(nil, "OVERLAY")
        subBar:SetColorTexture(unpack(C.gold))
        subBar:SetPoint("TOPLEFT", sub, "TOPLEFT", 0, -5)
        subBar:SetPoint("BOTTOMLEFT", sub, "BOTTOMLEFT", 0, 5)
        subBar:SetWidth(3)
        local text = Style.Text(sub, page.label, 15, C.text)
        text:SetPoint("LEFT", sub, "LEFT", 16, 0)
        sub:SetScript("OnClick", function() Select(index, pageIndex) end)
        sub:SetScript("OnEnter", function()
            if currentSection ~= index or currentPage ~= pageIndex then
                Motion.Fade(subHover, 0.48, 0.16)
            end
        end)
        sub:SetScript("OnLeave", function() Motion.Fade(subHover, 0, 0.20) end)
        pages[#pages + 1] = {
            button = sub, selected = subSelected, hover = subHover, bar = subBar, label = text
        }
    end
    subButtons[index] = pages
end

ns.Navigation = {
    RefreshSelection = function()
        if currentSection and currentPage then Select(currentSection, currentPage, true) end
    end,
}
Window.action:SetScript("OnClick", function() Select(1, 2) end)
Select(1, 1, true)
