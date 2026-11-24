local _,ns=...
-- Simulated wire codec and request lifecycle. Never calls Communication.Send.
local P={}
ns.SyncProtocol=P
local CHUNK,MAX_PARTS,MAX_PAGE,MAX_BODY,TTL,GAP=160,128,128,237,120,0.5
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
local function ParseRequest(body,client,rev,context)
    if not Safe(body) then return nil end
    if rev=='2' then
        if body:sub(-#context)~=context then return nil end
        body=body:sub(1,#body-#context)
    end
    local k,t,p=body:match('^Q|'..rev..'|(%a+)|([%w%-]+)|(%d+)$')
    if k~=client or not Token(t) then return nil end
    p=Integer(p,MAX_PAGE);if p then return t,p end
end
local function Frames(node,client,body,rev,context)
    local token,index=ParseRequest(body,client,rev,context);if not token then return nil,'request' end
    local pages=node.Export(token);local page=pages and pages[index];if not page then return nil,'page' end
    local data=Encode(page);if rev=='2' then data=context..'|'..data end
    local count=math.ceil(#data/CHUNK)
    if count>MAX_PARTS then return nil,'capacity' end
    local out={};for i=1,count do
        local msg=table.concat({'R',rev,client,token,index,page.total,i,count,data:sub((i-1)*CHUNK+1,i*CHUNK)},'|')
        if not Safe(msg) then return nil,'capacity' end;out[i]=msg
    end
    return out
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
    function D.Begin(peer,page,now)
        if not Time(now) or not Guid(peer) or type(page)~='number' or not Integer(tostring(page),MAX_PAGE) then return nil,'invalid' end
        if D.Status(now)=='waiting' then return nil,'busy' end
        if seq>=2147483647 then return nil,'capacity' end
        seq=seq+1;local token=prefix..'-'..seq
        pending={peer=peer,page=page,token=token,deadline=now+TTL,last=now,parts={},received=0}
        return 'Q|'..rev..'|'..client..'|'..token..'|'..page..context
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
        local page=Decode(payload,client,q.token,q.page,total)
        if not page then return false,'decode' end
        local ok,why=node.Receive(page,sender,q.peer,q.token)
        if not ok then return false,why end
        return true,'page_complete',total -- NOT global completeness
    end
    return D
end
-- One bounded frozen response; caller injects recognized peer identity and time.
-- Pull-based pacing only, no background timers, no game API.
function P.NewResponder(client,node)
    if not Client(client) then return nil end
    local rev,context=Context(client,node);if not rev then return nil end
    local D,stream,lastStart={},nil,nil
    function D.Cancel() stream=nil end
    function D.Begin(body,sender,expected,now)
        if not Time(now) or not Guid(sender) or sender~=expected then return false,'sender' end
        if stream and now>=stream.deadline then stream=nil end
        if stream or (lastStart and now-lastStart<2) then return false,'busy' end
        local frames,why=Frames(node,client,body,rev,context);if not frames then return false,why end
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
