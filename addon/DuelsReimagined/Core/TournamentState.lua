local _,ns=...
-- Tournament navigation policy, separate from arena and ranked systems.
-- Session-only drafts; no live tournament records or communication.
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
    local scope=T.GetWorldScope()
    return {client=ns.Client.Kind(),region=scope and scope.region,ruleset=scope and scope.ruleset,state="idle",hasBracket=false,discovery=false,hosting=false}
end
function T.IsPageAvailable(key)
    local snapshot=T.GetSnapshot()
    return ns.Client.IsSupported() and T.Project(snapshot.state,snapshot.hasBracket)[key]==true
end
-- Creation is a local session draft only. Registration and hosting remain closed.
local function Copy(row)
    if not row then return nil end
    local out={};for k,v in pairs(row) do out[k]=v end
    return out
end
local function Plain(v)
    if type(issecretvalue)=="function" then
        local ok,secret=pcall(issecretvalue,v)
        if not ok or secret then return nil end
    end
    return v
end
local function Whole(v,lo,hi)
    v=Plain(v)
    if type(v)~="number" or not tostring(v):match("^%d+$") then return false end
    return v>=lo and v<=hi and v==math.floor(v)
end
local function Supported(client) return client=="forever" or client=="retail" end
-- Portal IDs are a provisional region boundary; actual reachability is separate.
-- Use only documented 1 (Americas/Oceania) and 3 (Europe) until observed otherwise.
local function RegionFor(id)
    id=Plain(id)
    if id==1 then return "US" elseif id==3 then return "EU" end
end
local function Read(fn,...)
    if type(fn)~="function" then return nil end
    local ok,v=pcall(fn,...)
    if ok then return Plain(v) end
end
local function RulesetFor(pvp,rp,hardcore)
    if type(pvp)~="boolean" or type(rp)~="boolean" or type(hardcore)~="boolean" then return nil end
    if hardcore then return "hardcore" end
    if rp then return pvp and "rp-pvp" or "rp" end
    return pvp and "pvp" or "normal"
end
local function ReadRuleset(client,api,flags)
    if client=="retail" then return "retail" end
    if client~="forever" or type(api)~="table" or type(flags)~="table" then return nil end
    local function Flag(key)
        local id=flags[key]
        if not Whole(id,1,100000) then return nil end
        return Read(api.IsGameRuleActive,id)
    end
    return RulesetFor(Flag("PvPRuleset"),Flag("RPRuleset"),Flag("HardcoreRuleset"))
end
local function ValidScope(client,region,ruleset)
    return (region=="EU" or region=="US") and
        ((client=="retail" and ruleset=="retail") or (client=="forever" and
            (ruleset=="normal" or ruleset=="pvp" or ruleset=="rp" or ruleset=="rp-pvp")))
end
function T.GetWorldScope()
    local client=ns.Client.Kind()
    local region=RegionFor(Read(GetCurrentRegion))
    local ruleset=ReadRuleset(client,C_GameRules,Enum and Enum.GameRule)
    if not region or not ruleset then return nil end
    return {client=client,region=region,ruleset=ruleset}
end
function T.ScopeMatches(client,region,ruleset,record)
    return ValidScope(client,region,ruleset) and type(record)=="table"
        and record.client==client and record.region==region and record.ruleset==ruleset
end
local function Text(v,max,required)
    v=Plain(v)
    if type(v)~="string" or #v>max or v:find("[%c|]") then return nil end
    v=v:match("^%s*(.-)%s*$")
    if required and v=="" then return nil end
    return v
end
local function Leap(y) return y%4==0 and (y%100~=0 or y%400==0) end
local function Days(y,m)
    if m==2 then return Leap(y) and 29 or 28 end
    return (m==4 or m==6 or m==9 or m==11) and 30 or 31
end
-- Parse explicit UTC, independent of local timezone and daylight saving.
local function ParseUTC(value)
    local s=Text(value,16,true)
    if not s then return nil end
    local y,m,d,h,minute=s:match("^(%d%d%d%d)%-(%d%d)%-(%d%d) (%d%d):(%d%d)$")
    y,m,d,h,minute=tonumber(y),tonumber(m),tonumber(d),tonumber(h),tonumber(minute)
    if not y or y<2020 or y>2099 or m<1 or m>12 or d<1 or d>Days(y,m) or h>23 or minute>59 then return nil end
    local days=0
    for year=1970,y-1 do days=days+(Leap(year) and 366 or 365) end
    for month=1,m-1 do days=days+Days(y,month) end
    return (days+d-1)*86400+h*3600+minute*60,s
end
local capacities={[4]=true,[8]=true,[16]=true,[32]=true}
local series={[1]=true,[3]=true,[5]=true}
local deadlines={[0]=true,[15]=true,[30]=true,[60]=true}
local fields={name=true,location=true,startUTC=true,capacity=true,bestOf=true,closeBefore=true,minLevel=true,maxLevel=true,rules=true}
-- Display-only local time at the event date, independent of realm time.
local function FormatLocal(epoch,formatter)
    if type(formatter)~="function" then return nil end
    local ok,s=pcall(formatter,"%Y-%m-%d %H:%M",epoch)
    s=ok and Text(s,16,true) or nil
    if s and s:match("^%d%d%d%d%-%d%d%-%d%d %d%d:%d%d$") then return s end
end
local function SchedulePreview(value,lead,formatter)
    local start=ParseUTC(value)
    if not start or not Whole(lead,0,60) or not deadlines[lead] then return nil end
    local starts=FormatLocal(start,formatter)
    local closes=FormatLocal(start-lead*60,formatter)
    if starts and closes then return {starts=starts,closes=closes} end
end
function T.GetSchedulePreview(value,lead)
    return SchedulePreview(value,lead,date)
end
local function Level(v)
    v=Text(v,3,false)
    if v=="" then return 0 end
    if not v or not v:match("^%d+$") then return nil end
    local n=tonumber(v)
    if not Whole(n,1,255) then return nil end
    return n
end
function T.DraftDefaults()
    return {name="",location="",startUTC="",capacity=16,bestOf=1,closeBefore=15,minLevel="",maxLevel="",rules=""}
end
function T.ValidateDraft(client,input,now,region,ruleset)
    if not Supported(client) then return nil,"This client does not support tournaments." end
    if not ValidScope(client,region,ruleset) then return nil,"Your tournament community is unavailable or not supported yet." end
    if not Whole(now,1,4102444800) then return nil,"Server time is unavailable. Try again later." end
    if type(input)~="table" then return nil,"Tournament details are missing." end
    for k in pairs(input) do if not fields[k] then return nil,"Invalid tournament details." end end
    local name=Text(input.name,60,true)
    if not name then return nil,"Enter a tournament name (up to 60 bytes; no links)." end
    local location=Text(input.location,100,true)
    if not location then return nil,"Enter the world duel location (up to 100 bytes)." end
    local start,startUTC=ParseUTC(input.startUTC)
    if not start then return nil,"Use a valid UTC date and time: YYYY-MM-DD HH:MM (2020–2099)." end
    local size,best,lead=Plain(input.capacity),Plain(input.bestOf),Plain(input.closeBefore)
    if not Whole(size,4,32) or not capacities[size] then return nil,"Choose 4, 8, 16 or 32 players." end
    if not Whole(best,1,5) or not series[best] then return nil,"Choose best of 1, 3 or 5." end
    if not Whole(lead,0,60) or not deadlines[lead] then return nil,"Choose a registration deadline." end
    local closes=start-lead*60
    if start<=now or closes<=now then return nil,"Start and registration close must both be in the future." end
    local lo,hi=Level(input.minLevel),Level(input.maxLevel)
    if lo==nil or hi==nil or (lo>0 and hi>0 and lo>hi) then return nil,"Enter a valid level range, or leave either field blank." end
    local rules=Text(input.rules,160,false)
    if rules==nil then return nil,"Rules must be plain text, up to 160 bytes." end
    return {scope="LOCAL",version=1,client=client,region=region,ruleset=ruleset,state="draft",name=name,location=location,startUTC=startUTC,
        startAt=start,registrationClosesAt=closes,capacity=size,bestOf=best,closeBefore=lead,
        format="single_elimination",minLevel=lo,maxLevel=hi,rules=rules}
end
local function DraftStore(client,region,ruleset,clock)
    local saved
    local D={}
    function D.Save(input)
        local record,why=T.ValidateDraft(client,input,clock(),region,ruleset)
        if not record then return nil,why end
        saved=record;return Copy(saved)
    end
    function D.Read() return Copy(saved) end
    return D
end
local function ServerNow()
    if type(GetServerTime)~="function" then return nil end
    local ok,v=pcall(GetServerTime)
    if ok then return Plain(v) end
end
local draft,draftKey
local function WorldKey(s)
    if s and ValidScope(s.client,s.region,s.ruleset) then
        return s.client..":"..s.region..":"..s.ruleset
    end
end
function T.SaveDraft(input)
    if not T.IsPageAvailable("host") then return nil,"You cannot host right now." end
    local s=T.GetWorldScope()
    local key=WorldKey(s)
    if not key then return nil,"Your tournament community is unavailable or not supported yet." end
    if draftKey~=key then draft=nil;draftKey=key end
    draft=draft or DraftStore(s.client,s.region,s.ruleset,ServerNow)
    return draft.Save(input)
end
function T.GetDraft()
    if draft and draftKey==WorldKey(T.GetWorldScope()) then return draft.Read() end
end
function T.RunCreationSelfTest(emit)
    emit=type(emit)=="function" and emit or function()end
    local pass,fail=0,0
    local function Case(label,fn)
        local ok,err=pcall(fn);if ok then pass=pass+1 else fail=fail+1 end
        emit("DR | SIMULATED | "..(ok and "PASS " or "FAIL ")..label..(ok and "" or ": "..tostring(err)))
    end
    local now=1795622400 -- 2026-11-25 16:00 UTC
    local function Form()
        local a=T.DraftDefaults()
        a.name="  Duel Cup  ";a.location="Durotar";a.startUTC="2026-11-25 18:00"
        return a
    end
    for _,client in ipairs({"forever","retail"}) do
        local mode=client=="retail" and "retail" or "pvp"
        local function Valid(a) return T.ValidateDraft(client,a,now,"EU",mode) end
        Case(client.." canonical UTC draft and registration cutoff",function()
            local a=Form();local d=assert(Valid(a))
            assert(d.name=="Duel Cup" and d.client==client and d.region=="EU" and d.ruleset==mode and d.scope=="LOCAL" and d.state=="draft")
            assert(T.ScopeMatches(client,"EU",mode,d) and not T.ScopeMatches(client,"US",mode,d))
            assert(not T.ScopeMatches(client=="retail" and "forever" or "retail","EU",mode,d))
            local us=assert(T.ValidateDraft(client,a,now,"US",mode))
            assert(T.ScopeMatches(client,"US",mode,us) and not T.ScopeMatches(client,"EU",mode,us))
            assert(not T.ValidateDraft(client,a,now,nil,mode) and not T.ValidateDraft(client,a,now,"EU",nil))
            if client=="forever" then
                for _,other in ipairs({"normal","rp","rp-pvp"}) do
                    local x=assert(T.ValidateDraft(client,a,now,"EU",other))
                    assert(not T.ScopeMatches(client,"EU",mode,x) and T.ScopeMatches(client,"EU",other,x))
                end
                assert(not T.ValidateDraft(client,a,now,"EU","hardcore"))
            end
            assert(d.startAt==now+7200 and d.registrationClosesAt==now+6300 and d.format=="single_elimination")
            assert(d.capacity==16 and d.bestOf==1 and d.minLevel==0 and d.maxLevel==0)
            local called=0
            local preview=assert(SchedulePreview(a.startUTC,a.closeBefore,function(fmt,stamp)
                assert(fmt=="%Y-%m-%d %H:%M");called=called+1
                if stamp==d.startAt then return "2026-11-25 13:00" end
                assert(stamp==d.registrationClosesAt);return "2026-11-25 12:45"
            end))
            assert(called==2 and preview.starts=="2026-11-25 13:00" and preview.closes=="2026-11-25 12:45")
            assert(not SchedulePreview(a.startUTC,15,nil))
            assert(not SchedulePreview(a.startUTC,15,function()error("unavailable")end))
            a.name="Changed";assert(d.name=="Duel Cup")
        end)
        Case(client.." leap years and malformed calendar dates",function()
            local a=Form();a.startUTC="2028-02-29 12:30";assert(Valid(a).startAt==1835440200)
            for _,v in ipairs({"2027-02-29 12:30","2028-04-31 00:00","2028-01-01 24:00","2028-01-01 23:60","2028-1-01 12:00","2028-00-01 12:00","2100-01-01 00:00"}) do
                a.startUTC=v;assert(not Valid(a),v)
            end
        end)
        Case(client.." elapsed registration and unavailable clock rejected",function()
            local a=Form();a.startUTC="2026-11-25 16:15";assert(not Valid(a))
            a.closeBefore=0;assert(Valid(a));a.startUTC="2026-11-25 16:00";assert(not Valid(a))
            assert(not T.ValidateDraft(client,Form(),nil,"EU",mode));assert(not T.ValidateDraft(client,Form(),0/0,"EU",mode))
        end)
        Case(client.." supported capacity and series options only",function()
            for _,size in ipairs({4,8,16,32}) do
                for _,best in ipairs({1,3,5}) do local a=Form();a.capacity=size;a.bestOf=best;assert(Valid(a)) end
            end
            local a=Form();a.capacity=64;assert(not Valid(a));a.capacity=16;a.bestOf=2;assert(not Valid(a))
            a.bestOf=3;a.closeBefore=12;assert(not Valid(a))
        end)
        Case(client.." required plain text and bounded fields",function()
            local a=Form();a.name=" ";assert(not Valid(a));a.name=string.rep("a",61);assert(not Valid(a))
            a=Form();a.location="";assert(not Valid(a));a.location="a|b";assert(not Valid(a))
            a=Form();a.rules="No potions";assert(Valid(a).rules=="No potions")
            a.rules="\n";assert(not Valid(a));a.rules=string.rep("a",161);assert(not Valid(a))
            a=Form();a.winner="invented";assert(not Valid(a))
        end)
        Case(client.." optional levels and reversed range",function()
            local a=Form();a.minLevel="30";assert(Valid(a).minLevel==30)
            a.maxLevel="60";assert(Valid(a).maxLevel==60)
            a.maxLevel="20";assert(not Valid(a));a.maxLevel="";a.minLevel="0";assert(not Valid(a))
            a.minLevel="1.5";assert(not Valid(a));a.minLevel="999";assert(not Valid(a))
        end)
        Case(client.." session draft copies, rejected edit and client isolation",function()
            local d=DraftStore(client,"EU",mode,function()return now end)
            local other=DraftStore(client,"US",mode,function()return now end)
            assert(not d.Read() and not other.Read())
            local a=Form();local r=assert(d.Save(a));r.name="changed";a.name=""
            assert(not d.Save(a));assert(d.Read().name=="Duel Cup" and not other.Read())
            local x=d.Read();x.capacity=64;assert(d.Read().capacity==16)
        end)
    end
    Case("creation remains local; unsupported client and publication gate",function()
        assert(not T.ValidateDraft("unsupported",Form(),now,"EU","retail"))
        assert(RegionFor(1)=="US" and RegionFor(3)=="EU" and not RegionFor(0) and not RegionFor(nil))
        assert(RulesetFor(false,false,false)=="normal" and RulesetFor(true,false,false)=="pvp")
        assert(RulesetFor(false,true,false)=="rp" and RulesetFor(true,true,false)=="rp-pvp")
        assert(RulesetFor(false,false,true)=="hardcore" and not RulesetFor(nil,false,false))
        local flags={PvPRuleset=213,RPRuleset=214,HardcoreRuleset=10}
        assert(ReadRuleset("forever",{IsGameRuleActive=function(id)return id==213 or id==214 end},flags)=="rp-pvp")
        assert(not ReadRuleset("forever",{IsGameRuleActive=function()error("unavailable")end},flags))
        assert(not ReadRuleset("forever",{},flags) and not ReadRuleset("forever",{IsGameRuleActive=function()return false end},{}))
        local a,b=T.GetDraft(),T.GetSnapshot()
        assert(not b.discovery and not b.hosting and b.state=="idle")
        if a then assert(a.scope=="LOCAL" and a.state=="draft") end
    end)
    return pass,fail
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
    ns.Diagnostics.Register("Tournament community / current client","health",function()
        local s=T.GetWorldScope()
        if not s then return "SKIP","Region or ruleset unavailable; hosting and discovery inactive." end
        if not ValidScope(s.client,s.region,s.ruleset) then return "SKIP","Community not supported yet." end
        return "PASS",s.client.." / "..s.region.." / "..s.ruleset.."; actual duel reachability not verified."
    end)
    ns.Diagnostics.Register("Tournament creation / isolated draft QA","deep",function()
        local log={}
        local p,f=T.RunCreationSelfTest(function(line) log[#log+1]=line end)
        return f==0 and p==15 and "PASS" or "FAIL",
            string.format("%d passed / %d failed (SIMULATED)\n",p,f)..table.concat(log,"\n")
    end)
    ns.Diagnostics.Register("tournament-ui-policy","deep",function()
        local ok,n=pcall(T.RunSelfTest)
        if not ok then return "FAIL",tostring(n) end
        return "PASS",n.." isolated navigation checks; discovery and hosting inactive."
    end)
end
