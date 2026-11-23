local _, ns = ...

-- Shared, read-only roster for Retail and Forever. Blizzard is the sole
-- source. No SavedVariables, network messages, timers, or OnUpdate.
local Group = {}
ns.Group = Group
local listeners = {}
local current = { mode = "unknown", complete = false, members = {}, revision = 0 }

-- Inspect secrecy BEFORE touching a value with type, comparisons or keys.
local function Readable(v)
    if type(issecretvalue) == "function" then
        local ok, secret = pcall(issecretvalue, v)
        if not ok or secret then return false end
    end
    return true
end
local function ReadOne(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a = pcall(fn, ...)
    if not ok or not Readable(a) then return nil end
    return a
end
local function ReadTwo(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if not ok or not Readable(a) or not Readable(b) then return nil end
    return a, b
end
local function ReadThree(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if not ok or not Readable(a) or not Readable(b) or not Readable(c) then
        return nil
    end
    return a, b, c
end
-- Many Blizzard boolean APIs return nil for FALSE; a secret/error is UNKNOWN.
local function Flag(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, answer = pcall(fn, ...)
    if not ok or not Readable(answer) then return nil end
    return answer == true
end
local function Count(fn, maximum)
    local n = ReadOne(fn)
    if type(n) ~= "number" or n ~= n or n < 0 or n > maximum
        or n ~= math.floor(n) then return nil end
    return n
end

-- On Forever UnitName returns a first name and surname. Retail returns
-- a name and realm. Use UnitFullName where available for Retail realms.
local function Identity(unit)
    local first, second = ReadTwo(UnitName, unit)
    if type(first) ~= "string" or first == "" or first == UNKNOWNOBJECT then
        return nil
    end
    local full = first
    if ns.Client and ns.Client.IsForever and ns.Client.IsForever() then
        local separator = " "
        local constants = Constants and Constants.CharacterNameSeparatorConsts
        local custom = constants and constants.CHARACTERNAME_SURNAME_SEPARATOR
        if Readable(custom) and type(custom) == "string" and custom ~= "" then
            separator = custom
        end
        if not first:find(separator, 1, true)
            and type(second) == "string" and second ~= "" then
            full = first .. separator .. second
        end
    else
        local name, realm = ReadTwo(UnitFullName, unit)
        if name == first and type(realm) == "string" and realm ~= "" then
            second = realm
        end
        if not first:find("-", 1, true)
            and type(second) == "string" and second ~= "" then
            full = first .. "-" .. second
        end
        if full == first and unit == "player" then
            local home = ReadOne(GetNormalizedRealmName)
            if type(home) == "string" and home ~= "" then
                full = first .. "-" .. home
            end
        end
    end
    return first, full
end

local function Member(unit, raidIndex)
    local name, fullName = Identity(unit)
    if not name then return nil end
    local class, classFile, classID = ReadThree(UnitClass, unit)
    local subgroup
    if raidIndex then
        local _, _, value = ReadThree(GetRaidRosterInfo, raidIndex)
        if type(value) == "number" and value >= 1 and value <= 8 then
            subgroup = value
        end
    end
    return {
        unit = unit, name = name, fullName = fullName,
        guid = ReadOne(UnitGUID, unit),
        class = class, classFile = classFile, classID = classID,
        subgroup = subgroup,
        isLeader = Flag(UnitIsGroupLeader, unit),
        isAssistant = Flag(UnitIsGroupAssistant, unit),
        online = Flag(UnitIsConnected, unit),
    }
end

local fields = { "unit", "name", "fullName", "guid", "class", "classFile",
    "classID", "subgroup", "isLeader", "isAssistant", "online" }

local function Build()
    local raid, grouped = Flag(IsInRaid), Flag(IsInGroup)
    if raid == nil or grouped == nil then
        return { mode = "unknown", complete = false, members = {} }
    end
    local mode = raid and "raid" or grouped and "party" or "solo"
    local nextState = { mode = mode, complete = true, members = {} }
    local units = {}
    if mode == "raid" then
        local n = Count(GetNumGroupMembers, 40)
        if not n or n < 1 then nextState.complete = false else
            for i = 1, n do units[#units + 1] = { "raid" .. i, i } end
        end
    else
        units[1] = { "player" }
        if mode == "party" then
            local n = Count(GetNumSubgroupMembers, 4)
            local whole = Count(GetNumGroupMembers, 5)
            if not n or n < 1 or not whole or whole ~= n + 1 then
                nextState.complete = false
            else
                for i = 1, n do units[#units + 1] = { "party" .. i } end
            end
        end
    end
    if nextState.complete then
        for _, entry in ipairs(units) do
            local member = Member(entry[1], entry[2])
            if not member then nextState.complete = false; break end
            nextState.members[#nextState.members + 1] = member
        end
    end
    if not nextState.complete then
        -- Stale data cannot authorize gameplay actions. Do not carry a party
        -- over into a raid (or vice versa) when a name becomes unreadable.
        if current.mode == mode and current.complete then
            nextState.members = current.members
        end
        nextState.stale = true
    end
    return nextState
end

local function Same(a, b)
    if a.mode ~= b.mode or a.complete ~= b.complete or a.stale ~= b.stale
        or #a.members ~= #b.members then return false end
    for i = 1, #a.members do
        for _, key in ipairs(fields) do
            if a.members[i][key] ~= b.members[i][key] then return false end
        end
    end
    return true
end

local function Copy(s)
    local result = { mode = s.mode, complete = s.complete,
        stale = s.stale or false, revision = s.revision, members = {} }
    for i, member in ipairs(s.members) do
        local value = {}
        for _, key in ipairs(fields) do value[key] = member[key] end
        result.members[i] = value
    end
    return result
end

function Group.GetSnapshot() return Copy(current) end
function Group.IsReady() return current.complete end
function Group.Subscribe(fn)
    if type(fn) ~= "function" then return function() end end
    listeners[fn] = true
    return function() listeners[fn] = nil end
end
function Group.Refresh()
    local nextState = Build()
    if Same(nextState, current) then return false end
    nextState.revision = current.revision + 1
    current = nextState
    for fn in pairs(listeners) do pcall(fn, Copy(current)) end
    return true
end

local driver = CreateFrame("Frame")
driver:SetScript("OnEvent", function(_, event, unit)
    if event == "UNIT_CONNECTION" or event == "UNIT_NAME_UPDATE" then
        if not Readable(unit) or type(unit) ~= "string" then return end
        if unit ~= "player" and not unit:match("^party%d+$")
            and not unit:match("^raid%d+$") then return end
    end
    Group.Refresh()
end)
-- Event-driven only; unrecognized optional events are skipped safely.
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE",
    "PARTY_LEADER_CHANGED", "UNIT_CONNECTION", "UNIT_NAME_UPDATE" }) do
    pcall(driver.RegisterEvent, driver, event)
end
