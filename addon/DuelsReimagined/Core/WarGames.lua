local _, ns = ...

-- Retail-only War Games owner. No SavedVariables, no group/communication
-- duplication, no forced queueing and no fabricated match confirmations.
local WarGames = {}
ns.WarGames = WarGames
local Group, Client = ns.Group, ns.Client
local listeners = {}
local state = {
    player = { bracket = 2, map = 1, tournamentRules = false },
    host = { bracket = 5, map = 1, tournamentRules = false },
}
local arena = false
local requests, pending = {}, nil
local friendCache
local PEER_TEST_ENABLED=false
local peer, sequence, lastReply, lastProbe = nil,0,-math.huge,-math.huge
local refreshPending=false
local REQUEST_WAIT=90
local function Clock()
    if type(GetTime)~="function" then return nil end
    local ok,t=pcall(GetTime)
    if not ok then return nil end
    if type(issecretvalue)=="function" then
        local safe,secret=pcall(issecretvalue,t)
        if not safe or secret then return nil end
    end
    if type(t)=="number" and t>=0 and t<math.huge then return t end
end

-- Arena names / unambiguous /wargame keywords verified against the Retail
-- WarGameHelper 1.2.6 map list. Never let a player enter an arbitrary map ID.
WarGames.Maps = {
    { name = "Nagrand Arena", keyword = "nagrand" },
    { name = "Blade's Edge Arena", keyword = "blade's" },
    { name = "Ruins of Lordaeron", keyword = "lordaeron" },
    { name = "Dalaran Sewers", keyword = "dalaran" },
    { name = "Tol'viron Arena", keyword = "tol'viron" },
    { name = "The Tiger's Peak", keyword = "tiger's" },
    -- Full map names are safer than ambiguous shortened /wargame tokens.
    -- These additional Retail arenas are not present in old helper addons.
    { name = "Ashamane's Fall", keyword = "Ashamane's Fall" },
    { name = "Black Rook Hold Arena", keyword = "Black Rook Hold Arena" },
    { name = "Cage of Carnage", keyword = "Cage of Carnage" },
    { name = "Empyrean Domain", keyword = "Empyrean Domain" },
    { name = "Enigma Crucible", keyword = "Enigma Crucible" },
    { name = "Hook Point", keyword = "Hook Point" },
    { name = "Maldraxxus Coliseum", keyword = "Maldraxxus Coliseum" },
    { name = "Mugambala", keyword = "Mugambala" },
    { name = "Nokhudon Proving Grounds", keyword = "Nokhudon Proving Grounds" },
    { name = "The Robodrome", keyword = "The Robodrome" },
}
WarGames.Brackets = { 2, 3, 5 }

-- Retail's optional War Game type catalogue can expose newer arenas than
-- any hardcoded reference. Add only entries explicitly categorized as Arena;
-- preserve existing indices/previous selections throughout this session.
local function Readable(v)
    if type(issecretvalue) == "function" then
        local ok, secret = pcall(issecretvalue, v)
        if not ok or secret then return false end
    end
    return true
end

local function AddClientArenas()
    if not (Client and Client.IsRetail and Client.IsRetail()) then return end
    if type(GetNumWarGameTypes) ~= "function" or
        type(GetWarGameTypeInfo) ~= "function" then return end
    local ok, count = pcall(GetNumWarGameTypes)
    if not ok or not Readable(count) or type(count) ~= "number" or count < 1 or count > 150
        or count ~= math.floor(count) then return end
    local existing = {}
    for _, item in ipairs(WarGames.Maps) do
        existing[item.name:lower()] = item
    end
    for i = 1, count do
        local success, name, kind, _, _, _, _, random =
            pcall(GetWarGameTypeInfo, i)
        if success and Readable(name) and Readable(kind) and Readable(random) and
            type(name) == "string" and #name >= 3 and
            #name <= 96 and type(kind) == "string" and
            kind:upper() == "ARENA" and random ~= true and
            name:lower() ~= "arena" and name:lower() ~= "arenas" then
            local key=name:lower()
            if existing[key] then existing[key].clientReported=true
            else
                local item={name=name,keyword=name,clientReported=true}
                WarGames.Maps[#WarGames.Maps+1]=item;existing[key]=item
            end
        end
    end
    return true
end
local arenaCatalogRead = false
function WarGames.GetMaps()
    -- Retry when the PvP UI loads its optional catalogue later in the
    -- session; a failed query never removes our known map references.
    if not arenaCatalogRead then
        arenaCatalogRead = AddClientArenas() == true
    end
    local copy = {}
    for i, map in ipairs(WarGames.Maps) do
        copy[i] = { name = map.name, keyword = map.keyword,
                    clientReported = map.clientReported }
    end
    return copy
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
    for fn in pairs(listeners) do
        local ok=pcall(fn)
        if not ok and ns.Diagnostics and ns.Diagnostics.Record then
            ns.Diagnostics.Record("War Games callback","A War Games refresh listener failed")
        end
    end
end

local function MatchPhase()
    if not IsArena() then return "outside" end
    local wg=One(IsWargame)
    if wg==false then return "ordinary_arena" end
    if wg~=true then return "arena_unknown" end
    local state=One(C_PvP and C_PvP.GetActiveMatchState)
    local e=Enum and Enum.PvPMatchState
    if e and state~=nil then
        if state==e.Complete then return "complete"
        elseif state==e.Engaged then return "engaged"
        elseif state==e.StartUp or state==e.Waiting then return "preparing" end
    end
    return "entered"
end
local phase="outside"
local function Expire()
    local now=Clock()
    if pending and now and now>=pending.deadline then
        requests[pending.page]="No entry confirmed before timeout. Check Blizzard before retrying."
        pending=nil
    end
    if peer and now and now>=peer.deadline then peer=nil end
end
function WarGames.Refresh()
    arena=IsArena()
    local nextPhase=MatchPhase()
    if nextPhase~="outside" and nextPhase~=phase then
        if pending then
            requests[pending.page]=nextPhase=="ordinary_arena" and "Ordinary arena entered; War Game request not confirmed."
                or "Arena entered; association with the previous request is not confirmed."
            pending=nil
        end
        peer=nil
    end
    phase=nextPhase
    Expire()
    Notify()
end
local function QueueRefresh()
    if refreshPending then return end
    if C_Timer and type(C_Timer.After)=="function" then
        refreshPending=true
        C_Timer.After(.1,function() refreshPending=false;WarGames.Refresh() end)
    else WarGames.Refresh() end
end
function WarGames.GetMatchStatus()
    local p=MatchPhase()
    local labels={outside="Match preparation",ordinary_arena="Ordinary arena — not a War Game",
        arena_unknown="Arena entered — War Game status unknown",entered="War Game entry observed",
        preparing="War Game preparation",engaged="War Game in progress",complete="War Game completed"}
    return p,labels[p]
end
function WarGames.PeerTestingEnabled() return PEER_TEST_ENABLED end
function WarGames.CanCommunicate()
    return PEER_TEST_ENABLED and IsRetail() and not IsArena() and
        ns.Settings and ns.Settings.Get("warGamesConsent")==true
end
function WarGames.PreferenceChanged()
    peer=nil;Notify()
end
function WarGames.GetDiagnosticResources()
    local n=0
    for _ in pairs(listeners) do n=n+1 end
    return {subscriptions=n,pending=(pending and 1 or 0)+(peer and 1 or 0),timers=refreshPending and 1 or 0}
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
    return { bracket=s.bracket, map=s.map, tournamentRules=s.tournamentRules, captain=s.captain,
        captain1=s.captain1, captain2=s.captain2 }
end
function WarGames.SelectBracket(page, count)
    if not state[page] or (count ~= 2 and count ~= 3 and count ~= 5) then
        return false
    end
    state[page].bracket = count
    peer=nil
    Notify()
    return true
end
-- Match-local toggle, not an addon-wide preference or tournament manager.
-- Players and Host each retain their own selection for this session.
function WarGames.SelectTournamentRules(page, enabled)
    local s = state[page]
    if not s or type(enabled) ~= "boolean" then return false end
    if s.tournamentRules ~= enabled then
        s.tournamentRules = enabled
        peer=nil
        Notify()
    end
    return true
end

function WarGames.SelectMap(page, index)
    if not state[page] or type(index) ~= "number" or
        index ~= math.floor(index) or not WarGames.GetMaps()[index] then return false end
    state[page].map = index
    peer=nil
    Notify()
    return true
end

local function SafeField(object, name)
    if not Readable(object) or type(object) ~= "table" then return nil end
    local ok, value = pcall(function() return object[name] end)
    if ok and Readable(value) then return value end
end

-- Blizzard requires opaque Battle.net account IDs for spectator invitations.
-- We never pretend a typed BattleTag can replace one or infer IDs from chat.
local function ReadFriends()
    local result = {}
    local number = One(BNGetNumFriends)
    local api = C_BattleNet and C_BattleNet.GetFriendAccountInfo
    if type(number) ~= "number" or number < 1 or number > 500
        or type(api) ~= "function" then return result end
    for index = 1, number do
        local info = One(api, index)
        if type(info) == "table" then
            local id = SafeField(info, "bnetAccountID")
            local account = SafeField(info, "accountName")
            local tag = SafeField(info, "battleTag")
            if type(id) == "number" and id > 0 and
                type(account) == "string" and account ~= "" then
                local display = type(tag) == "string" and
                    tag ~= "" and tag or account
                local online = SafeField(info, "isOnline")
                local source = "Battle.net"
                if type(online) ~= "boolean" then
                    local game = SafeField(info, "gameAccountInfo")
                    online = SafeField(game, "isOnline")
                    source = "World of Warcraft"
                end
                if type(online) ~= "boolean" then online = nil end
                -- A BNet green dot is not evidence of a playable Retail character.
                local wow,route,routeCount=nil,nil,0
                local function Game(game)
                    local connected=SafeField(game,"isOnline")
                    local program=SafeField(game,"clientProgram")
                    if connected~=true or program~="WoW" then return end
                    wow=true
                    local project=SafeField(game,"wowProjectID")
                    local name,realm=SafeField(game,"characterName"),SafeField(game,"realmName")
                    if project==WOW_PROJECT_MAINLINE and WOW_PROJECT_MAINLINE~=nil and
                        type(name)=="string" and type(realm)=="string" and #name>0 and #realm>0
                        and not name:find("[%c|%-]") and not realm:find("[%c|]") then
                        routeCount=routeCount+1;route=name.."-"..realm:gsub("%s+","")
                    end
                end
                local count=One(C_BattleNet.GetFriendNumGameAccounts,index)
                if type(count)=="number" and count>=0 and count<=20 and count==math.floor(count)
                    and type(C_BattleNet.GetFriendGameAccountInfo)=="function" then
                    wow=false
                    for n=1,count do Game(One(C_BattleNet.GetFriendGameAccountInfo,index,n)) end
                else
                    Game(SafeField(info,"gameAccountInfo"))
                    -- Single primary account is not proof there is only one route.
                    routeCount=0
                end
                local availability=online==false and "Offline" or wow==true and "In WoW" or
                    online==true and (wow==false and "Online — not in WoW" or "Online — game unknown") or "Availability unknown"
                result[#result + 1] = {
                    id=id, accountName=account, displayName=display,
                    online=online, onlineSource=online ~= nil and source or nil,
                    availability=availability, wow=wow, route=routeCount==1 and route or nil,
                }
            end
        end
    end
    table.sort(result, function(a,b)
        if a.online ~= b.online then
            if a.online == true then return true end
            if b.online == true then return false end
            if a.online == false then return false end
            if b.online == false then return true end
        end
        return a.displayName:lower() < b.displayName:lower()
    end)
    return result
end
function WarGames.InvalidateFriends() friendCache=nil end
function WarGames.GetFriends()
    if not friendCache then friendCache=ReadFriends() end
    local result={}
    for i,f in ipairs(friendCache) do
        local row={};for k,v in pairs(f) do row[k]=v end;result[i]=row
    end
    return result
end
local function FriendByID(id)
    if type(id) ~= "number" then return nil end
    if not friendCache then friendCache=ReadFriends() end
    for _, item in ipairs(friendCache) do
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
    peer=nil
    Notify()
    return true
end
function WarGames.GetCaptain(page, slot)
    local s = state[page]
    if not s then return nil end
    -- Never use a Lua 'and/or' fallback here: nil captain2 previously
    -- returned captain1 and falsely displayed both teams as identical.
    local id
    if page == "player" and slot == 1 then
        id = s.captain
    elseif page == "host" and slot == 1 then
        id = s.captain1
    elseif page == "host" and slot == 2 then
        id = s.captain2
    else
        return nil
    end
    if id == nil then return nil end
    return FriendByID(id)
end
function WarGames.GetTeam()
    return Group and Group.GetSnapshot and Group.GetSnapshot() or {
        mode="unknown", complete=false, members={}
    }
end

local function Combat()
    if type(InCombatLockdown)~="function" then return false end
    local ok,locked=pcall(InCombatLockdown)
    return not ok or not Readable(locked) or locked==true
end
local function ReadyTime()
    return One(C_PartyInfo and C_PartyInfo.GetReadyCheckTimeLeft or GetReadyCheckTimeLeft)
end
function WarGames.GetReadiness(team)
    team=team or WarGames.GetTeam()
    local time=ReadyTime()
    local active=type(time)=="number" and time>0
    local rows,ready={},0
    for i,m in ipairs(team.members or {}) do
        local r=active and One(C_PartyInfo and C_PartyInfo.GetReadyCheckStatus or GetReadyCheckStatus,m.unit)
        local status=m.online==false and "Offline" or r=="ready" and "Ready" or
            r=="notready" and "Not ready" or r=="waiting" and "Waiting" or
            m.online==true and "Connected" or "Unknown"
        rows[i]=status
        if status=="Ready" then ready=ready+1 end
    end
    return {rows=rows,active=active,ready=ready,total=#rows,
        allReady=active and team.complete and not team.stale and #rows>0 and ready==#rows}
end
function WarGames.GetReadyCheckReason()
    if not IsRetail() or IsArena() or Combat() then return "Unavailable here." end
    local team=WarGames.GetTeam()
    if not team.complete or team.stale or (team.mode~="party" and team.mode~="raid") then return "Join a group first." end
    if One(UnitIsGroupLeader,"player")~=true then return "Only the group leader can start a ready check." end
    if type(C_PartyInfo and C_PartyInfo.DoReadyCheck or DoReadyCheck)~="function" then return "Ready check API unavailable." end
    local time=ReadyTime()
    if type(time)=="number" and time>0 then return "Ready check already active." end
end
function WarGames.ReadyCheck()
    local reason=WarGames.GetReadyCheckReason()
    if reason then return false,reason end
    local ok=pcall(C_PartyInfo and C_PartyInfo.DoReadyCheck or DoReadyCheck)
    QueueRefresh()
    return ok,ok and "Ready check requested." or "Blizzard refused the ready check."
end
function WarGames.GetReason(page)
    if not IsRetail() then return "War Games are available on Retail only." end
    if IsArena() then return "Match setup is unavailable inside an arena." end
    if type(InCombatLockdown)=="function" then
        local ok,locked=pcall(InCombatLockdown)
        if not ok or not Readable(locked) or locked then
            return "War Game requests are unavailable during combat."
        end
    end
    local s = state[page]
    if not s then return "Select a War Games page." end
    Expire()
    if pending then return "A request is pending; check Blizzard before retrying." end
    if not Clock() then return "Request clock unavailable." end
    if not WarGames.GetMaps()[s.map] then return "Choose an arena." end
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
        local captain=WarGames.GetCaptain("player",1)
        if not captain then return "Select the opposing team captain from Battle.net friends." end
        if captain.online==false then return "The opposing captain is offline." end
        for _,m in ipairs(team.members) do if m.online==false then return "A group member is offline." end end
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
        if one.online==false or two.online==false then return "A selected captain is offline." end
    end
    return nil
end

function WarGames.Request(page)
    -- Re-read BNet before a user-initiated native request, not per widget.
    friendCache=nil
    local reason = WarGames.GetReason(page)
    if reason then requests[page]=reason;Notify();return false, reason end
    local s, map = state[page], WarGames.GetMaps()[state[page].map]
    local now=Clock()
    if not now then return false,"Request clock unavailable." end
    local ok, result
    if page == "player" then
        local captain = WarGames.GetCaptain("player", 1)
        -- The Retail slash API reads tournament rules as 0 (off) or 1 (on).
        local rules = s.tournamentRules and "1" or "0"
        ok, result = pcall(StartWarGameByName,
            captain.accountName .. " " .. map.keyword .. " " .. rules)
    elseif page == "host" then
        local a, b = WarGames.GetCaptain("host", 1),
            WarGames.GetCaptain("host", 2)
        ok, result = pcall(StartSpectatorWarGame,
            a.id, b.id, s.bracket, map.name, s.tournamentRules == true)
    else
        return false, "Select a War Games page."
    end
    if not ok or (Readable(result) and result==false) then
        requests[page]="Blizzard request refused or unavailable. Check the team and try again."
        Notify()
        return false,requests[page]
    end
    requests[page]="Request handed to Blizzard; acceptance and entry are not confirmed."
    pending={page=page,deadline=now+REQUEST_WAIT}
    local ticket=pending
    if C_Timer and type(C_Timer.After)=="function" then
        C_Timer.After(REQUEST_WAIT,function()
            if pending==ticket then WarGames.Refresh() end
        end)
    end
    Notify()
    return true,requests[page]
end
function WarGames.GetMessage(page) Expire();return requests[page] end

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

-- Optional coordination between mutually selected, unambiguous Retail
-- character routes. No Battle.net IDs/tags, names, rosters or combat data
-- in packets. Never sends a native challenge or changes the other setup.
local function Key(route)
    return ns.OpponentDiscovery and ns.OpponentDiscovery.NormalizeSender(route)
end
local function PeerContext()
    if not WarGames.CanCommunicate() or Combat() or One(UnitIsGroupLeader,"player")~=true then return end
    local c=WarGames.GetCaptain("player",1)
    local s=state.player
    local map=WarGames.GetMaps()[s.map]
    if not c or not c.route or not Key(c.route) or not map or #map.name>96 or map.name:find("[%c|]") then return end
    local team=WarGames.GetTeam()
    local size=team.complete and not team.stale and #team.members or 0
    if size>5 then size=0 end
    local readiness=WarGames.GetReadiness(team)
    local flag=readiness.allReady and size==s.bracket and "R" or "U"
    return c,s,map,size,flag
end
local function Packet(op,token,s,map,size,flag)
    return table.concat({op,token,s.bracket,s.tournamentRules and "1" or "0",size,flag,map.name},"|")
end
function WarGames.CheckCaptain()
    local c,s,map,size,flag=PeerContext()
    local now=Clock()
    if not c or not now or not ns.Communication then return false,"Captain exchange unavailable." end
    if now-lastProbe<10 then return false,"Wait before checking again." end
    lastProbe=now
    sequence=sequence+1
    local token=tostring(math.floor(now*1000)).."-"..sequence
    local ticket={token=token,key=Key(c.route),deadline=now+12,state="checking"}
    peer=ticket
    local sent=ns.Communication.Send("W1",Packet("Q",token,s,map,size,flag),"WHISPER",c.route)
    if not sent then peer=nil;Notify();return false,"Captain check not sent." end
    if C_Timer and type(C_Timer.After)=="function" then
        C_Timer.After(12,function() if peer==ticket then peer=nil;Notify() end end)
    end
    Notify();return true
end
function WarGames.GetPeerStatus()
    Expire()
    if not WarGames.PeerTestingEnabled() then return nil end
    if not WarGames.CanCommunicate() then return "Captain exchange disabled" end
    if not peer then return "Captain status unknown" end
    if peer.state=="checking" then return "Checking captain..." end
    return peer.match and ("Captain confirmed setup; "..peer.size.." players reported"..(peer.ready and ", ready" or ", readiness unknown"))
        or "Captain setup differs; review selections"
end
local function ReceivePeer(body,channel,sender)
    local c,s,map,size,flag=PeerContext()
    local now=Clock()
    if not c or not now or channel~="WHISPER" or Key(sender)~=Key(c.route) then return end
    local op,token,br,rules,n,ready,name=body:match("^([QA])|([%d%-]+)|(%d)|([01])|(%d)|([RU])|([^|]+)$")
    if not op or #token>32 or #name>96 or name:find("%c") or
        (br~="2" and br~="3" and br~="5") or tonumber(n)>5 then return end
    local same=tonumber(br)==s.bracket and (rules=="1")==s.tournamentRules and name==map.name
    if op=="Q" then
        if not ns.Communication or now-lastReply<10 then return end
        lastReply=now
        ns.Communication.Send("W1",Packet("A",token,s,map,size,flag),"WHISPER",c.route)
    elseif peer and peer.state=="checking" and now<peer.deadline and peer.token==token and peer.key==Key(sender) then
        peer={state="reported",match=same,size=tonumber(n),ready=ready=="R" and tonumber(n)==tonumber(br),deadline=now+30}
        local ticket=peer
        if C_Timer and type(C_Timer.After)=="function" then
            C_Timer.After(30,function() if peer==ticket then peer=nil;Notify() end end)
        end
        Notify()
    end
end
if PEER_TEST_ENABLED and ns.Communication then ns.Communication.Subscribe("W1",ReceivePeer) end
local driver = CreateFrame("Frame")
for _, event in ipairs({
    "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA",
    "ARENA_OPPONENT_UPDATE", "ARENA_PREP_OPPONENT_SPECIALIZATIONS",
    "GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED",
    "BN_FRIEND_INFO_CHANGED", "BN_CONNECTED", "BN_DISCONNECTED", "BN_FRIEND_ACCOUNT_ONLINE",
    "BN_FRIEND_ACCOUNT_OFFLINE", "BN_FRIEND_LIST_SIZE_CHANGED",
    "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED",
    "READY_CHECK", "READY_CHECK_CONFIRM", "READY_CHECK_FINISHED",
    "PVP_MATCH_STATE_CHANGED", "PVP_MATCH_COMPLETE", "UNIT_NAME_UPDATE",
}) do
    pcall(driver.RegisterEvent, driver, event)
end
driver:SetScript("OnEvent", function(_, event, unit)
    if event == "UNIT_NAME_UPDATE" then
        if not Readable(unit) or type(unit) ~= "string" or
            not unit:match("^arena[1-5]$") then return end
    end
    if event:match("^BN_") or event=="PLAYER_ENTERING_WORLD" then friendCache=nil;peer=nil end
    if event=="GROUP_ROSTER_UPDATE" or event=="PARTY_LEADER_CHANGED" or
        event=="PLAYER_REGEN_DISABLED" or event=="READY_CHECK" or event=="READY_CHECK_CONFIRM" or event=="READY_CHECK_FINISHED" then peer=nil end
    if event=="PLAYER_ENTERING_WORLD" then
        -- A reload starts a fresh session; entering a world does not prove
        -- this request's match. Keep the request timer until entry or expiry.
        arenaCatalogRead=false
    end
    QueueRefresh()
end)
