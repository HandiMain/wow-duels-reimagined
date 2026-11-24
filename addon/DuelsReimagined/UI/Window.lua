local _, ns = ...
local Style, Chrome, Motion = ns.Style, ns.Chrome, ns.Motion
local C = Style.color
-- Default matches the approved larger in-game layout. Keep the older
-- minimum available for players who prefer a compact, resizable window.
local MIN_WIDTH, MIN_HEIGHT = 1050, 650
local DEFAULT_WIDTH, DEFAULT_HEIGHT, EDGE = 1240, 770, 16

local Window = {}
ns.Window = Window

local frame = CreateFrame("Frame", "DuelsReimaginedWindow", UIParent)
frame:SetSize(DEFAULT_WIDTH, DEFAULT_HEIGHT)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
frame:SetFrameStrata("DIALOG")
frame:SetToplevel(true)
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:Hide()

-- A rounded, theme-tinted shell closes the transparent gap previously
-- visible between the metal perimeter and the inset header/footer. The
-- interior is tucked INSIDE the masked corner radius: no square pixels
-- extend beyond the outer edge when scaled or resized.
Style.Skin(frame, C.window, {
    corner=12, edge=C.window, shine=0.07, shade=0.11, rim=0,
    -- Do not fill the transparent area outside the sculpted copper 9-slice.
    inset=5,
})
-- Single shell border owner: Chrome.Shell adds sculpted accents.
local inset = 6
local interior = CreateFrame("Frame", nil, frame)
interior:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)
interior:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset)
Style.Fill(interior, C.window)
-- native-style optional frame clipping: interior backgrounds and page
-- canvases must stay within the real metallic frame, not its outside corners.
if interior.SetClipsChildren then interior:SetClipsChildren(true) end
Window.frame = frame

-- Magnetic positioning is an enhancement to the ONE existing window drag
-- owner. Guides and the temporary OnUpdate callback exist only while dragging.
local MAGNET_GAP, MAGNET_RANGE = 14, 24
local snapKey = {}
local guideX = Style.Fill(UIParent, C.gold, "OVERLAY")
guideX:SetSize(2, 96)
guideX:Hide()
local guideY = Style.Fill(UIParent, C.gold, "OVERLAY")
guideY:SetSize(112, 2)
guideY:Hide()
local function HideGuides()
    guideX:Hide()
    guideY:Hide()
end
local function ValidCoordinate(n)
    return type(n) == "number" and n == n and
        n ~= math.huge and n ~= -math.huge and
        (not issecretvalue or not issecretvalue(n))
end
local function MagnetOffset()
    if IsAltKeyDown and IsAltKeyDown() then return nil, nil end
    local l, r, t, b = frame:GetLeft(), frame:GetRight(),
        frame:GetTop(), frame:GetBottom()
    local pl, pr, pt, pb = UIParent:GetLeft(), UIParent:GetRight(),
        UIParent:GetTop(), UIParent:GetBottom()
    if not (ValidCoordinate(l) and ValidCoordinate(r) and
        ValidCoordinate(t) and ValidCoordinate(b) and
        ValidCoordinate(pl) and ValidCoordinate(pr) and
        ValidCoordinate(pt) and ValidCoordinate(pb)) then return nil, nil end
    local left, right = pl + MAGNET_GAP - l, pr - MAGNET_GAP - r
    local top, bottom = pt - MAGNET_GAP - t, pb + MAGNET_GAP - b
    local dx, dy, horizontal, vertical
    if math.abs(left) <= MAGNET_RANGE and
        (math.abs(left) <= math.abs(right) or
        math.abs(right) > MAGNET_RANGE) then
        dx, horizontal = left, "LEFT"
    elseif math.abs(right) <= MAGNET_RANGE then
        dx, horizontal = right, "RIGHT"
    end
    if math.abs(top) <= MAGNET_RANGE and
        (math.abs(top) <= math.abs(bottom) or
        math.abs(bottom) > MAGNET_RANGE) then
        dy, vertical = top, "TOP"
    elseif math.abs(bottom) <= MAGNET_RANGE then
        dy, vertical = bottom, "BOTTOM"
    end
    return dx, dy, horizontal, vertical
end
local function DrawGuides()
    local dx, dy, h, v = MagnetOffset()
    guideX:SetShown(dx ~= nil)
    guideY:SetShown(dy ~= nil)
    if h then
        guideX:ClearAllPoints()
        guideX:SetPoint("CENTER", frame, h, dx, 0)
    end
    if v then
        guideY:ClearAllPoints()
        guideY:SetPoint("CENTER", frame, v, 0, dy)
    end
end
local function FinishSnap()
    HideGuides()
    local dx, dy = MagnetOffset()
    if dx == nil and dy == nil then return end
    local cx, cy = frame:GetCenter()
    local px, py = UIParent:GetCenter()
    if not (ValidCoordinate(cx) and ValidCoordinate(cy) and
        ValidCoordinate(px) and ValidCoordinate(py)) then return end
    local x, y = cx - px, cy - py
    Motion.Stop(snapKey)
    Motion.Value(snapKey, 0, 1, 0.13, function(_, amount)
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER",
            x + (dx or 0) * amount, y + (dy or 0) * amount)
    end)
end
function Window.CancelMagnet()
    HideGuides()
    Motion.Stop(snapKey)
end

local function Drag(handle)
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    handle:SetScript("OnDragStart", function(self)
        Motion.Stop(snapKey)
        HideGuides()
        frame:StartMoving()
        self:SetScript("OnUpdate", function() DrawGuides() end)
    end)
    handle:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        frame:StopMovingOrSizing()
        FinishSnap()
    end)
    handle:HookScript("OnHide", function(self)
        self:SetScript("OnUpdate", nil)
        HideGuides()
        Motion.Stop(snapKey)
    end)
end
frame:HookScript("OnHide", function()
    HideGuides()
    Motion.Stop(snapKey)
end)

-- These bands span the entire window, not individual navigation columns.
local header = CreateFrame("Frame", nil, frame)
header:SetHeight(72)
header:SetPoint("TOPLEFT", interior, "TOPLEFT")
header:SetPoint("TOPRIGHT", interior, "TOPRIGHT")
Style.LitBand(header, C.header, { brightness=0.12, edge=C.shellEdge })
Drag(header)

local footer = CreateFrame("Frame", nil, frame)
footer:SetHeight(50)
footer:SetPoint("BOTTOMLEFT", interior, "BOTTOMLEFT")
footer:SetPoint("BOTTOMRIGHT", interior, "BOTTOMRIGHT")
Style.LitBand(footer, C.footer, { brightness=0.12, edge=C.goldDim })

-- Approved Duel Hall geometry: a dedicated left gameplay rail, compact
-- footer shortcuts, and page-specific tabs in the right content region.
local body = CreateFrame("Frame", nil, frame)
body:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
body:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", 0, 0)
Style.Fill(body, C.window)

local rail = CreateFrame("Frame", nil, body)
rail:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
rail:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", 0, 0)
rail:SetWidth(226)
Style.Skin(rail, C.rail, { corner=8, edge=C.shellEdge, smooth=true })
-- One rail edge, not a second line on top of its skin.
Window.rail = rail

local main = CreateFrame("Frame", nil, body)
main:SetPoint("TOPLEFT", rail, "TOPRIGHT", 0, 0)
main:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", 0, 0)
Window.main = main

local content = CreateFrame("Frame", nil, main)
content:SetAllPoints(main)
Style.Skin(content, C.body, { corner=7, edge=C.border, smooth=true })
Window.content = content

local utility = CreateFrame("Frame", nil, footer)
utility:SetSize(360, 36)
utility:SetPoint("RIGHT", footer, "RIGHT", -187, 0)
Window.utility = utility

-- Subcategories are NOT primary navigation buttons.
local nav = CreateFrame("Frame", nil, content)
nav:SetPoint("TOPLEFT", content, "TOPLEFT", 22, -83)
nav:SetPoint("TOPRIGHT", content, "TOPRIGHT", -22, -83)
nav:SetHeight(35)
nav:SetFrameLevel(content:GetFrameLevel() + 5)
Window.nav = nav

Window.chromeSeams = Chrome.Shell(frame, header, footer, rail, nav)
Window.header, Window.footer, Window.body = header, footer, body

-- The approved static identity has ONE paint owner. The previous
-- sword, tinted wordmark, subtitle and decorative lines were still created
-- under the extraction and caused duplicated / blurred text.
-- Dragging is a separate invisible live frame, not a screenshot hotspot.
local brandArea = CreateFrame("Frame", nil, header)
brandArea:SetSize(390, 70)
brandArea:SetPoint("LEFT", header, "LEFT", 14, 0)
brandArea:EnableMouse(false)

local brandDrag = CreateFrame("Frame", nil, brandArea)
brandDrag:SetAllPoints(brandArea)
Drag(brandDrag)
local exactBrand = brandArea:CreateTexture(nil, "ARTWORK", nil, 3)
exactBrand:SetTexture("Interface\\AddOns\\DuelsReimagined\\Media\\Skin\\DuelBrand.png")
exactBrand:SetTexCoord(0, 384/512, 25/128, 93/128)
exactBrand:SetPoint("LEFT", brandArea, "LEFT", 2, 0)
if exactBrand.SetSnapToPixelGrid then exactBrand:SetSnapToPixelGrid(false) end
if exactBrand.SetTexelSnappingBias then exactBrand:SetTexelSnappingBias(0) end

local function FitBrand(_, width)
    local available = math.max(1, (width or brandArea:GetWidth()) - 5)
    local visualWidth = math.min(330, available)
    exactBrand:SetSize(visualWidth, visualWidth * 68 / 384)
end
brandArea:SetScript("OnSizeChanged", FitBrand)
function Window.PlaceBrandBefore(searchBox)
    if not searchBox then return end
    brandArea:ClearAllPoints()
    brandArea:SetPoint("LEFT", header, "LEFT", 14, 0)
    brandArea:SetPoint("RIGHT", searchBox, "LEFT", -12, 0)
    brandArea:SetHeight(70)
    FitBrand(brandArea, brandArea:GetWidth())
end

local Settings = ns.Settings
local scaleCaption = Style.Text(header, "Menu Scale", 12, C.headerMuted)
scaleCaption:SetPoint("RIGHT", header, "RIGHT", -223, 0)

local scale = CreateFrame("Slider", nil, header)
scale:SetSize(80, 20)
scale:SetOrientation("HORIZONTAL")
scale:SetMinMaxValues(Settings.MIN_SCALE, Settings.MAX_SCALE)
scale:SetValueStep(Settings.SCALE_STEP)
if scale.SetObeyStepOnDrag then scale:SetObeyStepOnDrag(true) end
scale:EnableMouseWheel(true)
scale:SetPoint("LEFT", scaleCaption, "RIGHT", 15, 0)

local scaleTrack = scale:CreateTexture(nil, "BACKGROUND")
scaleTrack:SetColorTexture(unpack(C.track))
scaleTrack:SetPoint("LEFT", scale, "LEFT")
scaleTrack:SetPoint("RIGHT", scale, "RIGHT")
scaleTrack:SetHeight(2)

local scaleFill = scale:CreateTexture(nil, "ARTWORK")
scaleFill:SetColorTexture(unpack(C.gold))
scaleFill:SetPoint("LEFT", scaleTrack, "LEFT")
scaleFill:SetHeight(2)

local scaleThumb = scale:CreateTexture(nil, "OVERLAY")
scaleThumb:SetTexture("Interface\\AddOns\\DuelsReimagined\\Media\\Textures\\SliderThumb.tga")
scaleThumb:SetSize(14, 14)
Chrome.Sharp(scaleThumb)
scale:SetThumbTexture(scaleThumb)

local scalePercent = Style.Text(header, "100%", 12, C.headerText)
scalePercent:SetPoint("LEFT", scale, "RIGHT", 10, 0)
Window.scaleCaption = scaleCaption
Window.scaleSlider = scale
Window.scalePercent = scalePercent

-- Search must lead to an actual, visible control even when addon tooltips
-- are disabled. Highlight the existing slider instead of adding a new popup.
function Window.HighlightMenuScale()
    Motion.Stop(scaleFill, 0.20)
    Motion.Fade(scaleFill, 1, 0.55)
    Motion.Stop(scalePercent, 0.30)
    Motion.Fade(scalePercent, 1, 0.55)
    if ns.Tooltips and ns.Tooltips.Enabled() then
        ns.Tooltips.Show(scale, { title = "Menu Scale",
            detail = "Drag or scroll this header slider to resize the window." })
    end
end

-- Menu Scale gets the same modified marker and per-setting reset as Options.
local scaleDot = Style.Text(header, "•", 13, C.gold)
scaleDot:SetPoint("RIGHT", scaleCaption, "LEFT", -4, 0)
local scaleReset = CreateFrame("Button", nil, header)
scaleReset:SetSize(18, 18)
scaleReset:SetPoint("RIGHT", scaleDot, "LEFT", -2, 0)
scaleReset:RegisterForClicks("LeftButtonUp")
local scaleResetIcon = scaleReset:CreateTexture(nil, "ARTWORK")
scaleResetIcon:SetAllPoints(scaleReset)
scaleResetIcon:SetTexture("Interface\\AddOns\\DuelsReimagined\\Media\\Controls\\reset.tga")
Chrome.Sharp(scaleResetIcon)
scaleReset:SetScript("OnClick", function()
    Settings.Reset("menuScale")
end)
ns.Tooltips.Bind(scaleReset, { title = "Reset Menu Scale",
    detail = "Restore the window to 100% scale." })
Window.scaleReset = scaleReset
function Window.RefreshScaleMarker()
    local changed = Settings.IsModified("menuScale")
    scaleDot:SetShown(changed)
    scaleReset:SetShown(changed)
end

local function RoundScale(value)
    return Settings.NormalizeScale(value)
end

local pendingScale
local draggingScale = false
local function PaintScale(value)
    local v = RoundScale(value)
    scaleFill:SetWidth(math.max(1, scale:GetWidth() * (v - Settings.MIN_SCALE) / (Settings.MAX_SCALE - Settings.MIN_SCALE)))
    scalePercent:SetText(math.floor(v * 100 + 0.5) .. "%")
end

-- Constrain the window to the available screen after
-- Menu Scale. The larger default is distinct from the resize minimum;
-- previously saved custom dimensions still take priority.
-- The scale slider remains release-to-apply, never resize-on-drag.
local function WindowGeometry(menuScale)
    local parentH, parentW = UIParent:GetHeight(), UIParent:GetWidth()
    local maxW = math.max(1, math.floor(parentW / menuScale - 2 * EDGE))
    local maxH = math.max(1, math.floor(parentH / menuScale - 2 * EDGE))
    local minW, minH = math.min(MIN_WIDTH, maxW), math.min(MIN_HEIGHT, maxH)
    local defaultW = math.max(minW, math.min(DEFAULT_WIDTH, maxW))
    local defaultH = math.max(minH, math.min(DEFAULT_HEIGHT, maxH))
    return defaultW, defaultH, minW, minH, maxW, maxH
end

frame:SetResizable(true)
local function FitWindowToScreen(menuScale)
    local dw, dh, minW, minH, maxW, maxH = WindowGeometry(menuScale)
    if frame.SetResizeBounds then
        frame:SetResizeBounds(minW, minH, maxW, maxH)
    else
        if frame.SetMinResize then frame:SetMinResize(minW, minH) end
        if frame.SetMaxResize then frame:SetMaxResize(maxW, maxH) end
    end
    local savedW, savedH = Settings.GetWindowSize()
    frame:SetSize(math.max(minW, math.min(maxW, savedW or dw)),
        math.max(minH, math.min(maxH, savedH or dh)))
end

function Window.DefaultSize()
    return WindowGeometry(Settings.Get("menuScale") or 1)
end

function Window.CommitResize()
    local w, h = math.floor(frame:GetWidth() + 0.5), math.floor(frame:GetHeight() + 0.5)
    local defaultW, defaultH = Window.DefaultSize()
    if math.abs(w - defaultW) <= 2 and math.abs(h - defaultH) <= 2 then
        Settings.SetWindowSize(nil)
    else
        Settings.SetWindowSize(w, h)
    end
    if ns.Footer and ns.Footer.Refresh then ns.Footer.Refresh() end
end

function Window.ResetSize()
    Settings.SetWindowSize(nil)
    Window.ApplyScale(Settings.Get("menuScale") or 1)
end

function Window.ResetWindow()
    Settings.SetWindowSize(nil)
    Settings.Reset("menuScale")
    Window.ApplyScale(Settings.Get("menuScale") or 1)
    if ns.Footer and ns.Footer.Refresh then ns.Footer.Refresh() end
end

function Window.IsDefault()
    if Settings.IsModified("menuScale") then return false end
    local w, h = Settings.GetWindowSize()
    if not w then return true end
    -- A persisted custom size is considered default only if it matches
    -- the current screen-fitted default at the current scale.
    local dw, dh = Window.DefaultSize()
    return math.abs(w - dw) <= 2 and math.abs(h - dh) <= 2
end

function Window.ApplyScale(value)
    Window.CancelMagnet()
    local v = RoundScale(value)
    pendingScale = nil
    frame:SetScale(v)
    FitWindowToScreen(v)
    if Style.RefreshPixelEdges then Style.RefreshPixelEdges() end
    if ns.Chrome and ns.Chrome.Refresh then ns.Chrome.Refresh() end
    if ns.Header and ns.Header.AfterWindowResized then
        ns.Header.AfterWindowResized()
    end
    scale:SetValue(v)
    PaintScale(v)
    Window.RefreshScaleMarker()
end

scale:SetScript("OnMouseDown", function(_, mouse)
    if mouse == "LeftButton" then draggingScale = true end
end)
scale:SetScript("OnValueChanged", function(_, value, userInput)
    PaintScale(value)
    if userInput or draggingScale then pendingScale = RoundScale(value) end
    -- Deliberately do not call SetScale here: the slider must not move mid-drag.
end)
scale:SetScript("OnMouseUp", function(_, mouse)
    draggingScale = false
    if mouse == "RightButton" then
        pendingScale = nil
        Settings.Set("menuScale", 1)
        Window.ApplyScale(Settings.Get("menuScale") or 1)
        return
    end
    if mouse ~= "LeftButton" then return end
    local value = pendingScale or RoundScale(scale:GetValue())
    pendingScale = nil
    Settings.Set("menuScale", value)
    Window.ApplyScale(Settings.Get("menuScale") or 1)
end)
scale:SetScript("OnMouseWheel", function(_, delta)
    draggingScale = false
    pendingScale = nil
    local value = RoundScale((Settings.Get("menuScale") or 1)
        + (delta > 0 and Settings.SCALE_STEP or -Settings.SCALE_STEP))
    Settings.Set("menuScale", value)
    Window.ApplyScale(Settings.Get("menuScale") or 1)
end)
scale:SetScript("OnHide", function()
    draggingScale = false
    pendingScale = nil
    Window.ApplyScale(Settings.Get("menuScale") or 1)
end)
ns.Tooltips.Bind(scale, function()
    return { title = "Menu Scale",
        detail = "Current: " .. math.floor((Settings.Get("menuScale") or 1) * 100 + 0.5) ..
            "%. Drag or scroll to resize the window; right-click to reset." }
end)

function Window.RefreshTheme()
    scaleFill:SetColorTexture(unpack(C.gold))
    scaleTrack:SetColorTexture(unpack(C.track))
    scaleResetIcon:SetVertexColor(unpack(C.gold))
    -- Fixed Duel Hall copper art is deliberately independent of font matching.
end

Window.ApplyScale(Settings.Get("menuScale") or 1)

-- One resize owner: user-approved copper filigree Corner 03 (round jewel).
-- Exact ornament extracted from artwork 03 with transparent, feathered alpha:
-- the established Chrome.Shell (+20) alone draws right/bottom border lines.
-- This art remains at +18, beneath the rim, and is limited to the corner;
-- it never overlays footer Close. Hover and press masks use the same source
-- ornament, with a stronger jewel flash while clicking/dragging.
-- The separate existing button alone owns drag/reset and Motion feedback.
local resizeArt = CreateFrame("Frame", nil, frame)
resizeArt:SetSize(96, 96)
resizeArt:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
resizeArt:SetFrameLevel(frame:GetFrameLevel() + 18)
resizeArt:EnableMouse(false)
local CORNER_ART = "Interface\\AddOns\\DuelsReimagined\\Media\\Skin\\DuelResizeCopper.png"
local CORNER_HOVER = "Interface\\AddOns\\DuelsReimagined\\Media\\Skin\\DuelResizeHover.png"
local CORNER_PRESS = "Interface\\AddOns\\DuelsReimagined\\Media\\Skin\\DuelResizePress.png"
local forgedCorner = resizeArt:CreateTexture(nil, "ARTWORK", nil, 2)
forgedCorner:SetTexture(CORNER_ART)
forgedCorner:SetAllPoints(resizeArt)
if Chrome then Chrome.Sharp(forgedCorner) end

-- Both overlays use the same source art and the shared Motion driver.
-- Hover reveals metallic blue/red/gold accents; press lights the sapphire.
local gripGlow = resizeArt:CreateTexture(nil, "OVERLAY", nil, 2)
gripGlow:SetTexture(CORNER_HOVER)
gripGlow:SetAllPoints(resizeArt)
gripGlow:SetBlendMode("ADD")
gripGlow:SetAlpha(0)
if Chrome then Chrome.Sharp(gripGlow) end
local gripPress = resizeArt:CreateTexture(nil, "OVERLAY", nil, 3)
gripPress:SetTexture(CORNER_PRESS)
gripPress:SetAllPoints(resizeArt)
gripPress:SetBlendMode("ADD")
gripPress:SetAlpha(0)
if Chrome then Chrome.Sharp(gripPress) end

-- Enlarged corner art never swallows clicks on footer buttons.
local grip = CreateFrame("Button", nil, frame)
grip:SetSize(54, 54)
grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
grip:SetFrameLevel(frame:GetFrameLevel() + 45)
grip:RegisterForClicks("RightButtonUp")
local sizing, pressed = false, false
local function ShiftCorner(down)
    resizeArt:ClearAllPoints()
    resizeArt:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT",
        down and -1 or -2, down and 1 or 2)
end
local function GripFeedback(alpha, duration)
    Motion.Fade(gripGlow, alpha, duration)
    Motion.Fade(gripPress, pressed and 0.94 or 0, duration)
end

grip.icon = forgedCorner
grip:SetScript("OnMouseDown", function(_, button)
    if (button ~= "LeftButton" and button ~= "RightButton")
        or (ns.Header and ns.Header.IsFolded()) then return end
    pressed = true
    ShiftCorner(true)
    GripFeedback(0.94, Motion.Duration("quick"))
    if button ~= "LeftButton" then return end
    local left, top = frame:GetLeft(), frame:GetTop()
    if left and top then
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    end
    sizing = true
    frame:StartSizing("BOTTOMRIGHT")
end)
grip:SetScript("OnMouseUp", function(_, button)
    if button == "LeftButton" and sizing then
        sizing = false
        frame:StopMovingOrSizing()
        Window.CommitResize()
    end
    if button ~= "LeftButton" and button ~= "RightButton" then return end
    pressed = false
    ShiftCorner(false)
    GripFeedback(grip:IsMouseOver() and 0.62 or 0, Motion.Duration("quick"))
end)
grip:SetScript("OnClick", function(_, button)
    if button == "RightButton" then Window.ResetSize() end
end)
grip:SetScript("OnEnter", function()
    GripFeedback(pressed and 0.94 or 0.62, Motion.Duration("quick"))
end)
grip:SetScript("OnLeave", function()
    GripFeedback(pressed and 0.94 or 0, Motion.Duration("gentle"))
end)
ns.Tooltips.Bind(grip, { title = "Resize window",
    detail = "Drag the corner to resize. Right-click to restore default dimensions." })
-- Stop fades and moving if the parent folds/hides during a press.
grip:HookScript("OnHide", function()
    Motion.Stop(gripGlow, 0)
    Motion.Stop(gripPress, 0)
    pressed = false
    ShiftCorner(false)
    if sizing then
        sizing = false
        frame:StopMovingOrSizing()
    end
end)
Window.resizeGrip = grip
function Window.SetSizingEnabled(on)
    if not on then
        Motion.Stop(gripGlow, 0)
        Motion.Stop(gripPress, 0)
        pressed = false
        ShiftCorner(false)
    end
    if not on and sizing then
        sizing = false
        frame:StopMovingOrSizing()
    end
    frame:SetResizable(on and true or false)
    grip:SetShown(on and true or false)
    resizeArt:SetShown(on and true or false)
end
local close = Style.Action(footer, "Close", "footer")
close:SetSize(105, 30)
-- Centered vertically, with safe padding from the actual interior boundary.
-- The ornamental border corner stays clear of the working Close button.
close:SetPoint("RIGHT", footer, "RIGHT", -64, 0)
close:SetScript("OnClick", function() frame:Hide() end)
Window.closeButton = close -- Navigation anchors its compact Back beside Close.
ns.Tooltips.Bind(close, { title = "Close Duels Reimagined",
    detail = "Hide this window without changing your settings." })

local pageIcon = Chrome.Icon(content, "Options")
pageIcon:SetSize(30, 30)
pageIcon:SetPoint("TOPLEFT", content, "TOPLEFT", 23, -20)
pageIcon:Hide()
local title = Style.Text(content, "Welcome to the Hall", 27, C.pale, nil, "display")
title:SetPoint("TOPLEFT", content, "TOPLEFT", 24, -23)
local titleRule = Chrome.Divider(content, 430, 14)
titleRule:SetPoint("TOPLEFT", content, "TOPLEFT", 25, -124)
titleRule:SetPoint("TOPRIGHT", content, "TOPRIGHT", -25, -124)
local subtitle = Style.Text(content, "Your dueling journey starts here.", 13, C.text)
subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)

local watermark = content:CreateTexture(nil, "BORDER")
watermark:SetTexture("Interface\\AddOns\\DuelsReimagined\\Media\\Artwork\\Watermark.png")
watermark:SetSize(214, 196)
watermark:SetPoint("CENTER", content, "CENTER", 0, -12)
-- Trim uneven transparent padding without stretching the emblem.
watermark:SetTexCoord(0.085, 0.98, 0.055, 0.975)
watermark:SetAlpha(0.54)
watermark:EnableMouse(false)

local emptyHeading = Style.Text(content, "No duels recorded yet", 20, C.pale)
emptyHeading:SetPoint("TOP", watermark, "BOTTOM", 0, -8)
local emptyDetail = Style.Text(content, "Your recent activity will appear here.", 13, C.muted)
emptyDetail:SetPoint("TOP", emptyHeading, "BOTTOM", 0, -8)
function Window.ShowPage(page)
    local isOptions = page.key == "options" or page.key == "interface"
    title:SetText(isOptions and "Options" or (page.title or ""))
    subtitle:SetText(isOptions and
        "Configure the addon to your preference." or (page.subtitle or ""))
    pageIcon:SetShown(isOptions)
    title:ClearAllPoints()
    if isOptions then
        title:SetPoint("LEFT", pageIcon, "RIGHT", 9, 0)
    else
        title:SetPoint("TOPLEFT", content, "TOPLEFT", 24, -23)
    end
    subtitle:ClearAllPoints()
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    emptyHeading:SetText(page.emptyTitle or "")
    emptyDetail:SetText(page.emptyDetail or "")
    local isCommunity = page.community == true
    local isPatchNotes = page.patchNotes == true
    local isAddonStatus = page.addonStatus == true
    local isWarGames = page.warGames == true
    local isCompetitive = page.competitive == true
    local isCustomPage = isOptions or isCommunity or isPatchNotes or isAddonStatus or isWarGames or isCompetitive
    -- Hall artwork stays Hall-only. Other owners present their own pages.
    title:SetShown(not isCommunity and not isPatchNotes and not isAddonStatus and not isWarGames and not isCompetitive)
    titleRule:SetShown(not isCommunity and not isPatchNotes and not isAddonStatus and not isWarGames and not isCompetitive)
    subtitle:SetShown(not isCommunity and not isPatchNotes and not isAddonStatus and not isWarGames and not isCompetitive)
    watermark:SetShown(not isCustomPage)
    emptyHeading:SetShown(not isCustomPage)
    emptyDetail:SetShown(not isCustomPage)
    if ns.CompetitiveUI then ns.CompetitiveUI.Show(isCompetitive and page.key or nil) end
    if ns.WarGamesUI then
        ns.WarGamesUI.Show(isWarGames and page.key or nil)
    end
    if ns.AddonStatus then ns.AddonStatus.Show(isAddonStatus) end
    if ns.Options then ns.Options.Show(isOptions and page.key or nil) end
    if ns.Community then ns.Community.Show(isCommunity and page.key or nil) end
    if ns.PatchNotes then
        ns.PatchNotes.Show(isPatchNotes and page.key or nil)
    end
    if frame:IsShown() then
        Motion.Stop(content, 0.68)
        Motion.Fade(content, 1, 0.19)
    end
end

frame:SetScript("OnHide", function()
    Motion.Stop(frame, 1)
    Motion.Stop(content, 1)
end)

function Window.Toggle()
    if frame:IsShown() then
        frame:Hide()
    else
        -- Recompute the physical-pixel footprint if resolution or UI scale changed.
        Window.ApplyScale(Settings.Get("menuScale") or 1)
        frame:SetAlpha(0.25)
        frame:Show()
        frame:Raise()
        -- Restore a verified real page only when Duels is actually opened.
        if ns.Navigation and ns.Navigation.ResumeWorkspace then
            ns.Navigation.ResumeWorkspace()
        end
        Motion.Fade(frame, 1, 0.22)
    end
end

if type(UISpecialFrames) == "table" then
    table.insert(UISpecialFrames, "DuelsReimaginedWindow")
end
