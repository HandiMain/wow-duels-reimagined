local addonName, ns = ...

-- Single owner for account-wide preferences. Read the SavedVariables global
-- on every access: WoW may replace its table after addon files have executed.
local Settings = {}
ns.Settings = Settings

Settings.MIN_SCALE = 0.65
Settings.MAX_SCALE = 1.20
Settings.SCALE_STEP = 0.05
-- Independent type scale: keep 100% as the Blizzard/Ellesmere default.
Settings.MIN_FONT_SCALE = 0.75
Settings.MAX_FONT_SCALE = 1.50
Settings.FONT_SCALE_STEP = 0.05

-- From earlier project's proven minimap + floating-access-widget design.
-- Access preferences are account-wide and owned here, never by UI modules.
Settings.MIN_WIDGET_SIZE, Settings.MAX_WIDGET_SIZE = 24, 128
Settings.WIDGET_SIZE_STEP = 2
Settings.MAX_WIDGET_TRANSPARENCY = 0.90
Settings.MIN_MINIMAP_SIZE, Settings.MAX_MINIMAP_SIZE = 24, 64
Settings.MINIMAP_SIZE_STEP = 2
Settings.MAX_MINIMAP_TRANSPARENCY = 0.90
local accessDefaults = {
    iconMode = "minimap", widgetSize = 42,
    widgetTransparency = 0, minimapAngle = 225,
    minimapSize = 36, minimapTransparency = 0,
}
local allowedModes = { minimap = true, widget = true, both = true, none = true }
local countdownStyles = {
    {key="impact",label="Gladiator"}, {key="slash",label="Blade Strike"},
    {key="forge",label="Molten Forge"}, {key="arcane",label="Arcane Rift"},
    {key="thunder",label="Thunderstrike"}, {key="cinematic",label="Cinematic"},
    {key="shatter",label="Shatter"}, {key="pulse",label="Heartbeat"},
    {key="minimal",label="Minimal"},
}
local countdownChannels={{key="SFX",label="Effects"},{key="Master",label="Master"},
    {key="Ambience",label="Ambience"},{key="Music",label="Music"},{key="Dialog",label="Dialog"}}
local allowedCountdownChannels={}
for _,choice in ipairs(countdownChannels) do allowedCountdownChannels[choice.key]=true end
function Settings.GetCountdownChannels()
    local out={}
    for i,v in ipairs(countdownChannels) do out[i]={key=v.key,label=v.label} end
    return out
end
local function ValidSharedSound(value)
    return type(value)=="string" and #value>4 and #value<=128 and
        value:sub(1,4)=="lsm:" and not value:find("%c")
end
local function ValidCountdownPack(value)
    return type(value)=="string" and #value<=128 and
        (value=="builtin:tick" or value:match("^pack:[%w _%-%/]+$")~=nil or ValidSharedSound(value))
end
local function ValidFightPack(value)
    return type(value)=="string" and #value<=128 and
        (value=="builtin:tick" or value:match("^fight:[%w_%-]+$")~=nil or ValidSharedSound(value))
end
local allowedCountdownStyles={}
for _,choice in ipairs(countdownStyles) do allowedCountdownStyles[choice.key]=true end
function Settings.GetCountdownStyles()
    local out={}
    for i,v in ipairs(countdownStyles) do out[i]={key=v.key,label=v.label} end
    return out
end

-- Every persistent Options toggle belongs here, including future ones.
local boolDefaults = {
    matchFont = false,
    autoPeekMoving = true,
    reduceMotion = false,
    competitiveConsent = false,
    practiceDuels = false,
    duelHUDEnabled = true,
    duelHUDLocked = false,
    duelHUDAdaptive = true,
    duelHUDSessionStats = false,
    duelCountdownVisual = true,
    duelCountdownSounds = true,
    duelFightSounds = true,
    duelResultVisual = true,
    duelResultVignette = true,
    warGamesConsent = false,
    showTooltips = true,
    patchNotesReminder = true,
    notificationEnabled = true,
    notificationSounds = true,
    showGameMenuButton = true,
    -- This is our membership in Blizzard's addon compartment, NOT the
    -- visibility of Blizzard's own compartment button.
    showInCompartment = true,
}

-- Only Addon Compartment membership needs a reload: Blizzard exposes a
-- registration API but no reliable in-session unregister contract.
local reloadRequired, loadValues = {}, {}
local ReadDB

-- Ellesmere integration is an optional capability, not a fixed user default.
-- No saved override: follow availability. Explicit stored choices persist.
local function EllesmereReady()
    return ns.Theme and type(ns.Theme.IsAvailable) == "function"
        and ns.Theme.IsAvailable() or false
end

local function IsMatchPreference(key)
    return key == "matchFont"
end

function Settings.GetDefault(key)
    if key=="duelCountdownStyle" then return "impact" end
    if key=="duelCountdownSoundPack" then return "builtin:tick" end
    if key=="duelCountdownAudioChannel" or key=="duelFightAudioChannel" then return "SFX" end
    if key=="duelFightSoundPack" then return "fight:mortal_kombat" end
    if key=="duelCountdownFont" then return "builtin:Morpheus" end
    if key == "duelHUDScale" or key == "duelHUDOpacity" then return 1 end
    if key == "menuScale" then return 1 end
    if key == "fontChoice" then return "default" end
    if key == "fontScale" then return 1 end
    if key == "fontOutline" then return "default" end
    if accessDefaults[key] ~= nil then return accessDefaults[key] end
    -- Only optional font matching remains; colors always use Duel Hall.
    if key == "matchFont" then return EllesmereReady() end
    return boolDefaults[key]
end

function Settings.IsModified(key)
    local default = Settings.GetDefault(key)
    return default ~= nil and Settings.Get(key) ~= default
end

function Settings.Reset(key)
    if IsMatchPreference(key) then
        -- Reset means AUTO: remove the override rather than saving whatever
        -- the third-party addon happens to report in this session.
        local db = ReadDB()
        if db and db[key] ~= nil then
            db[key] = nil
            if ns.Theme and ns.Theme.Refresh then ns.Theme.Refresh() end
        end
        return
    end
    local default = Settings.GetDefault(key)
    if default ~= nil then Settings.Set(key, default) end
end

function Settings.RegisterReloadRequired(key)
    if Settings.GetDefault(key) == nil then return end
    reloadRequired[key] = true
    loadValues[key] = Settings.Get(key)
end

function Settings.NeedsReload()
    for key in pairs(reloadRequired) do
        if Settings.Get(key) ~= loadValues[key] then return true end
    end
    return false
end

ReadDB = function()
    local db = _G.DuelsReimaginedDB
    return type(db) == "table" and db or nil
end

local function WriteDB()
    local db = ReadDB()
    if not db then
        db = {}
        _G.DuelsReimaginedDB = db
    end
    return db
end

-- Patch Notes is account-wide presentation state, not a real addon version.
-- The stable content ID is stored alongside other preferences, by this owner.
-- One bounded account-wide acknowledgement. Preview never calls this.
function Settings.IsUpdateSnoozed(version,now)
    local db=ReadDB();local v=db and db.updateNoticeSnooze
    return type(version)=="string" and type(now)=="number" and type(v)=="table"
        and v.version==version and type(v.untilTime)=="number"
        and v.untilTime>now and v.untilTime<=now+86400
end
function Settings.SnoozeUpdate(version,now)
    if type(version)~="string" or #version>24 or not version:match("^%d+%.%d+%.%d+$")
        or type(now)~="number" or now~=now or now<=0 or now>=math.huge then return end
    WriteDB().updateNoticeSnooze={version=version,untilTime=now+86400}
end
function Settings.GetPatchNotesSeenId()
    local db = ReadDB()
    local id = db and db.patchNotesSeenId
    return type(id) == "string" and #id <= 128 and id or nil
end

-- Feature discovery acknowledgements are account-wide and owned by this
-- storage module. Only actual, installed controls may use these stable IDs.
local discoveries = { ["navigation-back-v1"] = true, ["widget-preview-v1"] = true }
function Settings.HasSeenDiscovery(id)
    if not discoveries[id] then return true end
    local db = ReadDB()
    return type(db and db.discoverySeen) == "table" and db.discoverySeen[id] == true or false
end
function Settings.MarkDiscoverySeen(id)
    if not discoveries[id] then return false end
    local db = WriteDB()
    if type(db.discoverySeen) ~= "table" then db.discoverySeen = {} end
    if db.discoverySeen[id] then return false end
    db.discoverySeen[id] = true
    if ns.Feedback then ns.Feedback.RefreshDiscovery() end
    return true
end

function Settings.MarkPatchNotesSeen(id)
    if type(id) ~= "string" or #id < 1 or #id > 128 then return end
    local db = WriteDB()
    if db.patchNotesSeenId == id then return end
    db.patchNotesSeenId = id
    if ns.PatchNotes and ns.PatchNotes.RefreshReminder then
        ns.PatchNotes.RefreshReminder()
    end
end

function Settings.NormalizeScale(value)
    if type(value) ~= "number" or value ~= value then return 1 end
    local step = Settings.SCALE_STEP
    return math.max(Settings.MIN_SCALE, math.min(Settings.MAX_SCALE,
        math.floor(value / step + 0.5) * step))
end

function Settings.NormalizeFontScale(value)
    if type(value) ~= "number" or value ~= value then return 1 end
    local step = Settings.FONT_SCALE_STEP
    return math.max(Settings.MIN_FONT_SCALE, math.min(Settings.MAX_FONT_SCALE,
        math.floor(value / step + 0.5) * step))
end

-- Separate, optional account-wide window dimensions. A missing entry
-- requests the existing screen-fitted default. Never return the database table.
local function CleanWindowSize(size)
    if type(size) ~= "table" then return nil end
    local w, h = size.width, size.height
    if type(w) ~= "number" or type(h) ~= "number" or w ~= w or h ~= h or
        w < 600 or h < 450 or w > 6000 or h > 6000 then return nil end
    return math.floor(w + 0.5), math.floor(h + 0.5)
end

function Settings.GetWindowSize()
    local db = ReadDB()
    return CleanWindowSize(db and db.windowSize)
end

function Settings.HasWindowSize()
    return Settings.GetWindowSize() ~= nil
end

function Settings.SetWindowSize(w, h)
    local db = WriteDB()
    local nw, nh = CleanWindowSize({ width = w, height = h })
    local ow, oh = CleanWindowSize(db.windowSize)
    if nw == ow and nh == oh then return end
    db.windowSize = nw and { width = nw, height = nh } or nil
    if ns.Footer and ns.Footer.Refresh then ns.Footer.Refresh() end
end

-- Only the most recent real page and its scroll offset persist. Navigation
-- validates these stable page keys before ever displaying a saved destination.
-- Missing/older SavedVariables are safely treated as the Hall default.
local function WorkspaceKey(value)
    return type(value) == "string" and #value > 0 and #value <= 64
        and value:match("^[%w%-]+$") ~= nil
end
local function WorkspaceScroll(value)
    if type(value) ~= "number" or value ~= value or
        value == math.huge or value == -math.huge then return 0 end
    return math.floor(math.max(0, math.min(60000, value)) + 0.5)
end
-- Arena favorites are the only persistent part of the visual War Games
-- chooser. Settings remains the one storage owner, not the transient picker.
local function CleanArenaFavorites(source)
    local out, seen = {}, {}
    if type(source) ~= "table" then return out end
    for i=1,math.min(#source,32) do
        local name=source[i]
        if type(name)=="string" and #name>=3 and #name<=96 and
            not name:find("[%c]") and not seen[name] then
            out[#out+1]=name
            seen[name]=true
        end
    end
    return out
end
function Settings.GetWarGamesArenaFavorites()
    local db=ReadDB()
    return CleanArenaFavorites(db and db.warGamesArenaFavorites)
end
function Settings.IsWarGamesArenaFavorite(name)
    if type(name)~="string" then return false end
    for _,item in ipairs(Settings.GetWarGamesArenaFavorites()) do
        if item==name then return true end
    end
    return false
end
function Settings.ToggleWarGamesArenaFavorite(name)
    if type(name)~="string" or #name<3 or #name>96 or
        name:find("[%c]") then return false end
    local list=Settings.GetWarGamesArenaFavorites()
    local nextList={}
    local removed=false
    for _,item in ipairs(list) do
        if item==name then removed=true
        else nextList[#nextList+1]=item end
    end
    if not removed then
        if #nextList>=32 then return false end
        nextList[#nextList+1]=name
    end
    WriteDB().warGamesArenaFavorites=nextList
    return true,not removed
end

-- Explicit diagnostic exports only. One storage owner, bounded text,
-- no live duel records or automatic writes from scanning.
function Settings.GetDiagnosticReports()
    local db=ReadDB()
    local out={}
    local list=db and db.diagnosticReports
    if type(list)=="table" then
        for i=1,3 do
            local item=list[i]
            if type(item)=="table" and type(item.text)=="string" and
                #item.text<=98304 and type(item.label)=="string" and #item.label<=80 then
                out[#out+1]={text=item.text,label=item.label}
            end
        end
    end
    return out
end
function Settings.SaveDiagnosticReport(label,report)
    if type(label)~="string" or #label>80 or type(report)~="string" or
        #report==0 or #report>98304 then return false end
    local list=Settings.GetDiagnosticReports()
    table.insert(list,1,{label=label,text=report})
    while #list>3 do table.remove(list) end
    WriteDB().diagnosticReports=list
    return true
end
-- Explicit reference baselines; bounded and separated by client.
local function CleanBaseline(value)
    if type(value)~="table" or type(value.stamp)~="string" or #value.stamp>80
        or value.mode~="complete" or type(value.rows)~="table" then return nil end
    local out={stamp=value.stamp,mode="complete",rows={}}
    for i=1,math.min(#value.rows,200) do
        local row=value.rows[i]
        if type(row)=="table" and type(row.id)=="string" and #row.id<=180 and
            (row.status=="PASS" or row.status=="WARN" or row.status=="SKIP" or row.status=="FAIL") then
            out.rows[#out.rows+1]={id=row.id,status=row.status}
        end
    end
    if #out.rows==0 then return nil end
    return out
end
function Settings.GetDiagnosticBaseline(kind)
    if kind~="forever" and kind~="retail" then return nil end
    local db=ReadDB()
    local b=db and db.diagnosticBaselines
    return type(b)=="table" and CleanBaseline(b[kind]) or nil
end
function Settings.SaveDiagnosticBaseline(kind,value)
    if kind~="forever" and kind~="retail" then return false end
    local b=CleanBaseline(value)
    if not b then return false end
    for _,row in ipairs(b.rows) do
        if row.status=="FAIL" or row.status=="WARN" then return false end
    end
    local db=WriteDB()
    if type(db.diagnosticBaselines)~="table" then db.diagnosticBaselines={} end
    db.diagnosticBaselines[kind]=b
    return true
end
function Settings.ClearDiagnosticReports()
    local db=ReadDB()
    if db then db.diagnosticReports=nil end
end

function Settings.GetWorkspace()
    local db = ReadDB()
    local state = db and db.lastWorkspace
    if type(state) ~= "table" or
        not WorkspaceKey(state.section) or
        not WorkspaceKey(state.page) then return nil end
    return state.section, state.page, WorkspaceScroll(state.scroll)
end
function Settings.SetWorkspace(section, page, scroll)
    if not WorkspaceKey(section) or not WorkspaceKey(page) then return end
    local offset = WorkspaceScroll(scroll)
    local db = WriteDB()
    local old = db.lastWorkspace
    if type(old) == "table" and old.section == section and
        old.page == page and old.scroll == offset then return end
    db.lastWorkspace = { section = section, page = page, scroll = offset }
end

local function ValidCountdownFont(value)
    return type(value)=="string" and #value<=128 and
        (value:match("^builtin:.+") or value:match("^lsm:.+"))~=nil
end
function Settings.Get(key)
    local db = ReadDB()
    if key=="duelCountdownSoundPack" then
        local v=db and db[key]
        return ValidCountdownPack(v) and v or "builtin:tick"
    end
    if key=="duelFightSoundPack" then
        local v=db and db[key]
        return ValidFightPack(v) and v or "fight:mortal_kombat"
    end
    if key=="duelCountdownAudioChannel" or key=="duelFightAudioChannel" then
        local v=db and db[key]
        return type(v)=="string" and allowedCountdownChannels[v] and v or "SFX"
    end
    if key=="duelCountdownFont" then
        local v=db and db[key]
        return ValidCountdownFont(v) and v or Settings.GetDefault(key)
    end
    if key=="duelCountdownStyle" then
        local v=db and db[key]
        return type(v)=="string" and allowedCountdownStyles[v] and v or "impact"
    end
    if key == "duelHUDOpacity" then
        local v=db and db.duelHUDOpacity
        if type(v)~="number" or v~=v then return 1 end
        return math.max(.3,math.min(1,math.floor(v*20+.5)/20))
    end
    if key == "duelHUDScale" then
        local v=db and db.duelHUDScale
        if type(v)~="number" or v~=v then return 1 end
        return math.max(.8,math.min(1.2,math.floor(v*20+.5)/20))
    end
    if key == "menuScale" then
        return Settings.NormalizeScale(db and db.menuScale)
    end
    if key == "fontScale" then
        return Settings.NormalizeFontScale(db and db.fontScale)
    end
    if key == "iconMode" then
        local value = db and db.iconMode
        return allowedModes[value] and value or accessDefaults.iconMode
    end
    if key == "minimapSize" then
        local value = db and db.minimapSize
        if type(value) ~= "number" or value ~= value then return accessDefaults.minimapSize end
        local low, high, step = Settings.MIN_MINIMAP_SIZE,
            Settings.MAX_MINIMAP_SIZE, Settings.MINIMAP_SIZE_STEP
        return math.max(low, math.min(high, low + step *
            math.floor((value - low) / step + 0.5)))
    end
    if key == "minimapTransparency" then
        local value = db and db.minimapTransparency
        if type(value) ~= "number" or value ~= value then return accessDefaults.minimapTransparency end
        return math.max(0, math.min(Settings.MAX_MINIMAP_TRANSPARENCY,
            math.floor(value / 0.05 + 0.5) * 0.05))
    end
    if key == "widgetSize" then
        local value = db and db.widgetSize
        if type(value) ~= "number" or value ~= value then return accessDefaults.widgetSize end
        return math.max(24, math.min(128, 24 + 2 *
            math.floor((value - 24) / 2 + 0.5)))
    end
    if key == "widgetTransparency" then
        local value = db and db.widgetTransparency
        if type(value) ~= "number" or value ~= value then return 0 end
        return math.max(0, math.min(0.9, math.floor(value / 0.05 + 0.5) * 0.05))
    end
    if key == "minimapAngle" then
        local value = db and db.minimapAngle
        if type(value) ~= "number" or value ~= value or
            value == math.huge or value == -math.huge then return 225 end
        return value % 360
    end
    if key == "fontChoice" then
        local value = db and db.fontChoice
        if type(value) ~= "string" or #value > 128 or value == "" then return "default" end
        return value
    end
    if key == "fontOutline" then
        local value = db and db.fontOutline
        if value == "none" or value == "outline" or value == "thick" then return value end
        return "default"
    end
    if boolDefaults[key] == nil then return nil end
    -- When the integration is unavailable, the EFFECTIVE setting is OFF.
    -- Preserve any saved ON override for when EllesmereUI is enabled again.
    if IsMatchPreference(key) and not EllesmereReady() then return false end
    local stored = db and db[key]
    if type(stored) == "boolean" then return stored end
    return Settings.GetDefault(key)
end

-- Return numeric coordinates, not the mutable SavedVariables table.
function Settings.GetWidgetPosition()
    local db = ReadDB()
    local position = db and db.widgetPosition
    if type(position) ~= "table" then return 280, 0 end
    local x, y = position.x, position.y
    if type(x) ~= "number" or type(y) ~= "number" or
        x ~= x or y ~= y or math.abs(x) > 10000 or math.abs(y) > 10000 then
        return 280, 0
    end
    return x, y
end

function Settings.SetWidgetPosition(x, y)
    if type(x) ~= "number" or type(y) ~= "number" or x ~= x or y ~= y or
        math.abs(x) > 10000 or math.abs(y) > 10000 then return end
    WriteDB().widgetPosition = { x = x, y = y }
end

-- Shared screen-layout storage. Only explicitly registered visual keys may
-- be saved; editor drafts never touch SavedVariables.
local visualKeys={countdown=true}
local function LayoutNumber(n)
    if type(issecretvalue)=="function" then
        local ok,secret=pcall(issecretvalue,n)
        if not ok or secret then return false end
    end
    return type(n)=="number" and n==n and n~=math.huge and n~=-math.huge
end
local function Clamp(n,lo,hi) return math.max(lo,math.min(hi,n)) end
function Settings.GetVisualLayout(key)
    local db=ReadDB()
    local p=visualKeys[key] and db and type(db.visualLayouts)=="table" and db.visualLayouts[key]
    if type(p)=="table" and LayoutNumber(p.x) and LayoutNumber(p.y) and LayoutNumber(p.scale) then
        return Clamp(p.x,0,1),Clamp(p.y,0,1),Clamp(p.scale,.5,2)
    end
    return .5,.5,1
end
function Settings.SetVisualLayout(key,x,y,scale)
    if not visualKeys[key] or not LayoutNumber(x) or not LayoutNumber(y) or not LayoutNumber(scale) then return false end
    local db=WriteDB()
    if type(db.visualLayouts)~="table" then db.visualLayouts={} end
    db.visualLayouts[key]={x=Clamp(x,0,1),y=Clamp(y,0,1),scale=Clamp(scale,.5,2)}
    return true
end
-- UIParent units, not scaled child units. Clamp the settled visual's
-- footprint, keeping stored relative coordinates portable across resolutions.
function Settings.ClampVisualLayout(x,y,scale,w,h,bw,bh)
    if not (LayoutNumber(x) and LayoutNumber(y) and LayoutNumber(scale) and
        LayoutNumber(w) and LayoutNumber(h) and LayoutNumber(bw) and LayoutNumber(bh)) or
        w<=0 or h<=0 or bw<=0 or bh<=0 then return nil end
    scale=math.min(Clamp(scale,.5,2),w/bw,h/bh)
    local hx,hy=bw*scale/(2*w),bh*scale/(2*h)
    return Clamp(x,hx,1-hx),Clamp(y,hy,1-hy),scale
end

function Settings.GetDuelHUDPosition()
    local db=ReadDB();local p=db and db.duelHUDPosition
    if type(p)=="table" and type(p.x)=="number" and type(p.y)=="number"
        and p.x==p.x and p.y==p.y and p.x>=0 and p.x<=1 and p.y>=0 and p.y<=1 then
        return p.x,p.y
    end
    return .30,.52
end
function Settings.SetDuelHUDPosition(x,y)
    if type(x)~="number" or type(y)~="number" or x~=x or y~=y then return end
    WriteDB().duelHUDPosition={x=math.max(0,math.min(1,x)),y=math.max(0,math.min(1,y))}
end
function Settings.ResetDuelHUDPosition()
    WriteDB().duelHUDPosition=nil
    if ns.DuelHUD then ns.DuelHUD.ApplyPosition() end
end
function Settings.SetMinimapAngle(value)
    if type(value) ~= "number" or value ~= value then return end
    WriteDB().minimapAngle = value % 360
end

function Settings.ResetAccessPositions()
    local db = WriteDB()
    db.minimapAngle = accessDefaults.minimapAngle
    db.widgetPosition = nil
    if ns.AccessIcons and ns.AccessIcons.Refresh then ns.AccessIcons.Refresh() end
    if ns.Options and ns.Options.Refresh then ns.Options.Refresh() end
end

function Settings.Set(key, value)
    if key=="duelCountdownSoundPack" or key=="duelCountdownAudioChannel" or
        key=="duelFightSoundPack" or key=="duelFightAudioChannel" then
        if key=="duelCountdownSoundPack" then
            if not ValidCountdownPack(value) or value~="builtin:tick" and
                (not ns.CountdownAudio or not ns.CountdownAudio.IsAvailable(value)) then return end
        elseif key=="duelFightSoundPack" then
            if not ValidFightPack(value) or value~="fight:mortal_kombat" and value~="builtin:tick" and
                (not ns.CountdownAudio or not ns.CountdownAudio.IsFightAvailable(value)) then return end
        elseif type(value)~="string" or not allowedCountdownChannels[value] then return end
        local db=WriteDB();if db[key]==value then return end
        db[key]=value
        if ns.CountdownAudio then ns.CountdownAudio.Stop(key:find("duelFight",1,true) and "fight" or "countdown") end
        if ns.Options and ns.Options.Refresh then ns.Options.Refresh() end
        return
    end
    if key=="duelCountdownFont" then
        if not ValidCountdownFont(value) then return end
        local db=WriteDB();if db[key]==value then return end
        db[key]=value
        if ns.DuelCountdown then ns.DuelCountdown.Refresh() end
        if ns.Options and ns.Options.Refresh then ns.Options.Refresh() end
        return
    end
    if key=="duelCountdownStyle" then
        if type(value)~="string" or not allowedCountdownStyles[value] then return end
        local db=WriteDB();if db[key]==value then return end
        db[key]=value
        if ns.DuelCountdown then ns.DuelCountdown.Refresh() end
        if ns.Options and ns.Options.Refresh then ns.Options.Refresh() end
        return
    end
    if key=="duelHUDScale" or key=="duelHUDOpacity" then
        if type(value)~="number" or value~=value then return end
        local normalized=key=="duelHUDScale" and math.max(.8,math.min(1.2,math.floor(value*20+.5)/20)) or math.max(.3,math.min(1,math.floor(value*20+.5)/20))
        local db=WriteDB()
        if db[key]==normalized then return end
        db[key]=normalized
        if ns.DuelHUD then
            if key=="duelHUDOpacity" then ns.DuelHUD.ApplyOpacity()
            else ns.DuelHUD.Refresh() end
        end
        if ns.Options and ns.Options.RefreshHUDModified then ns.Options.RefreshHUDModified() end
        return
    end
    if accessDefaults[key] ~= nil then
        if key == "minimapAngle" then
            Settings.SetMinimapAngle(value)
            if ns.AccessIcons then ns.AccessIcons.Refresh() end
            return
        end
        if key == "iconMode" then
            if not allowedModes[value] then return end
        elseif type(value) ~= "number" or value ~= value then
            return
        elseif key == "minimapSize" then
            local low, high, step = Settings.MIN_MINIMAP_SIZE,
                Settings.MAX_MINIMAP_SIZE, Settings.MINIMAP_SIZE_STEP
            value = math.max(low, math.min(high, low + step *
                math.floor((value - low) / step + 0.5)))
        elseif key == "minimapTransparency" then
            value = math.max(0, math.min(Settings.MAX_MINIMAP_TRANSPARENCY,
                math.floor(value / 0.05 + 0.5) * 0.05))
        elseif key == "widgetSize" then
            value = math.max(24, math.min(128, 24 +
                2 * math.floor((value - 24) / 2 + 0.5)))
        elseif key == "widgetTransparency" then
            value = math.max(0, math.min(0.9,
                math.floor(value / 0.05 + 0.5) * 0.05))
        end
        local db = WriteDB()
        if db[key] == value then return end
        db[key] = value
        if ns.AccessIcons and ns.AccessIcons.Refresh then ns.AccessIcons.Refresh() end
        if ns.Options then
            if key == "iconMode" and ns.Options.Refresh then
                ns.Options.Refresh()
            elseif ns.Options.RefreshAccessModified then
                ns.Options.RefreshAccessModified()
            end
        end
        return
    end
    if key == "menuScale" then
        local nextValue = Settings.NormalizeScale(value)
        local db = WriteDB()
        if db.menuScale == nextValue then return end
        db.menuScale = nextValue
        if ns.Window and ns.Window.ApplyScale then
            ns.Window.ApplyScale(nextValue)
        end
        if ns.Window and ns.Window.RefreshScaleMarker then ns.Window.RefreshScaleMarker() end
        if ns.Footer and ns.Footer.Refresh then ns.Footer.Refresh() end
        return
    end
    -- Typography shares this settings owner and persists immediately.
    if key == "fontChoice" or key == "fontScale" or key == "fontOutline" then
        local nextValue
        if key == "fontChoice" then
            if type(value) ~= "string" or #value > 128 or value == "" then return end
            nextValue = value
        elseif key == "fontScale" then
            if type(value) ~= "number" or value ~= value then return end
            nextValue = Settings.NormalizeFontScale(value)
        else
            if value ~= "default" and value ~= "none" and
                value ~= "outline" and value ~= "thick" then return end
            nextValue = value
        end
        local db = WriteDB()
        if Settings.Get(key) == nextValue then return end
        db[key] = nextValue
        if ns.Theme and ns.Theme.Refresh then ns.Theme.Refresh() end
        return
    end
    if boolDefaults[key] == nil or type(value) ~= "boolean" then return end
    local db = WriteDB()
    if db[key] == value then return end
    db[key] = value
    if key == "patchNotesReminder" then
        if ns.PatchNotes and ns.PatchNotes.RefreshReminder then
            ns.PatchNotes.RefreshReminder()
        end
    elseif key == "duelCountdownSounds" or key=="duelFightSounds" then
        if ns.CountdownAudio then ns.CountdownAudio.Stop(key=="duelFightSounds" and "fight" or "countdown") end
        if ns.Options and ns.Options.Refresh then ns.Options.Refresh() end
    elseif key=="duelResultVisual" or key=="duelResultVignette" then
        if ns.DuelResult then ns.DuelResult.Refresh() end
        if ns.Options and ns.Options.Refresh then ns.Options.Refresh() end
    elseif key == "duelCountdownVisual" then
        if ns.DuelCountdown then ns.DuelCountdown.Refresh() end
        if ns.Options and ns.Options.Refresh then ns.Options.Refresh() end
    elseif key == "notificationEnabled" or key == "notificationSounds" then
        if ns.Notifications then ns.Notifications.Refresh() end
        if ns.Options and ns.Options.Refresh then ns.Options.Refresh() end
    elseif key == "autoPeekMoving" then
        if ns.Header and ns.Header.RefreshAutoPeek then
            ns.Header.RefreshAutoPeek()
        end
        if ns.Options and ns.Options.Refresh then ns.Options.Refresh() end
    elseif key == "warGamesConsent" then
        if ns.WarGames then ns.WarGames.PreferenceChanged() end
        if ns.Options and ns.Options.Refresh then ns.Options.Refresh() end
    elseif key == "duelHUDEnabled" or key == "duelHUDLocked" or key == "duelHUDAdaptive" or key == "duelHUDSessionStats" then
        if ns.DuelHUD then ns.DuelHUD.Refresh() end
        if ns.Options and ns.Options.Refresh then ns.Options.Refresh() end
    elseif key == "practiceDuels" then
        if ns.OpponentDiscovery and ns.OpponentDiscovery.PublishOffer then ns.OpponentDiscovery.PublishOffer() end
        if ns.DuelHUD then ns.DuelHUD.Refresh() end
        -- The live lifecycle captures the choice on the next challenge.
        if ns.Options and ns.Options.Refresh then ns.Options.Refresh() end
    elseif key == "competitiveConsent" then
        if ns.CompetitiveLifecycle then ns.CompetitiveLifecycle.PreferenceChanged() end
        if ns.OpponentDiscovery and ns.OpponentDiscovery.PublishOffer then ns.OpponentDiscovery.PublishOffer() end
        if ns.DuelHUD then ns.DuelHUD.Refresh() end
        if ns.Options and ns.Options.Refresh then ns.Options.Refresh() end
    elseif key == "showTooltips" then
        if not value and ns.Tooltips then ns.Tooltips.Hide(nil, true) end
        if ns.Options and ns.Options.Refresh then ns.Options.Refresh() end
    elseif key == "showGameMenuButton" then
        -- GameMenu owns the native button. A hidden menu refreshes on next open.
        if ns.GameMenu and ns.GameMenu.Refresh then ns.GameMenu.Refresh() end
        if ns.Options and ns.Options.Refresh then ns.Options.Refresh() end
    elseif key == "showInCompartment" then
        -- Registration is applied on PLAYER_LOGIN after /reload. The footer
        -- shows Reload UI because RegisterReloadRequired tracks this key.
        if ns.Options and ns.Options.Refresh then ns.Options.Refresh() end
    elseif ns.Theme then
        ns.Theme.Refresh()
    end
    if key == "reduceMotion" and ns.DuelCountdown then ns.DuelCountdown.Refresh() end
    if key == "reduceMotion" and ns.DuelResult then ns.DuelResult.Refresh() end
    if key == "reduceMotion" and ns.PatchNotes and
        ns.PatchNotes.RefreshReminder then
        ns.PatchNotes.RefreshReminder()
    end
    if ns.Footer and ns.Footer.Refresh then ns.Footer.Refresh() end
end

-- SavedVariables are authoritative only once this addon's ADDON_LOADED fires.
-- Seed missing/invalid values then repaint UI built from earlier defaults.
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, _, loadedName)
    if loadedName ~= addonName then return end
    self:UnregisterEvent("ADDON_LOADED")
    -- Competitive storage owns its separate roots; this only forwards lifecycle.
    if ns.CompetitiveStorage then ns.CompetitiveStorage.MarkLoaded() end
    local db = WriteDB()
    for key, default in pairs(boolDefaults) do
        if IsMatchPreference(key) then
            -- Keep nil for automatic detection. Legacy true/false choices
            -- remain intact; invalid saved types become auto.
            if db[key] ~= nil and type(db[key]) ~= "boolean" then
                db[key] = nil
            end
        elseif type(db[key]) ~= "boolean" then
            db[key] = default
        end
    end
    db.duelHUDScale = Settings.Get("duelHUDScale")
    db.duelHUDOpacity = Settings.Get("duelHUDOpacity")
    db.menuScale = Settings.NormalizeScale(db.menuScale)
    -- Normalize through the same getters, keeping existing SavedVariables.
    -- Retire old theme/color overrides; retain font and other player settings.
    db.uiTheme = nil
    db.matchColors = nil
    db.fontChoice = Settings.Get("fontChoice")
    db.fontScale = Settings.Get("fontScale")
    db.fontOutline = Settings.Get("fontOutline")
    db.duelCountdownStyle = Settings.Get("duelCountdownStyle")
    db.duelCountdownFont = Settings.Get("duelCountdownFont")
    db.duelCountdownSoundPack = Settings.Get("duelCountdownSoundPack")
    db.duelCountdownAudioChannel = Settings.Get("duelCountdownAudioChannel")
    db.duelFightSoundPack = Settings.Get("duelFightSoundPack")
    db.duelFightAudioChannel = Settings.Get("duelFightAudioChannel")
    for key in pairs(accessDefaults) do db[key] = Settings.Get(key) end
    if type(db.patchNotesSeenId) ~= "string" or
        #db.patchNotesSeenId > 128 then
        db.patchNotesSeenId = nil
    end
    local position = db.widgetPosition
    if position ~= nil then
        local valid = type(position) == "table" and
            type(position.x) == "number" and type(position.y) == "number" and
            position.x == position.x and position.y == position.y and
            math.abs(position.x) <= 10000 and math.abs(position.y) <= 10000
        if not valid then db.widgetPosition = nil end
    end
    if type(db.discoverySeen) ~= "table" then
        db.discoverySeen = {}
    else
        for id, seen in pairs(db.discoverySeen) do
            if not discoveries[id] or seen ~= true then db.discoverySeen[id] = nil end
        end
    end
    if not Settings.HasWindowSize() then db.windowSize = nil end
    for key in pairs(reloadRequired) do loadValues[key] = Settings.Get(key) end
    if ns.Window and ns.Window.ApplyScale then
        ns.Window.ApplyScale(db.menuScale)
    end
    if ns.Theme and ns.Theme.Refresh then ns.Theme.Refresh() end
    if ns.Header and ns.Header.RefreshAutoPeek then
        ns.Header.RefreshAutoPeek()
    end
    if ns.Window and ns.Window.RefreshScaleMarker then ns.Window.RefreshScaleMarker() end
    if ns.Footer and ns.Footer.Refresh then ns.Footer.Refresh() end
    if ns.AccessIcons and ns.AccessIcons.Refresh then ns.AccessIcons.Refresh() end
    if ns.PatchNotes and ns.PatchNotes.RefreshReminder then
        ns.PatchNotes.RefreshReminder()
    end
    if ns.Feedback then ns.Feedback.RefreshDiscovery() end
    if ns.CompetitiveLifecycle and ns.CompetitiveLifecycle.Initialize then
        ns.CompetitiveLifecycle.Initialize()
    end
end)
