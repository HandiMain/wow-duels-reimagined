local _,ns=...
-- Retail War Games organization only. No matchmaking, no predicted results,
-- no addon messages, no automatic chat, no second gameplay/API owner.
local Engine, Settings=ns.WarGames,ns.Settings
local Tools={}
ns.WarGamesSession=Tools
local snapshots={player=nil,host=nil}
local series={bestOf=0,score1=0,score2=0,opponent="",page="player"}
local veto={}
local note=""
local function Update()
    if ns.WarGamesUI and ns.WarGamesUI.Refresh then ns.WarGamesUI.Refresh() end
end
local function Library() return Settings.GetWarGamesLibrary() end
local function Save(data) Settings.SaveWarGamesLibrary(data); Update() end
local function Contains(list,v)
    for _,item in ipairs(list) do if item==v then return true end end
    return false
end
local function Recent(list,v,limit)
    local out={v}
    for _,item in ipairs(list) do
        if item~=v and #out<limit then out[#out+1]=item end
    end
    return out
end
function Tools.IsFavorite(kind,value)
    local k=kind=="captain" and "favoriteCaptains" or
        kind=="map" and "favoriteMaps" or nil
    return k and Contains(Library()[k],value) or false
end
function Tools.ToggleFavorite(kind,value)
    local k=kind=="captain" and "favoriteCaptains" or
        kind=="map" and "favoriteMaps" or nil
    if not k or ((kind=="captain" and
        (type(value)~="number" or value<=0)) or
        (kind=="map" and (type(value)~="string" or #value>96)))
        then return false end
    local data=Library()
    local out={}
    local remove=Contains(data[k],value)
    for _,item in ipairs(data[k]) do if item~=value then out[#out+1]=item end end
    if not remove and #out<20 then out[#out+1]=value end
    data[k]=out
    Save(data)
    return true,not remove
end
function Tools.Remember(kind,value)
    local k,cap=kind=="captain" and "recentCaptains" or
        kind=="map" and "recentMaps" or nil,8
    if not k or ((kind=="captain" and
        (type(value)~="number" or value<=0)) or
        (kind=="map" and (type(value)~="string" or #value>96)))
        then return false end
    local data=Library()
    data[k]=Recent(data[k],value,cap)
    Save(data)
    return true
end
function Tools.Choices(kind)
    local library=Library()
    local data={}
    if kind=="captain" then
        for _,f in ipairs(Engine.GetFriends()) do
            data[#data+1]={
                key=f.id,label=(Tools.IsFavorite("captain",f.id) and "★ " or "")..f.displayName,
                online=f.online,onlineSource=f.onlineSource,
                detail=Tools.IsFavorite("captain",f.id) and "Favorite captain" or "Battle.net friend",
                rank=Tools.IsFavorite("captain",f.id) and 1 or
                    Contains(library.recentCaptains,f.id) and 2 or 3,
            }
        end
    elseif kind=="map" then
        for index,map in ipairs(Engine.GetMaps()) do
            data[#data+1]={key=index,
                label=(Tools.IsFavorite("map",map.name) and "★ " or "")..map.name,
                detail=map.clientReported and "Client-reported Arena; availability unconfirmed." or
                    "Known Arena; availability unconfirmed.",
                rank=Tools.IsFavorite("map",map.name) and 1 or
                    Contains(library.recentMaps,map.name) and 2 or 3,
            }
        end
    end
    table.sort(data,function(a,b)
        if a.rank~=b.rank then return a.rank<b.rank end
        return a.label:lower()<b.label:lower()
    end)
    return data
end
function Tools.GetLibrary() return Library() end
function Tools.GetSnapshot(page)
    return snapshots[page]
end
function Tools.CaptureRequest(page)
    if page~="player" and page~="host" then return false end
    local cfg=Engine.GetConfig(page)
    if not cfg then return false end
    local map=Engine.GetMaps()[cfg.map]
    local a=Engine.GetCaptain(page,1)
    local b=page=="host" and Engine.GetCaptain("host",2) or nil
    snapshots[page]={bracket=cfg.bracket,mapName=map and map.name,
        captain1=a and a.id,captain2=b and b.id,
        tournamentRules=cfg.tournamentRules}
    return true
end
function Tools.PrepareRematch(page)
    local old=snapshots[page]
    if not old then return false,"No previous request setup in this session." end
    local index
    for i,map in ipairs(Engine.GetMaps()) do
        if map.name==old.mapName then index=i;break end
    end
    if not index then return false,"The previous arena is unavailable." end
    if old.captain1 and not Engine.SelectCaptain(page,1,old.captain1) then
        return false,"Previous captain is not in your Battle.net friends list."
    end
    if page=="host" and old.captain2 and
        not Engine.SelectCaptain(page,2,old.captain2) then
        return false,"Previous second captain is no longer available."
    end
    Engine.SelectBracket(page,old.bracket)
    Engine.SelectMap(page,index)
    Engine.SelectTournamentRules(page,old.tournamentRules==true)
    Tools.Remember("map",old.mapName)
    return true,"Previous setup restored. Sending remains manual."
end
function Tools.UseTarget()
    if type(UnitFullName)~="function" then
        return false,"Target realm identity is unavailable on this client."
    end
    local ok,name,realm=pcall(UnitFullName,"target")
    if ok and type(issecretvalue)=="function" then
        local safe1,secret1=pcall(issecretvalue,name)
        local safe2,secret2=pcall(issecretvalue,realm)
        if not safe1 or not safe2 or secret1 or secret2 then ok=false end
    end
    if not ok or type(name)~="string" or name=="" or
        type(realm)~="string" or realm=="" then
        return false,"Target must have a readable character name and realm."
    end
    local normalize=function(v)return v:lower():gsub("[%s%-]","")end
    local found
    for _,friend in ipairs(Engine.GetFriends()) do
        if type(friend.characterName)=="string" and
            type(friend.characterRealm)=="string" and
            normalize(friend.characterName)==normalize(name) and
            normalize(friend.characterRealm)==normalize(realm) then
            if found then return false,"Multiple friends match that name. Choose manually." end
            found=friend
        end
    end
    if not found then return false,"Target is not verified in your Battle.net friends." end
    if not Engine.SelectCaptain("player",1,found.id) then
        return false,"That friend could not be selected."
    end
    Tools.Remember("captain",found.id)
    return true,"Target matched to a Battle.net friend. Ready to review."
end
function Tools.Status(page)
    local state=Engine.GetRequestState(page)
    if state=="in_arena" then
        return "IN ARENA — arena observed; linked match not confirmed"
    elseif state=="submitted" then
        return "REQUEST SUBMITTED — awaiting independent Blizzard confirmation"
    elseif state=="refused" then
        return "REQUEST REFUSED — review setup before retrying"
    end
    local reason=Engine.GetReason(page)
    return reason and "NOT READY — "..reason or "READY TO REQUEST — not yet sent"
end
function Tools.MatchCard(page)
    local cfg=Engine.GetConfig(page)
    if not cfg then return "No setup." end
    local map=Engine.GetMaps()[cfg.map]
    local first=Engine.GetCaptain(page,1)
    local second=page=="host" and Engine.GetCaptain(page,2) or nil
    local cap=page=="host" and
        ((first and first.displayName or "Team 1 ?").." vs "..
         (second and second.displayName or "Team 2 ?")) or
        (first and first.displayName or "No opposing captain")
    return cfg.bracket.."v"..cfg.bracket.." • "..
        (map and map.name or "Choose arena").." • "..
        (cfg.tournamentRules and "Tournament" or "Standard").." • "..cap
end
function Tools.Presence()
    local p=ns.Presence and ns.Presence.GetSnapshot and ns.Presence.GetSnapshot()
    if not p or not p.complete then return "Group addon presence unavailable." end
    local confirmed,unknown=0,0
    for _,member in ipairs(p.members) do
        if member.status=="confirmed" then confirmed=confirmed+1
        elseif member.status=="unknown" or member.status=="checking" then
            unknown=unknown+1 end
    end
    return confirmed.." group member(s) confirmed using addon; "..
        unknown.." unknown. Unknown does not mean missing."
end
function Tools.StartSeries(best,page)
    if best~=3 and best~=5 then return false end
    page=(page=="host") and "host" or "player"
    local enemy=Engine.GetCaptain(page,1)
    series={bestOf=best,score1=0,score2=0,page=page,
        opponent=enemy and enemy.displayName or "Unspecified opponent"}
    Update()
    return true
end
function Tools.GetSeries()
    return {bestOf=series.bestOf,score1=series.score1,
        score2=series.score2,opponent=series.opponent,
        finished=series.bestOf>0 and
            (series.score1>=math.floor(series.bestOf/2)+1 or
             series.score2>=math.floor(series.bestOf/2)+1)}
end
function Tools.MarkRound(winner)
    if (winner~=1 and winner~=2) or series.bestOf==0 then
        return false,"Choose a Best of 3 or Best of 5 series."
    end
    local target=math.floor(series.bestOf/2)+1
    if series.score1>=target or series.score2>=target then
        return false,"Series already finished. Start a new one."
    end
    if winner==1 then series.score1=series.score1+1
    else series.score2=series.score2+1 end
    if series.score1>=target or series.score2>=target then
        local data=Library()
        local record={manual=true,format=series.bestOf,
            winner=series.score1>=target and 1 or 2,
            page=series.page,
            score1=series.score1,score2=series.score2,
            opponent=series.opponent}
        data.history=Recent(data.history,record,20)
        -- Recent dedup uses reference identity for tables; capped storage
        -- still filters history through Settings' validated copy.
        Save(data)
    else Update() end
    return true
end
function Tools.ResetSeries()
    series={bestOf=0,score1=0,score2=0,opponent="",page="player"}
    Update()
end
-- Local, explicitly manual rivals: no automatic win/loss observation.
-- Host spectator matches do not count as the current player's personal wins.
function Tools.Rivalries()
    local results, byName={},{}
    for _,record in ipairs(Library().history) do
        if record.page=="player" then
            local name=record.opponent
            if not byName[name] then
                byName[name]={name=name,wins=0,losses=0,manual=true}
                results[#results+1]=byName[name]
            end
            local item=byName[name]
            if record.winner==1 then item.wins=item.wins+1
            else item.losses=item.losses+1 end
        end
    end
    table.sort(results,function(a,b)
        return (a.wins+a.losses)>(b.wins+b.losses)
    end)
    return results
end
function Tools.GetVeto() 
    local result={}
    for k in pairs(veto) do result[#result+1]=k end
    table.sort(result)
    return result
end
function Tools.BanMap(name)
    if type(name)~="string" then return false,"Choose an arena to veto." end
    local all=Engine.GetMaps()
    local known=false
    for _,m in ipairs(all) do if m.name==name then known=true;break end end
    if not known then return false,"Only listed arena maps may be vetoed." end
    if veto[name] then return false,"Already vetoed." end
    if #Tools.GetVeto()>=#all-1 then
        return false,"At least one arena must remain."
    end
    veto[name]=true
    Update()
    return true
end
function Tools.RestoreMap(name)
    if not veto[name] then return false end
    veto[name]=nil
    Update()
    return true
end
function Tools.ClearVeto()
    veto={}
    Update()
end
function Tools.AvailableMaps()
    local maps={}
    for i,m in ipairs(Engine.GetMaps()) do
        if not veto[m.name] then maps[#maps+1]={key=i,label=m.name} end
    end
    return maps
end
function Tools.VetoSelectMap(page,index)
    local map=Engine.GetMaps()[index]
    if not map or veto[map.name] then return false end
    return Engine.SelectMap(page,index)
end
function Tools.Listing(page)
    local cfg=Engine.GetConfig(page or "player")
    if not cfg then return "" end
    local arena=Engine.GetMaps()[cfg.map]
    return "[War Games] LF "..cfg.bracket.."v"..cfg.bracket..
        " private arena practice ("..(arena and arena.name or "arena TBD")..
        "). Whisper to organize. No automated matchmaking."
end
function Tools.DraftListing(page)
    if type(ChatFrame_OpenChat)~="function" then
        return false,"Blizzard chat composer is unavailable."
    end
    local ok=pcall(ChatFrame_OpenChat,Tools.Listing(page))
    if not ok then return false,"Could not open Blizzard chat." end
    return true,"Draft opened; you choose the channel and send it yourself."
end
function Tools.SetNotice(message)
    note=type(message)=="string" and message or ""
    Update()
end
function Tools.GetNotice() return note end
