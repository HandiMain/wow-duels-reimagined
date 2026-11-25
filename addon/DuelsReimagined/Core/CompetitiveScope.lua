local _,ns=...
-- One competitive population identity. No storage, polling or network owner.
local P={};ns.CompetitiveScope=P
local function Plain(v)
    if type(issecretvalue)=="function" then
        local ok,secret=pcall(issecretvalue,v)
        if not ok or secret then return nil end
    end
    return v
end
local function Read(fn,...)
    if type(fn)~="function" then return nil end
    local ok,v=pcall(fn,...)
    if ok then return Plain(v) end
end
local function RegionFor(id)
    id=Plain(id)
    if id==1 then return "US" elseif id==3 then return "EU" end
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
        local id=Plain(flags[key])
        if type(id)~="number" or not tostring(id):match("^%d+$") or id<1 or id>100000 then return nil end
        return Read(api.IsGameRuleActive,id)
    end
    return RulesetFor(Flag("PvPRuleset"),Flag("RPRuleset"),Flag("HardcoreRuleset"))
end
local function FactionFor(value)
    value=Plain(value)
    if value=="Alliance" or value=="Horde" or value=="Neutral" then return value end
end
local function Detect(client,regionFn,api,flags,factionFn)
    return {client=client,region=RegionFor(Read(regionFn)),
        ruleset=ReadRuleset(client,api,flags),faction=FactionFor(Read(factionFn,"player"))}
end
function P.GetCurrent()
    return Detect(ns.Client.Kind(),GetCurrentRegion,C_GameRules,Enum and Enum.GameRule,UnitFactionGroup)
end
function P.Key(s)
    s=Plain(s)
    if type(s)~="table" then return nil end
    local c,r,m,f=Plain(s.client),Plain(s.region),Plain(s.ruleset),Plain(s.faction)
    if r~="EU" and r~="US" then return nil end
    if f~="Alliance" and f~="Horde" then return nil end
    if not ((c=="retail" and m=="retail") or (c=="forever" and
        (m=="normal" or m=="pvp" or m=="rp" or m=="rp-pvp"))) then return nil end
    return c..":"..r..":"..m..":"..f
end
function P.Matches(expected,record)
    local key=P.Key(expected)
    return key~=nil and key==P.Key(record)
end
-- Compact, reversible population code for the existing bounded wire tokens.
local regionCodes={EU="e",US="u"}
local modeCodes={retail="s",normal="n",pvp="p",rp="r",["rp-pvp"]="b"}
local factionCodes={Alliance="a",Horde="h"}
function P.Code(key,client)
    if type(key)~="string" then return nil end
    local c,r,m,f=key:match("^([%a]+):([%a]+):([%a%-]+):([%a]+)$")
    if c~=client or P.Key({client=c,region=r,ruleset=m,faction=f})~=key then return nil end
    return regionCodes[r]..modeCodes[m]..factionCodes[f]
end
function P.TokenPrefix(key,client)
    local code=P.Code(key,client);return code and code.."-"
end
function P.TokenMatches(key,client,token)
    local prefix=P.TokenPrefix(key,client)
    return prefix~=nil and type(token)=="string" and #token<=32 and #token>#prefix
        and token:match("^[%w%-]+$")~=nil and token:sub(1,#prefix)==prefix
end
function P.SessionMatches(key,client,session)
    if type(session)~="string" then return false end
    local a,b=session:match("^([%w%-]+):([%w%-]+)$")
    return P.TokenMatches(key,client,a) and P.TokenMatches(key,client,b)
end
-- A separate release gate; scoped implementation is NOT multiplayer evidence.
function P.RankedReady() return false end
function P.RunSelfTest(emit)
    emit=type(emit)=="function" and emit or function() end
    local pass,fail=0,0
    local function Case(label,fn)
        local ok,err=pcall(fn);if ok then pass=pass+1 else fail=fail+1 end
        emit("DR | SIMULATED | "..(ok and "PASS " or "FAIL ")..label..(ok and "" or ": "..tostring(err)))
    end
    Case("all twenty supported populations are distinct",function()
        local all,keys={},{}
        for _,c in ipairs({"retail","forever"}) do
            for _,r in ipairs({"EU","US"}) do
                for _,m in ipairs(c=="retail" and {"retail"} or {"normal","pvp","rp","rp-pvp"}) do
                    for _,f in ipairs({"Alliance","Horde"}) do
                        local s={client=c,region=r,ruleset=m,faction=f}
                        local k=assert(P.Key(s));assert(not keys[k]);keys[k]=true;all[#all+1]=s
                    end
                end
            end
        end
        assert(#all==20)
        for i,a in ipairs(all) do
            local key=P.Key(a);local prefix=assert(P.TokenPrefix(key,a.client))
            assert(P.SessionMatches(key,a.client,prefix.."r1-1:"..prefix.."r2-1"))
            assert(not P.SessionMatches(key,a.client,"r1-1:r2-1"))
            for j,b in ipairs(all) do
                assert(P.Matches(a,b)==(i==j))
                if a.client==b.client then
                    local other=assert(P.TokenPrefix(P.Key(b),b.client))
                    assert(P.SessionMatches(key,a.client,prefix.."x:"..other.."y")== (i==j))
                end
            end
        end
    end)
    Case("unknown regions, unsupported modes and neutral factions fail closed",function()
        local s={client="forever",region="EU",ruleset="pvp",faction="Neutral"}
        assert(not P.Key(s) and not P.Matches(s,s))
        s.faction="Alliance";s.ruleset="hardcore";assert(not P.Key(s))
        s.ruleset="pvp";s.region="KR";assert(not P.Key(s))
        s.region=nil;assert(not P.Key(s))
        s.region="US";s.client="retail";assert(not P.Key(s))
        s.client="unknown";assert(not P.Key(s) and not P.Matches(nil,nil))
    end)
    Case("region API maps EU and Americas only",function()
        assert(RegionFor(1)=="US" and RegionFor(3)=="EU")
        for _,v in ipairs({0,2,4,5,"3",false,{}}) do assert(not RegionFor(v)) end
    end)
    Case("Forever ruleset flags including combined RP-PvP",function()
        assert(RulesetFor(false,false,false)=="normal" and RulesetFor(true,false,false)=="pvp")
        assert(RulesetFor(false,true,false)=="rp" and RulesetFor(true,true,false)=="rp-pvp")
        assert(RulesetFor(false,false,true)=="hardcore" and not RulesetFor(nil,false,false))
        local flags={PvPRuleset=213,RPRuleset=214,HardcoreRuleset=10}
        assert(ReadRuleset("forever",{IsGameRuleActive=function(id)return id==213 or id==214 end},flags)=="rp-pvp")
        assert(not ReadRuleset("forever",{IsGameRuleActive=function()error("unavailable")end},flags))
        assert(not ReadRuleset("forever",{},flags) and not ReadRuleset("forever",{},{}))
    end)
    Case("Retail faction is read without Forever ruleset assumptions",function()
        local s=Detect("retail",function()return 3 end,nil,nil,function(unit)
            assert(unit=="player");return "Alliance"
        end)
        assert(P.Key(s)=="retail:EU:retail:Alliance")
        local t=Detect("retail",function()return 1 end,nil,nil,function()return "Horde" end)
        assert(P.Key(t)=="retail:US:retail:Horde" and not P.Matches(s,t))
        s.faction="Horde";assert(not P.Matches(s,t))
    end)
    Case("failed APIs and partial observations cannot authorize a population",function()
        local s=Detect("forever",function()error("unavailable")end,nil,nil,function()return "Horde" end)
        assert(s.client=="forever" and s.faction=="Horde" and not P.Key(s))
        local t=Detect("retail",function()return 3 end,nil,nil,function()error("unavailable")end)
        assert(t.region=="EU" and not t.faction and not P.Key(t))
    end)
    Case("ranked activation remains locked pending release verification",function()
        assert(not P.RankedReady())
    end)
    return pass,fail
end
