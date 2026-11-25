local _,ns=...
-- Read-only projection of the existing single-elimination draw. No match
-- ownership, new database, network, synthetic live entries or polling.
local B={};ns.BracketView=B
local max,min,floor=math.max,math.min,math.floor
local function Count(t) return type(t)=="table" and #t or 0 end
local function RoundName(distance)
    return distance==0 and "Final" or distance==1 and "Semifinals" or distance==2 and "Quarterfinals" or "Round of "..2^(distance+1)
end
-- Compress one-sided paths using the frozen slots, NOT current names:
-- unresolved future matches still count; byes are not played matches.
function B.Project(view,names,focus,viewportW,viewportH,zoom)
    if type(view)~="table" or type(view.slots)~="table" or type(view.rounds)~="table" then return nil end
    local size=Count(view.slots);local rounds=Count(view.rounds)
    if size<2 or size>64 or rounds<1 or rounds>6 or size~=2^rounds then return nil end
    for r=1,rounds do
        if Count(view.rounds[r])~=size/2^r then return nil end
    end
    names=type(names)=="table" and names or {}
    local function Build(r,i)
        if r==0 then
            local guid=view.slots[i]
            if type(guid)=="string" then return {guid=guid,count=1} end
            return nil
        end
        local a,b=Build(r-1,i*2-1),Build(r-1,i*2)
        if not a then return b elseif not b then return a end
        local m=view.rounds[r][i]
        if type(m)~="table" or type(m.id)~="string" or type(m.wins)~="table" then return nil end
        return {row=m,r=r,a=a,b=b,count=a.count+b.count}
    end
    local root=Build(rounds,1)
    if not root or not root.row then return nil end
    zoom=max(.8,min(1.3,zoom or 1))
    local cw,ch,fw,gap,step= floor(200*zoom),floor(82*zoom),floor(326*zoom),floor(42*zoom),floor(108*zoom)
    local sides={[-1]={depths={},columns={},rows=0},[1]={depths={},columns={},rows=0}}
    local function Collect(n,side)
        if not n.row then return end
        local s=sides[side];s.depths[root.r-n.r]=true
        Collect(n.a,side);Collect(n.b,side)
    end
    Collect(root.a,-1);Collect(root.b,1)
    for _,s in pairs(sides) do
        local list={}
        for d in pairs(s.depths) do list[#list+1]=d end
        table.sort(list)
        for i,d in ipairs(list) do s.columns[d]=i end
        s.width=#list*(cw+gap)
    end
    -- Give each subtree its own compact vertical span. A direct entrant
    -- takes no card; if both feeders are matches, their midpoint is used.
    local function AssignY(n,s)
        if not n.row then return nil end
        local ay,by=AssignY(n.a,s),AssignY(n.b,s)
        local y
        if ay and by then y=(ay+by)/2
        elseif ay or by then y=ay or by
        else s.rows=s.rows+1;y=(s.rows-1)*step end
        n.y=y;return y
    end
    AssignY(root.a,sides[-1]);AssignY(root.b,sides[1])
    local totalW=fw+sides[-1].width+sides[1].width+32
    local rows=max(1,sides[-1].rows,sides[1].rows)
    local totalH=rows*step+76
    local w,h=max(viewportW or 1,totalW),max(viewportH or 1,totalH)
    local centerX=(w-totalW)/2+16+sides[-1].width+fw/2
    local centerY=44+(h-60)/2
    local out={width=w,height=h,nodes={},edges={},headers={},focus=nil,count=root.count}
    local function Name(g)
        if type(g)~="string" then return "Awaiting player" end
        return type(names[g])=="string" and names[g] or "Unknown player"
    end
    local function Node(n,x,y,width)
        local m=n.row
        local a,b=m.a or n.a.guid,m.b or n.b.guid
        local highlighted=focus==m.id
        local status=m.state=="ready" and "Match ready" or m.state=="done" and "Completed" or "Awaiting players"
        if m.forfeit then status="Forfeit"
        elseif view.dispute and view.dispute.match==m.id then status="Disputed" end
        local node={id=m.id,x=x-width/2,y=y-ch/2,w=width,h=ch,cx=x,cy=y,
            a=Name(a),b=Name(b),sa=m.state=="waiting" and "-" or tostring(m.wins[1] or 0),
            sb=m.state=="waiting" and "-" or tostring(m.wins[2] or 0),
            winnerA=type(a)=="string" and m.winner==a,winnerB=type(b)=="string" and m.winner==b,
            status=status,focus=highlighted,final=n==root,ready=m.state=="ready",disputed=status=="Disputed"}
        out.nodes[#out.nodes+1]=node
        if highlighted then out.focus=node end
        return node
    end
    local final=Node(root,centerX,centerY,fw)
    out.headers[1]={label="Final",x=centerX,w=fw}
    local function PlaceTree(n,side,parent)
        if not n.row then return end
        local s=sides[side];local d=root.r-n.r;local column=s.columns[d]
        local x=centerX+side*(fw/2+gap+cw/2+(column-1)*(cw+gap))
        local y=centerY+n.y-(s.rows-1)*step/2
        local node=Node(n,x,y,cw)
        local fromX=side==-1 and node.x+node.w or node.x
        local toX=side==-1 and parent.x or parent.x+parent.w
        out.edges[#out.edges+1]={x1=fromX,y1=node.cy,x2=toX,y2=parent.cy,focus=node.focus or parent.focus}
        PlaceTree(n.a,side,node);PlaceTree(n.b,side,node)
    end
    for _,side in ipairs({-1,1}) do
        local s=sides[side]
        for d,col in pairs(s.columns) do
            local x=centerX+side*(fw/2+gap+cw/2+(col-1)*(cw+gap))
            out.headers[#out.headers+1]={label=RoundName(d),x=x,w=cw}
        end
    end
    PlaceTree(root.a,-1,final);PlaceTree(root.b,1,final)
    return out
end

-- All UI is lazy, pooled, and visible only in the bracket panel. The native
-- scroll frame clips both axes; zoom changes card spacing, not font settings.
function B.New(parent)
    local S,C=ns.Style,ns.Style.color
    local D={}
    local function At(f,p,x,y,w,h)
        f:ClearAllPoints();f:SetPoint("TOPLEFT",p,"TOPLEFT",x,-y);f:SetSize(max(1,w),max(1,h))
    end
    local function Text(p,size,color,align)
        local t=S.Text(p,"",size,color);t:SetJustifyH(align or "LEFT");t:SetWordWrap(false)
        return t
    end
    local board=CreateFrame("Frame",nil,parent)
    S.Plate(board,"dark",{corner=11,layer="BACKGROUND",sublevel=0})
    local viewport=CreateFrame("ScrollFrame",nil,board)
    local canvas=CreateFrame("Frame",nil,viewport);canvas:SetSize(1,1);viewport:SetScrollChild(canvas)
    local controls=CreateFrame("Frame",nil,board)
    local cards,lines,headers={},{},{}
    local model,view,names,focus,event,zoom=nil,nil,nil,nil,nil,1
    local vw,vh=1,1
    local function Card(i)
        if cards[i] then return cards[i] end
        local f=CreateFrame("Frame",nil,canvas)
        S.Plate(f,"dark",{corner=9,layer="BACKGROUND",sublevel=0})
        f.edges={}
        for k=1,4 do f.edges[k]=f:CreateTexture(nil,"BORDER") end
        f.rule=f:CreateTexture(nil,"ARTWORK");f.rule:SetColorTexture(.40,.30,.17,.65)
        f.a=Text(f,14,C.text);f.b=Text(f,14,C.text)
        f.sa=Text(f,15,C.pale,"CENTER");f.sb=Text(f,15,C.pale,"CENTER")
        f.status=Text(f,11,C.muted,"CENTER")
        cards[i]=f;return f
    end
    local function Line(i,x1,y1,x2,y2,bright)
        local t=lines[i]
        if not t then t=canvas:CreateTexture(nil,"BACKGROUND",nil,1);lines[i]=t end
        local color=bright and C.gold or C.goldDim
        t:SetColorTexture(color[1],color[2],color[3],bright and .95 or .62)
        At(t,canvas,min(x1,x2),min(y1,y2),max(2,math.abs(x2-x1)),max(2,math.abs(y2-y1)))
        t:Show()
    end
    local function Header(i,m)
        local f=headers[i]
        if not f then
            f=CreateFrame("Frame",nil,canvas)
            S.Plate(f,"dark",{corner=8,layer="BACKGROUND",sublevel=0})
            f.text=Text(f,15,C.pale,"CENTER");f.text:SetAllPoints(f)
            headers[i]=f
        end
        At(f,canvas,m.x-m.w/2+4,10,m.w-8,26)
        f.text:SetText(m.label);f:Show()
    end
    local function Paint(m,i)
        local f=Card(i);At(f,canvas,m.x,m.y,m.w,m.h)
        local bright=m.focus or m.final and m.ready
        local color=bright and C.gold or m.disputed and C.red or C.goldDim
        for _,t in ipairs(f.edges) do t:SetColorTexture(color[1],color[2],color[3],bright and 1 or .75) end
        At(f.edges[1],f,2,2,m.w-4,bright and 2 or 1)
        At(f.edges[2],f,2,m.h-3,m.w-4,bright and 2 or 1)
        At(f.edges[3],f,2,2,bright and 2 or 1,m.h-4)
        At(f.edges[4],f,m.w-3,2,bright and 2 or 1,m.h-4)
        local rowH=floor((m.h-24)/2)
        At(f.a,f,10,4,m.w-52,rowH);At(f.b,f,10,4+rowH,m.w-52,rowH)
        At(f.sa,f,m.w-37,4,27,rowH);At(f.sb,f,m.w-37,4+rowH,27,rowH)
        At(f.rule,f,10,4+rowH,m.w-20,1)
        At(f.status,f,8,m.h-21,m.w-16,18)
        f.a:SetText(m.a);f.b:SetText(m.b);f.sa:SetText(m.sa);f.sb:SetText(m.sb)
        f.a:SetTextColor(unpack(m.winnerA and {.54,.90,.40,1} or C.text))
        f.b:SetTextColor(unpack(m.winnerB and {.54,.90,.40,1} or C.text))
        f.status:SetText(m.status);f.status:SetTextColor(unpack(m.disputed and C.red or bright and C.pale or C.muted))
        if f.a.SetMaxLines then f.a:SetMaxLines(1);f.b:SetMaxLines(1) end
        f:Show()
    end
    local function Clamp()
        if not model then return end
        viewport:SetHorizontalScroll(max(0,min(viewport:GetHorizontalScroll(),model.width-vw)))
        viewport:SetVerticalScroll(max(0,min(viewport:GetVerticalScroll(),model.height-vh)))
    end
    local function Center(n)
        if not model then return end
        n=n or model.nodes[1]
        if not n then return end
        viewport:SetHorizontalScroll(max(0,min(n.cx-vw/2,model.width-vw)))
        viewport:SetVerticalScroll(max(0,min(n.cy-vh/2,model.height-vh)))
    end
    local function Render(recenter)
        model=B.Project(view,names,focus,vw,vh,zoom)
        if not model then board:Hide();return false end
        canvas:SetSize(model.width,model.height)
        if viewport.UpdateScrollChildRect then viewport:UpdateScrollChildRect() end
        local k=0
        for _,e in ipairs(model.edges) do
            local mid=(e.x1+e.x2)/2
            k=k+1;Line(k,e.x1,e.y1,mid,e.y1,e.focus)
            k=k+1;Line(k,mid,e.y1,mid,e.y2,e.focus)
            k=k+1;Line(k,mid,e.y2,e.x2,e.y2,e.focus)
        end
        for i=k+1,#lines do lines[i]:Hide() end
        for i,m in ipairs(model.nodes) do Paint(m,i) end
        for i=#model.nodes+1,#cards do cards[i]:Hide() end
        for i,m in ipairs(model.headers) do Header(i,m) end
        for i=#model.headers+1,#headers do headers[i]:Hide() end
        if recenter then Center(model.focus) else Clamp() end
        return true
    end
    local function Pan(dx,dy)
        if not model then return end
        viewport:SetHorizontalScroll(max(0,min(viewport:GetHorizontalScroll()+dx,model.width-vw)))
        viewport:SetVerticalScroll(max(0,min(viewport:GetVerticalScroll()+dy,model.height-vh)))
    end
    local function Button(label,fn)
        local b=S.Action(controls,label,"footer",{plate="dark",text=C.pale,edge=C.goldDim,hover=C.gold,tooltip=false})
        b:SetScript("OnClick",fn);return b
    end
    local left=Button("<",function()Pan(-180,0)end)
    local right=Button(">",function()Pan(180,0)end)
    local minus=Button("-",function()zoom=max(.8,zoom-.1);Render(true)end)
    local plus=Button("+",function()zoom=min(1.3,zoom+.1);Render(true)end)
    local center=Button("My match",function()Center(model and model.focus)end)
    viewport:EnableMouseWheel(true)
    viewport:SetScript("OnMouseWheel",function(_,delta)
        if IsShiftKeyDown and IsShiftKeyDown() then Pan(-delta*90,0) else Pan(0,-delta*70) end
    end)
    function D.Hide()
        board:Hide();model,view,names,focus,event=nil,nil,nil,nil,nil;zoom=1
        for _,pool in ipairs({cards,lines,headers}) do for _,f in ipairs(pool) do f:Hide() end end
    end
    function D.Show(p,w,h)
        if not p or not p.bracket then D.Hide();return false end
        local changed=event~=p.event.id
        local nextFocus=p.match and p.match.id
        local recenter=changed or focus~=nextFocus
        if changed then zoom=1 end
        event=p.event.id;view=p.bracket;names=p.names;focus=nextFocus
        -- More than one actual match exposes navigation. Small windows
        -- may need the controls even for a single final.
        local probe=B.Project(view,names,focus,w-20,h-68,zoom)
        if not probe then D.Hide();return false end
        local nav=#probe.nodes>1 or probe.width>w-20 or probe.height>h-68
        At(board,parent,10,44,w-20,h-54)
        vw=max(1,w-36);vh=max(1,h-70-(nav and 34 or 0))
        At(viewport,board,8,8,vw,vh)
        controls:SetShown(nav);At(controls,board,8,h-88,w-36,28)
        At(left,controls,0,0,36,26);At(right,controls,40,0,36,26)
        At(minus,controls,84,0,36,26);At(plus,controls,124,0,36,26)
        At(center,controls,168,0,112,26)
        board:Show()
        return Render(recenter)
    end
    board:Hide()
    return D
end

-- Pure geometry tests use explicit synthetic fixtures, never player data.
function B.RunSelfTest(emit)
    emit=type(emit)=="function" and emit or function()end
    local p,f=0,0
    local function Case(label,fn)
        local ok,err=pcall(fn)
        if ok then p=p+1 else f=f+1 end
        emit("DR | SIMULATED | "..(ok and "PASS " or "FAIL ")..label..(ok and "" or ": "..tostring(err)))
    end
    local function Fixture(size,n)
        local v={slots={},rounds={}}
        for i=1,size do v.slots[i]=false end
        -- Spread the entrants over the draw without inventing played games.
        for i=1,n do v.slots[floor((i-1)*size/n)+1]="P"..i end
        local r,amount=1,size/2
        while amount>=1 do
            v.rounds[r]={}
            for i=1,amount do v.rounds[r][i]={id="R"..r.."M"..i,state="waiting",wins={0,0}} end
            r=r+1;amount=amount/2
        end
        return v
    end
    Case("all capacities and sparse counts 2 through 64",function()
        for _,size in ipairs({2,4,8,16,32,64}) do
            for n=2,size do
                local m=assert(B.Project(Fixture(size,n),{},nil,700,280,1))
                assert(m.count==n and #m.nodes==n-1 and #m.edges==n-2)
                for _,v in ipairs(m.nodes) do assert(v.x>=0 and v.y>=0 and v.x+v.w<=m.width and v.y+v.h<=m.height) end
                for i,a in ipairs(m.nodes) do for j=i+1,#m.nodes do
                    local b=m.nodes[j]
                    assert(a.x+a.w<=b.x or b.x+b.w<=a.x or a.y+a.h<=b.y or b.y+b.h<=a.y,"overlap")
                end end
            end
        end
    end)
    Case("two players collapse to one centered final, including oversized draw",function()
        local m=assert(B.Project(Fixture(32,2),{},nil,900,300,1))
        assert(#m.nodes==1 and #m.edges==0 and #m.headers==1 and m.nodes[1].cx==450)
    end)
    Case("ready and completed score, focus and dispute from snapshot",function()
        local v=Fixture(2,2);local r=v.rounds[1][1]
        r.a,r.b,r.state,r.wins="P1","P2","ready",{1,0}
        local m=B.Project(v,{P1="First",P2="Second"},r.id,400,200,1)
        assert(m.focus.a=="First" and m.focus.sa=="1" and m.focus.status=="Match ready")
        r.state="done";r.winner="P1";r.wins={2,0}
        m=B.Project(v,{},nil,400,200,1);assert(m.nodes[1].winnerA and m.nodes[1].status=="Completed")
        v.dispute={match=r.id};m=B.Project(v,{},nil,400,200,1);assert(m.nodes[1].status=="Disputed")
    end)
    Case("bounded zoom and invalid snapshot",function()
        assert(not B.Project({},nil,nil,300,200,1))
        local v=Fixture(64,64)
        local a=B.Project(v,{},nil,300,200,.8)
        local b=B.Project(v,{},nil,300,200,1.3)
        assert(a.width<b.width and a.height<b.height and #a.nodes==#b.nodes)
    end)
    return p,f
end
if ns.Diagnostics then
    ns.Diagnostics.Register("Tournament bracket / isolated layout QA","deep",function()
        local log={};local p,f=B.RunSelfTest(function(line)log[#log+1]=line end)
        return f==0 and p==4 and "PASS" or "FAIL",string.format("%d passed / %d failed (SIMULATED)\n",p,f)..table.concat(log,"\n")
    end)
end
