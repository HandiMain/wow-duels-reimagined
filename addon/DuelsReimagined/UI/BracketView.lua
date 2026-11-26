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
function B.Project(view,names,focus,viewportW,viewportH,zoom,own)
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
    local cw,ch,fw,gap,step= floor(218*zoom),floor(112*zoom),floor(310*zoom),floor(38*zoom),floor(140*zoom)
    local finalH=floor(250*zoom)
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
    local totalH=max(rows*step+76,finalH+80)
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
        local nh=n==root and finalH or ch
        local node={id=m.id,x=x-width/2,y=y-nh/2,w=width,h=nh,cx=x,cy=y,
            guidA=a,guidB=b,ownA=own~=nil and a==own,ownB=own~=nil and b==own,winner=m.winner,
            a=Name(a),b=Name(b),sa=m.state=="waiting" and "-" or tostring(m.wins[1] or 0),
            sb=m.state=="waiting" and "-" or tostring(m.wins[2] or 0),
            winnerA=type(a)=="string" and m.winner==a,winnerB=type(b)=="string" and m.winner==b,
            status=status,focus=highlighted,final=n==root,ready=m.state=="ready",disputed=status=="Disputed"}
        out.nodes[#out.nodes+1]=node
        if highlighted then out.focus=node end
        return node
    end
    local final=Node(root,centerX,centerY,fw)
    -- The championship card carries its own Final plaque.
    local function PlaceTree(n,side,parent)
        if not n.row then return end
        local s=sides[side];local d=root.r-n.r;local column=s.columns[d]
        local x=centerX+side*(fw/2+gap+cw/2+(column-1)*(cw+gap))
        local y=centerY+n.y-(s.rows-1)*step/2
        local node=Node(n,x,y,cw)
        local fromX=side==-1 and node.x+node.w or node.x
        local toX=side==-1 and parent.x or parent.x+parent.w
        out.edges[#out.edges+1]={x1=fromX,y1=node.cy,x2=toX,y2=parent.cy,focus=own~=nil and node.winner==own and (parent.ownA or parent.ownB),completed=type(node.winner)=="string"}
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

-- One pooled native scroll canvas. Mouse drag is active only while held.
function B.New(parent)
    local S,C=ns.Style,ns.Style.color
    local D={}
    local ROOT="Interface\\AddOns\\DuelsReimagined\\Media\\"
    local ART=ROOT.."Skin\\TournamentOverviewArt.png"
    local BRACKET_ART=ROOT.."Skin\\TournamentBracketArt.tga"
    local PORTRAIT=ROOT.."Skin\\TournamentPlayerArt.png"
    local function At(f,p,x,y,w,h)
        f:ClearAllPoints();f:SetPoint("TOPLEFT",p,"TOPLEFT",x,-y);f:SetSize(max(1,w),max(1,h))
    end
    local function Text(p,size,color,align)
        local t=S.Text(p,"",size,color);t:SetJustifyH(align or "LEFT");t:SetJustifyV("MIDDLE");t:SetWordWrap(false);return t
    end
    local function Art(p,path,x1,x2,y1,y2,layer,sub)
        local t=p:CreateTexture(nil,layer or "ARTWORK",nil,sub or 0);t:SetTexture(path)
        t:SetTexCoord(x1,x2,y1,y2);ns.Chrome.Sharp(t);return t
    end
    local function Fade(p,color,alpha,layer,sub)
        local t=p:CreateTexture(nil,layer or "BACKGROUND",nil,sub or 2)
        t:SetColorTexture(1,1,1,1)
        if t.SetGradient and CreateColor then
            t:SetGradient("VERTICAL",CreateColor(color[1],color[2],color[3],0),CreateColor(color[1],color[2],color[3],alpha))
        else t:SetColorTexture(color[1],color[2],color[3],alpha*.5) end
        return t
    end
    local board=CreateFrame("Frame",nil,parent)
    S.Plate(board,"organizerPanel",{corner=13,layer="BACKGROUND",sublevel=0})
    local arena=Art(board,ROOT.."Arenas\\WarGamesArenaFallback.png",.50,.75,.25,.50,"BACKGROUND",1)
    arena:SetVertexColor(.68,.58,.47,.22)
    local shade=Fade(board,{.025,.018,.012},.94,"BACKGROUND",2)
    local banner=CreateFrame("Frame",nil,board)
    S.Plate(banner,"organizerHero",{corner=13,layer="BACKGROUND",sublevel=0})
    local leftArt=Art(banner,ART,0,456/1024,0,100/512)
    local rightArt=Art(banner,ART,464/1024,892/1024,0,100/512)
    leftArt:SetAlpha(.68);rightArt:SetAlpha(.68)
    local title=Text(banner,23,C.pale,"CENTER")
    local meta=Text(banner,13,C.text,"CENTER")
    local viewport=CreateFrame("ScrollFrame",nil,board)
    local canvas=CreateFrame("Frame",nil,viewport);canvas:SetSize(1,1);viewport:SetScrollChild(canvas)
    local controls=CreateFrame("Frame",nil,board)
    local hint=Text(controls,12,C.muted,"RIGHT")
    local legend=Text(controls,12,C.pale)
    local cards,lines,headers={},{},{}
    local model,view,names,focus,event,own,projection=nil,nil,nil,nil,nil,nil,nil
    local zoom,vw,vh=1,1,1
    local autoFit=true
    local dragX,dragY,dragH,dragV
    local Render,Pan,Wheel
    local classes={"WARRIOR","PALADIN","HUNTER","ROGUE","PRIEST","SHAMAN","MAGE","WARLOCK","DRUID"}
    local classColors={WARRIOR={.78,.61,.43},PALADIN={.96,.55,.73},HUNTER={.67,.83,.45},ROGUE={1,.96,.41},PRIEST={.95,.95,.95},SHAMAN={.15,.48,1},MAGE={.25,.78,.92},WARLOCK={.58,.51,.79},DRUID={1,.49,.04}}
    local function Class(guid)
        -- Tournament registration does not carry class evidence. These
        -- decorative classes are explicitly simulated, never peer claims.
        if not projection or projection.scope~="SIMULATED" or type(guid)~="string" then return nil end
        local n=0;for i=1,#guid do n=(n*31+guid:byte(i))%#classes end
        return classes[n+1]
    end
    local function Profile(guid)
        local p=projection
        local member=p and p.scope=="SIMULATED" and p.players and p.players[guid]
        if member and ns.CompetitiveUI then ns.CompetitiveUI.OpenTournamentPlayerCard(member,p.event.draft.name,p.scope) end
    end
    local function Row(f)
        local b=CreateFrame("Button",nil,f)
        b.bg=b:CreateTexture(nil,"BACKGROUND");b.bg:SetAllPoints()
        b.relief=Fade(b,{1,.73,.34},.11,"BACKGROUND",1);b.relief:SetAllPoints()
        b.rule=b:CreateTexture(nil,"BORDER")
        b.light=Fade(b,{1,.66,.18},.10,"BACKGROUND",2);b.light:SetAllPoints()
        b.icon=b:CreateTexture(nil,"ARTWORK");ns.Chrome.Sharp(b.icon)
        b.iconRim=b:CreateTexture(nil,"BORDER");b.iconRim:SetColorTexture(.65,.43,.18,.72)
        b.name=Text(b,17,C.text);b.score=Text(b,19,C.pale,"CENTER")
        b.accent=b:CreateTexture(nil,"BORDER")
        b:SetScript("OnClick",function(self) if self.guid then Profile(self.guid) end end)
        b:SetScript("OnEnter",function(self) if self.guid then self.light:SetAlpha(1) end end)
        b:SetScript("OnLeave",function(self) self.light:SetAlpha(0) end)
        b.light:SetAlpha(0)
        b:EnableMouseWheel(true);b:SetScript("OnMouseWheel",function(_,d) Wheel(d) end)
        return b
    end
    local function Card(i)
        if cards[i] then return cards[i] end
        local f=CreateFrame("Frame",nil,canvas)
        f.frameArt=Art(f,BRACKET_ART,.5,1,0,.5,"BACKGROUND",0);f.frameArt:SetAllPoints()
        f.trophy=Art(f,ART,160/1024,314/1024,112/512,240/512,"ARTWORK",3)
        f.trophy:SetBlendMode("ADD")
        f.finalTitle=Text(f,19,C.pale,"CENTER")
        f.a=Row(f);f.b=Row(f)
        f.status=Text(f,13,C.muted,"CENTER")
        cards[i]=f;return f
    end
    local function Line(i,x1,y1,x2,y2,bright,complete)
        local t=lines[i]
        if not t then
            t={core=canvas:CreateTexture(nil,"BACKGROUND",nil,3),glow=canvas:CreateTexture(nil,"BACKGROUND",nil,2)};lines[i]=t
        end
        local color=bright and {1,.82,.31} or complete and {.76,.55,.24} or {.40,.38,.33}
        local x,y=min(x1,x2),min(y1,y2)
        local thickness=bright and 3 or 2
        local w,h=max(thickness,math.abs(x2-x1)),max(thickness,math.abs(y2-y1))
        t.core:SetColorTexture(color[1],color[2],color[3],bright and 1 or .80)
        At(t.core,canvas,x,y,w,h);t.core:Show()
        t.glow:SetColorTexture(1,.63,.10,.23)
        At(t.glow,canvas,x-3,y-3,w+6,h+6);t.glow:SetShown(bright)
    end
    local function Header(i,m)
        local f=headers[i]
        if not f then
            f=CreateFrame("Frame",nil,canvas)
            S.Plate(f,"browseCard",{corner=9,layer="BACKGROUND",sublevel=0})
            f.text=Text(f,14,C.pale,"CENTER");f.text:SetAllPoints(f)
            headers[i]=f
        end
        At(f,canvas,m.x-m.w/2+4,10,m.w-8,27)
        f.text:SetText(m.label);f:Show()
    end
    local function PaintRow(b,f,x,y,w,h,guid,name,score,winner,mine,finished)
        At(b,f,x,y,w,h)
        local class=Class(guid);local tint=classColors[class] or {.72,.62,.43}
        b.guid=guid
        if class then
            b.icon:SetTexture("Interface\\Icons\\ClassIcon_"..class);b.icon:SetTexCoord(.06,.94,.06,.94)
        else
            b.icon:SetTexture(PORTRAIT);b.icon:SetTexCoord(0,46/256,82/128,1)
        end
        b.icon:SetAlpha(guid and 1 or .58)
        local sz=max(15,min(h-6,34))
        At(b.iconRim,b,4,(h-sz)/2-1,sz+2,sz+2);At(b.icon,b,5,(h-sz)/2,sz,sz)
        At(b.name,b,sz+13,0,w-sz-48,h);At(b.score,b,w-32,0,30,h)
        At(b.rule,b,2,h-1,w-4,1);b.rule:SetColorTexture(.68,.46,.21,.35)
        At(b.accent,b,1,2,2,h-4);b.accent:SetColorTexture(tint[1],tint[2],tint[3],guid and .9 or .24)
        b.bg:SetColorTexture(tint[1],tint[2],tint[3],mine and .24 or winner and .14 or .055)
        b.relief:SetAlpha(guid and 1 or .40)
        b.name:SetText(name);b.score:SetText(score)
        b.name:SetTextColor(unpack(mine and C.pale or finished and not winner and C.muted or C.text))
        b.score:SetTextColor(unpack(winner and C.gold or C.pale))
        if S.ConstrainText then S.ConstrainText(b.name,max(1,w-sz-48),h,12) end
        b:EnableMouse(projection and projection.scope=="SIMULATED" and projection.players and projection.players[guid]~=nil or false)
        b.light:SetAlpha(0)
    end
    local function Paint(m,i)
        local f=Card(i);At(f,canvas,m.x,m.y,m.w,m.h)
        local bright=m.focus or m.ownA or m.ownB
        if m.final then f.frameArt:SetTexCoord(0,.5,0,1)
        else f.frameArt:SetTexCoord(.5,1,bright and .5 or 0,bright and 1 or .5) end
        f.trophy:SetShown(m.final);f.finalTitle:SetShown(m.final)
        local top=m.final and floor(m.h*.46) or 9
        if m.final then
            local tw=floor(m.h*.46);At(f.trophy,f,(m.w-tw)/2,5,tw,tw*.80)
            At(f.finalTitle,f,22,floor(m.h*.38),m.w-44,floor(m.h*.09));f.finalTitle:SetText("FINAL")
        end
        local bottom=m.final and floor(m.h*.20) or 24
        local rh=floor((m.h-top-bottom)/2)
        local finished=m.status=="Completed" or m.status=="Forfeit"
        local pad=m.final and floor(m.w*.115) or 9
        PaintRow(f.a,f,pad,top,m.w-pad*2,rh,m.guidA,m.a,m.sa,m.winnerA,m.ownA,finished)
        PaintRow(f.b,f,pad,top+rh,m.w-pad*2,rh,m.guidB,m.b,m.sb,m.winnerB,m.ownB,finished)
        At(f.status,f,pad,m.final and m.h-bottom+1 or m.h-23,m.w-pad*2,19)
        f.status:SetText(m.status);f.status:SetTextColor(unpack(m.disputed and C.red or finished and {.54,.90,.40,1} or m.ready and C.gold or C.muted))
        f:Show()
    end
    local function Clamp()
        if not model then return end
        viewport:SetHorizontalScroll(max(0,min(viewport:GetHorizontalScroll(),model.width-vw)))
        viewport:SetVerticalScroll(max(0,min(viewport:GetVerticalScroll(),model.height-vh)))
    end
    local function Center(n)
        if not model then return end
        n=n or model.nodes[1];if not n then return end
        viewport:SetHorizontalScroll(max(0,min(n.cx-vw/2,model.width-vw)))
        viewport:SetVerticalScroll(max(0,min(n.cy-vh/2,model.height-vh)))
    end
    local function Fit()
        local probe=B.Project(view,names,focus,1,1,1,own)
        if not probe then return 1 end
        -- Large draws are pannable, not unreadably tiny overviews.
        if probe.count>8 then return 1 end
        return max(.8,min(1,vw/probe.width,vh/probe.height))
    end
    Render=function(recenter)
        model=B.Project(view,names,focus,vw,vh,zoom,own)
        if not model then board:Hide();return false end
        canvas:SetSize(model.width,model.height)
        if viewport.UpdateScrollChildRect then viewport:UpdateScrollChildRect() end
        local k=0
        for _,e in ipairs(model.edges) do
            local mid=(e.x1+e.x2)/2
            k=k+1;Line(k,e.x1,e.y1,mid,e.y1,e.focus,e.completed)
            k=k+1;Line(k,mid,e.y1,mid,e.y2,e.focus,e.completed)
            k=k+1;Line(k,mid,e.y2,e.x2,e.y2,e.focus,e.completed)
        end
        for i=k+1,#lines do lines[i].core:Hide();lines[i].glow:Hide() end
        for i,m in ipairs(model.nodes) do Paint(m,i) end
        for i=#model.nodes+1,#cards do cards[i]:Hide() end
        for i,m in ipairs(model.headers) do Header(i,m) end
        for i=#model.headers+1,#headers do headers[i]:Hide() end
        if recenter then Center(model.focus) else Clamp() end
        local p=projection
        title:SetText(p.event.draft.name or "Tournament")
        if S.ConstrainText then S.ConstrainText(title,max(1,vw*.66),30,15) end
        meta:SetText("Single elimination  •  Best of "..tostring(p.event.draft.bestOf or "—").."  •  "..model.count.." Players")
        legend:SetText(p.scope=="SIMULATED" and "LOCAL TEST · Sample class icons" or "Gold: your path")
        return true
    end
    Pan=function(dx,dy)
        if not model then return end
        viewport:SetHorizontalScroll(max(0,min(viewport:GetHorizontalScroll()+dx,model.width-vw)))
        viewport:SetVerticalScroll(max(0,min(viewport:GetVerticalScroll()+dy,model.height-vh)))
    end
    Wheel=function(delta)
        if not model then return end
        autoFit=false
        local nextZoom=max(.8,min(1.3,zoom+delta*.1))
        if nextZoom==zoom then return end
        local oldW,oldH=model.width,model.height
        local x=(viewport:GetHorizontalScroll()+vw/2)/oldW
        local y=(viewport:GetVerticalScroll()+vh/2)/oldH
        zoom=nextZoom
        if Render(false) then
            viewport:SetHorizontalScroll(max(0,min(x*model.width-vw/2,model.width-vw)))
            viewport:SetVerticalScroll(max(0,min(y*model.height-vh/2,model.height-vh)))
        end
    end
    local function StopDrag()
        dragX=nil;canvas:SetScript("OnUpdate",nil)
    end
    canvas:EnableMouse(true);canvas:EnableMouseWheel(true)
    canvas:SetScript("OnMouseDown",function(_,button)
        if button~="LeftButton" or not model then return end
        dragX,dragY=GetCursorPosition();dragH,dragV=viewport:GetHorizontalScroll(),viewport:GetVerticalScroll()
        canvas:SetScript("OnUpdate",function()
            if not dragX or not canvas:IsVisible() or not IsMouseButtonDown("LeftButton") then StopDrag();return end
            local x,y=GetCursorPosition();local scale=viewport:GetEffectiveScale()
            if scale<=0 then return end
            viewport:SetHorizontalScroll(max(0,min(dragH+(dragX-x)/scale,model.width-vw)))
            viewport:SetVerticalScroll(max(0,min(dragV+(y-dragY)/scale,model.height-vh)))
        end)
    end)
    canvas:SetScript("OnMouseUp",StopDrag);canvas:SetScript("OnHide",StopDrag)
    canvas:SetScript("OnMouseWheel",function(_,delta) Wheel(delta) end)
    viewport:EnableMouseWheel(true);viewport:SetScript("OnMouseWheel",function(_,delta) Wheel(delta) end)
    local fit=S.Action(controls,"Fit view","footer",{plate="browseCard",text=C.pale,edge=C.goldDim,hover=C.gold,tooltip=false})
    fit:SetScript("OnClick",function() if model then autoFit=true;zoom=Fit();Render(true) end end)
    local center=S.Action(controls,"My match","footer",{plate="browseCard",text=C.pale,edge=C.goldDim,hover=C.gold,tooltip=false})
    center:SetScript("OnClick",function() if model and model.focus then Center(model.focus) end end)
    function D.Hide()
        StopDrag();board:Hide();model,view,names,focus,event,own,projection=nil,nil,nil,nil,nil,nil,nil;zoom=1;autoFit=true
        for _,pool in ipairs({cards,headers}) do for _,f in ipairs(pool) do f:Hide() end end
        for _,t in ipairs(lines) do t.core:Hide();t.glow:Hide() end
        if ns.CompetitiveUI then ns.CompetitiveUI.CloseTournamentPlayerCard() end
    end
    function D.Show(p,w,h)
        if not p or not p.bracket or not p.event or not p.event.draft then D.Hide();return false end
        local changed=event~=p.event.id
        local nextFocus=p.match and p.match.id
        local recenter=changed or focus~=nextFocus
        if changed then zoom=1;autoFit=true end
        event=p.event.id;view=p.bracket;names=p.names;focus=nextFocus;own=p.member and p.member.guid;projection=p
        local bw,bh=max(1,w-20),max(1,h-54)
        At(board,parent,10,44,bw,bh)
        At(arena,board,5,5,bw-10,bh-10);At(shade,board,5,5,bw-10,bh-10)
        local ratio=max(1,bw-10)/max(1,bh-10)
        local cropW,cropH=.25,.25
        if ratio>2 then cropH=cropH*2/ratio else cropW=cropW*ratio/2 end
        arena:SetTexCoord(.625-cropW/2,.625+cropW/2,.375-cropH/2,.375+cropH/2)
        At(banner,board,7,7,bw-14,64)
        At(leftArt,banner,6,4,(bw-14)*.30,56);At(rightArt,banner,(bw-14)*.70-6,4,(bw-14)*.30,56)
        At(title,banner,(bw-14)*.17,4,(bw-14)*.66,31);At(meta,banner,10,35,bw-34,22)
        local oldW,oldH=vw,vh
        vw=max(1,bw-16);vh=max(1,bh-110)
        At(viewport,board,8,76,vw,vh)
        At(controls,board,8,bh-31,vw,26)
        At(fit,controls,0,0,82,24);At(center,controls,86,0,90,24);center:SetShown(nextFocus~=nil)
        local narrow=vw<640
        legend:SetShown(not narrow);At(legend,controls,185,0,max(1,vw-445),24)
        At(hint,controls,narrow and 180 or vw-254,0,narrow and vw-180 or 254,24)
        hint:SetText(narrow and "Drag · Wheel zoom" or "Drag to pan · Mouse wheel to zoom")
        if autoFit and (recenter or oldW~=vw or oldH~=vh) then zoom=Fit() end
        board:Show()
        return Render(recenter or autoFit and (oldW~=vw or oldH~=vh))
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
        assert(#m.nodes==1 and #m.edges==0 and #m.headers==0 and m.nodes[1].cx==450)
    end)
    Case("ready and completed score, focus and dispute from snapshot",function()
        local v=Fixture(2,2);local r=v.rounds[1][1]
        r.a,r.b,r.state,r.wins="P1","P2","ready",{1,0}
        local m=B.Project(v,{P1="First",P2="Second"},r.id,400,200,1)
        assert(m.focus.a=="First" and m.focus.sa=="1" and m.focus.status=="Match ready")
        m=B.Project(v,{P1="First"},r.id,400,200,1,"P1")
        assert(m.focus.ownA and not m.focus.ownB and m.focus.final and m.focus.h>100)
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
