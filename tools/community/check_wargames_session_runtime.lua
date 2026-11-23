-- Mock-only War Games Session contracts. Never proof of live multiplayer.
local function Check(test,why) if not test then error(why,2) end end
local db={favoriteCaptains={},recentCaptains={},favoriteMaps={},recentMaps={},history={}}
local function Copy(v)
    if type(v)~="table" then return v end
    local c={}
    for k,value in pairs(v) do c[k]=Copy(value) end
    return c
end
local cfg={
    player={bracket=2,map=1,tournamentRules=false,captain=101},
    host={bracket=5,map=1,tournamentRules=false,captain1=101,captain2=202},
}
local maps={{name="Nagrand Arena"},{name="Blade's Edge Arena"},
    {name="Ruins of Lordaeron"}}
local friends={
    {id=101,displayName="Alice#123",characterName="Alice",
     characterRealm="Moon Guard",online=true},
    {id=202,displayName="Bob#123",characterName="Bob",
     characterRealm="OtherRealm",online=false},
}
local requests={player="idle",host="idle"}
local engine={
    GetConfig=function(page) return cfg[page] and Copy(cfg[page]) end,
    GetMaps=function()return Copy(maps)end,
    GetFriends=function()return Copy(friends)end,
    GetReason=function(page) return page=="player" and nil or nil end,
    GetRequestState=function(page)return requests[page]end,
    SelectCaptain=function(page,slot,id)
        if not cfg[page] then return false end
        if id~=101 and id~=202 then return false end
        local key=page=="player" and "captain" or
            slot==1 and "captain1" or "captain2"
        cfg[page][key]=id
        return true
    end,
    SelectBracket=function(page,size)cfg[page].bracket=size;return true end,
    SelectMap=function(page,index)cfg[page].map=index;return true end,
    SelectTournamentRules=function(page,flag)cfg[page].tournamentRules=flag;return true end,
}
function engine.GetCaptain(page,slot)
    local selected=cfg[page]
    if not selected then return nil end
    local id=page=="player" and selected.captain or
        slot==1 and selected.captain1 or selected.captain2
    for _,f in ipairs(friends) do if f.id==id then return Copy(f) end end
end
local openChat={}, sends=0
ChatFrame_OpenChat=function(message)openChat[#openChat+1]=message end
UnitFullName=function()return "Alice","MoonGuard"end
issecretvalue=function()return false end
local ns={WarGames=engine,Settings={
    GetWarGamesLibrary=function()return Copy(db)end,
    SaveWarGamesLibrary=function(v)db=Copy(v)end,
},Presence={GetSnapshot=function()
    return {complete=true,members={{status="self"},{status="confirmed"},
        {status="unknown"},{status="checking"}}}
end}}
assert(loadfile("addon/DuelsReimagined/Core/WarGamesSession.lua"))("DuelsReimagined",ns)
local T=ns.WarGamesSession
Check(T.GetSnapshot("player")==nil,"must not invent prior request")
Check(T.Remember("captain",101),"recent captain")
Check(T.Remember("map","Nagrand Arena"),"recent arena")
Check(db.recentCaptains[1]==101 and db.recentMaps[1]=="Nagrand Arena",
    "recent choices persisted through Settings")
Check(T.ToggleFavorite("captain",101),"favorite captain")
Check(T.ToggleFavorite("map","Nagrand Arena"),"favorite arena")
Check(T.IsFavorite("captain",101) and T.IsFavorite("map","Nagrand Arena"),
    "favorite flags read through Settings")
Check(T.Choices("captain")[1].key==101,"favorite first")
Check(T.Choices("map")[1].key==1,"favorite arena first")
Check(T.CaptureRequest("player"),"capture manual request setup")
cfg.player.bracket=3;cfg.player.map=2;cfg.player.captain=202
Check(T.PrepareRematch("player"),"restore prior setup")
Check(cfg.player.bracket==2 and cfg.player.map==1 and cfg.player.captain==101,
    "rematch restores options but does not send anything")
Check(sends==0,"no auto send")
Check(T.UseTarget(),"verified character name AND realm shortcut")
UnitFullName=function()return "Alice","OtherRealm"end
Check(not T.UseTarget(),"same character short name on other realm rejected")
UnitFullName=function()return "Alice","MoonGuard"end
friends[2].characterName="Alice";friends[2].characterRealm="Moon Guard"
Check(not T.UseTarget(),"ambiguous matching friends rejected")
friends[2].characterName="Bob";friends[2].characterRealm="OtherRealm"
Check(T.StartSeries(3,"player"),"start manual Bo3")
Check(T.MarkRound(1),"team1 manual victory")
Check(T.MarkRound(2),"team2 manual victory")
Check(T.MarkRound(1),"manual series concluded")
Check(T.GetSeries().finished,"best-of-three ends on two wins")
Check(not T.MarkRound(1),"no extra automatic results")
Check(#db.history==1 and db.history[1].manual and db.history[1].page=="player",
    "only manual complete series persisted")
Check(#T.Rivalries()==1 and T.Rivalries()[1].wins==1,
    "player-only rivalry record")
T.ResetSeries()
Check(T.StartSeries(5,"host"),"host may manually organize a series")
Check(T.MarkRound(1) and T.MarkRound(1) and T.MarkRound(1),
    "host manual series can complete")
Check(#T.Rivalries()==1,"host result not counted as own rivalry")
Check(T.BanMap("Nagrand Arena"),"ban first locally")
Check(T.BanMap("Blade's Edge Arena"),"ban second locally")
Check(not T.BanMap("Ruins of Lordaeron"),"never veto every map")
Check(#T.AvailableMaps()==1,"one map left")
Check(not T.VetoSelectMap("player",1),"banned map cannot be selected")
Check(T.VetoSelectMap("player",3),"remaining map selection")
Check(T.RestoreMap("Nagrand Arena"),"restore local map")
T.ClearVeto()
Check(#T.AvailableMaps()==3,"clear veto fully")
Check(T.Presence():find("1 group member",1,true)~=nil,
    "confirmed addon presence but unknown never missing")
local ok,msg=T.DraftListing("player")
Check(ok and #openChat==1 and #openChat[1]>10,
    "draft through Blizzard composer only")
Check(sends==0,"no addon chat or challenge ever transmitted by studio")
print("War Games session mock contracts: PASS")
