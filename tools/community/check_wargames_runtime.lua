-- Mock-only Retail War Games. Not multiplayer proof.
local function Check(x,msg) if not x then error(msg,2) end end
local driver
CreateFrame=function()
 driver={events={}}
 function driver:RegisterEvent(e) self.events[e]=true end
 function driver:SetScript(e,fn) self[e]=fn end
 return driver
end
local inside=false
IsInInstance=function() return inside,"arena" end
local leader=true
UnitIsGroupLeader=function() return leader end
local friends={
 {bnetAccountID=101,accountName="OneAccount",battleTag="One#1111"},
 {bnetAccountID=202,accountName="TwoAccount",battleTag="Two#2222"},
}
BNGetNumFriends=function() return 2 end
C_BattleNet={GetFriendAccountInfo=function(i) return friends[i] end}
friends[1].isOnline=true
friends[2].isOnline=false
local group={mode="party",complete=true,members={{name="One",unit="player"},{name="Two",unit="party1"}}}
local sends,spectates={},{}
StartWarGameByName=function(cmd) sends[#sends+1]=cmd end
StartSpectatorWarGame=function(...) spectates[#spectates+1]={...} end
local secret={}
issecretvalue=function(v) return v==secret end
local enemySecret=false
UnitExists=function(unit) return unit=="arena1" and inside end
UnitName=function(unit) if enemySecret then return secret end
 return unit=="arena1" and "Opponent" or nil,"TheirRealm" end
UnitClass=function(unit) return "Mage","MAGE" end
local function Load(retail)
 local ns={Client={IsRetail=function() return retail end},Group={
 GetSnapshot=function() return group end}}
 assert(loadfile("addon/DuelsReimagined/Core/WarGames.lua"))("DuelsReimagined",ns)
 return ns.WarGames
end
local W=Load(true)
Check(#W.Brackets==3 and W.Brackets[3]==5,"full 5v5 bracket")
Check(W.GetReason("player")~=nil,"must require captain")
local maps=W.GetMaps()
Check(#maps>=16,"expanded Retail arena references")
Check(maps[1].name=="Nagrand Arena","preserve current arena selection")
Check(W.SelectCaptain("player",1,101),"known friend")
Check(W.GetReason("player")==nil,"ready 2v2")
local roster=W.GetFriends()
Check(roster[1].online==true and roster[2].online==false,
 "online and offline status from Blizzard is preserved")
Check(#sends==0 and #spectates==0,"no automatic requests")
local ok,msg=W.Request("player")
Check(ok and sends[1]=="OneAccount nagrand 0","Retail challenge arguments")
Check(msg:find("not confirmed",1,true)~=nil,"never claim entry")
Check(not W.SelectCaptain("host",1,999),"reject unknown ID")
Check(W.SelectCaptain("host",1,101),"first host captain")
Check(W.GetCaptain("host",1).id==101,"team 1 selection")
Check(W.GetCaptain("host",2)==nil,"team 2 must remain unselected")
Check(W.GetReason("host"):find("both captains",1,true)~=nil,
 "unselected captain cannot silently inherit team 1")
Check(W.SelectCaptain("host",2,101),"duplicate can be selected")
Check(W.GetReason("host"):find("different",1,true)~=nil,
 "must reject matching captains")
Check(W.SelectCaptain("host",2,202),"second captain")
Check(W.GetCaptain("host",1).id==101 and W.GetCaptain("host",2).id==202,
 "two team captains are independent")
Check(W.SelectCaptain("host",2,nil),"clear captain 2")
Check(W.GetCaptain("host",2)==nil and W.GetCaptain("host",1).id==101,
 "clearing team 2 preserves team 1")
Check(W.SelectCaptain("host",2,202),"restore captain 2")
Check(W.SelectBracket("host",5),"5v5 spectator setup")
Check(W.GetReason("host")==nil,"two BNet captains ready")
ok,msg=W.Request("host")
Check(ok and #spectates==1,"only button requests spectator")
Check(spectates[1][1]==101 and spectates[1][2]==202 and
 spectates[1][3]==5 and spectates[1][4]=="Nagrand Arena" and
 spectates[1][5]==false,"spectator API arguments")
Check(not W.SelectBracket("player",4),"reject fake bracket")
Check(not W.SelectMap("player",999),"reject unknown map")
leader=false
Check(W.GetReason("player")~=nil,"leader required")
leader=true
W.SelectBracket("player",5)
Check(W.GetReason("player"):find("exactly 5",1,true)~=nil,"exact 5v5 group")
W.SelectBracket("player",2)
inside=true
Check(W.InArena(),"arena detected")
local opponents=W.GetOpponents()
Check(opponents[1].name=="Opponent-TheirRealm" and
 opponents[1].classFile=="MAGE","real revealed opponent")
Check(opponents[5]==nil,"do not invent fifth enemy")
enemySecret=true
Check(W.GetOpponents()[1]==nil,"secret opponent not read")
enemySecret=false
Check(W.GetReason("player"):find("unavailable inside an arena",1,true)~=nil,
 "setup cannot request inside match")
inside=false
Check(not W.InArena(),"setup resumes outside arena")
local fn=StartWarGameByName
StartWarGameByName=function() error("blocked") end
ok,msg=W.Request("player")
Check(not ok and #sends==1,"API failure not a successful match")
StartWarGameByName=fn
local updates=0
local unsubscribe=W.Subscribe(function() updates=updates+1 end)
driver.OnEvent(driver,"PLAYER_ENTERING_WORLD")
Check(updates==1,"events refresh view")
unsubscribe()
driver.OnEvent(driver,"ZONE_CHANGED_NEW_AREA")
Check(updates==1,"view unsubscribe")
local forever=Load(false)
Check(forever.GetReason("host"):find("Retail only",1,true)~=nil,
 "runtime Forever safety")
print("War Games runtime contracts: PASS")
