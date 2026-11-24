local _,ns=...
-- Simulated wire codec and request lifecycle. Never calls Communication.Send.
local P={}
ns.SyncProtocol=P
local CHUNK,MAX_PARTS,MAX_BODY,TTL,GAP=160,128,237,120,0.5
local MAX_PAGE=ns.LeaderboardSync.GetPageLimit()
local function Client(v) return v=='forever' or v=='retail' end
local function Guid(v) return type(v)=='string' and #v<=64 and v:match('^Player%-%w[%w%-]*$')~=nil end
local function Token(v) return type(v)=='string' and #v<=32 and v:match('^[%w%-]+$')~=nil end
local function Integer(v,max)
    local n=tonumber(v);if n and n>=1 and n<=max and n==math.floor(n) and tostring(n)==v then return n end
end
local function Time(v) return type(v)=='number' and v>=0 and v<math.huge end
local function Safe(v) return type(v)=='string' and #v<=MAX_BODY and not v:find('%c') end
local function Split(s,sep)
    local out={};local pos=1
    while true do local i=s:find(sep,pos,true);if not i then out[#out+1]=s:sub(pos);return out end
        out[#out+1]=s:sub(pos,i-1);pos=i+1 end
end
local function Record(a,b,client)
    local rev,k,session,x,y,out=a:match('^(%d+)|(%a+)|([^|]+)|([^|]+)|([^|]+)|(%a+)|%d+$')
    if rev~='1' or k~=client or not Guid(x) or not Guid(y) or x>=y or (out~='won' and out~='lost') then return nil end
    local r={scope='SIMULATED',version='1',client=k,session=session,id=k..'|'..x..'|'..y..'|'..session,
        player1=x,player2=y,winner=out=='won' and x or y,loser=out=='won' and y or x,endType='knockout',
        rankEligible=false,statement1=a,statement2=b}
    return ns.ResultConfirmation.ValidateSimulatedRecord(r)
end
local function Encode(page)
    local rows={}
    for _,e in ipairs(page.entries) do
        local fields={};for _,r in ipairs(e.records) do fields[#fields+1]=r.statement1;fields[#fields+1]=r.statement2 end
        local clocks={};for _,c in ipairs(e.clocks or {}) do clocks[#clocks+1]=c[1]..','..c[2] end
        rows[#rows+1]=table.concat(fields,';')..'~'..table.concat(clocks,';')
    end
    return #rows==0 and '-' or table.concat(rows,'/')
end
local function Decode(body,client,token,page,total)
    local p={version=1,scope='SIMULATED',client=client,rule='elo-trial-2',token=token,index=page,total=total,entries={}}
    if body=='-' then return p end
    local rows=Split(body,'/');if #rows>16 then return nil end
    for _,row in ipairs(rows) do
        local f=Split(row,'~');if #f~=2 then return nil end
        local s=Split(f[1],';');if #s~=2 and #s~=4 then return nil end
        local records={};for i=1,#s,2 do local r=Record(s[i],s[i+1],client);if not r then return nil end;records[#records+1]=r end
        local clocks
        if f[2]~='' then
            clocks={};local cs=Split(f[2],';');if #cs>2 then return nil end
            for _,v in ipairs(cs) do local a,b=v:match('^(%d+),(%d+)$');a=Integer(a,4102444800);b=Integer(b,4102444800)
                if not a or not b then return nil end;clocks[#clocks+1]={a,b} end
        end
        p.entries[#p.entries+1]={id=records[1].id,records=records,clocks=clocks}
    end
    if Encode(p)~=body then return nil end
    return p -- existing merge owner validates entire page before mutation
end
-- Revision 2 binds the request and the assembled response to the same
-- immutable fixture calendar and advertised build. No extra live transport.
local function Context(client,node)
    local epoch=node.GetSeasonEpoch()
    if epoch==nil then return '1','' end
    local descriptor=ns.CompetitiveIntegrity.SeasonDescriptor(client,epoch)
    if descriptor then return '2','|'..descriptor end
end
-- The same request/fragment lifecycle carries summary and group pages.
-- Summary has exactly one logical page, independent of its packet count.
local function EncodeSummary(summary)
    local rows={}
    for _,g in ipairs(summary.groups) do rows[#rows+1]=table.concat({g.count,g.a,g.b},',') end
    return table.concat(rows,';')
end
local function DecodeSummary(payload,context)
    local rows=Split(payload,';')
    if #rows~=ns.LeaderboardSync.GetGroupCount() then return nil end
    local summary={version=1,scope='SIMULATED',context=context:sub(2),groups={}}
    for i,row in ipairs(rows) do
        local c,a,b=row:match('^(%d+),(%d+),(%d+)$')
        c,a,b=tonumber(c),tonumber(a),tonumber(b)
        if not c or not a or not b then return nil end
        summary.groups[i]={count=c,a=a,b=b}
    end
    if EncodeSummary(summary)~=payload then return nil end
    return summary -- PlanDelta checks bounds and canonical shape.
end
local function DecodeSpec(spec)
    local g,c,a,b=spec:match('^(%d+),(%d+),(%d+),(%d+)$')
    g,c,a,b=tonumber(g),tonumber(c),tonumber(a),tonumber(b)
    local expected={count=c,a=a,b=b}
    if ns.LeaderboardSync.DeltaGroupSpec(g,expected)~=spec then return nil end
    return g,expected
end
local function ParseRequest(body,client,rev,context)
    if not Safe(body) then return nil end
    if rev=='2' then
        if body:sub(-#context)~=context then return nil end
        body=body:sub(1,#body-#context)
    end
    local k,t,p,suffix=body:match('^Q|'..rev..'|(%a+)|([%w%-]+)|(%d+)(.*)$')
    if k~=client or not Token(t) then return nil end
    p=Integer(p,MAX_PAGE);if not p then return nil end
    if suffix=='' then return t,p,'page' end
    if rev~='2' then return nil end
    if suffix=='|S' and p==1 then return t,p,'summary' end
    if suffix=='|A' and p==1 then return t,p,'audit_start' end
    local session,generation=suffix:match('^|A|([%w%-]+)|(%d+)$')
    generation=Integer(generation,2147483647)
    if Token(session) and generation then return t,p,'audit',session,generation end
    local spec=suffix:match('^|D|(.+)$')
    if spec then
        local group,expected=DecodeSpec(spec)
        if group then return t,p,'delta',group,expected,spec end
    end
end
local function Frames(node,client,body,rev,context,audit,sender,now)
    local token,index,mode,group,expected,spec=ParseRequest(body,client,rev,context)
    if not token then return nil,'request' end
    local data,total,nextAudit
    if mode=='audit_start' or mode=='audit' then
        local generation=node.GetEvidenceRevision()
        if not Integer(tostring(generation),2147483647) then return nil,'capacity' end
        local session=token
        if mode=='audit' then
            session=group
            if not audit or audit.peer~=sender or audit.session~=session or audit.generation~=expected
                or generation~=expected or now>=audit.deadline then return nil,'stale_audit' end
        end
        local page,why=node.ExportPage(token,index)
        if not page then return nil,why end
        if mode=='audit' and page.total~=audit.total then return nil,'stale_audit' end
        total=page.total
        data=context..'|A|'..session..'|'..generation..'|'..Encode(page)
        nextAudit={peer=sender,session=session,generation=generation,total=total,deadline=now+TTL+60}
    elseif mode=='summary' then
        local summary=node.DeltaSummary();if not summary then return nil,'summary' end
        data=context..'|S|'..EncodeSummary(summary);total=1
    else
        local page,why
        if mode=='delta' then page,why=node.ExportDeltaPage(token,group,expected,index)
        else page,why=node.ExportPage(token,index) end
        if not page then return nil,why or 'page' end
        total=page.total;data=Encode(page)
        if rev=='2' then
            data=context..'|'..(mode=='delta' and ('D|'..spec..'|') or '')..data
        end
    end
    local count=math.ceil(#data/CHUNK)
    if count>MAX_PARTS then return nil,'capacity' end
    local out={};for i=1,count do
        local msg=table.concat({'R',rev,client,token,index,total,i,count,data:sub((i-1)*CHUNK+1,i*CHUNK)},'|')
        if not Safe(msg) then return nil,'capacity' end;out[i]=msg
    end
    return out,nil,nextAudit
end
-- One outstanding request per fixture; prefix must be unique per simulated run.
function P.NewRequester(client,node,prefix)
    if not Client(client) or not Token(prefix) or #prefix>20 then return nil end
    local rev,context=Context(client,node);if not rev then return nil end
    local D,seq,pending={},0,nil
    function D.Status(now)
        if pending and Time(now) and now>=pending.deadline then pending=nil;return 'expired' end
        return pending and 'waiting' or 'idle'
    end
    function D.Cancel() pending=nil end
    local function Begin(peer,page,now,mode,group,expected,spec,auditTotal)
        if not Time(now) or not Guid(peer) or type(page)~='number' or not Integer(tostring(page),MAX_PAGE) then return nil,'invalid' end
        if D.Status(now)=='waiting' then return nil,'busy' end
        if seq>=2147483647 then return nil,'capacity' end
        seq=seq+1;local token=prefix..'-'..seq
        local suffix=mode=='summary' and '|S' or mode=='delta' and ('|D|'..spec)
            or mode=='audit_start' and '|A' or mode=='audit' and ('|A|'..spec) or ''
        local body='Q|'..rev..'|'..client..'|'..token..'|'..page..suffix..context
        if not Safe(body) then return nil,'capacity' end
        pending={peer=peer,page=page,token=token,deadline=now+TTL,last=now,parts={},received=0,
            mode=mode,group=group,expected=expected,spec=spec,auditTotal=auditTotal}
        return body
    end
    function D.Begin(peer,page,now) return Begin(peer,page,now,'page') end
    function D.BeginSummary(peer,now)
        if rev~='2' then return nil,'season_context_required' end
        return Begin(peer,1,now,'summary')
    end
    function D.BeginDelta(peer,group,expected,page,now)
        if rev~='2' then return nil,'season_context_required' end
        local spec=ns.LeaderboardSync.DeltaGroupSpec(group,expected)
        if not spec then return nil,'invalid_group' end
        local g,info=DecodeSpec(spec)
        if type(page)~='number' or page>math.ceil(info.count/16) then return nil,'page' end
        return Begin(peer,page,now,'delta',g,info,spec)
    end
    function D.BeginAudit(peer,now)
        if rev~='2' then return nil,'season_context_required' end
        return Begin(peer,1,now,'audit_start')
    end
    function D.BeginAuditPage(peer,audit,page,now)
        if rev~='2' or type(audit)~='table' or audit.scope~='SIMULATED' or audit.peer~=peer
            or audit.context~=context or not Token(audit.session) or type(audit.generation)~='number'
            or not Integer(tostring(audit.generation),2147483647) or type(audit.total)~='number'
            or not Integer(tostring(audit.total),MAX_PAGE) or type(page)~='number' or page>audit.total then
            return nil,'invalid_audit'
        end
        return Begin(peer,page,now,'audit',audit.session,audit.generation,
            audit.session..'|'..audit.generation,audit.total)
    end
    function D.Receive(body,sender,now)
        if not Time(now) or D.Status(now)~='waiting' then return false,'no_request' end
        local q=pending
        if now<q.last or sender~=q.peer or not Safe(body) then return false,'sender_or_packet' end
        local k,t,p,total,i,n,data=body:match('^R|'..rev..'|(%a+)|([%w%-]+)|(%d+)|(%d+)|(%d+)|(%d+)|(.+)$')
        p=Integer(p,MAX_PAGE);total=Integer(total,MAX_PAGE);i=Integer(i,MAX_PARTS);n=Integer(n,MAX_PARTS)
        if k~=client or t~=q.token or p~=q.page or not total or p>total or not i or not n or i>n
            or #data>CHUNK or (i<n and #data~=CHUNK) then return false,'packet' end
        if q.count and (q.count~=n or q.total~=total) then pending=nil;return false,'conflict' end
        q.count=n;q.total=total;q.last=now
        if q.parts[i] then
            if q.parts[i]~=data then pending=nil;return false,'conflict' end
            return true,'duplicate'
        end
        q.parts[i]=data;q.received=q.received+1
        if q.received<n then return true,'partial' end
        pending=nil
        local payload=table.concat(q.parts)
        if rev=='2' then
            local header=context..'|'
            if payload:sub(1,#header)~=header then return false,'season_context' end
            payload=payload:sub(#header+1)
        end
        if q.mode=='summary' then
            if total~=1 or payload:sub(1,2)~='S|' then return false,'summary_context' end
            local summary=DecodeSummary(payload:sub(3),context)
            if not summary then return false,'summary_decode' end
            local plan,why=node.PlanDelta(summary)
            if not plan then return false,why end
            return true,'summary_complete',plan
        end
        local auditResult
        if q.mode=='audit_start' or q.mode=='audit' then
            local session,generation,rest=payload:match('^A|([%w%-]+)|(%d+)|(.+)$')
            generation=Integer(generation,2147483647)
            if not generation or not Token(session) then return false,'audit_context' end
            if q.mode=='audit_start' then
                if session~=q.token then return false,'audit_context' end
            elseif session~=q.group or generation~=q.expected or total~=q.auditTotal then
                return false,'audit_context'
            end
            auditResult={scope='SIMULATED',peer=q.peer,context=context,session=session,
                generation=generation,total=total,index=q.page}
            payload=rest
        end
        if q.mode=='delta' then
            local header='D|'..q.spec..'|'
            if payload:sub(1,#header)~=header then return false,'delta_context' end
            payload=payload:sub(#header+1)
        end
        local page=Decode(payload,client,q.token,q.page,total)
        if not page then return false,'decode' end
        if q.mode=='delta' and not ns.LeaderboardSync.ValidateDeltaPage(q.group,q.expected,page) then
            return false,'delta_page'
        end
        local ok,why=node.Receive(page,sender,q.peer,q.token)
        if not ok then return false,why end
        if auditResult then return true,'audit_page_complete',auditResult end
        return true,'page_complete',total -- NOT global completeness
    end
    return D
end
-- One bounded frozen response; caller injects recognized peer identity and time.
-- Pull-based pacing only, no background timers, no game API.
function P.NewResponder(client,node)
    if not Client(client) then return nil end
    local rev,context=Context(client,node);if not rev then return nil end
    local D,stream,lastStart,audit={},nil,nil,nil
    function D.Cancel() stream=nil;audit=nil end
    function D.Begin(body,sender,expected,now)
        if not Time(now) or not Guid(sender) or sender~=expected then return false,'sender' end
        if stream and now>=stream.deadline then stream=nil end
        if stream or (lastStart and now-lastStart<2) then return false,'busy' end
        local frames,why,nextAudit=Frames(node,client,body,rev,context,audit,sender,now)
        if not frames then return false,why end
        audit=nextAudit
        stream={frames=frames,next=1,at=now,deadline=now+TTL,peer=sender};lastStart=now;return true
    end
    function D.Next(now)
        if not stream or not Time(now) then return nil,'idle' end
        if now>=stream.deadline then stream=nil;return nil,'expired' end
        if now<stream.at then return nil,'paced' end
        local s=stream;local body=s.frames[s.next];s.next=s.next+1;s.at=now+GAP
        if s.next>#s.frames then stream=nil end
        return body,s.peer
    end
    return D
end
-- One explicit, caller-driven catch-up session. No send API, timer or
-- automatic peer selection. Retain valid merged pages on retry/cancel.
function P.NewCatchupSimulated(client,node,prefix,peer,mode)
    if not Guid(peer) or (mode~='delta' and mode~='audit') or not node.GetSeasonEpoch() then return nil end
    local q=P.NewRequester(client,node,prefix);if not q then return nil end
    local D={}
    local state='working'
    local task=mode=='delta' and 'summary' or 'audit_start'
    local requests,restarts,rounds,pages=0,0,0,0
    local plan,groupIndex,pageIndex,audit
    local last,due=0,0
    local function Restart(now)
        q.Cancel();restarts=restarts+1
        if restarts>2 then state='retry_exhausted';return end
        task=mode=='delta' and 'summary' or 'audit_start'
        plan,groupIndex,pageIndex,audit=nil,nil,nil,nil
        due=now+2
    end
    function D.GetStatus()
        return {scope='SIMULATED',state=state,mode=mode,requests=requests,restarts=restarts,
            rounds=rounds,pages=pages,completeness='unknown',rankEligible=false}
    end
    function D.Cancel() q.Cancel();state='cancelled';plan=nil;audit=nil end
    function D.Poll(now)
        if not Time(now) or now<last then return nil,'clock' end
        last=now
        if state~='working' then return nil,state end
        local status=q.Status(now)
        if status=='waiting' then return nil,'waiting' end
        if status=='expired' then Restart(now);return nil,state=='working' and 'backoff' or state end
        if now<due then return nil,'backoff' end
        if requests>=2048 then state='request_limit';return nil,state end
        local body,why
        if task=='summary' then
            local ready=node.PrepareDelta(32)
            if not ready then return nil,'preparing' end
            body,why=q.BeginSummary(peer,now)
        elseif task=='delta' then
            local g=plan.pulls[groupIndex]
            body,why=q.BeginDelta(peer,g.group,g.expected,pageIndex,now)
        elseif task=='audit_start' then body,why=q.BeginAudit(peer,now)
        else body,why=q.BeginAuditPage(peer,audit,pageIndex,now) end
        if not body then state='request_rejected';return nil,why end
        requests=requests+1
        return body,'request'
    end
    function D.Receive(body,sender,now)
        if state~='working' or not Time(now) or now<last then return false,'inactive_or_clock' end
        last=now
        -- Check expiry before delegation so a late fragment cannot lose the
        -- timeout signal and bypass the session retry budget.
        if q.Status(now)=='expired' then Restart(now);return false,'expired' end
        local ok,why,value=q.Receive(body,sender,now)
        if not ok then
            if q.Status(now)=='idle' and (why~='no_request') then Restart(now) end
            return false,why
        end
        if why=='summary_complete' then
            if value.different==0 then state='summary_agrees'
            elseif #value.pulls==0 or rounds>=3 then state='differences_remaining'
            else
                rounds=rounds+1;plan=value;groupIndex=1;pageIndex=1;task='delta'
            end
            due=now+2
        elseif why=='page_complete' then
            pages=pages+1;pageIndex=pageIndex+1
            if pageIndex>plan.pulls[groupIndex].pages then
                groupIndex=groupIndex+1;pageIndex=1
            end
            if groupIndex>#plan.pulls then task='summary';plan=nil end
            due=now+2
        elseif why=='audit_page_complete' then
            pages=pages+1;audit=value;pageIndex=value.index+1
            if pageIndex>value.total then state='audit_received';audit=nil
            else task='audit' end
            due=now+2
        end
        return true,why
    end
    return D
end
function P.GetSnapshot() return {scope='LOCAL',state='disabled',rankEligible=false,version=1} end
function P.GetDiagnosticResources() return {pending=0,subscriptions=0,timers=0} end
function P.RunSelfTest(emit)
    emit=type(emit)=='function' and emit or function()end
    local pass,fail=0,0
    local function Case(label,fn)
        local ok,err=pcall(fn);if ok then pass=pass+1 else fail=fail+1 end
        emit('DR | SIMULATED | '..(ok and 'PASS ' or 'FAIL ')..label..(ok and '' or ': '..tostring(err)))
    end
    local a,b='Player-1-AAA','Player-2-BBB'
    for _,client in ipairs({'forever','retail'}) do
        local function R(i,reverse)
            local s='a-'..i..':b-'..i;local w,l=reverse and b or a,reverse and a or b
            return {scope='SIMULATED',version='1',client=client,session=s,id=client..'|'..a..'|'..b..'|'..s,
                player1=a,player2=b,winner=w,loser=l,endType='knockout',rankEligible=false,
                statement1=table.concat({'1',client,s,a,b,reverse and 'lost' or 'won','1'},'|'),
                statement2=table.concat({'1',client,s,b,a,reverse and 'won' or 'lost','2'},'|')}
        end
        local function Fixture(n)
            local x,y=assert(ns.LeaderboardSync.OpenSimulated(client)),assert(ns.LeaderboardSync.OpenSimulated(client))
            for i=1,n do assert(x.Observe(R(i),i,i))end
            return x,y,P.NewRequester(client,y,'run'),P.NewResponder(client,x)
        end
        local function Request(q,r,page,at)
            local msg=assert(q.Begin(a,page,at));assert(r.Begin(msg,b,b,at));return msg
        end
        local function Drain(r,at)
            local frames={};while true do local m,peer=r.Next(at);if not m then break end;assert(peer==b and #m+3<=240);frames[#frames+1]=m;at=at+GAP end;return frames
        end
        local function Deliver(q,frames,at)
            local ok,why,total;for _,m in ipairs(frames)do ok,why,total=q.Receive(m,a,at);assert(ok,why)end;assert(why=='page_complete');return total
        end
        Case(client..' bounded packet roundtrip and ratings',function()
            local x,y,q,r=Fixture(16);Request(q,r,1,0);local f=Drain(r,0);assert(#f>1);assert(Deliver(q,f,40)==1)
            assert(y.Replay().matched==16 and y.Replay().players[a].rating==x.Replay().players[a].rating)
        end)
        Case(client..' reverse delivery and duplicates',function()
            local _,y,q,r=Fixture(16);Request(q,r,1,0);local f=Drain(r,0)
            for i=#f,1,-1 do assert(q.Receive(f[i],a,40));if i>1 then local ok,why=q.Receive(f[i],a,40);assert(ok and why=='duplicate')end end
            assert(y.Replay().matched==16 and not q.Receive(f[1],a,41))
        end)
        Case(client..' partial timeout and fresh retry',function()
            local _,y,q,r=Fixture(16);Request(q,r,1,0);local f=Drain(r,0);assert(q.Receive(f[1],a,40));assert(y.Replay().matched==0)
            assert(q.Status(120)=='expired');Request(q,r,1,121);assert(not q.Receive(f[2],a,122));Deliver(q,Drain(r,121),161);assert(y.Replay().matched==16)
        end)
        Case(client..' wrong peer or version cannot merge',function()
            local _,y,q,r=Fixture(1);Request(q,r,1,0);local f=Drain(r,0)
            assert(not q.Receive(f[1],b,1) and not q.Receive(f[1]:gsub('^R|1|','R|2|'),a,1));assert(y.Replay().matched==0);Deliver(q,f,2)
        end)
        Case(client..' conflicting duplicate aborts without mutation',function()
            local _,y,q,r=Fixture(16);Request(q,r,1,0);local f=Drain(r,0);assert(q.Receive(f[1],a,40));local m=f[1]:sub(1,-2)..(f[1]:sub(-1)=='X' and 'Y' or 'X')
            assert(not q.Receive(m,a,40) and q.Status(40)=='idle' and y.Replay().matched==0)
        end)
        Case(client..' two pages require explicit requests',function()
            local _,y,q,r=Fixture(17);Request(q,r,2,0);assert(Deliver(q,Drain(r,0),20)==2);assert(y.Replay().matched==1)
            Request(q,r,1,30);Deliver(q,Drain(r,30),70);assert(y.Replay().matched==17 and y.Replay().completeness=='unknown')
        end)
        Case(client..' outcome and clock disputes survive wire',function()
            local x,y,q,r=Fixture(2);assert(x.Observe(R(1,true),1,1));assert(x.Observe(R(2),3,3));Request(q,r,1,0);Deliver(q,Drain(r,0),10)
            local s=y.Replay();assert(s.disputed==1 and s.timeDisputed==1 and s.matched==0)
        end)
        Case(client..' malformed page atomic rejection',function()
            local _,y,q,r=Fixture(1);Request(q,r,1,0);local f=Drain(r,0);f[#f]=f[#f]:sub(1,-2)..'!';local ok
            for _,m in ipairs(f) do ok=q.Receive(m,a,5)end;assert(not ok and y.Replay().matched==0)
        end)
        Case(client..' pacing busy cancel and frozen response',function()
            local x,y,q,r=Fixture(16);local m=Request(q,r,1,0);assert(not r.Begin(m,b,b,0) and not q.Begin(a,1,0));local first=assert(r.Next(0));assert(not r.Next(0.1));assert(x.Observe(R(17),17,17))
            local f=Drain(r,0.5);table.insert(f,1,first);Deliver(q,f,40);assert(y.Replay().matched==16);q.Cancel();r.Cancel();assert(not r.Next(50))
        end)
        Case(client..' invalid size request sender and expiry',function()
            local _,y,q,r=Fixture(16);local m=assert(q.Begin(a,1,0));assert(not r.Begin(m,b,a,0));assert(not r.Begin(m..string.rep('X',240),b,b,0));assert(r.Begin(m,b,b,0));assert(not r.Next(120));assert(not q.Receive(string.rep('X',238),a,1));assert(y.Replay().matched==0)
        end)
        Case(client..' empty page no invented standings',function()
            local _,y,q,r=Fixture(0);Request(q,r,1,0);Deliver(q,Drain(r,0),1);assert(#y.Replay().standings==0 and not y.Replay().rankEligible)
        end)
    end
    Case('live protocol remains disabled',function()local s=P.GetSnapshot();assert(s.scope=='LOCAL' and s.state=='disabled' and not s.rankEligible)end)
    return pass,fail
end

function P.RunSeasonSelfTest(emit)
    emit=type(emit)=='function' and emit or function()end
    local pass,fail=0,0
    local function Case(label,fn)
        local ok,err=pcall(fn);if ok then pass=pass+1 else fail=fail+1 end
        emit('DR | SIMULATED | '..(ok and 'PASS ' or 'FAIL ')..label..(ok and '' or ': '..tostring(err)))
    end
    local a,b='Player-1-AAA','Player-2-BBB'
    local epoch=1000
    for _,client in ipairs({'forever','retail'}) do
        local function Node(start) return assert(ns.LeaderboardSync.OpenSeasonSimulated(client,start or epoch)) end
        local function Fixture()
            local x,y=Node(),Node()
            local s='a-1:b-1';local r={scope='SIMULATED',version='1',client=client,session=s,id=client..'|'..a..'|'..b..'|'..s,
                player1=a,player2=b,winner=a,loser=b,endType='knockout',rankEligible=false,
                statement1=table.concat({'1',client,s,a,b,'won','1'},'|'),statement2=table.concat({'1',client,s,b,a,'lost','1'},'|')}
            assert(x.Observe(r,epoch+1,epoch+2))
            return x,y,assert(P.NewRequester(client,y,'season')),assert(P.NewResponder(client,x))
        end
        local function Replay(node) return assert(node.ReplaySeasonSimulated({epoch=epoch,asOf=epoch+2})) end
        local function FramesFor(req,res)
            local request=assert(req.Begin(a,1,0));assert(#request+3<=240 and request:match('^Q|2|'))
            assert(res.Begin(request,b,b,0));local frames,t={},0
            while true do local msg=res.Next(t);if not msg then break end;assert(#msg+3<=240 and msg:match('^R|2|'));frames[#frames+1]=msg;t=t+GAP end
            return frames
        end
        Case(client..' balanced descriptor validates exact calendar',function()
            local I=ns.CompetitiveIntegrity;local d=assert(I.SeasonDescriptor(client,epoch))
            local function Check(body,state) local s=I.CompareSeasonSimulated(client,epoch,body);assert(s.state==state and s.compatible==(state=='compatible') and not s.originVerified and not s.rankEligible) end
            Check(d,'compatible');Check(nil,'unknown');Check(I.Descriptor(client),'invalid')
            Check(I.SeasonDescriptor(client,epoch+1),'schedule_mismatch');Check(I.SeasonDescriptor(client=='forever' and 'retail' or 'forever',epoch),'client_mismatch')
            Check((d:gsub('elo%-season%-2','elo-season-1')),'rule_mismatch');Check((d:gsub('|1000|','|01000|')),'invalid')
            local last=d:sub(-1);Check(d:sub(1,-2)..(last=='0' and '1' or '0'),'build_mismatch')
        end)
        Case(client..' season packet roundtrip and balanced replay',function()
            local x,y,q,r=Fixture();local frames=FramesFor(q,r);assert(#frames>1)
            for i=#frames,1,-1 do assert(q.Receive(frames[i],a,10)) end
            local s=Replay(y);assert(s.matched==1 and s.players[a].rating==1100 and s.players[b].rating==909 and not s.rankEligible and s.completeness=='unknown')
            assert(Replay(x).players[a].rating==s.players[a].rating and not y.Replay() and not y.ReplaySeasonSimulated({epoch=epoch+1,asOf=epoch+2}))
        end)
        Case(client..' mismatched season and build refused before response',function()
            local _,y,q,r=Fixture();local msg=assert(q.Begin(a,1,0))
            local wrong=assert(P.NewResponder(client,Node(epoch+1)));assert(not wrong.Begin(msg,b,b,0))
            local last=msg:sub(-1);assert(not r.Begin(msg:sub(1,-2)..(last=='0' and '1' or '0'),b,b,0));assert(Replay(y).matched==0)
            assert(r.Begin(msg,b,b,0))
        end)
        Case(client..' tampered response context cannot partially merge',function()
            local _,y,q,r=Fixture();local frames=FramesFor(q,r)
            frames[1]=frames[1]:gsub('|1000|','|1001|',1);assert(frames[1]:find('|1001|',1,true))
            for i=1,#frames-1 do assert(q.Receive(frames[i],a,10));assert(Replay(y).matched==0) end
            local ok,why=q.Receive(frames[#frames],a,10);assert(not ok and why=='season_context' and Replay(y).matched==0)
        end)
        Case(client..' no legacy downgrade and exact sender',function()
            local _,y,q,r=Fixture();local msg=assert(q.Begin(a,1,0));local legacy=assert(ns.LeaderboardSync.OpenSimulated(client))
            assert(not P.NewResponder(client,legacy).Begin(msg,b,b,0))
            local old=assert(P.NewRequester(client,legacy,'old'));assert(not r.Begin(assert(old.Begin(a,1,0)),b,b,0))
            assert(r.Begin(msg,b,b,0));local body=assert(r.Next(0));assert(not q.Receive(body,b,0));assert(not q.Receive(body:gsub('^R|2|','R|1|'),a,0));assert(Replay(y).matched==0)
        end)
        Case(client..' invalid epoch and absent compatibility fail closed',function()
            assert(not ns.LeaderboardSync.OpenSeasonSimulated(client,nil) and not ns.LeaderboardSync.OpenSeasonSimulated(client,0))
            assert(not ns.CompetitiveIntegrity.SeasonDescriptor(client,0));local bad={GetSeasonEpoch=function()return 0 end}
            assert(not P.NewRequester(client,bad,'x') and not P.NewResponder(client,bad))
        end)
    end
    Case('season wire remains disabled live',function()local s=P.GetSnapshot();assert(s.scope=='LOCAL' and s.state=='disabled' and not s.rankEligible)end)
    return pass,fail
end

function P.RunCapacitySelfTest(emit)
    emit=type(emit)=="function" and emit or function()end
    local passed,failed=0,0
    local function Case(label,fn)
        local ok,err=pcall(fn);if ok then passed=passed+1 else failed=failed+1 end
        emit("DR | SIMULATED | "..(ok and "PASS " or "FAIL ")..label..(ok and "" or ": "..tostring(err)))
    end
    local a,b="Player-1-AAA","Player-2-BBB"
    Case("bounded capacities and page count agree",function()
        assert(ns.MatchLedger.GetCapacity()==8192 and ns.PersonalHistory.GetCapacity()==8192 and MAX_PAGE==512)
    end)
    for _,client in ipairs({"forever","retail"}) do
        Case(client.." expanded page addressing remains bounded",function()
            local n=assert(ns.LeaderboardSync.OpenSeasonSimulated(client,1000))
            local q=assert(P.NewRequester(client,n,"capacity"))
            assert(not q.Begin(a,MAX_PAGE+1,0) and not q.Begin(a,0,0))
            local msg=assert(q.Begin(a,MAX_PAGE,0));assert(#msg+3<=240 and msg:find("|512|",1,true))
            local r=assert(P.NewResponder(client,n))
            assert(not r.Begin(msg,b,b,0)) -- no invented page at an empty source
            q.Cancel();assert(q.Begin(a,1,1))
        end)
        Case(client.." invalid capacities refused and prior empty stores reopen",function()
            local l=assert(ns.MatchLedger.OpenSimulated(client))
            local h=assert(ns.PersonalHistory.OpenSimulated(client,a,l))
            for _,cap in ipairs({0,-1,1.5,8193,math.huge,"8192",false}) do
                assert(not ns.MatchLedger.OpenSimulated(client,nil,cap))
                assert(not ns.PersonalHistory.OpenSimulated(client,a,l,nil,cap))
            end
            assert(ns.MatchLedger.OpenSimulated(client,l.Save()))
            assert(ns.PersonalHistory.OpenSimulated(client,a,l,h.Save()))
            assert(P.GetSnapshot().state=="disabled" and not P.GetSnapshot().rankEligible)
        end)
    end
    return passed,failed
end

function P.RunDeltaWireSelfTest(emit)
    emit=type(emit)=='function' and emit or function()end
    local pass,fail=0,0
    local function Case(label,fn)
        local ok,err=pcall(fn);if ok then pass=pass+1 else fail=fail+1 end
        emit('DR | SIMULATED | '..(ok and 'PASS ' or 'FAIL ')..label..(ok and '' or ': '..tostring(err)))
    end
    local a,b='Player-1-AAA','Player-2-BBB'
    local epoch=1000
    for _,client in ipairs({'forever','retail'}) do
        local function Fixture()
            local x=assert(ns.LeaderboardSync.OpenSeasonSimulated(client,epoch))
            local y=assert(ns.LeaderboardSync.OpenSeasonSimulated(client,epoch))
            local s='a-1:b-1'
            local r={scope='SIMULATED',version='1',client=client,session=s,id=client..'|'..a..'|'..b..'|'..s,
                player1=a,player2=b,winner=a,loser=b,endType='knockout',rankEligible=false,
                statement1=table.concat({'1',client,s,a,b,'won','1'},'|'),statement2=table.concat({'1',client,s,b,a,'lost','2'},'|')}
            assert(x.Observe(r,epoch,epoch))
            return x,y,assert(P.NewRequester(client,y,'delta')),assert(P.NewResponder(client,x)),r
        end
        local function FramesFor(res,msg,t)
            assert(#msg+3<=240)
            local ok,why=res.Begin(msg,b,b,t);assert(ok,why)
            local frames={}
            while true do
                local body,peer=res.Next(t);if not body then break end
                assert(peer==b and #body+3<=240)
                frames[#frames+1]=body;t=t+GAP;assert(#frames<=MAX_PARTS)
            end
            return frames,t
        end
        local function Deliver(q,frames,t,status)
            local value
            for i=#frames,1,-1 do
                local ok,why,v=q.Receive(frames[i],a,t);assert(ok,why)
                if i==1 then assert(why==status);value=v end
            end
            return value
        end
        local function Summary(q,res,t)
            local frames,finish=FramesFor(res,assert(q.BeginSummary(a,t)),t)
            return Deliver(q,frames,finish,'summary_complete'),finish+2
        end
        Case(client..' summary and differing group wire roundtrip',function()
            local x,y,q,res=Fixture()
            local plan,t=Summary(q,res,0);assert(plan.different==1 and #plan.pulls==1 and next(y.Save().ledger.entries)==nil)
            local g=plan.pulls[1]
            local frames,finish=FramesFor(res,assert(q.BeginDelta(a,g.group,g.expected,1,t)),t)
            assert(Deliver(q,frames,finish,'page_complete')==1)
            assert(y.ReplaySeasonSimulated({epoch=epoch,asOf=epoch}).matched==1)
            local nextPlan=Summary(q,res,finish+2);assert(nextPlan.different==0 and #nextPlan.pulls==0 and nextPlan.completeness=='unknown')
        end)
        Case(client..' interrupted summary rejects late fragments and retries',function()
            local _,y,q,res=Fixture()
            local frames=FramesFor(res,assert(q.BeginSummary(a,0)),0)
            assert(#frames>1 and not q.Receive(frames[1],b,1))
            local ok,why=q.Receive(frames[1],a,1);assert(ok and why=='partial')
            assert(q.Status(TTL)=='expired' and not q.Receive(frames[2],a,TTL))
            local fresh,finish=FramesFor(res,assert(q.BeginSummary(a,TTL+1)),TTL+1)
            assert(not q.Receive(frames[1],a,finish))
            local plan=Deliver(q,fresh,finish,'summary_complete');assert(#plan.pulls==1 and next(y.Save().ledger.entries)==nil)
        end)
        Case(client..' stale group and wrong response mode refuse merge',function()
            local x,y,q,res,r=Fixture();local plan,t=Summary(q,res,0);local g=plan.pulls[1]
            assert(x.Observe(r,epoch+1,epoch+1))
            local stale=assert(q.BeginDelta(a,g.group,g.expected,1,t))
            local ok,why=res.Begin(stale,b,b,t);assert(not ok and why=='stale_group')
            q.Cancel();plan,t=Summary(q,res,t+2);g=plan.pulls[1]
            local msg=assert(q.BeginDelta(a,g.group,g.expected,1,t))
            local wrong=msg:gsub('|D|[%d,]+','',1)
            assert(wrong~=msg)
            local frames,finish=FramesFor(res,wrong,t)
            for i=#frames,1,-1 do
                local good,reason=q.Receive(frames[i],a,finish)
                if i==1 then assert(not good and reason=='delta_context') else assert(good) end
            end
            assert(next(y.Save().ledger.entries)==nil)
            local retry,done=FramesFor(res,assert(q.BeginDelta(a,g.group,g.expected,1,finish+2)),finish+2)
            Deliver(q,retry,done,'page_complete')
            assert(y.ReplaySeasonSimulated({epoch=epoch,asOf=epoch+1}).timeDisputed==1)
        end)
        Case(client..' delta binding and full fallback remain bounded',function()
            local x,y,q,res=Fixture();local plan,t=Summary(q,res,0);local g=plan.pulls[1]
            assert(not q.BeginDelta(a,0,g.expected,1,t) and not q.BeginDelta(a,g.group,g.expected,2,t))
            local page=assert(x.ExportDeltaPage('fixture',g.group,g.expected,1))
            assert(ns.LeaderboardSync.ValidateDeltaPage(g.group,g.expected,page))
            assert(not ns.LeaderboardSync.ValidateDeltaPage(g.group%ns.LeaderboardSync.GetGroupCount()+1,g.expected,page))
            page.entries={};assert(not ns.LeaderboardSync.ValidateDeltaPage(g.group,g.expected,page))
            local frames,finish=FramesFor(res,assert(q.Begin(a,1,t)),t)
            Deliver(q,frames,finish,'page_complete')
            assert(y.ReplaySeasonSimulated({epoch=epoch,asOf=epoch}).matched==1)
            local legacy=assert(ns.LeaderboardSync.OpenSimulated(client))
            local old=assert(P.NewRequester(client,legacy,'old'))
            assert(not old.BeginSummary(a,0) and not old.BeginDelta(a,g.group,g.expected,1,0))
        end)
    end
    Case('delta wire remains simulation only',function()
        local s=P.GetSnapshot();assert(s.scope=='LOCAL' and s.state=='disabled' and not s.rankEligible)
    end)
    return pass,fail
end

function P.RunRecoverySelfTest(emit)
    emit=type(emit)=='function' and emit or function()end
    local pass,fail=0,0
    local function Case(label,fn)
        local ok,err=pcall(fn);if ok then pass=pass+1 else fail=fail+1 end
        emit('DR | SIMULATED | '..(ok and 'PASS ' or 'FAIL ')..label..(ok and '' or ': '..tostring(err)))
    end
    local a,b='Player-1-AAA','Player-2-BBB'
    local epoch=1000
    for _,client in ipairs({'forever','retail'}) do
        local function Node() return assert(ns.LeaderboardSync.OpenSeasonSimulated(client,epoch)) end
        local function Record(i,reverse)
            local s='a-'..i..':b-'..i
            return {scope='SIMULATED',version='1',client=client,session=s,id=client..'|'..a..'|'..b..'|'..s,
                player1=a,player2=b,winner=reverse and b or a,loser=reverse and a or b,endType='knockout',rankEligible=false,
                statement1=table.concat({'1',client,s,a,b,reverse and 'lost' or 'won','1'},'|'),
                statement2=table.concat({'1',client,s,b,a,reverse and 'won' or 'lost','2'},'|')}
        end
        local function Source(n)
            local x=Node()
            for i=1,n do assert(x.Observe(Record(i),epoch+i,epoch+i)) end
            return x
        end
        local function Drive(q,res,t,hook)
            for _=1,4096 do
                local status=q.GetStatus()
                if status.state~='working' then return status,t end
                local msg,why=q.Poll(t)
                if msg then
                    assert(#msg+3<=240)
                    local skip=hook and hook(msg,status,t)
                    if not skip then
                        local ok,err=res.Begin(msg,b,b,t)
                        if ok then
                            local packets={}
                            while true do
                                local body=res.Next(t);if not body then break end
                                assert(#body+3<=240);packets[#packets+1]=body;t=t+GAP
                            end
                            for i=#packets,1,-1 do assert(q.Receive(packets[i],a,t)) end
                            t=t+2
                        else
                            assert(err=='stale_audit' or err=='stale_group',err);t=t+TTL
                        end
                    else t=t+TTL end
                elseif why=='waiting' then t=t+TTL
                else t=t+2 end
            end
            error('catch-up did not terminate')
        end
        Case(client..' exact audit restarts after source changes and preserves merged pages',function()
            local x,y=Source(17),Node()
            local q=assert(P.NewCatchupSimulated(client,y,'audit',a,'audit'))
            local r=assert(P.NewResponder(client,x));local mutated=false
            local status=Drive(q,r,0,function(_,st)
                if st.pages==1 and not mutated then
                    mutated=true;assert(x.Observe(Record(18),epoch+18,epoch+18))
                end
            end)
            assert(mutated and status.state=='audit_received' and status.restarts==1 and status.pages==3)
            assert(y.ReplaySeasonSimulated({epoch=epoch,asOf=epoch+18}).matched==18)
            assert(y.PlanDelta(x.DeltaSummary()).different==0 and status.completeness=='unknown')
        end)
        Case(client..' lost delta request retries and reverse reconciliation works',function()
            local x,y=Source(3),Node()
            assert(y.Observe(Record(4),epoch+4,epoch+4))
            local q=assert(P.NewCatchupSimulated(client,y,'pull',a,'delta'))
            local r=assert(P.NewResponder(client,x));local dropped=false
            local status,t=Drive(q,r,0,function()
                if not dropped then dropped=true;return true end
            end)
            assert(dropped and status.restarts==1 and status.state=='differences_remaining')
            assert(y.ReplaySeasonSimulated({epoch=epoch,asOf=epoch+4}).matched==4)
            local reverse=assert(P.NewCatchupSimulated(client,x,'reverse',a,'delta'))
            local other=assert(P.NewResponder(client,y))
            local done=Drive(reverse,other,t);assert(done.state=='summary_agrees')
            assert(x.PlanDelta(y.DeltaSummary()).different==0)
        end)
        Case(client..' retry budget and cancellation stop requests',function()
            local x=Node();local q=assert(P.NewCatchupSimulated(client,x,'drop',a,'delta'))
            local r=assert(P.NewResponder(client,Source(1)))
            local status,t=Drive(q,r,0,function()return true end)
            assert(status.state=='retry_exhausted' and status.requests==3 and status.restarts==3)
            assert(not q.Poll(t+1) and next(x.Save().ledger.entries)==nil)
            local c=assert(P.NewCatchupSimulated(client,x,'cancel',a,'audit'))
            assert(c.Poll(0));c.Cancel();assert(c.GetStatus().state=='cancelled' and not c.Poll(1))
        end)
        Case(client..' audit binding rejects foreign sessions and changed generations',function()
            local x,y=Source(17),Node()
            local q=assert(P.NewRequester(client,y,'binding'));local r=assert(P.NewResponder(client,x))
            local msg=assert(q.BeginAudit(a,0));assert(r.Begin(msg,b,b,0));local t=0;local info
            while true do
                local body=r.Next(t);if not body then break end
                local ok,why,v=q.Receive(body,a,t);assert(ok,why)
                if why=='audit_page_complete' then info=v end
                t=t+GAP
            end
            assert(info and info.total==2 and info.index==1)
            local msg2=assert(q.BeginAuditPage(a,info,2,t+2))
            assert(not r.Begin(msg2,a,a,t+2))
            local newResponder=assert(P.NewResponder(client,x));assert(not newResponder.Begin(msg2,b,b,t+2))
            assert(x.Observe(Record(1,true),epoch+1,epoch+1))
            local ok,why=r.Begin(msg2,b,b,t+2);assert(not ok and why=='stale_audit')
            q.Cancel();assert(next(y.Save().ledger.entries)~=nil)
        end)
    end
    Case('catch-up requires season-bound simulations',function()
        local x=assert(ns.LeaderboardSync.OpenSimulated('retail'))
        assert(not P.NewCatchupSimulated('retail',x,'invalid',a,'audit'))
        local s=P.GetSnapshot();assert(s.scope=='LOCAL' and s.state=='disabled' and not s.rankEligible)
    end)
    return pass,fail
end
