local _,ns=...
-- Tournament navigation policy, separate from arena and ranked systems.
-- No tournament records, storage, communication, or live actions in Stage 1.
local T={};ns.TournamentState=T
local states={
    idle={overview=true,browse=true,host=true,champions=true},
    registered={overview=true,["my-tournament"]=true,champions=true},
    competing={overview=true,["my-tournament"]=true,brackets=true,champions=true},
    eliminated={overview=true,["my-tournament"]=true,brackets=true,champions=true},
    hosting={overview=true,host=true,champions=true},
    completed={overview=true,browse=true,["my-tournament"]=true,host=true,champions=true},
}
function T.Project(state,hasBracket)
    local source=states[state] or states.idle
    local out={}
    for key,value in pairs(source) do out[key]=value end
    -- A bracket cannot be displayed before there is an actual draw.
    if hasBracket==true and (state=="registered" or state=="hosting" or state=="completed") then
        out.brackets=true
    elseif hasBracket~=true then out.brackets=nil end
    return out
end
function T.GetSnapshot()
    return {client=ns.Client.Kind(),state="idle",hasBracket=false,discovery=false,hosting=false}
end
function T.IsPageAvailable(key)
    local snapshot=T.GetSnapshot()
    return ns.Client.IsSupported() and T.Project(snapshot.state,snapshot.hasBracket)[key]==true
end
function T.RunSelfTest()
    local n=0
    local function check(v) assert(v,"Tournament navigation policy");n=n+1 end
    local idle=T.Project("idle",false)
    check(idle.overview and idle.browse and idle.host and idle.champions and not idle["my-tournament"] and not idle.brackets)
    local registered=T.Project("registered",false)
    check(registered["my-tournament"] and not registered.host and not registered.browse and not registered.brackets)
    check(T.Project("registered",true).brackets)
    local competing=T.Project("competing",true)
    check(competing.brackets and competing["my-tournament"] and not competing.browse and not competing.host)
    check(not T.Project("competing",false).brackets)
    check(T.Project("eliminated",true)["my-tournament"] and not T.Project("eliminated",true).host)
    check(T.Project("hosting",true).host and T.Project("hosting",true).brackets and not T.Project("hosting",true).browse)
    check(T.Project("completed",true).browse and T.Project("completed",true).host and T.Project("completed",true)["my-tournament"])
    idle.browse=nil
    check(T.Project("idle",false).browse)
    local snapshot=T.GetSnapshot()
    check(snapshot.state=="idle" and not snapshot.discovery and not snapshot.hosting and not snapshot.hasBracket)
    return n
end
if ns.Diagnostics then
    ns.Diagnostics.Register("tournament-ui-policy","deep",function()
        local ok,n=pcall(T.RunSelfTest)
        if not ok then return "FAIL",tostring(n) end
        return "PASS",n.." isolated navigation checks; discovery and hosting inactive."
    end)
end
