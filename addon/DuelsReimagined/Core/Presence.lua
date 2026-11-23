local addonName, ns = ...

-- Cross-client, session-only addon detection. NOT a War Games subsystem.
-- A reply proves that this group member is speaking our protocol, but an
-- unanswered request NEVER proves that the member lacks the addon.
local Group, Comm = ns.Group, ns.Communication
local Presence = {}
ns.Presence = Presence

local CHECK_GAP = 15
local REPLY_GAP = 10
local WAIT_SECONDS = 8
local callbacks = {}
local known = {}
local signature
local lastCheck = -math.huge
local lastReply = -math.huge
local pendingUntil = 0
local epoch = 0
local revision = 0

local function Readable(v)
    if type(issecretvalue) == "function" then
        local ok, secret = pcall(issecretvalue, v)
        if not ok or secret then return false end
    end
    return true
end

local function Clock()
    if type(GetTime) ~= "function" then return 0 end
    local ok, time = pcall(GetTime)
    if not ok or not Readable(time) or type(time) ~= "number" or
        time ~= time then return 0 end
    return time
end

local function Version(v)
    if not Readable(v) or type(v) ~= "string" or #v < 1 or #v > 32 then
        return nil
    end
    if not v:match("^[%w%._%-]+$") then return nil end
    return v
end

local function MyVersion()
    local c = C_AddOns
    local getter = c and c.GetAddOnMetadata or GetAddOnMetadata
    if type(getter) ~= "function" then return nil end
    local ok, raw = pcall(getter, addonName, "Version")
    if not ok then return nil end
    return Version(raw)
end

local function Key(member)
    if type(member.guid) == "string" and member.guid ~= "" then
        return "guid:" .. member.guid
    end
    if type(member.fullName) == "string" and member.fullName ~= "" then
        return "name:" .. member.fullName
    end
end

local function IsSelf(member)
    if member.unit == "player" then return true end
    if type(UnitIsUnit) == "function" then
        local ok, same = pcall(UnitIsUnit, member.unit, "player")
        if ok and Readable(same) and same == true then return true end
    end
    if type(UnitGUID) == "function" and member.guid then
        local ok, guid = pcall(UnitGUID, "player")
        if ok and Readable(guid) and type(guid) == "string"
            and guid == member.guid then return true end
    end
    return false
end

local function CurrentGroup()
    local roster = Group and Group.GetSnapshot and Group.GetSnapshot()
    if not roster or not roster.complete or
        (roster.mode ~= "party" and roster.mode ~= "raid") then return nil end
    return roster
end

local function Channel(roster)
    return roster.mode == "raid" and "RAID" or "PARTY"
end

local function MembersSignature(roster)
    local ids = {}
    for _, member in ipairs(roster.members) do
        local key = Key(member)
        if not key then return nil end
        ids[#ids + 1] = key
    end
    table.sort(ids)
    return roster.mode .. ":" .. table.concat(ids, ",")
end

local function Status(roster, member)
    if IsSelf(member) then return "self", MyVersion() end
    if member.online == false then return "offline" end
    if not roster.complete or roster.stale then return "unknown" end
    local record = known[Key(member)]
    if record then return "confirmed", record.version end
    if Clock() < pendingUntil then return "checking" end
    return "unknown"
end

function Presence.GetSnapshot()
    local roster = Group and Group.GetSnapshot and Group.GetSnapshot() or
        { mode="unknown", complete=false, members={} }
    local ready, reason = Comm.IsAvailable()
    local result = {
        mode=roster.mode, complete=roster.complete, stale=roster.stale or false,
        revision=revision, transport=ready and "ready" or reason,
        members={},
    }
    for _, member in ipairs(roster.members) do
        local item = {}
        for k, v in pairs(member) do item[k] = v end
        item.status, item.version = Status(roster, member)
        if not roster.complete then item.status = "unknown" end
        result.members[#result.members + 1] = item
    end
    return result
end

local function Changed()
    revision = revision + 1
    for cb in pairs(callbacks) do pcall(cb, Presence.GetSnapshot()) end
end

function Presence.Subscribe(fn)
    if type(fn) ~= "function" then return function() end end
    callbacks[fn] = true
    return function() callbacks[fn] = nil end
end

local function ScheduleExpiry()
    epoch = epoch + 1
    local id = epoch
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(WAIT_SECONDS + 0.05, function()
            if epoch ~= id then return end
            pendingUntil = 0
            Changed()
        end)
    end
end

function Presence.CheckNow()
    local roster = CurrentGroup()
    if not roster then return false, "no-group" end
    local current = Clock()
    if current - lastCheck < CHECK_GAP then return false, "cooldown" end
    local ok, reason = Comm.Send("P1", "H|" .. (MyVersion() or "?"), Channel(roster))
    if not ok then return false, reason end
    lastCheck = current
    pendingUntil = current + WAIT_SECONDS
    ScheduleExpiry()
    Changed()
    return true
end

local function ResetIfChanged(roster, notify)
    local nextSignature = roster and MembersSignature(roster)
    if nextSignature == signature then
        if notify then Changed() end
        return
    end
    signature = nextSignature
    pendingUntil = 0
    epoch = epoch + 1
    if not signature then
        known = {}
    else
        local present = {}
        for _, member in ipairs(roster.members) do present[Key(member)] = true end
        for key in pairs(known) do
            if not present[key] then known[key] = nil end
        end
    end
    Changed()
    if signature then Presence.CheckNow() end
end

-- Roster information belongs ONLY to Group. We keep peer presence from the
-- current membership, never from an independent party/raid scanner.
if Group and Group.Subscribe then
    Group.Subscribe(function(roster) ResetIfChanged(
        roster.complete and (roster.mode == "party" or roster.mode == "raid")
        and roster or nil, true) end)
end

local function FromSender(sender, roster)
    local found
    for _, member in ipairs(roster.members) do
        if not IsSelf(member) then
            local match = member.fullName == sender
            if not match and type(UnitIsUnit) == "function" then
                local ok, yes = pcall(UnitIsUnit, sender, member.unit)
                match = ok and Readable(yes) and yes == true
            end
            if match then
                if found then return nil end
                found = member
            end
        end
    end
    return found
end

Comm.Subscribe("P1", function(body, channel, sender)
    local roster = CurrentGroup()
    if not roster or channel ~= Channel(roster) then return end
    if not Readable(body) or not Readable(sender) or
        type(body) ~= "string" or type(sender) ~= "string" then return end
    local kind, version = body:match("^([HA])|([^|]+)$")
    if not kind or (version ~= "?" and not Version(version)) then return end
    local member = FromSender(sender, roster)
    if not member or not Key(member) then return end
    local key = Key(member)
    local reported = version ~= "?" and version or nil
    if not known[key] or known[key].version ~= reported then
        known[key] = { version=reported }
        Changed()
    end
    -- One group announcement at most per burst of incoming HELLOs; raid
    -- members do not flood the channel with one reply per sender.
    if kind == "H" and Clock() - lastReply >= REPLY_GAP then
        local sent = Comm.Send("P1", "A|" .. (MyVersion() or "?"), channel)
        if sent then lastReply = Clock() end
    end
end)

-- When the player leaves a restricted PvP area, make a fresh attempt when
-- allowed; never send repeatedly while restrictions remain in force.
local driver = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_ENTERING_WORLD",
    "ZONE_CHANGED_NEW_AREA", "ADDON_RESTRICTION_STATE_CHANGED" }) do
    pcall(driver.RegisterEvent, driver, event)
end
driver:SetScript("OnEvent", function()
    local roster = CurrentGroup()
    ResetIfChanged(roster)
    if roster and Clock() - lastCheck >= CHECK_GAP then
        Presence.CheckNow()
    end
end)
