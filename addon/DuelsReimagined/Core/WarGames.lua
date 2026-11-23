local _, ns = ...

-- Retail-only War Games owner. No SavedVariables, no group/communication
-- duplication, no forced queueing and no fabricated match confirmations.
local WarGames = {}
ns.WarGames = WarGames
local Group, Client = ns.Group, ns.Client
local listeners = {}
local state = {
    player = { bracket = 2, map = 1 },
    host = { bracket = 5, map = 1 },
}
local arena = false
local lastResult

-- Arena names / unambiguous /wargame keywords verified against the Retail
-- WarGameHelper 1.2.6 map list. Never let a player enter an arbitrary map ID.
WarGames.Maps = {
    { name = "Nagrand Arena", keyword = "nagrand" },
    { name = "Blade's Edge Arena", keyword = "blade's" },
    { name = "Ruins of Lordaeron", keyword = "lordaeron" },
    { name = "Dalaran Sewers", keyword = "dalaran" },
    { name = "Tol'viron Arena", keyword = "tol'viron" },
    { name = "The Tiger's Peak", keyword = "tiger's" },
}
WarGames.Brackets = { 2, 3, 5 }

local function Readable(v)
    if type(issecretvalue) == "function" then
        local ok, secret = pcall(issecretvalue, v)
        if not ok or secret then return false end
    end
    return true
end
local function One(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a = pcall(fn, ...)
    if not ok or not Readable(a) then return nil end
    return a
end
local function Two(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if not ok or not Readable(a) or not Readable(b) then return nil end
    return a, b
end
local function IsRetail()
    return Client and Client.IsRetail and Client.IsRetail() == true
end
local function IsArena()
    if not IsRetail() then return false end
    local inside, kind = Two(IsInInstance)
    return inside == true and kind == "arena"
end
local function Notify()
    for fn in pairs(listeners) do pcall(fn) end
end

function WarGames.Refresh()
    arena = IsArena()
    Notify()
end
function WarGames.Subscribe(fn)
    if type(fn) ~= "function" then return function() end end
    listeners[fn] = true
    return function() listeners[fn] = nil end
end
function WarGames.InArena() return IsArena() end
function WarGames.GetConfig(page)
    local s = state[page]
    if not s then return nil end
    return { bracket=s.bracket, map=s.map, captain=s.captain,
        captain1=s.captain1, captain2=s.captain2 }
end
function WarGames.SelectBracket(page, count)
    if not state[page] or (count ~= 2 and count ~= 3 and count ~= 5) then
        return false
    end
    state[page].bracket = count
    Notify()
    return true
end
function WarGames.SelectMap(page, index)
    if not state[page] or type(index) ~= "number" or
        index ~= math.floor(index) or not WarGames.Maps[index] then return false end
    state[page].map = index
    Notify()
    return true
end

-- Blizzard requires opaque Battle.net account IDs for spectator invitations.
-- We never pretend a typed BattleTag can replace one or infer IDs from chat.
function WarGames.GetFriends()
    local result = {}
    local number = One(BNGetNumFriends)
    local api = C_BattleNet and C_BattleNet.GetFriendAccountInfo
    if type(number) ~= "number" or number < 1 or number > 500
        or type(api) ~= "function" then return result end
    for index = 1, number do
        local info = One(api, index)
        if type(info) == "table" then
            local id, account, tag = info.bnetAccountID, info.accountName,
                info.battleTag
            if Readable(id) and type(id) == "number" and id > 0 and
                Readable(account) and type(account) == "string" and
                account ~= "" then
                local display = Readable(tag) and type(tag) == "string" and
                    tag ~= "" and tag or account
                result[#result + 1] = {
                    id=id, accountName=account, displayName=display,
                }
            end
        end
    end
    table.sort(result, function(a,b)
        return a.displayName:lower() < b.displayName:lower()
    end)
    return result
end
local function FriendByID(id)
    if type(id) ~= "number" then return nil end
    for _, item in ipairs(WarGames.GetFriends()) do
        if item.id == id then return item end
    end
end
function WarGames.SelectCaptain(page, slot, id)
    local s = state[page]
    if not s then return false end
    local key = page == "player" and slot == 1 and "captain" or
        page == "host" and slot == 1 and "captain1" or
        page == "host" and slot == 2 and "captain2" or nil
    if not key then return false end
    if id ~= nil and not FriendByID(id) then return false end
    s[key] = id
    Notify()
    return true
end
function WarGames.GetCaptain(page, slot)
    local s = state[page]
    if not s then return nil end
    return FriendByID(slot == 2 and s.captain2 or
        page == "player" and s.captain or s.captain1)
end
function WarGames.GetTeam()
    return Group and Group.GetSnapshot and Group.GetSnapshot() or {
        mode="unknown", complete=false, members={}
    }
end

function WarGames.GetReason(page)
    if not IsRetail() then return "War Games are available on Retail only." end
    if IsArena() then return "Match setup is unavailable inside an arena." end
    local s = state[page]
    if not s then return "Select a War Games page." end
    if not WarGames.Maps[s.map] then return "Choose an arena." end
    if page == "player" then
        if type(StartWarGameByName) ~= "function" then
            return "This client does not provide the War Game challenge API."
        end
        local team = WarGames.GetTeam()
        if not team.complete or team.stale then
            return "Your group roster is not ready."
        end
        if team.mode ~= "party" and team.mode ~= "raid" then
            return "Join a party before challenging another team."
        end
        if #team.members ~= s.bracket then
            return "Your group needs exactly " .. s.bracket ..
                " players for this match."
        end
        if One(UnitIsGroupLeader, "player") ~= true then
            return "Only your group leader can send a War Game challenge."
        end
        if not WarGames.GetCaptain("player", 1) then
            return "Select the opposing team captain from Battle.net friends."
        end
    elseif page == "host" then
        if type(StartSpectatorWarGame) ~= "function" then
            return "This client does not provide spectator War Games."
        end
        local one, two = WarGames.GetCaptain("host", 1),
            WarGames.GetCaptain("host", 2)
        if not one or not two then
            return "Select both captains from Battle.net friends."
        end
        if one.id == two.id then return "Choose two different captains." end
    end
    return nil
end

function WarGames.Request(page)
    local reason = WarGames.GetReason(page)
    if reason then return false, reason end
    local s, map = state[page], WarGames.Maps[state[page].map]
    local ok, result
    if page == "player" then
        local captain = WarGames.GetCaptain("player", 1)
        -- The Retail slash API expects the Battle.net account NAME, plus a
        -- unique arena keyword and 0 for non-tournament rules.
        ok, result = pcall(StartWarGameByName,
            captain.accountName .. " " .. map.keyword .. " 0")
    elseif page == "host" then
        local a, b = WarGames.GetCaptain("host", 1),
            WarGames.GetCaptain("host", 2)
        ok, result = pcall(StartSpectatorWarGame,
            a.id, b.id, s.bracket, map.name, false)
    else
        return false, "Select a War Games page."
    end
    if not ok or (Readable(result) and result == false) then
        lastResult = "Blizzard refused this request. Check the team and try again."
        Notify()
        return false, lastResult
    end
    -- A protected Blizzard function returning normally does NOT prove
    -- either captain accepted, teams entered, or a spectator was admitted.
    lastResult = "Request handed to Blizzard; acceptance and entry are not confirmed."
    Notify()
    return true, lastResult
end
function WarGames.GetMessage() return lastResult end

function WarGames.GetOpponents()
    local result = {}
    if not IsArena() then return result end
    for index = 1, 5 do
        local unit = "arena" .. index
        if One(UnitExists, unit) == true then
            local name, realm = Two(UnitName, unit)
            local _, class = Two(UnitClass, unit)
            if type(name) == "string" and name ~= "" then
                if type(realm) == "string" and realm ~= "" and
                    not name:find("-", 1, true) then
                    name = name .. "-" .. realm
                end
                result[index] = { name=name,
                    classFile=type(class) == "string" and class or nil }
            end
        end
    end
    return result
end

local driver = CreateFrame("Frame")
for _, event in ipairs({
    "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA",
    "ARENA_OPPONENT_UPDATE", "ARENA_PREP_OPPONENT_SPECIALIZATIONS",
    "GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED",
    "BN_FRIEND_INFO_CHANGED", "BN_CONNECTED", "PLAYER_REGEN_ENABLED",
    "UNIT_NAME_UPDATE",
}) do
    pcall(driver.RegisterEvent, driver, event)
end
driver:SetScript("OnEvent", function(_, event, unit)
    if event == "UNIT_NAME_UPDATE" then
        if not Readable(unit) or type(unit) ~= "string" or
            not unit:match("^arena[1-5]$") then return end
    end
    WarGames.Refresh()
end)
