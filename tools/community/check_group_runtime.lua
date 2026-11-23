-- Runtime mocks for the shared Retail/Forever group roster.
local function Check(condition, why) if not condition then error(why, 2) end end
local mode, entries, secret = "solo", {}, {}
local HIDDEN = {}
issecretvalue = function(v) return v == HIDDEN end
UNKNOWNOBJECT = "Unknown"
Constants = { CharacterNameSeparatorConsts = { CHARACTERNAME_SURNAME_SEPARATOR = " " } }
GetBuildInfo = function() return "mock", "mock", "mock", 120105 end
IsInRaid = function() return mode == "raid" and true or nil end
IsInGroup = function() return mode ~= "solo" and true or nil end
GetNumGroupMembers = function()
    local n = 0
    for _ in pairs(entries) do n = n + 1 end
    return n
end
GetNumSubgroupMembers = function()
    local n = 0
    for id in pairs(entries) do if id:match("^party%d+$") then n = n + 1 end end
    return n
end
UnitName = function(id)
    if secret[id] then return HIDDEN end
    local m = entries[id]
    return m and m.name, m and m.second
end
UnitFullName = function(id)
    local m = entries[id]
    return m and m.name, m and m.realm
end
GetNormalizedRealmName = function() return "Home" end
UnitClass = function(id)
    local m = entries[id]
    if m and m.secretClass then return HIDDEN end
    return "Warrior", "WARRIOR", 1
end
UnitGUID = function(id) return entries[id] and (entries[id].guid or HIDDEN) end
UnitIsGroupLeader = function(id) return entries[id] and entries[id].leader end
UnitIsGroupAssistant = function(id) return entries[id] and entries[id].assistant end
UnitIsConnected = function(id)
    local m = entries[id]
    return m and (not m.offline)
end
GetRaidRosterInfo = function(i)
    local m = entries["raid" .. i]
    return m and m.name, m and (m.leader and 2 or 0), m and m.subgroup
end
local frame
CreateFrame = function()
    frame = { events={}, scripts={} }
    function frame:RegisterEvent(event)
        if event == "UNIT_NAME_UPDATE" then error("optional event unavailable") end
        self.events[event] = true
    end
    function frame:SetScript(event, fn) self.scripts[event] = fn end
    return frame
end
local function Load()
    local ns = {}
    assert(loadfile("addon/DuelsReimagined/Core/Client.lua"))("DuelsReimagined", ns)
    assert(loadfile("addon/DuelsReimagined/Core/Group.lua"))("DuelsReimagined", ns)
    return ns.Group, frame
end
local function Fire(f, event, unit)
    Check(f.events[event], "unregistered group event " .. event)
    f.scripts.OnEvent(f, event, unit)
end
entries.player = {name="Alpha", guid="Player-1"}
local roster, events = Load()
local notifications = 0
local remove = roster.Subscribe(function(s)
    notifications = notifications + 1
    if s.members[1] then s.members[1].name = "changed" end
end)
roster.Subscribe(function() error("consumer deliberately fails") end)
Fire(events, "PLAYER_ENTERING_WORLD")
local snap = roster.GetSnapshot()
Check(snap.mode == "solo" and snap.complete and #snap.members == 1, "solo roster")
Check(snap.members[1].fullName == "Alpha-Home", "Retail player realm")
Check(snap.members[1].name == "Alpha" and snap.members[1].isLeader == false, "protected copy and nil boolean")
snap.members[1].name = "bad"
Check(roster.GetSnapshot().members[1].name == "Alpha", "snapshot must be copied")
Fire(events, "GROUP_ROSTER_UPDATE")
Check(notifications == 1, "identical roster cannot notify twice")
mode = "party"
entries.party1 = {name="Beta",realm="Other",second="Other",guid="Player-2",leader=true}
Fire(events, "GROUP_ROSTER_UPDATE")
snap = roster.GetSnapshot()
Check(snap.complete and #snap.members == 2 and snap.members[2].isLeader, "party leader")
Check(snap.members[2].fullName == "Beta-Other", "Retail cross-realm name")
Check(snap.members[2].classFile == "WARRIOR", "class token")
local previous = notifications
Fire(events, "UNIT_CONNECTION", "target")
Check(previous == notifications, "irrelevant unit should not update roster")
entries.party1.leader, entries.player.leader = nil, true
Fire(events, "PARTY_LEADER_CHANGED")
Check(roster.GetSnapshot().members[1].isLeader == true, "leader change")
secret.party1 = true
Fire(events, "GROUP_ROSTER_UPDATE")
snap = roster.GetSnapshot()
Check(not snap.complete and snap.stale and #snap.members == 2 and not roster.IsReady(),
    "snapshot should be incomplete when a member is secret")
secret.party1 = nil
Fire(events, "UNIT_CONNECTION", "party1")
Check(roster.IsReady() and not roster.GetSnapshot().stale, "readable name recovery")
entries.party1.secretClass = true
Fire(events, "GROUP_ROSTER_UPDATE")
Check(roster.IsReady() and roster.GetSnapshot().members[2].class == nil,
    "secret class should remain unknown while names are readable")
entries.party1.secretClass = nil
Fire(events, "GROUP_ROSTER_UPDATE")
mode = "solo"; entries.party1 = nil
Fire(events, "GROUP_ROSTER_UPDATE")
Check(roster.IsReady() and #roster.GetSnapshot().members == 1, "leaving party clears members")
mode = "raid"
entries = {
    raid1={name="Alpha",realm="Home",guid="Player-1",subgroup=1,leader=true},
    raid2={name="Gamma",realm="Elsewhere",guid="Player-3",subgroup=2,assistant=true,offline=true},
}
Fire(events, "GROUP_ROSTER_UPDATE")
snap = roster.GetSnapshot()
Check(snap.mode == "raid" and snap.complete and #snap.members == 2, "raid roster")
Check(snap.members[2].subgroup == 2 and snap.members[2].isAssistant == true
    and snap.members[2].online == false, "raid subgroup/assistant/offline")
secret.raid2 = true
Fire(events, "GROUP_ROSTER_UPDATE")
Check(not roster.IsReady() and roster.GetSnapshot().stale, "incomplete raid")
mode = "party"; entries = {player={name="Alpha",realm="Home"}}
Fire(events, "GROUP_ROSTER_UPDATE")
Check(not roster.IsReady() and #roster.GetSnapshot().members == 0,
    "raid members must never leak into changed group mode")
mode = "solo"; secret = {}
Fire(events, "GROUP_ROSTER_UPDATE")
Check(roster.IsReady(), "recovery")
remove()
previous = notifications
mode = "party"; entries.party1 = {name="Beta",realm="Other"}
Fire(events, "GROUP_ROSTER_UPDATE")
Check(previous == notifications, "unsubscription")
GetBuildInfo = function() return "mock", "mock", "mock", 16001 end
mode = "party"
entries = {
    player={name="Ana",second="Smith",guid="Player-A"},
    party1={name="Bob Jones",second="Jones",guid="Player-B"},
}
local forever, ff = Load()
Fire(ff, "PLAYER_ENTERING_WORLD")
snap = forever.GetSnapshot()
Check(snap.complete and #snap.members == 2, "Forever party")
Check(snap.members[1].fullName == "Ana Smith", "Forever surname")
Check(snap.members[2].fullName == "Bob Jones", "do not duplicate surname")
IsInGroup = nil
Fire(ff, "GROUP_ROSTER_UPDATE")
Check(not forever.IsReady() and forever.GetSnapshot().mode == "unknown",
    "missing API fails closed")
print("Group roster runtime contracts: PASS")
