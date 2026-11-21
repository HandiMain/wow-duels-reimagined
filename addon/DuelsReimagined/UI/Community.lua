local _, ns = ...

-- The Duelist's Circle. One passive view over bundled GitHub-generated data:
-- zero networking, no guessed achievements, and no duplicate data owners.
local Window, Style, Chrome = ns.Window, ns.Style, ns.Chrome
local Widgets, Motion, Search = ns.Widgets, ns.Motion, ns.Search
local C = Style.color
local Community = {}
ns.Community = Community

local GITHUB = "https://github.com/HandiMain/wow-duels-reimagined/issues/new?template="
local LINKS = {
    bug = GITHUB .. "bug-report.yml",
    idea = GITHUB .. "feature-request.yml",
}

local definitions = {
    { key = "contributors", title = "CONTRIBUTORS",
      hint = "Merged GitHub pull requests.", field = "contributors",
      empty = "No contributors credited yet." },
    { key = "bug-hunters", title = "BUG HUNTERS",
      hint = "Reports that led to verified fixes.", field = "bugHunters",
      empty = "No verified reports yet." },
    { key = "community-ideas", title = "COMMUNITY IDEAS",
      hint = "Ideas that made it into the addon.", field = "ideas",
      empty = "No implemented ideas yet." },
    { key = "special-thanks", title = "SPECIAL THANKS",
      hint = "People we appreciate.", field = "specialThanks",
      empty = "No acknowledgements yet." },
}
local byKey = {}
for _, data in ipairs(definitions) do byKey[data.key] = data end

local function Entries(data)
    local source = ns.CommunityCredits or {}
    local list = source[data.field]
    if type(list) ~= "table" then return {} end
    return list
end

local function Entry(item)
    if type(item) == "string" then return item, nil end
    if type(item) ~= "table" or type(item.name) ~= "string" then return nil end
    if type(item.prs) == "number" then
        return item.name, item.prs == 1 and "1 PR" or (item.prs .. " PRs")
    elseif type(item.reports) == "number" then
        return item.name, item.reports == 1 and "1 report" or (item.reports .. " reports")
    elseif type(item.ref) == "number" then
        return item.name, "#" .. item.ref
    end
    return item.name, nil
end

local root = CreateFrame("Frame", nil, Window.content)
root:SetAllPoints(Window.content)
root:EnableMouse(false)
root:Hide()

local scroll = CreateFrame("ScrollFrame", nil, root)
scroll:SetPoint("TOPLEFT", root, "TOPLEFT", 19, -139)
scroll:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -22, 16)
scroll:EnableMouseWheel(true)
local canvas = CreateFrame("Frame", nil, scroll)
canvas:SetSize(900, 532)
scroll:SetScrollChild(canvas)

local bar = Widgets.ScrollBar(scroll, function()
    return scroll:GetHeight(), canvas:GetHeight(), scroll:GetVerticalScroll()
end, function(position)
    scroll:SetVerticalScroll(position)
end)
local function ClampScroll()
    local maxScroll = math.max(0, canvas:GetHeight() - scroll:GetHeight())
    scroll:SetVerticalScroll(math.max(0,
        math.min(maxScroll, scroll:GetVerticalScroll())))
    bar:Refresh()
end
scroll:SetScript("OnMouseWheel", function(self, delta)
    local maxScroll = math.max(0, canvas:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.max(0,
        math.min(maxScroll, self:GetVerticalScroll() - delta * 43)))
    bar:Refresh()
end)
scroll:SetScript("OnVerticalScroll", function() bar:Refresh() end)
scroll:SetScript("OnSizeChanged", function(_, width)
    canvas:SetWidth(math.max(1, (width or 900) - 14))
    if scroll.UpdateScrollChildRect then scroll:UpdateScrollChildRect() end
    ClampScroll()
end)
scroll:HookScript("OnShow", ClampScroll)

-- The approved lion needed a higher-resolution crop: its face was lost when
-- the old 64px left half of the faction atlas was enlarged in-game.
-- Use a separately extracted 128px lion. The Horde keeps its original atlas,
-- UV, position, dimensions and opacity completely unchanged.
local art = "Interface\\AddOns\\DuelsReimagined\\Media\\Concept\\CommunityFactionMarks.png"
local allianceArt = "Interface\\AddOns\\DuelsReimagined\\Media\\Concept\\CommunityAllianceLion.png"
local symbolArt = "Interface\\AddOns\\DuelsReimagined\\Media\\Concept\\CommunityConceptSymbols.png"
local function ConceptSymbol(parent, slot, size)
    local tex = parent:CreateTexture(nil, "ARTWORK")
    tex:SetTexture(symbolArt)
    local x, y = slot % 4, math.floor(slot / 4)
    tex:SetTexCoord(x / 4 + 0.002, (x + 1) / 4 - 0.002,
        y / 4 + 0.002, (y + 1) / 4 - 0.002)
    tex:SetSize(size, size)
    tex:EnableMouse(false)
    return Chrome.Sharp(tex)
end
local function FactionMark(left)
    local tex = canvas:CreateTexture(nil, "BACKGROUND")
    tex:SetSize(192, 192)
    if left then
        tex:SetTexture(allianceArt)
        tex:SetTexCoord(0, 1, 0, 1)
        tex:SetPoint("TOPLEFT", canvas, "TOPLEFT", 4, 14)
    else
        tex:SetTexture(art)
        tex:SetTexCoord(0.5, 1, 0, 1)
        tex:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", -4, 14)
    end
    -- Slightly clearer Alliance face; Horde alpha stays at its prior 0.76.
    tex:SetAlpha(left and 0.84 or 0.76)
    tex:EnableMouse(false)
    Chrome.Sharp(tex)
    return tex
end
FactionMark(true)
FactionMark(false)

local title = Style.Text(canvas, "THE DUELIST'S CIRCLE", 23, C.pale)
title:SetPoint("TOPLEFT", canvas, "TOPLEFT", 22, -15)
title:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", -22, -15)
title:SetJustifyH("CENTER")
local ornament = Chrome.Divider(canvas, 298, 12)
ornament:SetPoint("TOP", title, "BOTTOM", 0, -5)
local subtitle = Style.Text(canvas, "The people shaping Duels Reimagined.", 13, C.muted)
subtitle:SetPoint("TOP", ornament, "BOTTOM", 0, -3)
subtitle:SetJustifyH("CENTER")

local function SelectableURL(kind)
    if not ns.Footer or not ns.Footer.ShowCommunityLink then return end
    local heading = kind == "bug" and "Report a Bug on GitHub" or "Suggest an Idea on GitHub"
    ns.Footer.ShowCommunityLink(heading, LINKS[kind])
end

local function Action(kind, heading, xOffset)
    local btn = Style.Action(canvas, heading, "community")
    btn:SetSize(246, 37)
    btn:SetPoint("TOP", canvas, "TOP", xOffset, -98)
    btn:SetScript("OnClick", function() SelectableURL(kind) end)
    local actionIcon = ConceptSymbol(btn, kind == "bug" and 8 or 9, 29)
    actionIcon:SetPoint("LEFT", btn, "LEFT", 10, 0)
    local githubIcon = ConceptSymbol(btn, 10, 26)
    githubIcon:SetPoint("RIGHT", btn, "RIGHT", -7, 0)
    ns.Tooltips.Bind(btn, {
        title = heading,
        detail = "Display the GitHub form URL. Copy it with Ctrl+C, then open it in your browser.",
    })
    -- An explanation, not a second button: the main action is the only
    -- clickable target. The URL dialog still lets players select Ctrl+C.
    local description = kind == "bug"
        and "Get a link to report a bug on GitHub."
        or "Get a link to suggest an improvement."
    local note = Style.Text(canvas, description, 12, C.muted)
    note:SetPoint("TOP", btn, "BOTTOM", 0, -3)
    note:SetWidth(284)
    note:SetHeight(25)
    note:SetJustifyH("CENTER")
    note:SetWordWrap(true)
    return btn
end

Action("bug", "REPORT A BUG", -151)
Action("idea", "SUGGEST AN IDEA", 151)

local cards = {}
local function PreviewCard(data, index)
    local card = CreateFrame("Button", nil, canvas)
    card:RegisterForClicks("LeftButtonUp")
    card:SetHeight(155)
    local upper = index <= 2
    local left = index == 1 or index == 3
    local y = upper and -175 or -345
    if left then
        card:SetPoint("TOPLEFT", canvas, "TOPLEFT", 22, y)
        card:SetPoint("TOPRIGHT", canvas, "TOP", -9, y)
    else
        card:SetPoint("TOPLEFT", canvas, "TOP", 9, y)
        card:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", -22, y)
    end
    Style.Skin(card, C.nav, { corner=11, edge=C.border, shine=0.30, shade=0.26 })
    local hover = Style.Skin(card, C.hover, {
        corner=11, edge=C.goldDim, shine=0.15, shade=0.14, alpha=0,
    })
    card:SetScript("OnEnter", function() Motion.Fade(hover, 0.14, 0.14) end)
    card:SetScript("OnLeave", function() Motion.Fade(hover, 0, 0.16) end)
    Widgets.PressFeedback(card, hover)
    ns.Tooltips.Bind(card, { title = data.title,
        detail = "Open the full " .. data.title:lower() .. " list." })
    local titleIcon = ConceptSymbol(card, index - 1, 40)
    titleIcon:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -10)
    local heading = Style.Text(card, data.title, 16, C.gold)
    heading:SetPoint("TOPLEFT", card, "TOPLEFT", 61, -12)
    local hint = Style.Text(card, data.hint, 11, C.muted)
    hint:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -3)
    hint:SetPoint("RIGHT", card, "RIGHT", -20, 0)
    local rule = Chrome.Divider(card, 224, 10)
    rule:SetPoint("TOP", card, "TOP", 0, -55)

    local emptyIcon = ConceptSymbol(card, index + 3, 42)
    emptyIcon:SetPoint("TOP", card, "TOP", 0, -68)
    emptyIcon:SetAlpha(0.88)
    local emptyLabel = Style.Text(card, data.empty, 13, C.muted)
    emptyLabel:SetPoint("TOPLEFT", card, "TOPLEFT", 13, -117)
    emptyLabel:SetPoint("TOPRIGHT", card, "TOPRIGHT", -13, -117)
    emptyLabel:SetJustifyH("CENTER")
    local preview = {}
    for i = 1, 3 do
        local n = Style.Text(card, "", 14, C.text)
        n:SetPoint("TOPLEFT", card, "TOPLEFT", 22, -75 - (i - 1) * 23)
        n:SetPoint("RIGHT", card, "RIGHT", -95, 0)
        local v = Style.Text(card, "", 12, C.muted)
        v:SetPoint("RIGHT", card, "RIGHT", -22, 0)
        v:SetPoint("TOP", card, "TOP", 0, -75 - (i - 1) * 23)
        preview[#preview + 1] = { name = n, value = v }
    end
    local more = Style.Text(card, "", 12, C.gold)
    more:SetPoint("BOTTOM", card, "BOTTOM", 0, 8)
    card:SetScript("OnClick", function()
        if ns.Navigation then ns.Navigation.SelectKey("community", data.key) end
    end)
    cards[#cards + 1] = {
        frame = card, def = data, empty = emptyLabel, icon = emptyIcon,
        preview = preview, more = more
    }
end

for i, item in ipairs(definitions) do PreviewCard(item, i) end

-- A single reusable detail list, rather than creating four separate panels.
local listing = CreateFrame("Frame", nil, canvas)
listing:SetPoint("TOPLEFT", canvas, "TOPLEFT", 22, -175)
listing:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", -22, -175)
listing:SetHeight(245)
Style.Skin(listing, C.nav, { corner=11, edge=C.border, shine=0.25, shade=0.26 })
local listTitle = Style.Text(listing, "", 19, C.gold)
listTitle:SetPoint("TOPLEFT", listing, "TOPLEFT", 20, -15)
local listHint = Style.Text(listing, "", 13, C.muted)
listHint:SetPoint("TOPLEFT", listTitle, "BOTTOMLEFT", 0, -5)
local listRule = Chrome.Divider(listing, 285, 12)
listRule:SetPoint("TOP", listing, "TOP", 0, -60)
local listEmpty = Style.Text(listing, "", 14, C.muted)
listEmpty:SetPoint("TOP", listing, "TOP", 0, -133)
listEmpty:SetJustifyH("CENTER")
local rows = {}
local function Row(i)
    if rows[i] then return rows[i] end
    local name = Style.Text(listing, "", 14, C.text)
    name:SetPoint("TOPLEFT", listing, "TOPLEFT", 25, -88 - (i - 1) * 30)
    name:SetPoint("RIGHT", listing, "RIGHT", -113, 0)
    local count = Style.Text(listing, "", 12, C.muted)
    count:SetPoint("TOPRIGHT", listing, "TOPRIGHT", -25, -88 - (i - 1) * 30)
    rows[i] = { name = name, value = count }
    return rows[i]
end
listing:Hide()

local function UpdateOverview()
    for _, item in ipairs(cards) do
        local entries = Entries(item.def)
        local empty = #entries == 0
        item.empty:SetShown(empty)
        item.icon:SetShown(empty)
        for i, texts in ipairs(item.preview) do
            local name, value = Entry(entries[i])
            texts.name:SetText(name or "")
            texts.value:SetText(value or "")
            texts.name:SetShown(name ~= nil)
            texts.value:SetShown(name ~= nil and value ~= nil)
        end
        item.more:SetText(#entries > 3 and ("View all " .. #entries) or "")
    end
end

local function UpdateList(data)
    local entries = Entries(data)
    listTitle:SetText(data.title)
    listHint:SetText(data.hint)
    listEmpty:SetText(data.empty)
    listEmpty:SetShown(#entries == 0)
    for i = 1, math.max(#entries, #rows) do
        local r = Row(i)
        local name, value = Entry(entries[i])
        r.name:SetText(name or "")
        r.value:SetText(value or "")
        r.name:SetShown(name ~= nil)
        r.value:SetShown(name ~= nil and value ~= nil)
    end
    local h = math.max(245, 116 + #entries * 30)
    listing:SetHeight(h)
    canvas:SetHeight(185 + h + 20)
end

function Community.GetPageScroll(key)
    if key ~= "community" and not byKey[key] then return 0 end
    return scroll:GetVerticalScroll()
end
function Community.SetPageScroll(key, offset)
    if (key ~= "community" and not byKey[key]) or
        type(offset) ~= "number" then return end
    local limit = math.max(0, canvas:GetHeight() - scroll:GetHeight())
    scroll:SetVerticalScroll(math.max(0, math.min(limit, offset)))
    bar:Refresh()
end

function Community.Show(key)
    local active = type(key) == "string" and
        (key == "community" or byKey[key] ~= nil)
    root:SetShown(active)
    if not active then return end
    local overview = key == "community"
    for _, item in ipairs(cards) do item.frame:SetShown(overview) end
    listing:SetShown(not overview)
    if overview then
        UpdateOverview()
        canvas:SetHeight(523)
    else
        UpdateList(byKey[key])
    end
    scroll:SetVerticalScroll(0)
    ClampScroll()
end

-- Search actions have one owner and never claim a browser was opened.
Search.Register("community:report-bug", "Report a Bug", "Community / GitHub",
    "Open a copyable link to the GitHub bug report form", function()
        if ns.Navigation then ns.Navigation.SelectKey("community", "community") end
        SelectableURL("bug")
    end)
Search.Register("community:suggest-idea", "Suggest an Idea", "Community / GitHub",
    "Open a copyable link to suggest a Duels Reimagined improvement", function()
        if ns.Navigation then ns.Navigation.SelectKey("community", "community") end
        SelectableURL("idea")
    end)
