local _,ns=...
-- Shared competitive compatibility and read-only peer review. No file attestation.
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
-- Explicit fixture calendar. Revision 1 remains a reproducible legacy policy.
function P.SeasonDescriptor(client,epoch)
    local build=Build();local policy=ns.SeasonRules
    if Client(client) and build and policy and policy.Schedule(epoch,epoch) then
        return table.concat({"2",client,policy.BALANCED_ID,tostring(epoch),build},"|")
    end
end
function P.ScopedSeasonDescriptor(client,epoch,population)
    local base=P.SeasonDescriptor(client,epoch)
    local code=ns.CompetitiveScope and ns.CompetitiveScope.Code(population,client)
    if base and code then return base.."|"..code end
end
function P.CompareSeasonSimulated(client,epoch,body)
    local function Result(state)
        return {scope="SIMULATED",state=state,compatible=state=="compatible",rankEligible=false,originVerified=false}
    end
    local expected=P.SeasonDescriptor(client,epoch)
    if not expected then return Result("unavailable") end
    if body==nil then return Result("unknown") end
    if type(body)~="string" or #body>120 or body:find("%c") then return Result("invalid") end
    local rev,k,rule,start,fp=body:match("^(%d+)|(%a+)|([%w%-]+)|(%d+)|([0-9a-f]+)$")
    if not rev or not Client(k) or not Digest(fp) or tostring(tonumber(start))~=start
        or not ns.SeasonRules.Schedule(tonumber(start),tonumber(start)) then return Result("invalid") end
    if k~=client then return Result("client_mismatch") end
    if rev~="2" or rule~=ns.SeasonRules.BALANCED_ID then return Result("rule_mismatch") end
    if tonumber(start)~=epoch then return Result("schedule_mismatch") end
    if body~=expected then return Result("build_mismatch") end
    return Result("compatible")
end
function P.GetSnapshot()
    return {scope="LOCAL",state="disabled",rankEligible=false,originVerified=false,build=Build(),rule=RULE}
end
function P.GetDiagnosticResources() return {pending=0,subscriptions=0,timers=0} end

-- A review compares receipts from the existing sender-bound sync session.
-- It never trusts a majority, treats silence as evidence, or changes records.
-- Receipt lifetime is one local evidence generation and at most ten minutes.
local REVIEW_LIMIT,REVIEW_TTL=32,600
local function FiniteNonnegative(v)
    -- Reject secret or nonnumeric inputs before arithmetic or formatting.
    if type(issecretvalue)=="function" then
        local ok,secret=pcall(issecretvalue,v)
        if not ok or secret then return false end
    end
    if type(v)~="number" then return false end
    -- WoW has native numeric predicates; ordinary Lua may not. Comparisons
    -- alone are not sufficient for NaN on optimized client runtimes.
    if type(math.isfinite)=="function" and not math.isfinite(v) then return false end
    if type(math.isnan)=="function" and math.isnan(v) then return false end
    -- A finite nonnegative number has a decimal/scientific representation.
    -- Reject NaN/Inf spellings, including platform-specific variants.
    local repr=tostring(v)
    if not (repr:match("^%-?%d+%.?%d*$") or repr:match("^%-?%d+%.?%d*[eE][+-]?%d+$")) then return false end
    return v>=0 and v<math.huge
end
local function Counter(v)
    return FiniteNonnegative(v) and v<=9007199254740991 and v==math.floor(v)
end
local function Clock(v) return FiniteNonnegative(v) end
local function ReviewPeer(v)
    return type(v)=="string" and #v<=64 and v:match("^Player%-%w[%w%-]*$")~=nil
end
function P.NewReview(client,domain,context,scope)
    if not Client(client) or (domain~="ranked" and domain~="tournament")
        or type(context)~="string" or #context<1 or #context>120 or context:find("[%c|]")
        or (scope~="SIMULATED" and scope~="PEER") then return nil,"context" end
    local receipts,count={},0
    local D={}
    function D.Observe(s,now)
        -- Only call with a locally produced terminal status from an already
        -- validated exchange; this is NOT a validator of raw peer packets.
        if type(s)~="table" or s.client~=client or s.domain~=domain or s.context~=context
            or s.scope~=scope or s.mode~="delta" or s.completeness~="unknown"
            or s.rankEligible~=false or not ReviewPeer(s.peer) or not Counter(s.comparedRevision)
            or not Clock(now) or (s.state~="summary_agrees" and s.state~="differences_remaining") then
            return false,"invalid_receipt"
        end
        local old=receipts[s.peer]
        if old and (now<old.at or s.comparedRevision<old.revision) then return false,"stale_receipt" end
        if not old and count>=REVIEW_LIMIT then
            local key,at
            for id,r in pairs(receipts) do
                if not at or r.at<at or (r.at==at and id<key) then key,at=id,r.at end
            end
            receipts[key]=nil;count=count-1
        end
        if not old then count=count+1 end
        receipts[s.peer]={state=s.state,revision=s.comparedRevision,at=now}
        return true
    end
    function D.Snapshot(revision,now)
        local out={scope=scope,client=client,domain=domain,state="unconfirmed",
            matching=0,different=0,stale=0,retained=count,completeness="unknown",
            originVerified=false,rankEligible=false,cheatingProven=false}
        if not Counter(revision) or not Clock(now) then return out end
        for _,r in pairs(receipts) do
            if r.revision~=revision or now<r.at or now-r.at>REVIEW_TTL then out.stale=out.stale+1
            elseif r.state=="summary_agrees" then out.matching=out.matching+1
            else out.different=out.different+1 end
        end
        if out.different>0 then out.state="differences_detected"
        elseif out.matching>0 then out.state="summaries_agree" end
        return out
    end
    return D
end
function P.RunReviewSelfTest(emit)
    emit=type(emit)=="function" and emit or function() end
    local pass,fail=0,0
    local function Case(label,fn)
        local ok,err=pcall(fn);if ok then pass=pass+1 else fail=fail+1 end
        emit("DR | SIMULATED | "..(ok and "PASS " or "FAIL ")..label..(ok and "" or ": "..tostring(err)))
    end
    for _,client in ipairs({"forever","retail"}) do
        local other=client=="retail" and "forever" or "retail"
        local function Review(domain,context) return assert(P.NewReview(client,domain or "ranked",context or "1000","SIMULATED")) end
        local function Receipt(i,state,revision)
            return {client=client,domain="ranked",context="1000",scope="SIMULATED",mode="delta",
                peer="Player-1-"..i,state=state,comparedRevision=revision or 4,completeness="unknown",rankEligible=false}
        end
        Case(client.." ten matching copies and one difference are not proof",function()
            local d=Review()
            for i=1,10 do assert(d.Observe(Receipt(i,"summary_agrees"),i)) end
            assert(d.Observe(Receipt(11,"differences_remaining"),11))
            local s=d.Snapshot(4,12)
            assert(s.matching==10 and s.different==1 and s.state=="differences_detected")
            assert(not s.cheatingProven and not s.originVerified and not s.rankEligible and s.completeness=="unknown")
        end)
        Case(client.." repeat peer is one receipt; matching after recovery replaces difference",function()
            local d=Review();assert(d.Observe(Receipt(1,"differences_remaining"),1))
            for i=2,10 do assert(d.Observe(Receipt(1,"summary_agrees"),i)) end
            local s=d.Snapshot(4,10);assert(s.matching==1 and s.retained==1 and s.different==0)
            assert(not d.Observe(Receipt(1,"differences_remaining",3),11))
            assert(not d.Observe(Receipt(1,"differences_remaining"),9))
        end)
        Case(client.." stale revision and expired receipts never count",function()
            local d=Review();assert(d.Observe(Receipt(1,"summary_agrees"),5))
            assert(d.Snapshot(5,6).state=="unconfirmed" and d.Snapshot(5,6).stale==1)
            assert(d.Snapshot(4,606).state=="unconfirmed" and d.Snapshot(4,605).matching==1)
            assert(d.Snapshot(4,4).matching==0)
        end)
        Case(client.." malformed or interrupted exchange is not evidence",function()
            local d=Review()
            for _,state in ipairs({"working","cancelled","retry_exhausted","audit_received"}) do
                assert(not d.Observe(Receipt(1,state),1))
            end
            local s=Receipt(1,"summary_agrees");s.peer="bad";assert(not d.Observe(s,1))
            local zero=0
            local invalidNumbers={0/0, zero/zero, -(zero/zero), math.huge, -math.huge, -1, "4", false, {}}
            for index,v in ipairs(invalidNumbers) do
                s=Receipt(1,"summary_agrees");s.comparedRevision=v
                assert(not d.Observe(s,1),"invalid revision "..index.." ("..tostring(v)..")")
                assert(not d.Observe(Receipt(1,"summary_agrees"),v),"invalid clock "..index.." ("..tostring(v)..")")
                assert(d.Snapshot(v,1).matching==0 and d.Snapshot(4,v).matching==0)
            end
            for _,v in ipairs({0.5,9007199254740992}) do
                s=Receipt(1,"summary_agrees");s.comparedRevision=v
                assert(not d.Observe(s,1),"fractional or oversized revision")
            end
            s=Receipt(1,"summary_agrees");s.comparedRevision=nil;assert(not d.Observe(s,1))
            assert(not d.Observe(Receipt(1,"summary_agrees"),nil))
            s=Receipt(1,"summary_agrees");s.rankEligible=true;assert(not d.Observe(s,1))
            assert(d.Snapshot(4,1).retained==0)
            assert(d.Observe(Receipt(1,"summary_agrees",0),0))
            assert(d.Snapshot(0,0).matching==1)
            for _,v in ipairs(invalidNumbers) do
                assert(d.Snapshot(v,0).matching==0 and d.Snapshot(0,v).matching==0)
            end
            assert(d.Observe(Receipt(1,"summary_agrees",9007199254740991),1.25))
            assert(d.Snapshot(9007199254740991,1.25).matching==1)
        end)
        Case(client.." client, domain, context and simulation isolation",function()
            local d=Review();local s=Receipt(1,"summary_agrees")
            s.client=other;assert(not d.Observe(s,1));s.client=client
            s.domain="tournament";assert(not d.Observe(s,1))
            local t=Review("tournament","event-1")
            s.context="event-1";assert(t.Observe(s,1));assert(t.Snapshot(4,1).matching==1)
            assert(not Review("tournament","event-2").Observe(s,1))
            s.scope="PEER";assert(not t.Observe(s,1))
            assert(d.Snapshot(4,1).retained==0)
        end)
        Case(client.." bounded peer receipts and detached snapshots",function()
            local d=Review()
            for i=1,40 do assert(d.Observe(Receipt(i,"summary_agrees"),i)) end
            local s=d.Snapshot(4,40);assert(s.retained==32 and s.matching==32)
            s.matching=99;assert(d.Snapshot(4,40).matching==32)
        end)
    end
    Case("review is opt-in memory only and live compatibility gate unchanged",function()
        assert(not P.NewReview("unsupported","ranked","1000","SIMULATED"))
        assert(not P.NewReview("retail","ranked","","SIMULATED"))
        assert(not P.NewReview("retail","unknown","1000","SIMULATED"))
        local s=P.GetSnapshot();assert(s.state=="disabled" and not s.originVerified)
    end)
    return pass,fail
end

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
