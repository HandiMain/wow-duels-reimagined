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
scroll:SetPoint("TOPLEFT", root, "TOPLEFT", 19, -10)
scroll:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -22, 16)
scroll:EnableMouseWheel(true)
local canvas = CreateFrame("Frame", nil, scroll)
canvas:SetSize(900, 717)
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

-- The original artwork is one power-of-two 512x256 atlas. Each crest
-- occupies a centered 160x160 region within its half of the canvas.
-- Decorative only: like BurstFX's class watermark, never intercepts input.
local art = "Interface\\AddOns\\DuelsReimagined\\Media\\Concept\\CommunityFactionMarks.png"
local function FactionMark(left)
    local tex = canvas:CreateTexture(nil, "BACKGROUND")
    tex:SetTexture(art)
    tex:SetSize(229, 229)
    if left then
        tex:SetTexCoord(48 / 512, 208 / 512, 48 / 256, 208 / 256)
        tex:SetPoint("TOPLEFT", canvas, "TOPLEFT", 4, 14)
    else
        tex:SetTexCoord(304 / 512, 464 / 512, 48 / 256, 208 / 256)
        tex:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", -4, 14)
    end
    tex:SetAlpha(left and 0.12 or 0.10)
    tex:EnableMouse(false)
    Chrome.Sharp(tex)
    return tex
end
FactionMark(true)
FactionMark(false)

local title = Style.Text(canvas, "THE DUELIST'S CIRCLE", 25, C.pale, true)
title:SetPoint("TOPLEFT", canvas, "TOPLEFT", 22, -18)
title:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", -22, -18)
title:SetJustifyH("CENTER")
local ornament = Chrome.Divider(canvas, 320, 14)
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
    local btn = Style.Action(canvas, heading)
    btn:SetSize(250, 42)
    btn:SetPoint("TOP", canvas, "TOP", xOffset, -112)
    btn:SetScript("OnClick", function() SelectableURL(kind) end)
    ns.Tooltips.Bind(btn, {
        title = heading,
        detail = "Display the GitHub form URL. Copy it with Ctrl+C, then open it in your browser.",
    })
    local copy = CreateFrame("Button", nil, canvas)
    copy:SetSize(184, 25)
    copy:SetPoint("TOP", btn, "BOTTOM", 0, -3)
    copy:RegisterForClicks("LeftButtonUp")
    local label = Style.Text(copy, "Copy GitHub link", 12, C.muted)
    label:SetPoint("CENTER")
    copy:SetScript("OnClick", function() SelectableURL(kind) end)
    copy:SetScript("OnEnter", function() label:SetTextColor(unpack(C.gold)) end)
    copy:SetScript("OnLeave", function() label:SetTextColor(unpack(C.muted)) end)
    ns.Tooltips.Bind(copy, {
        title = "Copy GitHub link",
        detail = "Show a selectable link, then press Ctrl+C (Cmd+C on Mac).",
    })
    return btn
end

Action("bug", "REPORT A BUG", -146)
Action("idea", "SUGGEST AN IDEA", 146)

local cards = {}
local function PreviewCard(data, index)
    local card = CreateFrame("Button", nil, canvas)
    card:RegisterForClicks("LeftButtonUp")
    card:SetHeight(214)
    local upper = index <= 2
    local left = index == 1 or index == 3
    local y = upper and -215 or -447
    if left then
        card:SetPoint("TOPLEFT", canvas, "TOPLEFT", 22, y)
        card:SetPoint("TOPRIGHT", canvas, "TOP", -9, y)
    else
        card:SetPoint("TOPLEFT", canvas, "TOP", 9, y)
        card:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", -22, y)
    end
    Style.Fill(card, C.nav)
    Style.Border(card, C.goldDim)
    local hover = Style.Fill(card, C.goldDim, "BACKGROUND")
    hover:SetAlpha(0)
    card:SetScript("OnEnter", function() Motion.Fade(hover, 0.14, 0.14) end)
    card:SetScript("OnLeave", function() Motion.Fade(hover, 0, 0.16) end)
    Widgets.PressFeedback(card, hover)
    ns.Tooltips.Bind(card, { title = data.title,
        detail = "Open the full " .. data.title:lower() .. " list." })
    local heading = Style.Text(card, data.title, 17, C.gold)
    heading:SetPoint("TOPLEFT", card, "TOPLEFT", 21, -16)
    local hint = Style.Text(card, data.hint, 12, C.muted)
    hint:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -4)
    hint:SetPoint("RIGHT", card, "RIGHT", -20, 0)
    local rule = Chrome.Divider(card, 265, 12)
    rule:SetPoint("TOP", card, "TOP", 0, -67)

    local emptyIcon = Chrome.Icon(card, "Community")
    emptyIcon:SetSize(48, 48)
    emptyIcon:SetPoint("TOP", card, "TOP", 0, -82)
    emptyIcon:SetAlpha(0.16)
    local emptyLabel = Style.Text(card, data.empty, 13, C.muted)
    emptyLabel:SetPoint("TOPLEFT", card, "TOPLEFT", 13, -151)
    emptyLabel:SetPoint("TOPRIGHT", card, "TOPRIGHT", -13, -151)
    emptyLabel:SetJustifyH("CENTER")
    local preview = {}
    for i = 1, 3 do
        local n = Style.Text(card, "", 14, C.text)
        n:SetPoint("TOPLEFT", card, "TOPLEFT", 22, -85 - (i - 1) * 30)
        n:SetPoint("RIGHT", card, "RIGHT", -95, 0)
        local v = Style.Text(card, "", 12, C.muted)
        v:SetPoint("RIGHT", card, "RIGHT", -22, 0)
        v:SetPoint("TOP", card, "TOP", 0, -85 - (i - 1) * 30)
        preview[#preview + 1] = { name = n, value = v }
    end
    local more = Style.Text(card, "", 12, C.gold)
    more:SetPoint("BOTTOM", card, "BOTTOM", 0, 12)
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
listing:SetPoint("TOPLEFT", canvas, "TOPLEFT", 22, -215)
listing:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", -22, -215)
listing:SetHeight(310)
Style.Fill(listing, C.nav)
Style.Border(listing, C.goldDim)
local listTitle = Style.Text(listing, "", 19, C.gold)
listTitle:SetPoint("TOPLEFT", listing, "TOPLEFT", 22, -20)
local listHint = Style.Text(listing, "", 13, C.muted)
listHint:SetPoint("TOPLEFT", listTitle, "BOTTOMLEFT", 0, -5)
local listRule = Chrome.Divider(listing, 315, 14)
listRule:SetPoint("TOP", listing, "TOP", 0, -78)
local listEmpty = Style.Text(listing, "", 14, C.muted)
listEmpty:SetPoint("TOP", listing, "TOP", 0, -165)
listEmpty:SetJustifyH("CENTER")
local rows = {}
local function Row(i)
    if rows[i] then return rows[i] end
    local name = Style.Text(listing, "", 14, C.text)
    name:SetPoint("TOPLEFT", listing, "TOPLEFT", 25, -102 - (i - 1) * 34)
    name:SetPoint("RIGHT", listing, "RIGHT", -113, 0)
    local count = Style.Text(listing, "", 12, C.muted)
    count:SetPoint("TOPRIGHT", listing, "TOPRIGHT", -25, -102 - (i - 1) * 34)
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
    local h = math.max(310, 130 + #entries * 34)
    listing:SetHeight(h)
    canvas:SetHeight(239 + h + 24)
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
        canvas:SetHeight(694)
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
