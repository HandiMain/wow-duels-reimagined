local _,ns=...
-- Compatibility only: a peer's advertised build is not file attestation.
local P={}
ns.CompetitiveIntegrity=P
local REV,RULE="1","elo-trial-2"
local function Client(v) return v=="forever" or v=="retail" end
local function Digest(v) return type(v)=="string" and #v==64 and v:match("^[0-9a-f]+$")~=nil end
local function Build()
    local m=ns.CompetitiveManifest
    if type(m)=="table" and m.version==1 and Digest(m.fingerprint) then return m.fingerprint end
end
function P.Descriptor(client)
    local build=Build()
    if Client(client) and build then return table.concat({REV,client,RULE,build},"|") end
end
function P.CompareSimulated(client,body)
    local function Result(state)
        return {scope="SIMULATED",state=state,compatible=state=="compatible",rankEligible=false,originVerified=false}
    end
    local build=Build()
    if not Client(client) or not build then return Result("unavailable") end
    if body==nil then return Result("unknown") end
    if type(body)~="string" or #body>120 or body:find("%c") then return Result("invalid") end
    local rev,k,rule,fp=body:match("^(%d+)|(%a+)|([%w%-]+)|([0-9a-f]+)$")
    if not rev or not Client(k) or not Digest(fp) then return Result("invalid") end
    if k~=client then return Result("client_mismatch") end
    if rev~=REV or rule~=RULE then return Result("rule_mismatch") end
    if fp~=build then return Result("build_mismatch") end
    return Result("compatible")
end
function P.GetSnapshot()
    return {scope="LOCAL",state="disabled",rankEligible=false,originVerified=false,build=Build(),rule=RULE}
end
function P.GetDiagnosticResources() return {pending=0,subscriptions=0,timers=0} end
function P.RunSelfTest(emit)
    emit=type(emit)=="function" and emit or function() end
    local pass,fail=0,0
    local function Case(label,fn)
        local ok,err=pcall(fn)
        if ok then pass=pass+1 else fail=fail+1 end
        emit("DR | SIMULATED | "..(ok and "PASS " or "FAIL ")..label..(ok and "" or ": "..tostring(err)))
    end
    for _,client in ipairs({"forever","retail"}) do
        local function Check(body,state)
            local s=P.CompareSimulated(client,body)
            assert(s.state==state and s.compatible==(state=="compatible") and not s.rankEligible and not s.originVerified)
        end
        Case(client.." matching build compatible not authenticated",function() Check(assert(P.Descriptor(client)),"compatible") end)
        Case(client.." mismatched build",function()
            local d=assert(P.Descriptor(client));local last=d:sub(-1);Check(d:sub(1,-2)..(last=="0" and "1" or "0"),"build_mismatch")
        end)
        Case(client.." incompatible rule and revision",function()
            local d=assert(P.Descriptor(client));Check((d:gsub("elo%-trial%-2","elo-trial-1")),"rule_mismatch");Check((d:gsub("^1|","2|")),"rule_mismatch")
        end)
        Case(client.." separate client",function() Check(P.Descriptor(client=="forever" and "retail" or "forever"),"client_mismatch") end)
        Case(client.." no reply and malformed data",function()
            Check(nil,"unknown");Check({},"invalid");Check("1|"..client.."|"..RULE.."|bad","invalid");Check(P.Descriptor(client).."\n","invalid");Check(string.rep("a",121),"invalid")
        end)
        Case(client.." snapshots isolated",function() local s=P.CompareSimulated(client,P.Descriptor(client));s.rankEligible=true;Check(P.Descriptor(client),"compatible") end)
    end
    Case("unsupported client and live gate",function()
        assert(not P.Descriptor("unknown") and P.CompareSimulated("unknown",nil).state=="unavailable")
        local s=P.GetSnapshot();assert(s.scope=="LOCAL" and s.state=="disabled" and not s.rankEligible and not s.originVerified and Digest(s.build))
    end)
    return pass,fail
end
