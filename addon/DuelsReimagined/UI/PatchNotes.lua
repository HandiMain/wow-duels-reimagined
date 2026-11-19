local _, ns = ...
local Style, Chrome, Widgets = ns.Style, ns.Chrome, ns.Widgets
local Motion, Search, Settings = ns.Motion, ns.Search, ns.Settings
local C, Window = Style.color, ns.Window

-- Demo presentation content only. None of these entries claim that gameplay
-- features shipped, or that this test build is a public release.
-- Replace with reviewed, factual notes before publishing.
local releases = {
    {
        id = "demo-2026-11-19-patch-notes",
        title = "Test Build — Latest Update",
        date = "Nov 19, 2026",
        entries = {
            { heading = "New: Patch Notes page",
              body = "A dedicated place to browse updates and discover related settings.",
              icon = "Interface\\Icons\\INV_Misc_Note_01" },
            { heading = "Improved: Minimap button",
              body = "Demo entry for widget size, transparency and AddOn Compartment controls.",
              icon = "Interface\\Icons\\INV_Misc_Gear_01",
              target = "setting:iconMode" },
            { heading = "Interface: Navigation and search",
              body = "Demo entry showing how interface changes and fixes can be presented.",
              icon = "Interface\\Icons\\Ability_Warrior_OffensiveStance" },
        },
    },
    {
        id = "demo-2026-11-18-visual-foundation",
        title = "Visual Foundation — Preview",
        date = "Nov 18, 2026",
        entries = {
            { heading = "The Hall takes shape",
              body = "A sample look at the gold-trimmed interface and empty duel history.",
              icon = "Interface\\Icons\\INV_Sword_04" },
            { heading = "A cleaner community view",
              body = "A sample summary of the Duels community presentation.",
              icon = "Interface\\Icons\\INV_Misc_GroupLooking" },
        },
    },
}

local PatchNotes = {}
ns.PatchNotes = PatchNotes

local root = CreateFrame("Frame", nil, Window.content)
root:SetAllPoints(Window.content)
root:Hide()

local heading = Style.Text(root, "Patch Notes", 30, C.pale, true)
heading:SetPoint("TOP", root, "TOP", 0, -25)
local rule = Chrome.Divider(root, 354, 16)
rule:SetPoint("TOP", heading, "BOTTOM", 0, -5)
local subtitle = Style.Text(root, "What's new in Duels Reimagined", 14, C.muted)
subtitle:SetPoint("TOP", rule, "BOTTOM", 0, -7)

local scroll = CreateFrame("ScrollFrame", nil, root)
scroll:SetPoint("TOPLEFT", root, "TOPLEFT", 30, -143)
scroll:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -30, 25)
scroll:EnableMouseWheel(true)

local latest = CreateFrame("Frame", nil, scroll)
local history = CreateFrame("Frame", nil, scroll)
latest:SetSize(760, 575)
history:SetSize(760, 680)
scroll:SetScrollChild(latest)
history:Hide()

local bar = Widgets.ScrollBar(scroll, function()
    local child = scroll:GetScrollChild()
    return scroll:GetHeight(), child and child:GetHeight() or 0,
        scroll:GetVerticalScroll()
end, function(position)
    scroll:SetVerticalScroll(position)
end)

local function Clamp()
    local child = scroll:GetScrollChild()
    if not child then return end
    local limit = math.max(0, child:GetHeight() - scroll:GetHeight())
    scroll:SetVerticalScroll(math.max(0,
        math.min(limit, scroll:GetVerticalScroll())))
    bar:Refresh()
end

local function ResizeCanvas()
    local width = math.max(240, scroll:GetWidth() - 15)
    latest:SetWidth(width)
    history:SetWidth(width)
    if scroll.UpdateScrollChildRect then scroll:UpdateScrollChildRect() end
    Clamp()
end

scroll:SetScript("OnSizeChanged", ResizeCanvas)
scroll:SetScript("OnVerticalScroll", function() bar:Refresh() end)
scroll:SetScript("OnMouseWheel", function(self, delta)
    local child = self:GetScrollChild()
    if not child then return end
    local limit = math.max(0, child:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.max(0, math.min(limit,
        self:GetVerticalScroll() - delta * 46)))
    bar:Refresh()
end)
scroll:HookScript("OnShow", ResizeCanvas)

local function Card(parent, top, height, color)
    local card = CreateFrame("Frame", nil, parent)
    card:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -top)
    card:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -18, -top)
    card:SetHeight(height)
    Style.Fill(card, color or C.nav)
    Style.Border(card, C.goldDim, 1)
    return card
end

local function Banner(parent, release, top)
    local card = Card(parent, top, 112, C.selected)
    local wash = Style.Fill(card, C.red, "BORDER")
    wash:SetAlpha(0.12)
    local mark = card:CreateTexture(nil, "ARTWORK")
    mark:SetTexture("Interface\\AddOns\\DuelsReimagined\\Media\\Concept\\Watermark.png")
    mark:SetSize(104, 96)
    mark:SetPoint("LEFT", card, "LEFT", 15, 0)
    mark:SetAlpha(0.34)
    local separator = Style.Rule(card, "TOPLEFT", card,
        "TOPLEFT", 1, 75, C.goldDim)
    separator:ClearAllPoints()
    separator:SetPoint("LEFT", card, "LEFT", 129, 0)
    local caption = Style.Text(card, release.title, 22, C.pale, true)
    caption:SetPoint("TOPLEFT", card, "TOPLEFT", 153, -17)
    caption:SetPoint("RIGHT", card, "RIGHT", -15, 0)
    local tag = Style.Text(card, "DEMO NOTES", 12, C.gold, true)
    tag:SetPoint("TOPLEFT", caption, "BOTTOMLEFT", 0, -12)
    local date = Style.Text(card, release.date .. "  •  Fictional preview", 12, C.muted)
    date:SetPoint("LEFT", tag, "RIGHT", 15, 0)
    return card
end

local function OpenSetting(id)
    local item = Search.entries[id]
    if item then Search.Open(item) end
end

local function UpdateRow(parent, entry, top)
    local linked = entry.target and Search.entries[entry.target] ~= nil
    local row = CreateFrame(linked and "Button" or "Frame", nil, parent)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -top)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -18, -top)
    row:SetHeight(88)
    Style.Fill(row, C.nav)
    Style.Border(row, C.goldDim, 1)
    local glow = Style.Fill(row, C.goldDim, "ARTWORK")
    glow:SetAlpha(0)

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(entry.icon or "Interface\\Icons\\INV_Misc_Note_01")
    icon:SetSize(33, 33)
    icon:SetPoint("TOPLEFT", row, "TOPLEFT", 20, -24)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local title = Style.Text(row, entry.heading, 18, C.pale)
    title:SetPoint("TOPLEFT", row, "TOPLEFT", 83, -15)
    title:SetPoint("RIGHT", row, "RIGHT", linked and -133 or -16, 0)

    local detail = Style.Text(row, entry.body, 13, C.muted)
    detail:SetPoint("TOPLEFT", row, "TOPLEFT", 83, -43)
    detail:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT",
        linked and -133 or -16, 7)
    detail:SetJustifyH("LEFT")
    detail:SetJustifyV("TOP")
    detail:SetWordWrap(true)

    if linked then
        row:RegisterForClicks("LeftButtonUp")
        local link = Style.Text(row, "View setting  >", 13, C.gold, true)
        link:SetPoint("RIGHT", row, "RIGHT", -19, 0)
        row:SetScript("OnClick", function() OpenSetting(entry.target) end)
        row:SetScript("OnEnter", function() Motion.Fade(glow, 0.16, 0.12) end)
        row:SetScript("OnLeave", function() Motion.Fade(glow, 0, 0.17) end)
        Widgets.PressFeedback(row, glow)
        ns.Tooltips.Bind(row, { title = "View related setting",
            detail = "Open the matching option and briefly highlight it." })
    end
    return row
end

local function Label(parent, text, top)
    local title = Style.Text(parent, text, 15, C.muted, true)
    title:SetPoint("TOP", parent, "TOP", 0, -top)
    return title
end

Banner(latest, releases[1], 4)
for index, entry in ipairs(releases[1].entries) do
    UpdateRow(latest, entry, 135 + (index - 1) * 101)
end
Label(latest, "OLDER UPDATES", 475)
local older = Style.Action(latest, "Browse previous updates")
older:SetSize(230, 34)
older:SetPoint("TOP", latest, "TOP", 0, -507)
older:SetScript("OnClick", function()
    if ns.Navigation then ns.Navigation.SelectKey("patchnotes", "history") end
end)
ns.Tooltips.Bind(older, { title = "Previous Updates",
    detail = "Browse older demo changelog entries." })
Label(latest, "Preview content only — not an actual release history.", 554)

Banner(history, releases[2], 4)
for index, entry in ipairs(releases[2].entries) do
    UpdateRow(history, entry, 134 + (index - 1) * 101)
end
Label(history, "All entries here are fictional examples for layout testing.", 376)
local back = Style.Action(history, "Back to latest update")
back:SetSize(225, 34)
back:SetPoint("TOP", history, "TOP", 0, -412)
back:SetScript("OnClick", function()
    if ns.Navigation then ns.Navigation.SelectKey("patchnotes", "latest") end
end)
ns.Tooltips.Bind(back, { title = "Latest Update",
    detail = "Return to the newest demo notes." })
history:SetHeight(495)

function PatchNotes.RefreshReminder()
    local unread = Settings.Get("patchNotesReminder") and
        Settings.GetPatchNotesSeenId() ~= releases[1].id
    if ns.Navigation and ns.Navigation.SetPatchUnread then
        ns.Navigation.SetPatchUnread(unread)
    end
end

function PatchNotes.Show(pageKey)
    local active = pageKey == "latest" or pageKey == "history"
    root:SetShown(active)
    if not active then return end

    local canvas = pageKey == "history" and history or latest
    heading:SetText(pageKey == "history" and "Previous Updates" or "Patch Notes")
    subtitle:SetText(pageKey == "history" and
        "A look back at earlier demo notes" or "What's new in Duels Reimagined")
    latest:SetShown(canvas == latest)
    history:SetShown(canvas == history)
    scroll:SetScrollChild(canvas)
    scroll:SetVerticalScroll(0)
    ResizeCanvas()

    if pageKey == "latest" then
        Settings.MarkPatchNotesSeen(releases[1].id)
    end
    PatchNotes.RefreshReminder()
    Motion.Stop(canvas, 0.63)
    Motion.Fade(canvas, 1, 0.23)
end

root:HookScript("OnHide", function()
    Motion.Stop(latest, 1)
    Motion.Stop(history, 1)
end)

-- Discover the page through the existing Navigation search registration;
-- release prose is intentionally not indexed as searchable settings.
PatchNotes.RefreshReminder()
