local _, ns = ...
-- Explicitly requested, session-only diagnostic. No Blizzard event injection,
-- global stubs, real timer, live subscriptions, storage or game actions.
local Test={}
ns.DuelSelfTest=Test

-- Produce fixture messages independently from the detector's parser,
-- including localized positional placeholders and escaped percent signs.
local function Format(pattern,...)
    assert(type(pattern)=="string","missing localized format")
    local args={...}
    local pos=0
    local text=pattern:gsub("%%(%d+)%$([sd])",function(n)
        return tostring(assert(args[tonumber(n)],"invalid positional field"))
    end)
    return (text:gsub("%%([sd%%])",function(k)
        if k=="%" then return "%" end
        pos=pos+1
        return tostring(assert(args[pos],"invalid sequential field"))
    end))
end
local function Check(v,why) assert(v,why) end
local function Setup(kind,locale,missing)
    local x=ns.DuelDetection.NewSandbox(kind,locale,missing)
    x.snap=x.detector.GetSnapshot
    x.me=x.people.player.fullName
    x.other=x.people.target.fullName
    x.msg=function(key,...)
        x.Fire("CHAT_MSG_SYSTEM",Format(x.formats[key],...))
    end
    x.begin=function(outgoing)
        if outgoing then x.Outgoing("target") else x.Fire("DUEL_REQUESTED",x.other) end
        x.msg("countdown",3)
    end
    x.finish=function() x.Fire("DUEL_FINISHED") end
    return x
end
local function Outcome(x,expected)
    local s=x.snap()
    Check(s.state=="idle" and s.last and s.last.outcome==expected,
        "expected "..expected..", got "..(s.last and s.last.outcome or s.state))
    Check(s.last.scope=="SIMULATED" and not s.last.rankEligible,"simulation escaped scope")
    Check(s.last.outcomeObserved==(expected~="unknown"),"incorrect evidence flag")
end

local cases={
    {"Win / finish first",function(x)
        x.begin(); x.finish()
        Check(x.snap().state=="finishing","not waiting for result")
        x.msg("knockout",x.me,x.other); Outcome(x,"won")
        Check(x.snap().last.opponent.guid=="SIMULATED-2","opponent not resolved")
    end},
    {"Loss / result first",function(x)
        x.begin(true); x.msg("knockout",x.other,x.me)
        Check(x.snap().state=="finishing","not waiting for finish")
        x.finish(); Outcome(x,"lost")
    end},
    {"You flee",function(x)
        x.begin(); x.msg("retreat",x.other,x.me); x.finish(); Outcome(x,"fled")
    end},
    {"Opponent flees",function(x)
        x.begin(); x.finish(); x.msg("retreat",x.me,x.other); Outcome(x,"they_fled")
    end},
    {"Incoming decline",function(x)
        x.Fire("DUEL_REQUESTED",x.other); x.finish()
        Check(x.snap().state=="idle" and not x.snap().last,"decline recorded")
    end},
    {"Outgoing cancellation",function(x)
        x.Outgoing("target"); Check(x.snap().state=="challenge","outgoing attempt missing")
        x.finish(); Check(x.snap().state=="idle" and not x.snap().last,"cancel recorded")
    end},
    {"Expired request",function(x)
        x.Fire("DUEL_REQUESTED",x.other); x.Advance(91)
        Check(x.snap().state=="idle" and not x.snap().last,"expiry recorded")
    end},
    {"Duplicates and rematch",function(x)
        x.begin(); local id=x.snap().active.id
        x.msg("countdown",3); x.msg("countdown",2); x.msg("countdown",1)
        Check(x.snap().active.id==id,"duplicate countdown")
        x.finish(); x.msg("knockout",x.me,x.other); Outcome(x,"won")
        local rev=x.snap().revision
        x.finish(); x.msg("knockout",x.me,x.other)
        Check(x.snap().revision==rev,"duplicate finish/result")
        x.begin(); x.Advance(3)
        Check(x.snap().active.id==id+1,"old timer damaged rematch")
        x.msg("knockout",x.other,x.me); x.finish(); Outcome(x,"lost")
    end},
    {"Other players / wrong opponent",function(x)
        x.msg("knockout","TestGamma","TestDelta")
        Check(not x.snap().last,"spectator result recorded")
        x.begin(); x.msg("knockout","TestGamma","TestDelta")
        x.msg("knockout",x.me,"TestGamma")
        Check(x.snap().state=="accepted","unrelated result accepted")
        x.finish(); x.Advance(3); Outcome(x,"unknown")
    end},
    {"Ordinary combat ignored",function(x)
        x.Fire("PLAYER_REGEN_DISABLED"); x.Fire("PLAYER_REGEN_ENABLED")
        Check(x.snap().state=="idle" and not x.snap().last,"combat treated as duel")
    end},
    {"Missing result / timeout",function(x)
        x.begin(); x.finish(); x.Advance(3); Outcome(x,"unknown")
        Check(x.snap().last.reason=="result_not_observed","wrong missing-result reason")
    end},
    {"Missing finish / timeout",function(x)
        x.begin(); x.msg("knockout",x.me,x.other); x.Advance(3); Outcome(x,"unknown")
        Check(x.snap().last.reason=="finish_not_observed","wrong missing-finish reason")
    end},
    {"Conflicting evidence",function(x)
        x.begin(); x.msg("knockout",x.me,x.other); x.msg("knockout",x.other,x.me)
        x.finish(); Outcome(x,"unknown"); Check(x.snap().last.conflict,"conflict not flagged")
    end},
    {"World transition",function(x)
        x.begin(); x.Fire("PLAYER_ENTERING_WORLD"); Outcome(x,"unknown")
    end},
    {"Restricted result (mock)",function(x)
        x.begin(); x.finish(); x.Fire("CHAT_MSG_SYSTEM",x.hidden)
        x.Advance(3); Outcome(x,"unknown")
    end},
    {"Known death duel excluded",function(x)
        x.Fire("DUEL_TO_THE_DEATH_REQUESTED",x.other)
        x.msg("countdown",3); x.msg("knockout",x.me,x.other); x.finish()
        Check(x.snap().state=="idle" and not x.snap().last,"death duel recorded")
    end},
    {"Missing challenge",function(x)
        x.msg("countdown",3); x.finish(); x.msg("knockout",x.me,x.other)
        Outcome(x,"won"); Check(x.snap().last.kind=="unclassified","wrong classification")
    end},
    {"Identity ambiguity / exact names",function(x)
        if x.snap().client=="retail" then
            x.people.target.fullName="TestAlpha-Other"
            x.other=x.people.target.fullName
            x.begin()
            x.msg("knockout","TestAlpha",x.other)
            Check(x.snap().state=="accepted","ambiguous role accepted")
        else
            x.Fire("DUEL_REQUESTED","TestBeta-Other")
            x.msg("countdown",3)
            Check(x.snap().active.opponent.guid=="SIMULATED-2","surname normalization failed")
        end
        x.finish(); x.msg("knockout",x.me,x.other); Outcome(x,"won")
    end},
    {"Snapshot and subscriber isolation",function(x)
        local count=0
        local remove=x.detector.Subscribe(function(s)
            count=count+1; if s.active then s.active.id=999 end
        end)
        x.begin(); Check(x.snap().active.id==1 and count>0,"snapshot or listener broken")
        remove(); local before=count
        x.finish(); x.msg("knockout",x.me,x.other); Outcome(x,"won")
        Check(count==before,"unsubscribe broken")
    end},
}
function Test.Run(emit,verbose)
    emit=type(emit)=="function" and emit or print
    local before=ns.DuelDetection.GetSnapshot()
    local passed,failed=0,0
    local function RunCase(label,fn)
        local ok,why=pcall(fn)
        if ok then passed=passed+1 else failed=failed+1 end
        if verbose or not ok then
            emit("DR | SIMULATED | "..(ok and "PASS " or "FAIL ")..label..
                (ok and "" or ": "..tostring(why)))
        end
    end
    emit("DR | SIMULATED solo duel test — no real challenges or records.")
    local current=ns.Client.Kind()
    for _,kind in ipairs({"forever","retail"}) do
        local startPass,startFail=passed,failed
        for _,case in ipairs(cases) do
            RunCase(kind.." / "..case[1],function()
                case[2](Setup(kind,false))
            end)
        end
        RunCase(kind.." / missing finish API",function()
            Check(Setup(kind,false,"DUEL_FINISHED").snap().state=="unavailable","API guard failed")
        end)
        emit(string.format("DR | SIMULATED | %s: %d passed / %d failed",kind,
            passed-startPass,failed-startFail))
    end
    if current=="forever" or current=="retail" then
        RunCase(current.." / actual client language formats",function()
            local x=Setup(current,true)
            Check(x.snap().state=="idle","client format unsupported")
            cases[1][2](x)
            cases[3][2](Setup(current,true))
        end)
        if not verbose then emit("DR | SIMULATED | Client-language case included in summary.") end
    else
        emit("DR | SIMULATED | SKIP actual client language: unsupported client")
    end
    RunCase("live state untouched",function()
        local after=ns.DuelDetection.GetSnapshot()
        Check(before.scope=="LOCAL" and after.scope=="LOCAL" and
            before.revision==after.revision,"live detector changed")
    end)
    emit(string.format("DR | SIMULATED SUMMARY: %d passed / %d failed. Live multiplayer not tested.",passed,failed))
    return passed,failed
end
