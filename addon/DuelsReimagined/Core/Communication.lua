local _, ns = ...

-- Duels Reimagined's single addon-message transport owner for BOTH clients.
-- Presence and future gameplay protocols share this prefix and this event.
local Comm = {}
ns.Communication = Comm
Comm.PREFIX = "DuelsReimagined"

local receivers = {}
local registered = false

local function Readable(value)
    if type(issecretvalue) == "function" then
        local ok, secret = pcall(issecretvalue, value)
        if not ok or secret then return false end
    end
    return true
end

function Comm.Register()
    if registered then return true end
    local c = C_ChatInfo
    if not c or type(c.RegisterAddonMessagePrefix) ~= "function" then
        return false
    end
    local ok, result = pcall(c.RegisterAddonMessagePrefix, Comm.PREFIX)
    -- The modern enum returns 0 for success and 1 for already registered.
    -- Older clients may return true or nil.
    registered = ok and (result == nil or result == true
        or result == 0 or result == 1)
    return registered
end

local function ChatRestricted()
    local restrictions = C_RestrictedActions
    local kind = Enum and Enum.AddOnRestrictionType
    if restrictions and kind and kind.Chat ~= nil and
        type(restrictions.IsAddOnRestrictionActive) == "function" then
        local ok, active = pcall(restrictions.IsAddOnRestrictionActive, kind.Chat)
        if not ok or not Readable(active) then return true end
        if active then return true end
    end
    -- Retail's active arena/BG chat restrictions can reject addon messages;
    -- never even attempt a presence handshake in that environment.
    if ns.Client and ns.Client.IsRetail and ns.Client.IsRetail()
        and type(IsInInstance) == "function" then
        local ok, inside, kindOfInstance = pcall(IsInInstance)
        if not ok or not Readable(inside) or not Readable(kindOfInstance) then
            return true
        end
        if inside and (kindOfInstance == "arena" or kindOfInstance == "pvp") then
            return true
        end
    end
    return false
end

function Comm.IsAvailable()
    if ns.Client and ns.Client.IsSupported and not ns.Client.IsSupported() then
        return false, "unsupported"
    end
    if ChatRestricted() then return false, "restricted" end
    if not Comm.Register() then return false, "unavailable" end
    return true
end

-- Message tags are uppercase letters plus a numeric protocol revision,
-- for example P1 (presence) or a future W1 (retail War Games).
function Comm.GetDiagnosticResources()
    local n=0
    for _,callbacks in pairs(receivers) do
        for _ in pairs(callbacks) do n=n+1 end
    end
    return {subscriptions=n}
end
function Comm.Subscribe(tag, callback)
    if type(tag) ~= "string" or not tag:match("^[A-Z]%d$") or
        type(callback) ~= "function" then return function() end end
    local callbacks = receivers[tag]
    if not callbacks then callbacks = {}; receivers[tag] = callbacks end
    callbacks[callback] = true
    return function() callbacks[callback] = nil end
end

function Comm.Send(tag, body, channel)
    if not Readable(tag) or not Readable(body) or not Readable(channel) or
        type(tag) ~= "string" or not tag:match("^[A-Z]%d$") or
        type(body) ~= "string" or type(channel) ~= "string" or
        (channel ~= "PARTY" and channel ~= "RAID") or
        #tag + #body + 1 > 240 then return false, "invalid" end
    local allowed, reason = Comm.IsAvailable()
    if not allowed then return false, reason end
    local fn = C_ChatInfo and C_ChatInfo.SendAddonMessage
    if type(fn) ~= "function" then return false, "unavailable" end
    local ok, result = pcall(fn, Comm.PREFIX, tag .. "|" .. body, channel)
    if not ok then return false, "refused" end
    local outcomes = Enum and Enum.SendAddonMessageResult
    local success = outcomes and outcomes.Success or 0
    if result ~= nil and result ~= true and result ~= success then
        return false, "refused"
    end
    -- Success means only Blizzard accepted the outgoing request, NOT that
    -- another player received or answered it.
    return true
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:SetScript("OnEvent", function(_, event, prefix, payload, channel, sender)
    if event == "PLAYER_ENTERING_WORLD" then
        Comm.Register()
        return
    end
    if not Readable(prefix) or not Readable(payload) or
        not Readable(channel) or not Readable(sender) or
        prefix ~= Comm.PREFIX or type(payload) ~= "string" or
        #payload > 240 or type(channel) ~= "string" or
        type(sender) ~= "string" or sender == "" then return end
    if channel ~= "PARTY" and channel ~= "RAID" then return end
    local tag, body = payload:match("^([A-Z]%d)|(.+)$")
    if not tag then return end
    local callbacks = receivers[tag]
    if not callbacks then return end
    for fn in pairs(callbacks) do
        -- A bad feature cannot disable the whole message transport.
        pcall(fn, body, channel, sender)
    end
end)
