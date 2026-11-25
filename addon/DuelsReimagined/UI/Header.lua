local _, ns = ...
local Window, Style = ns.Window, ns.Style
local Motion, Settings, Search = ns.Motion, ns.Settings, ns.Search
local C = Style.color
local frame, header = Window.frame, Window.header
local Header = {}
ns.Header = Header
local Tooltips = ns.Tooltips

local iconBase = "Interface\\AddOns\\DuelsReimagined\\Media\\Artwork\\Header\\"
local manualPeek, moving, folded = false, false, false
local expandedHeight = frame:GetHeight()
local alphaWhilePeeking = 0.16

local function HeaderButton(name, title, detail, parent, withoutTooltip, compact)
    local b = CreateFrame("Button", nil, parent or header)
    -- The red X is deliberately smaller than Peek/Fold, while its native
    -- button retains ordinary hover, pressed and tooltip behavior.
    local size = compact or (name == "Close" and 24 or 29)
    b:SetSize(size, size)
    b:RegisterForClicks("LeftButtonUp")
    -- Dark forged controls at rest; the close X gets its crimson plate.
    -- Exactly one extracted button surface. The click/Peek/Fold behavior
    -- stays native; drawing a second rim caused the doubled gold outline.
    -- Compact HUD glyphs rest directly on their continuous header face.
    -- Main window and dialog buttons keep their original forged plates.
    if not compact then
        Style.Plate(b, name == "Close" and "hall" or "dark", { corner=7 })
    end
    local hover = Style.FeedbackOverlay(b, {
        corner=compact and 6 or 8, inset=2, fill=C.gold, edge=C.gold,
        shine=compact and 0.45 or 0.60, rim=compact and 0 or 0.82,
    })
    local art
    if name == "Options" then
        art = ns.Chrome.Icon(b, "Options")
    else
        art = b:CreateTexture(nil, "ARTWORK")
        art:SetTexture(iconBase .. name .. ".png")
    end
    local iconSize = name == "Close" and 15 or 19
    if compact then
        -- Normalize the visible glyphs, not the padded 64px source squares.
        -- Fold variants have different vertical margins in the source art.
        function b:SetGlyph(glyph)
            if glyph == "Options" then
                art:SetSize(19,19) -- existing Options atlas cell
                return
            end
            art:SetTexture(iconBase .. glyph .. ".png")
            if glyph == "Close" then
                art:SetTexCoord(10/64,54/64,10/64,54/64)
                art:SetSize(17,17)
            elseif glyph == "FoldUp" then
                art:SetTexCoord(6/64,58/64,14/64,46/64)
                art:SetSize(17,17*32/52)
            elseif glyph == "FoldDown" then
                art:SetTexCoord(6/64,58/64,19/64,51/64)
                art:SetSize(17,17*32/52)
            end
        end
        b:SetGlyph(name)
        if art.SetDrawLayer then art:SetDrawLayer("OVERLAY",3) end
        art:SetVertexColor(1,.91,.70,1)
    else
        art:SetSize(iconSize, iconSize)
    end
    art:SetPoint("CENTER")
    ns.Chrome.Sharp(art)
    -- A separate, persistent selected accent for Fold/Peek, distinct from
    -- the short press flash. It does not cover the approved button art.
    local chosen = Style.FeedbackOverlay(b, {
        corner=compact and 6 or 8, inset=2, fill=C.goldDim, edge=C.gold,
        shine=0.36, rim=compact and 0 or 0.94,
    })
    b.art, b.hover, b.chosen = art, hover, chosen
    b.tooltipTitle, b.tooltipDetail = title, detail
    b:SetScript("OnEnter", function()
        Motion.Fade(hover, 0.24, 0.13)
    end)
    b:SetScript("OnLeave", function()
        Motion.Fade(hover, 0, 0.18)
    end)
    ns.Widgets.PressFeedback(b, hover, {
        corner=compact and 6 or 8, hoverAlpha=0.24, clickAlpha=0.42,
    })
    b:HookScript("OnMouseDown", function(_, mouse)
        if mouse == "LeftButton" then
            art:ClearAllPoints()
            art:SetPoint("CENTER", b, "CENTER", 0, -1)
        end
    end)
    b:HookScript("OnMouseUp", function()
        art:ClearAllPoints()
        art:SetPoint("CENTER")
    end)
    b:HookScript("OnHide", function()
        art:ClearAllPoints()
        art:SetPoint("CENTER")
    end)
    if not withoutTooltip then
        Tooltips.Bind(b, function()
            return { title = b.tooltipTitle, detail = b.tooltipDetail }
        end)
    end
    return b
end

-- Keep one close-button art/interaction owner: the small popup X is exactly
-- the normal header X (same forged red plate, icon, hover and click feedback),
-- but has no tooltip in an already self-explanatory dialog.
function Header.CreateCloseButton(parent)
    return HeaderButton("Close", "Close", "Close dialog", parent, true)
end

-- HUD controls share the same plated icon, hover, press and motion owner.
-- The HUD retains its own placement, tooltips and actions.
function Header.CreateHUDButton(parent, name, size)
    return HeaderButton(name, "", "", parent, true, size)
end

local function RefreshFade()
    if not frame:IsShown() then return end
    local faded = manualPeek or (moving and Settings.Get("autoPeekMoving"))
    if faded then Tooltips.Hide(nil, true) end
    Motion.Fade(frame, faded and alphaWhilePeeking or 1, 0.17)
end

function Header.SetManualPeek(on)
    manualPeek = on and true or false
    if Header.peekButton and Header.peekButton.chosen then
        Motion.Fade(Header.peekButton.chosen, manualPeek and 0.52 or 0,
            Motion.Duration("quick"))
    end
    RefreshFade()
end

local movement = CreateFrame("Frame")
movement:SetScript("OnEvent", function(_, event)
    moving = event == "PLAYER_STARTED_MOVING"
    RefreshFade()
end)

function Header.RefreshAutoPeek()
    movement:UnregisterEvent("PLAYER_STARTED_MOVING")
    movement:UnregisterEvent("PLAYER_STOPPED_MOVING")
    if frame:IsShown() and Settings.Get("autoPeekMoving") then
        movement:RegisterEvent("PLAYER_STARTED_MOVING")
        movement:RegisterEvent("PLAYER_STOPPED_MOVING")
        -- Opening while already running should Peek without needing a new
        -- PLAYER_STARTED_MOVING event. Never evaluate Retail secret values.
        moving = false
        if type(IsPlayerMoving) == "function" then
            local ok, value = pcall(IsPlayerMoving)
            if ok and type(value) == "boolean" then moving = value end
        elseif type(GetUnitSpeed) == "function" then
            local ok, speed = pcall(GetUnitSpeed, "player")
            if ok and type(speed) == "number" and
                (not issecretvalue or not issecretvalue(speed)) then
                moving = speed > 0
            end
        end
    else
        moving = false
    end
    RefreshFade()
end

local close = HeaderButton("Close", "Close", "Close Duels Reimagined.")
close:SetPoint("RIGHT", header, "RIGHT", -19, 0)
close:SetScript("OnClick", function() frame:Hide() end)

local foldButton = HeaderButton("FoldUp", "Fold window",
    "Collapse to the header without closing. Click again to unfold.")
local peekButton = HeaderButton("Eye", "Peek",
    "Hold to see what is behind the window.")
Header.peekButton = peekButton
peekButton:SetPoint("RIGHT", foldButton, "LEFT", -3, 0)
peekButton:SetScript("OnMouseDown", function(_, button)
    if button == "LeftButton" then Header.SetManualPeek(true) end
end)
peekButton:SetScript("OnMouseUp", function()
    Header.SetManualPeek(false)
end)
peekButton:SetScript("OnHide", function()
    manualPeek = false
    Motion.Stop(peekButton.chosen, 0)
end)

local function PaintFold()
    foldButton.art:SetTexture(iconBase .. (folded and "FoldDown" or "FoldUp") .. ".png")
    Motion.Fade(foldButton.chosen, folded and 0.58 or 0,
        Motion.Duration("quick"))
    foldButton.tooltipTitle = folded and "Unfold window" or "Fold window"
    foldButton.tooltipDetail = folded and
        "Restore the window as you left it." or
        "Collapse to the header without closing."
end

function Header.IsFolded()
    return folded
end

function Header.Fold(value)
    if Window.CancelMagnet then Window.CancelMagnet() end
    local want = value and true or false
    if want == folded then return end
    if want then
        local left, top = frame:GetLeft(), frame:GetTop()
        if left and top then
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        end
        expandedHeight = frame:GetHeight()
        folded = true
        if ns.Footer and ns.Footer.ClosePopup then ns.Footer.ClosePopup() end
        if ns.Widgets and ns.Widgets.CloseChoices then ns.Widgets.CloseChoices() end
        if Window.SetSizingEnabled then Window.SetSizingEnabled(false) end
        Header.CloseSearch(true)
        Window.body:Hide()
        Window.rail:Hide()
        Window.footer:Hide()
        if Window.chromeSeams then Window.chromeSeams:Hide() end
        frame:SetHeight(header:GetHeight() + 20)
    else
        folded = false
        frame:SetHeight(expandedHeight)
        if Window.SetSizingEnabled then Window.SetSizingEnabled(true) end
        Window.body:Show()
        Window.rail:Show()
        Window.footer:Show()
        if Window.chromeSeams then Window.chromeSeams:Show() end
    end
    PaintFold()
end

-- The standard window scale control may be used even while folded.
-- Keep its full-size target rather than losing that height on unfold.
function Header.AfterWindowResized()
    if folded then
        expandedHeight = frame:GetHeight()
        frame:SetHeight(header:GetHeight() + 20)
    end
end

foldButton:SetScript("OnClick", function() Header.Fold(not folded) end)
PaintFold()

-- Place compact header tools from the right edge inward. The search width
-- is independent of window scaling and does not overlap our unified logo.
Window.scalePercent:ClearAllPoints()
Window.scalePercent:SetPoint("RIGHT", close, "LEFT", -12, 0)
Window.scaleSlider:ClearAllPoints()
Window.scaleSlider:SetPoint("RIGHT", Window.scalePercent, "LEFT", -11, 0)
Window.scaleCaption:ClearAllPoints()
Window.scaleCaption:SetPoint("RIGHT", Window.scaleSlider, "LEFT", -9, 0)
foldButton:SetPoint("RIGHT", Window.scaleReset, "LEFT", -10, 0)

local searchBox = CreateFrame("Frame", nil, header)
searchBox:SetSize(254, 29)
searchBox:SetPoint("RIGHT", peekButton, "LEFT", -15, 0)
-- Center the approved brand in the real free space, not against the shell edge.
-- This stays responsive to window resizing and preserves the search hit area.
Window.PlaceBrandBefore(searchBox)
Style.Skin(searchBox, C.window, {
    corner=9, edge=C.goldDim, shine=0.28, shade=0.35, rim=0.8,
})

local glass = searchBox:CreateTexture(nil, "ARTWORK")
glass:SetTexture(iconBase .. "Search.png")
glass:SetSize(17, 17)
glass:SetPoint("LEFT", searchBox, "LEFT", 8, 0)
ns.Chrome.Sharp(glass)

local input = CreateFrame("EditBox", nil, searchBox)
input:SetAutoFocus(false)
input:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 13, "")
Style.BindFont(input, 13, false, C.headerText)
input:SetTextColor(unpack(C.headerText))
input:SetHeight(25)
input:SetPoint("LEFT", searchBox, "LEFT", 31, 0)
input:SetPoint("RIGHT", searchBox, "RIGHT", -7, 0)
input:SetMaxLetters(80)
input:SetText("")
local hint = Style.Text(searchBox, "Search pages and settings...", 12, C.headerMuted)
hint:SetPoint("LEFT", searchBox, "LEFT", 33, 0)
hint:EnableMouse(false)

local dropdown = CreateFrame("Frame", nil, frame)
dropdown:SetWidth(294)
dropdown:SetPoint("TOPRIGHT", searchBox, "BOTTOMRIGHT", 0, -5)
dropdown:SetFrameLevel(frame:GetFrameLevel() + 30)
Style.Fill(dropdown, C.nav)
Style.Border(dropdown, C.goldDim, 1)
dropdown:EnableMouse(true)
dropdown:Hide()

local resultButtons, currentResults, picked, firstVisible = {}, {}, 1, 1
local PAGE_SIZE = 6
local RenderRows
for i = 1, PAGE_SIZE do
    local b = CreateFrame("Button", nil, dropdown)
    b:SetSize(278, 43)
    b:SetPoint("TOPLEFT", dropdown, "TOPLEFT", 8, -8 - (i - 1) * 43)
    local hover = Style.Skin(b, C.goldDim, {
        corner=9, edge=C.goldDim, shine=0.18, shade=0.25, alpha=0,
    })
    local title = Style.Text(b, "", 13, C.text)
    title:SetPoint("TOPLEFT", b, "TOPLEFT", 8, -5)
    local where = Style.Text(b, "", 11, C.muted)
    where:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
    b:SetScript("OnEnter", function()
        picked = firstVisible + i - 1
        Motion.Fade(hover, 0.30, 0.13)
    end)
    b:SetScript("OnLeave", function() Motion.Fade(hover, 0, 0.16) end)
    b:SetScript("OnClick", function()
        local match = currentResults[firstVisible + i - 1]
        Header.CloseSearch(true)
        Search.Open(match)
    end)
    b:EnableMouseWheel(true)
    b:SetScript("OnMouseWheel", function(_, delta)
        local handler = dropdown:GetScript("OnMouseWheel")
        if handler then handler(dropdown, delta) end
    end)
    ns.Widgets.PressFeedback(b, hover)
    Tooltips.Bind(b, function()
        local match = currentResults[firstVisible + i - 1]
        return match and { title = match.title, detail = match.details or match.where }
    end)
    resultButtons[i] = { button = b, title = title, where = where, hover = hover }
end

local noMatch = Style.Text(dropdown, "No matching pages or settings", 12, C.muted)
noMatch:SetPoint("CENTER", dropdown, "CENTER")
noMatch:Hide()

local moreInfo = Style.Text(dropdown, "", 11, C.muted)
moreInfo:SetPoint("TOPLEFT", dropdown, "TOPLEFT", 11, -(9 + PAGE_SIZE * 43))
moreInfo:SetWidth(260)
moreInfo:Hide()

RenderRows = function()
    local count = #currentResults
    local shown = math.max(0, math.min(PAGE_SIZE, count - firstVisible + 1))
    for i, row in ipairs(resultButtons) do
        local idx = firstVisible + i - 1
        local match = currentResults[idx]
        row.button:SetShown(match ~= nil and i <= PAGE_SIZE)
        if match then
            row.title:SetText(match.title)
            row.where:SetText(match.where)
            Motion.Stop(row.hover, idx == picked and 0.22 or 0)
        end
    end
    noMatch:SetShown(count == 0)
    local more = count > PAGE_SIZE
    moreInfo:SetShown(more)
    if more then
        moreInfo:SetText("Showing " .. firstVisible .. "-" ..
            (firstVisible + shown - 1) .. " of " .. count .. " • scroll for more")
    end
    dropdown:SetHeight(count == 0 and 44 or
        (16 + shown * 43 + (more and 22 or 0)))
    dropdown:Show()
end

local function Render(query)
    currentResults = Search.Query(query)
    picked, firstVisible = 1, 1
    if query == "" or not frame:IsShown() or folded then
        dropdown:Hide()
        return
    end
    RenderRows()
end

dropdown:EnableMouseWheel(true)
dropdown:SetScript("OnMouseWheel", function(_, delta)
    if #currentResults <= PAGE_SIZE then return end
    firstVisible = math.max(1, math.min(#currentResults - PAGE_SIZE + 1,
        firstVisible - (delta > 0 and 2 or -2)))
    if picked < firstVisible or picked >= firstVisible + PAGE_SIZE then
        picked = firstVisible
    end
    RenderRows()
end)

function Header.CloseSearch(clear)
    dropdown:Hide()
    input:ClearFocus()
    if clear then input:SetText("") end
end

input:SetScript("OnTextChanged", function(self)
    local query = self:GetText() or ""
    hint:SetShown(query == "")
    Render(query)
end)
input:SetScript("OnEditFocusGained", function(self)
    Tooltips.Hide(nil, true)
    Render(self:GetText() or "")
end)
input:SetScript("OnEnterPressed", function()
    local match = currentResults[picked] or currentResults[1]
    Header.CloseSearch(true)
    Search.Open(match)
end)
input:SetScript("OnEscapePressed", function()
    Header.CloseSearch(true)
end)
input:SetScript("OnArrowPressed", function(_, key)
    if #currentResults == 0 then return end
    picked = math.max(1, math.min(#currentResults,
        picked + (key == "DOWN" and 1 or -1)))
    if picked < firstVisible then firstVisible = picked end
    if picked >= firstVisible + PAGE_SIZE then
        firstVisible = picked - PAGE_SIZE + 1
    end
    RenderRows()
end)
searchBox:EnableMouse(true)
searchBox:SetScript("OnMouseDown", function() input:SetFocus() end)
Tooltips.Bind(searchBox, { title = "Search Duels Reimagined",
    detail = "Find pages, settings, and available window actions." })
Tooltips.Bind(input, { title = "Search pages and settings",
    detail = "Type a name or keyword. Press Enter to open a result; Escape to clear." })

frame:HookScript("OnShow", Header.RefreshAutoPeek)
frame:HookScript("OnHide", function()
    Header.CloseSearch(true)
    Tooltips.Hide(nil, true)
    manualPeek = false
    moving = false
    movement:UnregisterEvent("PLAYER_STARTED_MOVING")
    movement:UnregisterEvent("PLAYER_STOPPED_MOVING")
    Header.Fold(false)
    Motion.Stop(frame, 1)
end)

Search.Register("header:close", "Close window", "Header",
    "Close the Duels Reimagined window", function() frame:Hide() end)
Search.Register("header:fold", "Fold window", "Header",
    "Collapse the window to its header; unfold it again", function()
        Header.Fold(not folded)
    end)
Search.Register("header:peek", "Peek behind the window", "Header",
    "Hold the eye button; automatic Peek while moving in Interface options",
    function()
        if ns.Navigation then ns.Navigation.SelectKey("options", "interface") end
    end)
