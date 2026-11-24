-- SIMULATED event-order contracts, never live gameplay evidence.
local function Check(ok,why) if not ok then error(why,2) end end
local path="addon/DuelsReimagined/Core/"
local HIDDEN={}
local function Setup(interface,missing,formats)
    local t, timers, frames, hooks=0,{},{},{}
    local people={
        player={name="Alpha",second=interface==16001 and "Ash" or "Home",guid="Player-1"},
        target={name="Beta",second=interface==16001 and "Oak" or "Other",guid="Player-2"},
    }
    _G.GetBuildInfo=function() return "mock","mock","mock",interface end
    _G.GetTime=function() return t end
    _G.issecretvalue=function(v) return v==HIDDEN end
    _G.UNKNOWNOBJECT="Unknown"
    _G.Constants={CharacterNameSeparatorConsts={CHARACTERNAME_SURNAME_SEPARATOR=" "}}
    _G.UnitIsPlayer=function(unit) return people[unit]~=nil end
    _G.UnitName=function(unit)
        local p=people[unit]
        if p and p.hidden then return HIDDEN,HIDDEN end
        return p and p.name,p and p.second
    end
    _G.UnitFullName=UnitName
    _G.UnitGUID=function(unit) return people[unit] and people[unit].guid end
    _G.GetNormalizedRealmName=function() return "Home" end
    _G.DUEL_COUNTDOWN=formats and formats[1] or "Duel starting: %d"
    _G.DUEL_WINNER_KNOCKOUT=formats and formats[2] or "%1$s has defeated %2$s in a duel"
    _G.DUEL_WINNER_RETREAT=formats and formats[3] or "%2$s has fled from %1$s in a duel"
    _G.CreateFrame=function()
        local f={events={},scripts={}}
        function f:RegisterEvent(event)
            if event==missing then error("unknown mock event") end
            self.events[event]=true
        end
        function f:UnregisterAllEvents() self.events={} end
        function f:SetScript(k,fn) self.scripts[k]=fn end
        frames[#frames+1]=f
        return f
    end
    _G.C_Timer={After=function(delay,fn) timers[#timers+1]={at=t+delay,fn=fn} end}
    _G.StartDuel=function() error("detector must never invoke StartDuel") end
    _G.hooksecurefunc=function(name,fn) hooks[name]=fn end
    local ns={}
    for _,file in ipairs({"Client.lua","Group.lua","DuelDetection.lua"}) do
        assert(loadfile(path..file))("DuelsReimagined",ns)
    end
    local f=frames[#frames]
    local function Fire(event,value)
        if f and f.events[event] and f.scripts.OnEvent then
            f.scripts.OnEvent(f,event,value)
        end
    end
    local function Advance(seconds)
        local target=t+seconds
        while true do
            local best
            for i,job in ipairs(timers) do
                if job.at<=target and (not best or job.at<timers[best].at) then best=i end
            end
            if not best then break end
            local job=table.remove(timers,best)
            t=job.at; job.fn()
        end
        t=target
    end
    return {D=ns.DuelDetection,G=ns.Group,fire=Fire,advance=Advance,
        hooks=hooks,people=people,driver=f}
end
local function Snap(x) return x.D.GetSnapshot() end
local function Msg(x,text) x.fire("CHAT_MSG_SYSTEM",text) end
local function Begin(x,opponent)
    x.fire("DUEL_REQUESTED",opponent or "Beta-Other")
    Msg(x,"Duel starting: 3")
end

-- Retail: evidence in both orders, no dependence on combat.
local x=Setup(120105)
Check(Snap(x).state=="idle","ready on supported Retail mock")
Check(x.G.ReadPlayerIdentity("target").fullName=="Beta-Other","reuse roster realm identity")
local notifications=0
local remove=x.D.Subscribe(function(s)
    notifications=notifications+1
    if s.active then s.active.id=999 end
end)
x.D.Subscribe(function() error("deliberate listener failure") end)
x.fire("DUEL_REQUESTED","Beta-Other")
local rev=Snap(x).revision
x.fire("DUEL_REQUESTED","Beta-Other")
Check(Snap(x).revision==rev,"duplicate challenge does not notify twice")
x.fire("PLAYER_REGEN_DISABLED")
Check(Snap(x).state=="challenge" and not Snap(x).active,"combat is not a duel")
Msg(x,"Duel starting: 3")
local id=Snap(x).active.id
Check(Snap(x).state=="accepted" and id==1,"countdown accepted once")
Msg(x,"Duel starting: 3")
Msg(x,"Duel starting: 2")
Msg(x,"Duel starting: 1")
Check(Snap(x).active.id==id,"all countdown messages same cycle")
Msg(x,"Gamma has defeated Delta in a duel")
Check(Snap(x).state=="accepted","nearby spectator result ignored")
Msg(x,"Alpha has defeated Beta-WrongRealm in a duel")
Check(Snap(x).state=="accepted","explicit mismatched opponent realm ignored")
x.fire("DUEL_FINISHED")
Check(Snap(x).state=="finishing","finish before result waits")
Msg(x,"Alpha has defeated Beta-Other in a duel")
local last=Snap(x).last
Check(last.outcome=="won" and last.outcomeObserved and last.finishObserved
    and last.resultObserved and last.opponent.guid=="Player-2" and
    last.scope=="LOCAL" and last.rankEligible==false,"local knockout win")
rev=Snap(x).revision
Msg(x,"Alpha has defeated Beta-Other in a duel")
x.fire("DUEL_FINISHED")
x.advance(3)
Check(Snap(x).revision==rev and Snap(x).last.id==id,"duplicate result and finish do not create records")
last.opponent.display="bad"
Check(Snap(x).last.opponent.display~="bad","snapshot copy isolation")
remove()
local n=notifications
Begin(x)
Msg(x,"Beta-Other has defeated Alpha in a duel")
Check(Snap(x).state=="finishing" and Snap(x).active.result.outcome=="lost",
    "result before finish is pending")
x.fire("DUEL_FINISHED")
Check(Snap(x).last.outcome=="lost" and Snap(x).last.id==2,"local knockout loss")
Check(notifications==n,"unsubscribe works")

Begin(x)
Msg(x,"Alpha has fled from Beta-Other in a duel")
x.fire("DUEL_FINISHED")
Check(Snap(x).last.outcome=="fled","self fled is separate outcome")
Begin(x)
x.fire("DUEL_FINISHED")
Msg(x,"Beta-Other has fled from Alpha in a duel")
Check(Snap(x).last.outcome=="they_fled","opponent fled is separate outcome")

-- Invalid and incomplete evidence never becomes a verified local result.
x=Setup(120105)
x.fire("DUEL_REQUESTED","Beta-Other")
x.fire("DUEL_FINISHED")
Check(Snap(x).state=="idle" and not Snap(x).last,"cancelled challenge is not a duel")
Msg(x,"Alpha has defeated Beta-Other in a duel")
Check(not Snap(x).last,"orphan result ignored")
x.fire("DUEL_REQUESTED","Beta-Other")
x.advance(91)
Check(Snap(x).state=="idle" and not Snap(x).last,"stale challenge expires without record")
Begin(x)
x.fire("DUEL_FINISHED")
x.advance(3)
Check(Snap(x).last.outcome=="unknown" and not Snap(x).last.outcomeObserved,
    "finish without result is unresolved")
Begin(x)
Msg(x,"Alpha has defeated Beta-Other in a duel")
x.advance(3)
Check(Snap(x).last.outcome=="unknown" and Snap(x).last.reason=="finish_not_observed",
    "result without finish is unresolved")
Begin(x)
Msg(x,"Alpha has defeated Beta-Other in a duel")
Msg(x,"Beta-Other has defeated Alpha in a duel")
x.fire("DUEL_FINISHED")
Check(Snap(x).last.outcome=="unknown" and Snap(x).last.conflict,
    "conflicting evidence before finish is unresolved")
Begin(x)
x.fire("PLAYER_ENTERING_WORLD")
Check(Snap(x).last.reason=="world_transition" and not Snap(x).last.outcomeObserved,
    "loading screen does not manufacture outcome")
Begin(x)
x.fire("DUEL_FINISHED")
Msg(x,HIDDEN)
x.advance(3)
Check(Snap(x).last.outcome=="unknown","secret system message never parsed")

-- Fresh challenge, repeated opponent and timer isolation.
x=Setup(120105)
Begin(x)
x.fire("DUEL_FINISHED")
Msg(x,"Alpha has defeated Beta-Other in a duel")
Begin(x)
local fresh=Snap(x).active.id
x.advance(3)
Check(Snap(x).active.id==fresh,"old finish timer cannot clear new duel")
Msg(x,"Beta-Other has defeated Alpha in a duel")
x.fire("DUEL_FINISHED")
Check(Snap(x).last.id==fresh and Snap(x).last.outcome=="lost","rapid rematch separate cycle")
x.hooks.StartDuel("target")
Check(Snap(x).challenge.opponent.guid=="Player-2" and
    Snap(x).challenge.direction=="outgoing","outgoing unit hook is only attempt")
x.fire("DUEL_FINISHED")
x.hooks.StartDuel("player")
Check(Snap(x).state=="idle","targeting cursor not mistaken for challenge")
x.hooks.StartDuel("Beta-Other")
Check(Snap(x).challenge.opponent.guid=="Player-2","visible explicit name resolved")
x.fire("DUEL_FINISHED")
x.hooks.StartDuel("Nonexistent")
Check(Snap(x).challenge.opponent==nil,"failed name does not borrow current target")
x.fire("DUEL_FINISHED")

-- Countdown/result may be local even if the challenge was not captured.
x=Setup(120105)
Msg(x,"Duel starting: 3")
Check(Snap(x).active.kind=="unclassified" and not Snap(x).active.opponent,
    "missing challenge stays unknown identity")
x.fire("DUEL_FINISHED")
Msg(x,"Alpha has defeated Beta-Other in a duel")
Check(Snap(x).last.outcomeObserved and Snap(x).last.kind=="unclassified",
    "countdown + matching local finish/result can recover identity")
Check(not Snap(x).last.rankEligible,"unclassified never rank eligible")

-- Cross-realm short-name ambiguity cannot identify roles.
x=Setup(120105)
x.people.target={name="Alpha",second="Other",guid="Player-3"}
Begin(x,"Alpha-Other")
Msg(x,"Alpha has defeated Alpha-Other in a duel")
Check(Snap(x).state=="accepted","ambiguous short name rejected")
x.fire("DUEL_FINISHED")
Msg(x,"Alpha-Home has defeated Alpha-Other in a duel")
Check(Snap(x).last.outcome=="won","explicit distinct realms distinguish same first name")

-- Forever: actual surname normalization and reordered localized placeholders.
x=Setup(16001,nil,{"Comienza: %d","%2$s pierde ante %1$s!","%2$s huye de %1$s."})
Check(x.G.ReadPlayerIdentity("player").fullName=="Alpha Ash","Forever uses surnames")
x.fire("DUEL_REQUESTED","Beta-Oak")
Msg(x,"Comienza: 3")
Msg(x,"Beta Oak pierde ante Alpha Ash!")
x.fire("DUEL_FINISHED")
Check(Snap(x).last.outcome=="won" and Snap(x).last.opponent.guid=="Player-2",
    "localized reordered fields and hyphen/space surnames")
x.fire("DUEL_REQUESTED","Beta-Oak")
Msg(x,"Comienza: 3")
x.fire("DUEL_FINISHED")
Msg(x,"Alpha Ash huye de Beta Oak.")
Check(Snap(x).last.outcome=="fled","localized retreat uses winner and loser order")
local previous=Snap(x).last.id
x.fire("DUEL_TO_THE_DEATH_REQUESTED","Beta-Oak")
Msg(x,"Comienza: 3")
Msg(x,"Beta Oak pierde ante Alpha Ash!")
x.fire("DUEL_FINISHED")
Check(Snap(x).last.id==previous and Snap(x).state=="idle","known death duel excluded")
x.fire("DUEL_REQUESTED","Beta-Oak")
Msg(x,"Comienza: 3")
Check(Snap(x).active~=nil,"ordinary duel resumes after exclusion")
x.fire("DUEL_FINISHED")
x.advance(3)
Check(#Snap(x).trace<=24,"diagnostic trace bounded")

x=Setup(999)
Check(Snap(x).state=="unavailable","unsupported client fails closed")
x=Setup(120105,"DUEL_FINISHED")
Check(Snap(x).state=="unavailable" and not Snap(x).capabilities.finish,
    "missing required event fails closed")
x=Setup(120105,nil,{"bad %f","%s vs %s","%2$s fled %1$s"})
Check(Snap(x).state=="unavailable","unsupported format fails closed")
print("Duel detection simulated lifecycle contracts: PASS")
