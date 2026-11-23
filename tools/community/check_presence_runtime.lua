-- Retail/Forever addon detection: local mocks only, no real peers or WoW.
local function Check(value, msg) if not value then error(msg, 2) end end
local frames, timerQueue, outbound = {}, {}, {}
local now = 100
local HIDDEN = {}
issecretvalue = function(value) return value == HIDDEN end
GetTime = function() return now end
IsInInstance = function() return false, "none" end
C_Timer = { After = function(delay, callback)
    timerQueue[#timerQueue + 1] = { at = now + delay, call = callback }
end }
local function Advance(seconds)
    now = now + seconds
    local waiting, fired = timerQueue, {}
    timerQueue = {}
    for _, timer in ipairs(waiting) do
        if timer.at <= now then fired[#fired + 1] = timer.call
        else timerQueue[#timerQueue + 1] = timer end
    end
    for _, fn in ipairs(fired) do fn() end
end
CreateFrame = function()
    local frame = { handlers={}, events={} }
    function frame:RegisterEvent(name) self.events[name] = true end
    function frame:SetScript(name, fn) self.handlers[name] = fn end
    frames[#frames + 1] = frame
    return frame
end
local registerCount, registerResult, sendResult = 0, 0, 0
C_ChatInfo = {
    RegisterAddonMessagePrefix = function(prefix)
        registerCount = registerCount + 1
        Check(prefix == "DuelsReimagined", "one owned addon prefix")
        return registerResult
    end,
    SendAddonMessage = function(prefix, message, channel)
        outbound[#outbound + 1] = { prefix=prefix, message=message, channel=channel }
        return sendResult
    end,
}
Enum = { SendAddonMessageResult={ Success=0 },
    AddOnRestrictionType={ Chat=5 } }
local locked = false
C_RestrictedActions = { IsAddOnRestrictionActive = function()
    return locked
end }
GetAddOnMetadata = function() return nil end
local mine = {unit="player", name="Alpha", fullName="Alpha-Home",
    guid="GUID-A", online=true, isLeader=false}
local beta = {unit="party1", name="Beta", fullName="Beta-Other",
    guid="GUID-B", online=true, isLeader=true}
local gamma = {unit="party2", name="Gamma", fullName="Gamma-Else",
    guid="GUID-C", online=true, isLeader=false}
local group = {mode="solo", complete=true, stale=false, members={mine}}
local groupListeners = {}
local G = {
    GetSnapshot = function() return group end,
    Subscribe = function(fn)
        groupListeners[#groupListeners + 1] = fn
        return function() end
    end,
}
UnitIsUnit = function(a, b) return a == b end
UnitGUID = function(unit) return unit == "player" and "GUID-A" or nil end
local ns = { Group=G, Client={IsRetail=function() return true end,
    IsSupported=function() return true end} }
assert(loadfile("addon/DuelsReimagined/Core/Communication.lua"))("DuelsReimagined",ns)
assert(loadfile("addon/DuelsReimagined/Core/Presence.lua"))("DuelsReimagined",ns)
Check(#frames == 2, "one communication frame and one restriction-event frame")
local Comm, Presence = ns.Communication, ns.Presence
local commFrame, presenceFrame = frames[1], frames[2]
local function Message(payload, sender, channel, prefix)
    commFrame.handlers.OnEvent(commFrame,"CHAT_MSG_ADDON",
        prefix or Comm.PREFIX,payload,channel or "PARTY",sender)
end
local function SetGroup(mode, members, complete)
    group = {mode=mode, complete=complete ~= false, members=members or {}}
    for _, fn in ipairs(groupListeners) do fn(group) end
end
local callbacks = 0
local disconnect = Presence.Subscribe(function(s)
    callbacks = callbacks + 1
    if s.members[1] then s.members[1].name = "tampered" end
end)
Check(Presence.GetSnapshot().mode == "solo", "solo snapshot")
Check(#outbound == 0, "solo must never send presence messages")
SetGroup("party",{mine,beta})
Check(#outbound == 1 and outbound[1].message == "P1|H|?"
    and outbound[1].channel == "PARTY", "party hello with unknown version")
Check(registerCount == 1, "prefix registered once")
local snap = Presence.GetSnapshot()
Check(snap.complete and #snap.members == 2, "presence wraps shared roster")
Check(snap.members[1].status == "self" and snap.members[1].name == "Alpha",
    "self must not be marked a remote peer")
Check(snap.members[2].status == "checking", "sent request is not a confirmed peer")
Check(snap.members[2].version == nil, "do not invent an addon version")
Check(snap.transport == "ready", "transport reported ready")

Message("P1|A|1.2.3","Stranger-Realm")
Message("P1|A|1.2.3","Beta-Other","GUILD")
Message("P1|A|1.2.3","Beta-Other","PARTY","WrongPrefix")
Message("P1|A|1.2.3",HIDDEN)
Message("P1|A|invalid|extra","Beta-Other")
Check(Presence.GetSnapshot().members[2].status == "checking",
    "untrusted or malformed messages never confirm presence")
Message("P1|A|1.2.3","Beta-Other")
snap = Presence.GetSnapshot()
Check(snap.members[2].status == "confirmed"
    and snap.members[2].version == "1.2.3", "roster-bound version confirmation")
Check(snap.members[2].name == "Beta", "caller cannot mutate stored roster")

local before = #outbound
Message("P1|H|1.2.4","Beta-Other")
Check(#outbound == before + 1 and outbound[#outbound].message == "P1|A|?",
    "hello must generate one bounded answer")
before = #outbound
Message("P1|H|1.2.4","Beta-Other")
Check(#outbound == before, "repeated hello must be throttled")
Check(Presence.GetSnapshot().members[2].version == "1.2.4",
    "valid new reported version replaces old version")
Advance(9)
Check(Presence.GetSnapshot().members[2].status == "confirmed",
    "expiry must not clear confirmed users")
Check(not Presence.CheckNow(), "manual recheck respects cooldown")
Advance(7)
Check(Presence.CheckNow(), "manual recheck succeeds after cooldown")

local copy = Presence.GetSnapshot()
copy.members[2].version = "mutated"
Check(Presence.GetSnapshot().members[2].version == "1.2.4",
    "presence snapshots must be detached")
local others = {unit="party1", name="Beta", fullName="Beta-DifferentRealm",
    guid="GUID-D", online=true}
SetGroup("party",{mine,others})
snap = Presence.GetSnapshot()
Check(snap.members[2].status ~= "confirmed",
    "replacement with same short name may not inherit confirmation")
Message("P1|A|1.2.4","Beta-Other")
Check(Presence.GetSnapshot().members[2].status ~= "confirmed",
    "departed sender is not current group member")

SetGroup("party",{mine,beta,gamma})
Message("P1|A|2.1.0","Gamma-Else")
Check(Presence.GetSnapshot().members[3].status == "confirmed",
    "three-member group presence")
gamma.online = false
SetGroup("party",{mine,beta,gamma})
Check(Presence.GetSnapshot().members[3].status == "offline",
    "offline group member is not current confirmation")
gamma.online = true
SetGroup("party",{mine,beta,gamma})
Check(Presence.GetSnapshot().members[3].status == "confirmed",
    "same member may recover live session confirmation")
SetGroup("solo",{mine})
Check(#Presence.GetSnapshot().members == 1 and #outbound >= 2,
    "solo group transition clears roster")
SetGroup("party",{mine,beta})
Check(Presence.GetSnapshot().members[2].status ~= "confirmed",
    "new party session must not retain old confirmations")

locked = true
Advance(20)
before = #outbound
local sent, why = Presence.CheckNow()
Check(not sent and why == "restricted" and #outbound == before,
    "chat restriction blocks sending without fabricating a result")
Check(Presence.GetSnapshot().transport == "restricted",
    "UI can explain restriction without claiming addon absent")
locked = false
sendResult = 11
sent, why = Comm.Send("P1", "H|?", "PARTY")
Check(not sent and why == "refused", "refused Blizzard result is not a success")
sendResult = 0
local unblocked = Presence.CheckNow()
Check(unblocked == true, "failed attempt never starts cooldown")
Check(#outbound > before, "transport recovers after restrictions")
before = callbacks
SetGroup("raid",{mine,beta})
Check(callbacks > before, "raid roster refreshes existing subscribers")
Check(Presence.GetSnapshot().mode == "raid", "raid mode supported")
Advance(16)
Check(Presence.CheckNow(), "raid check after cooldown")
Check(outbound[#outbound].channel == "RAID", "raid check uses RAID channel")
Message("P1|A|3.0","Beta-Other","PARTY")
Check(Presence.GetSnapshot().members[2].status ~= "confirmed",
    "cross-channel messages are refused")
Message("P1|A|3.0","Beta-Other","RAID")
Check(Presence.GetSnapshot().members[2].status == "confirmed",
    "raid replies are accepted")

disconnect()
before = callbacks
SetGroup("solo",{mine})
Check(callbacks == before, "unsubscribe prevents future changes")
SetGroup("unknown",{},false)
Check(#Presence.GetSnapshot().members == 0
    and Presence.GetSnapshot().complete == false,
    "incomplete roster cannot leak stale confirmations")
print("Addon communication and presence runtime contracts: PASS")
