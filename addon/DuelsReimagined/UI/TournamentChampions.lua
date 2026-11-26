local _,ns=...
-- Personal archive presentation only; no storage, network or tournament authority.
local A={};ns.TournamentChampions=A
local S,C=ns.Style,ns.Style.color
local chrome=ns.TournamentBrowse.Chrome
local ROOT="Interface\\AddOns\\DuelsReimagined\\Media\\"
local ART=ROOT.."Skin\\TournamentOverviewArt.png"
local MONUMENT=ROOT.."Skin\\ChampionsMonument.png"
local LEGACY=ROOT.."Skin\\ChampionsLegacy.png"
local JEWEL=ROOT.."Skin\\DuelCornerJewel.tga"
local GOLD={1,.79,.32,1}
local SILVER={.78,.81,.86,1}
local BRONZE={.85,.55,.30,1}
local function At(f,p,x,y,w,h)
    f:ClearAllPoints();f:SetPoint("TOPLEFT",p,"TOPLEFT",x,-y);f:SetSize(math.max(1,w),math.max(1,h))
end
local function Text(p,size,color,align)
    local t=S.Text(p,"",size,color);t:SetJustifyH(align or "LEFT");t:SetJustifyV("MIDDLE");t:SetWordWrap(true);return t
end
local function Put(t,p,x,y,w,h,value,color)
    At(t,p,x,y,w,h);t:SetText(value or "")
    if color then t:SetTextColor(unpack(color)) end
end
local function Art(p,x,y,w,h,layer,sub)
    local t=p:CreateTexture(nil,layer or "ARTWORK",nil,sub or 0);t:SetTexture(ART)
    t:SetTexCoord(x/1024,(x+w)/1024,y/512,(y+h)/512);ns.Chrome.Sharp(t);return t
end
local function Panel(p,style)
    local f=CreateFrame("Frame",nil,p)
    S.Plate(f,style or "organizerPanel",{corner=12,layer="BACKGROUND",sublevel=0})
    return f
end
local function Line(p,color)
    local t=p:CreateTexture(nil,"BORDER");t:SetColorTexture(unpack(color));return t
end
local function Date(n)
    if not n or type(date)~="function" then return "Date unavailable" end
    local ok,v=pcall(date,"%b %d, %Y",n);return ok and v or "Date unavailable"
end
local function Placement(r)
    if not r.played then return "Organizer",C.muted end
    if r.placement==1 then return "Champion",GOLD end
    if r.placement==2 then return "Runner-up",SILVER end
    if r.placement==4 then return "Top 4",BRONZE end
    if r.placement then return "Top "..r.placement,C.text end
    return "Unavailable",C.muted
end
function A.Project(rows)
    local m={rows={},played=0,won=0,hosted=0}
    local seen={}
    for _,r in ipairs(rows or {}) do
        if type(r.id)=="string" and not seen[r.id] and (r.played or r.hosted) then
            seen[r.id]=true;m.rows[#m.rows+1]=r
            if r.played then
                m.played=m.played+1
                if r.placement==1 then m.won=m.won+1 end
                if r.placement and (not m.best or r.placement<m.best.placement) then m.best=r end
            end
            if r.hosted then m.hosted=m.hosted+1 end
        end
    end
    return m
end
-- Artwork extracted directly from the two approved concept images.
-- Text remains native; the scene never contains player names or results.
local function ConceptArt(p,path,u1,u2,v1,v2,layer)
    local t=p:CreateTexture(nil,layer or "BACKGROUND",nil,1)
    t:SetTexture(path);t:SetTexCoord(u1,u2,v1,v2);ns.Chrome.Sharp(t);return t
end
-- Separate the trophy artwork from the neighboring atlas ornaments.
local SURFACE={.086,.059,.039}
local function Surface(p)
    local t=p:CreateTexture(nil,"BACKGROUND",nil,1)
    t:SetPoint("TOPLEFT",p,"TOPLEFT",4,-4);t:SetPoint("BOTTOMRIGHT",p,"BOTTOMRIGHT",-4,4)
    t:SetColorTexture(SURFACE[1],SURFACE[2],SURFACE[3],1)
end
local function Blend(p,horizontal,reverse)
    local t=p:CreateTexture(nil,"ARTWORK",nil,0);t:SetColorTexture(1,1,1,1)
    if t.SetGradient and CreateColor then
        local clear=CreateColor(SURFACE[1],SURFACE[2],SURFACE[3],0)
        local opaque=CreateColor(SURFACE[1],SURFACE[2],SURFACE[3],1)
        t:SetGradient(horizontal and "HORIZONTAL" or "VERTICAL",reverse and opaque or clear,reverse and clear or opaque)
    else t:Hide() end
    return t
end
local function TrophyArt(p)
    local t=ConceptArt(p,LEGACY,0,338/512,0,146/256,"BACKGROUND")
    t:SetDrawLayer("BACKGROUND",2)
    return t,Blend(p,true,false)
end
local function TrophyAt(t,fade,p,w,h)
    local ah=math.min(h-8,w*146/338)
    local aw=ah*338/146;local y=(h-ah)/2
    At(t,p,4,y,aw,ah)
    local fadeW=math.min(55,aw)
    At(fade,p,4+aw-fadeW,y,fadeW,ah)
    return aw+4
end
function A.TimelineGeometry(w)
    if w<800 then
        return {compact=true,h=146,titleX=72,titleW=w-84,placementX=12,placementW=w*.26-12,
            championX=w*.28,championW=w*.72-148,buttonX=w-132,buttonW=120}
    end
    local identity=math.floor(w*.42)
    local placement=math.max(130,math.floor(w*.17))
    return {compact=false,h=104,titleX=68,titleW=identity-80,placementX=identity+3,placementW=placement-10,
        championX=identity+placement+10,championW=w-identity-placement-158,buttonX=w-136,buttonW=124}
end
local function GoldRule(p)
    local t=p:CreateTexture(nil,"BORDER")
    t:SetColorTexture(1,1,1,1)
    if t.SetGradient and CreateColor then
        t:SetGradient("HORIZONTAL",CreateColor(.45,.25,.08,0),CreateColor(1,.74,.27,.95))
    else t:SetColorTexture(.83,.52,.15,.72) end
    return t
end
local function Jewel(p)
    local t=p:CreateTexture(nil,"OVERLAY",nil,2);t:SetTexture(JEWEL);ns.Chrome.Sharp(t);return t
end
local function RulePair(p)
    local a=GoldRule(p);local b=GoldRule(p)
    if b.SetGradient and CreateColor then
        b:SetGradient("HORIZONTAL",CreateColor(1,.74,.27,.95),CreateColor(.45,.25,.08,0))
    end
    local jewel=Jewel(p)
    return {a=a,b=b,jewel=jewel}
end
local function RuleAt(r,p,x,y,w,soft)
    local half=math.max(1,w/2-7)
    local thickness=soft and 1 or 2
    At(r.a,p,x,y,half,thickness);At(r.b,p,x+w/2+7,y,half,thickness)
    At(r.jewel,p,x+w/2-8,y-7,16,16)
    r.a:SetAlpha(soft and .48 or 1);r.b:SetAlpha(soft and .48 or 1);r.jewel:SetAlpha(soft and .80 or 1)
end
function A.New(parent,onResults)
    local root=CreateFrame("Frame",nil,parent);root:Hide()
    local shell=Panel(root)
    local heading=Text(shell,25,GOLD);local mark=Art(shell,160,112,154,128)
    local scopeText=Text(shell,14,C.muted,"RIGHT")
    local rule=RulePair(shell)
    -- Empty-state header and artwork share one surface, not two hard-edged boxes.
    local emptyHeader=shell:CreateTexture(nil,"BACKGROUND",nil,2)
    emptyHeader:SetColorTexture(.071,.059,.047,1)
    local empty=CreateFrame("Frame",nil,shell)
    local scene=ConceptArt(empty,MONUMENT,0,1,0,367/512)
    local topFade=empty:CreateTexture(nil,"ARTWORK",nil,1);topFade:SetColorTexture(1,1,1,1)
    if topFade.SetGradient and CreateColor then
        topFade:SetGradient("VERTICAL",CreateColor(.071,.059,.047,0),CreateColor(.071,.059,.047,1))
    else topFade:Hide() end
    local floor=empty:CreateTexture(nil,"BACKGROUND",nil,0);floor:SetAllPoints();floor:SetColorTexture(.071,.059,.047,1)
    local fade=empty:CreateTexture(nil,"ARTWORK");fade:SetColorTexture(1,1,1,1)
    if fade.SetGradient and CreateColor then fade:SetGradient("VERTICAL",CreateColor(.071,.059,.047,1),CreateColor(.071,.059,.047,0)) else fade:Hide() end
    local emptyRule=RulePair(empty)
    local emptyTitle=Text(empty,24,GOLD,"CENTER")
    local emptyNote=Text(empty,17,C.text,"CENTER")
    local hero=Panel(shell,"organizerHero")
    Surface(hero)
    local heroScene,heroFade=TrophyArt(hero)
    local heroRule=RulePair(hero)
    local heroLaurelL=chrome.Art(hero,"laurelL");local heroLaurelR=chrome.Art(hero,"laurelR")
    local heroCaption=Text(hero,16,GOLD,"CENTER");local heroName=Text(hero,25,C.pale,"CENTER")
    local heroDetail=Text(hero,17,GOLD,"CENTER")
    local timelineTitle=Text(shell,22,GOLD)
    local legacy=Panel(shell,"organizerHero")
    Surface(legacy)
    local flag=ConceptArt(legacy,LEGACY,0,192/512,150/256,1,"BACKGROUND");flag:SetDrawLayer("BACKGROUND",2)
    local flagLeft,flagRight,flagBottom=Blend(legacy,true,true),Blend(legacy,true,false),Blend(legacy,false,true)
    local legacyRule=RulePair(legacy)
    local legacyFoot=Text(legacy,16,C.muted,"CENTER")
    local legacyTitle=Text(legacy,23,GOLD,"CENTER")
    local legacyHint=Text(legacy,15,C.muted,"CENTER")
    local stats={}
    for i,key in ipairs({"Played","Won","Hosted","Best Placement"}) do
        local icon=i==1 and Art(legacy,320,112,59,52) or i==3 and Art(legacy,480,112,43,40) or Art(legacy,160,112,154,128)
        stats[i]={icon=icon,label=Text(legacy,16,C.text),value=Text(legacy,22,GOLD,"RIGHT"),rule=Line(legacy,{.65,.43,.17,.38}),key=key}
    end
    local rail=Line(shell,{.81,.54,.18,.65})
    local cards={}
    local function Card(i)
        if cards[i] then return cards[i] end
        local f=Panel(shell,"browseCard")
        f.marker=Jewel(shell)
        f.sep1=Line(f,{.63,.42,.20,.38});f.sep2=Line(f,{.63,.42,.20,.38})
        f.logo=chrome.Art(f,"logo")
        f.name=Text(f,20,C.pale);f.date=Text(f,15,C.muted)
        f.placeLabel=Text(f,13,C.muted,"CENTER");f.place=Text(f,18,GOLD,"CENTER")
        f.champLabel=Text(f,13,C.muted);f.champ=Text(f,17,C.text)
        f.details=Text(f,14,C.muted)
        f.result=chrome.Action(f,false,17)
        f.result.label:SetText("View Results")
        f.result:SetScript("OnClick",function() if f.entry and onResults then onResults(f.entry.id,f.entry.scope) end end)
        if ns.Tooltips then ns.Tooltips.Bind(f.result,{title="View Results",detail="Inspect this completed tournament and its bracket."}) end
        cards[i]=f;return f
    end
    local function PaintRow(row,r,x,y,w,g)
        local h=g.h
        row.entry=r;row.result:SetEnabled(r.board~=nil);row.result:SetAlpha(r.board and 1 or .58)
        At(row,shell,x,y,w,h);At(row.marker,shell,x-24,y+(h-16)/2,16,16);row.marker:Show();row:Show()
        At(row.logo,row,10,g.compact and 12 or (h-46)/2,54,54*82/96)
        local placement,color=Placement(r)
        local titleH=g.compact and 38 or 44
        Put(row.name,row,g.titleX,6,g.titleW,titleH,r.title)
        if S.ConstrainText then S.ConstrainText(row.name,g.titleW,titleH,15) end
        Put(row.date,row,g.titleX,g.compact and 45 or 51,g.titleW,21,Date(r.finishedAt))
        Put(row.details,row,g.titleX,g.compact and 66 or 73,g.titleW,21,tostring(r.count).." players · Best of "..tostring(r.bestOf or "—"))
        local labelY=g.compact and 93 or 17
        local valueY=g.compact and 114 or 39
        local valueH=g.compact and 26 or 48
        Put(row.placeLabel,row,g.placementX,labelY,g.placementW,21,"Your placement")
        Put(row.place,row,g.placementX,valueY,g.placementW,valueH,placement,color)
        Put(row.champLabel,row,g.championX,labelY,g.championW,21,"Champion")
        Put(row.champ,row,g.championX,valueY,g.championW,valueH,r.champion)
        if S.ConstrainText then
            S.ConstrainText(row.champ,g.championW,valueH,13)
            S.ConstrainText(row.place,g.placementW,valueH,13)
        end
        At(row.result,row,g.buttonX,g.compact and 102 or (h-36)/2,g.buttonW,36);row.result:Show()
        row.sep1:SetShown(not g.compact);row.sep2:SetShown(not g.compact)
        if not g.compact then
            At(row.sep1,row,g.placementX-7,12,1,h-24)
            At(row.sep2,row,g.championX-7,12,1,h-24)
        end
        return h
    end
    local D={}
    function D.Hide() root:Hide();for _,card in ipairs(cards) do card.entry=nil end end
    function D.Show(rows,scope,reason,width,viewportH)
        local base,wide,scale=chrome.LayoutWidth(width,1160)
        local m=A.Project(rows);local count=#m.rows
        local gap=16;local sidebar=wide and 282 or base-24
        local leftW=wide and base-sidebar-gap-24 or base-24
        local rowW=leftW-30;local geometry=A.TimelineGeometry(rowW)
        local rowH=geometry.h;local listY=286
        local sidebarH=wide and 516 or 354
        local artH=math.floor((base-12)*367/1024+.5)
        local contentH=count==0 and math.max(56+artH+130,viewportH/scale-8) or math.max(listY+count*(rowH+12)+14,wide and 58+sidebarH+12 or 0)
        local legacyY=wide and 58 or contentH+10
        local total=count==0 and contentH or wide and contentH or contentH+sidebarH+22
        root:SetScale(scale);At(root,parent,0,0,base,total);At(shell,root,0,0,base,total);root:Show()
        At(mark,shell,12,9,35,31)
        Put(heading,shell,53,5,base-240,42,"Hall of Champions")
        Put(scopeText,shell,base-187,5,175,42,scope=="SIMULATED" and "LOCAL TEST" or scope=="PRIVATE_TEST" and "PRIVATE NETWORK TEST" or "Personal Archive")
        -- The short, softly lit ornament is not a horizontal panel boundary.
        RuleAt(rule,shell,count==0 and base*.23 or 12, count==0 and 40 or 48,count==0 and base*.54 or base-24,count==0)
        emptyHeader:SetShown(count==0)
        empty:SetShown(count==0);hero:SetShown(count>0);legacy:SetShown(count>0);timelineTitle:SetShown(count>0);rail:SetShown(count>0)
        if count==0 then
            local ew,eh=base-12,contentH-52
            At(emptyHeader,shell,6,5,ew,39)
            At(empty,shell,6,44,ew,eh)
            At(scene,empty,0,0,ew,artH)
            At(topFade,empty,0,0,ew,math.min(52,artH*.18))
            At(fade,empty,0,artH-18,ew,22)
            Put(emptyTitle,empty,12,artH+8,ew-24,42,reason and "Tournament history unavailable" or "NO COMPLETED TOURNAMENTS RECORDED")
            RuleAt(emptyRule,empty,ew*.24,artH+56,ew*.52)
            Put(emptyNote,empty,20,artH+65,ew-40,38,reason and "Your saved archive could not be read." or "Completed tournaments will appear here once they finish.")
        else
            At(hero,shell,12,58,leftW,188)
            local artW=math.min(leftW*.43,420)
            local edge=TrophyAt(heroScene,heroFade,hero,artW,188)
            local tx=edge+10;local tw=leftW-tx-12
            local hasLaurels=tw>=310
            local inset=hasLaurels and 34 or 0
            Put(heroCaption,hero,tx,12,tw,30,m.best and "YOUR BEST RESULT" or "YOUR TOURNAMENT LEGACY")
            RuleAt(heroRule,hero,tx+tw*.12,48,tw*.76,true)
            heroLaurelL:SetShown(hasLaurels);heroLaurelR:SetShown(hasLaurels)
            At(heroLaurelL,hero,tx,72,30,35)
            At(heroLaurelR,hero,leftW-42,72,32,35)
            Put(heroName,hero,tx+inset,53,tw-inset*2,67,m.best and m.best.title or "Organizer")
            if S.ConstrainText then S.ConstrainText(heroName,tw-inset*2,67,18) end
            local bestLabel=m.best and Placement(m.best) or "Hosted tournaments"
            Put(heroDetail,hero,tx+inset,125,tw-inset*2,44,m.best and (bestLabel.." · "..Date(m.best.finishedAt)) or bestLabel)
            Put(timelineTitle,shell,14,250,leftW,31,"Your Legacy Timeline")
            At(rail,shell,25,listY+rowH/2,2,math.max(1,(count-1)*(rowH+12)))
            rail:SetShown(count>1)
            for i,r in ipairs(m.rows) do PaintRow(Card(i),r,42,listY+(i-1)*(rowH+12),rowW,geometry) end
            local lx=wide and 12+leftW+gap or 12
            local lh=sidebarH
            At(legacy,shell,lx,legacyY,sidebar,lh)
            local fw=math.min(sidebar-20,220);local fx=(sidebar-fw)/2;local fh=fw*106/192
            At(flag,legacy,fx,5,fw,fh)
            At(flagLeft,legacy,fx,5,18,fh);At(flagRight,legacy,fx+fw-18,5,18,fh)
            At(flagBottom,legacy,fx,5+fh-18,fw,18)
            Put(legacyTitle,legacy,10,128,sidebar-20,32,"Your Legacy")
            Put(legacyHint,legacy,10,161,sidebar-20,26,"Personal Tournament Archive")
            RuleAt(legacyRule,legacy,22,193,sidebar-44,true)
            local bestValue=m.best and (m.best.placement==1 and "1st" or m.best.placement==2 and "2nd" or "Top "..m.best.placement) or "—"
            local values={m.played,m.won,m.hosted,bestValue}
            if wide then
                for i,v in ipairs(stats) do
                    local y=201+(i-1)*56
                    At(v.icon,legacy,18,y+13,25,25)
                    Put(v.label,legacy,51,y,sidebar-126,48,v.key)
                    Put(v.value,legacy,sidebar-73,y,55,48,tostring(values[i]))
                    if S.ConstrainText then S.ConstrainText(v.value,55,48,15) end
                    At(v.rule,legacy,18,y+50,sidebar-36,1)
                end
            else
                local cw=(sidebar-24)/2
                for i,v in ipairs(stats) do
                    local x=12+((i-1)%2)*cw;local y=201+math.floor((i-1)/2)*64
                    At(v.icon,legacy,x+4,y+12,26,25)
                    Put(v.label,legacy,x+35,y,cw-133,50,v.key)
                    Put(v.value,legacy,x+cw-96,y,89,50,tostring(values[i]))
                    At(v.rule,legacy,x+4,y+55,cw-8,1)
                end
            end
            legacyFoot:SetShown(wide)
            if wide then Put(legacyFoot,legacy,20,433,sidebar-40,68,"A record of your tournament journey, victories, and greatest results.") end
        end
        for i=count+1,#cards do cards[i].entry=nil;cards[i]:Hide();cards[i].marker:Hide() end
        return total*scale
    end
    return D
end
-- Archived results reuse the approved archive artwork and the existing read-only
-- bracket renderer. This view has no simulation, assignment or network actions.
function A.NewResults(parent)
    local root=CreateFrame("Frame",nil,parent);root:Hide()
    local shell=Panel(root)
    local title=Text(shell,21,GOLD)
    local emblem=chrome.Art(shell,"logo")
    local stamp=Text(shell,12,C.muted,"RIGHT")
    local hero=Panel(shell,"organizerHero")
    Surface(hero)
    local art,artFade=TrophyArt(hero)
    local cap=Text(hero,13,GOLD,"CENTER")
    local winner=Text(hero,24,GOLD,"CENTER")
    local versus=Text(hero,15,C.text,"CENTER")
    local meta=Text(hero,13,C.muted,"CENTER")
    local personal=Panel(shell)
    local personalTitle=Text(personal,18,GOLD)
    local summary=Text(personal,16,C.pale)
    local matchRows={}
    local boardParent=Panel(shell)
    local boardTitle=Text(boardParent,18,GOLD)
    local missing=Text(boardParent,15,C.muted,"CENTER")
    local board
    local function Match(i)
        if matchRows[i] then return matchRows[i] end
        local f=Panel(personal,"browseCard")
        f.round=Text(f,13,C.muted)
        f.name=Text(f,16,C.text)
        f.score=Text(f,16,C.pale,"CENTER")
        f.result=Text(f,14,C.pale,"RIGHT")
        matchRows[i]=f;return f
    end
    local D={}
    function D.Hide()
        if not root:IsShown() then return end
        if board then board.Hide() end
        root:Hide()
    end
    function D.Show(r,w,viewportH)
        local inside=math.max(1,w-24)
        local wide=inside>=650
        local headerH=wide and 150 or 184
        local matches=r.matches or {}
        local ph=76+#matches*(wide and 42 or 58)
        local by=52+headerH+12+ph+12
        local bh=math.max(460,viewportH-30)
        local total=by+bh+12
        At(root,parent,0,0,w,total);At(shell,root,0,0,w,total);root:Show()
        At(emblem,shell,12,6,38,33)
        Put(title,shell,58,5,w-230,39,"Completed Tournament")
        Put(stamp,shell,w-166,5,154,39,r.scope=="SIMULATED" and "LOCAL TEST" or "PRIVATE NETWORK TEST")
        At(hero,shell,12,52,inside,headerH)
        local aw=math.min(inside*.38,340)
        local edge=TrophyAt(art,artFade,hero,aw,headerH)
        local x=edge+10;local tw=inside-x-12
        Put(cap,hero,x,10,tw,24,r.title)
        Put(winner,hero,x,36,tw,41,r.champion or "Unknown player")
        local finalText=r.runner and ("Final: "..r.champion.." vs "..r.runner) or "Final opponent unavailable"
        if r.score then finalText=finalText.."  ·  "..r.score end
        if r.finalForfeit then finalText=finalText.."  ·  Forfeit" end
        Put(versus,hero,x,79,tw,wide and 30 or 52,finalText)
        Put(meta,hero,x,headerH-39,tw,33,Date(r.finishedAt).."  ·  "..tostring(r.count).." players  ·  Best of "..tostring(r.bestOf or "—"))
        At(personal,shell,12,52+headerH+12,inside,ph)
        Put(personalTitle,personal,12,5,inside-24,29,"Your Performance")
        local placement=Placement(r)
        local stat=r.played and (placement.."  ·  "..tostring(r.wins or 0).." matches won  ·  "..tostring(r.losses or 0).." lost") or "Organizer — no personal placement"
        Put(summary,personal,12,34,inside-24,34,stat)
        for i,m in ipairs(matches) do
            local f=Match(i);local h=wide and 36 or 52
            At(f,personal,10,70+(i-1)*(h+6),inside-20,h);f:Show()
            local rw=inside-20
            if wide then
                Put(f.round,f,10,0,rw*.22,h,m.round)
                Put(f.name,f,rw*.23,0,rw*.39,h,m.opponent)
                Put(f.score,f,rw*.63,0,rw*.14,h,m.score or "—")
                Put(f.result,f,rw*.78,0,rw*.21-6,h,m.forfeit and "Forfeit" or m.won and "Won" or "Lost",m.won and {.54,.90,.40,1} or C.muted)
            else
                Put(f.round,f,8,2,rw*.46,20,m.round)
                Put(f.name,f,8,23,rw*.60-8,25,m.opponent)
                Put(f.score,f,rw*.64,2,rw*.34,20,m.score or "—")
                Put(f.result,f,rw*.64,23,rw*.34,25,m.forfeit and "Forfeit" or m.won and "Won" or "Lost",m.won and {.54,.90,.40,1} or C.muted)
            end
        end
        for i=#matches+1,#matchRows do matchRows[i]:Hide() end
        At(boardParent,shell,12,by,inside,bh)
        Put(boardTitle,boardParent,12,5,inside-24,32,"Completed Bracket")
        if not board then board=ns.BracketView.New(boardParent) end
        local ok=r.board and board.Show(r.board,inside,bh-4)
        if not ok then board.Hide() end
        missing:SetShown(not ok)
        if not ok then Put(missing,boardParent,10,50,inside-20,100,"Completed bracket unavailable.") end
        return total
    end
    return D
end

function A.RunSelfTest()
    local a={id="1",played=true,placement=4};local b={id="2",played=true,placement=1}
    local c={id="3",hosted=true};local d={id="4",played=true,hosted=true,placement=2}
    local m=A.Project({a,b,c,d,b,{id="5"}})
    assert(#m.rows==4 and m.played==3 and m.won==1 and m.hosted==2 and m.best==b)
    assert(A.Project({c}).best==nil and #A.Project({}).rows==0)
    for _,w in ipairs({400,480,600,799,800,850,1100,1500}) do
        local g=A.TimelineGeometry(w)
        assert(g.titleW>0 and g.placementW>0 and g.championW>0)
        assert(g.championX+g.championW<=g.buttonX and g.buttonX+g.buttonW<=w)
        if not g.compact then assert(g.titleX+g.titleW<g.placementX and g.placementX+g.placementW<g.championX) end
    end
    return true
end
