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
function A.New(parent)
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
    local heroScene=ConceptArt(hero,LEGACY,0,384/512,0,146/256)
    local heroFade=hero:CreateTexture(nil,"ARTWORK");heroFade:SetColorTexture(1,1,1,1)
    if heroFade.SetGradient and CreateColor then heroFade:SetGradient("HORIZONTAL",CreateColor(.075,.055,.035,0),CreateColor(.075,.055,.035,1)) else heroFade:Hide() end
    local heroRule=RulePair(hero)
    local heroLaurel=ConceptArt(hero,LEGACY,348/512,384/512,40/256,132/256,"ARTWORK")
    heroLaurel:SetTexCoord(384/512,348/512,40/256,132/256)
    local heroCaption=Text(hero,16,GOLD,"CENTER");local heroName=Text(hero,25,C.pale,"CENTER")
    local heroDetail=Text(hero,17,GOLD,"CENTER")
    local timelineTitle=Text(shell,22,GOLD)
    local legacy=Panel(shell,"organizerHero")
    local flag=ConceptArt(legacy,LEGACY,0,192/512,150/256,1,"ARTWORK")
    local legacyRule=RulePair(legacy)
    local legacyFoot=Text(legacy,16,C.muted,"CENTER")
    local legacyTitle=Text(legacy,23,GOLD,"CENTER")
    local legacyHint=Text(legacy,15,C.muted,"CENTER")
    local stats={}
    for i,key in ipairs({"Played","Won","Hosted","Best Placement"}) do
        local icon=i==1 and Art(legacy,320,112,59,52) or i==3 and Art(legacy,480,112,43,40) or Art(legacy,160,112,154,128)
        stats[i]={icon=icon,label=Text(legacy,17,C.text),value=Text(legacy,24,GOLD,"RIGHT"),rule=Line(legacy,{.65,.43,.17,.38}),key=key}
    end
    local rail=Line(shell,{.81,.54,.18,.65})
    local cards={}
    local function Card(i)
        if cards[i] then return cards[i] end
        local f=Panel(shell,"browseCard")
        f.marker=Jewel(shell)
        f.sep1=Line(f,{.63,.42,.20,.38});f.sep2=Line(f,{.63,.42,.20,.38})
        f.flag=Art(f,656,112,82,110)
        f.name=Text(f,20,C.pale);f.date=Text(f,14,C.muted)
        f.placeLabel=Text(f,13,C.muted,"CENTER");f.place=Text(f,18,GOLD,"CENTER")
        f.champLabel=Text(f,13,C.muted);f.champ=Text(f,17,C.text)
        f.details=Text(f,13,C.muted)
        f.result=chrome.Action(f,false,17)
        f.result.label:SetText("View Results");f.result:SetEnabled(false);f.result:SetAlpha(.58)
        if ns.Tooltips then ns.Tooltips.Bind(f.result,{title="View Results",disabled="Detailed results are not available in this build."}) end
        cards[i]=f;return f
    end
    local function PaintRow(row,r,x,y,w,compact)
        local h=compact and 132 or 84
        At(row,shell,x,y,w,h);At(row.marker,shell,x-24,y+(h-16)/2,16,16);row.marker:Show();row:Show()
        At(row.flag,row,8,8,48,64)
        local placement,color=Placement(r)
        if compact then
            local left=w*.56
            Put(row.name,row,65,5,left-70,30,r.title)
            Put(row.date,row,65,35,left-70,22,Date(r.finishedAt))
            Put(row.details,row,65,58,left-70,43,tostring(r.count).." players · Best of "..tostring(r.bestOf or "—"))
            Put(row.placeLabel,row,left,4,w-left-8,18,"Your placement")
            Put(row.place,row,left,21,w-left-8,28,placement,color)
            Put(row.champLabel,row,left+4,53,w-left-10,18,"Champion")
            Put(row.champ,row,left+4,70,w-left-12,34,r.champion)
            At(row.result,row,w-130,101,120,25);row.result:Show()
            row.sep1:Hide();row.sep2:Hide()
        else
            local titleW=math.floor(w*.34);local placeW=math.floor(w*.18);local champX=titleW+placeW
            Put(row.name,row,65,5,titleW-72,34,r.title)
            Put(row.date,row,65,38,titleW-72,20,Date(r.finishedAt))
            Put(row.details,row,65,58,titleW-72,20,tostring(r.count).." players · Best of "..tostring(r.bestOf or "—"))
            Put(row.placeLabel,row,titleW,9,placeW-6,22,"Your placement")
            Put(row.place,row,titleW,31,placeW-6,40,placement,color)
            Put(row.champLabel,row,champX+5,9,w-champX-135,22,"Champion")
            Put(row.champ,row,champX+5,31,w-champX-135,40,r.champion)
            At(row.result,row,w-122,24,112,35);row.result:Show()
            At(row.sep1,row,titleW-4,12,1,h-24);row.sep1:Show()
            At(row.sep2,row,champX-2,12,1,h-24);row.sep2:Show()
        end
        return h
    end
    local D={}
    function D.Hide() root:Hide() end
    function D.Show(rows,scope,reason,width,viewportH)
        local base,wide,scale=chrome.LayoutWidth(width,1140)
        local m=A.Project(rows);local count=#m.rows
        local gap=12;local sidebar=wide and 264 or base-24
        local leftW=wide and base-sidebar-gap-24 or base-24
        local compact=leftW<820
        local rowH=compact and 132 or 84
        local listY=274
        local artH=math.floor((base-12)*367/1024+.5)
        local contentH=count==0 and math.max(56+artH+130,viewportH/scale-8) or math.max(listY+count*(rowH+10)+16,wide and 620 or 0)
        local legacyY=wide and 58 or contentH+10
        local total=count==0 and contentH or wide and contentH or contentH+388
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
            At(hero,shell,12,58,leftW,178)
            local artW=math.min(leftW*.46,448);local artHeight=artW*146/384
            At(heroScene,hero,4,(178-artHeight)/2,artW,artHeight)
            At(heroFade,hero,artW-22,5,28,168)
            local tx=artW+10;local tw=leftW-tx-12
            Put(heroCaption,hero,tx,15,tw,29,m.best and "YOUR BEST RESULT" or "YOUR TOURNAMENT LEGACY")
            RuleAt(heroRule,hero,tx+tw*.08,47,tw*.84)
            local laurelW=tw>=330 and 32 or 0
            heroLaurel:SetShown(laurelW>0);At(heroLaurel,hero,leftW-42,59,32,80)
            Put(heroName,hero,tx,55,tw-laurelW,55,m.best and m.best.title or "Organizer")
            local bestLabel=m.best and Placement(m.best) or "Hosted tournaments"
            Put(heroDetail,hero,tx,111,tw-laurelW,48,m.best and (bestLabel.." · "..Date(m.best.finishedAt)) or bestLabel)
            Put(timelineTitle,shell,14,239,leftW,30,"Your Legacy Timeline")
            At(rail,shell,24,listY+8,2,math.max(1,count*(rowH+10)-20))
            for i,r in ipairs(m.rows) do PaintRow(Card(i),r,42,listY+(i-1)*(rowH+10),leftW-30,compact) end
            local lx=wide and 12+leftW+gap or 12
            local lh=wide and math.max(550,contentH-70) or 368
            At(legacy,shell,lx,legacyY,sidebar,lh)
            local fw=math.min(sidebar-16,220)
            At(flag,legacy,(sidebar-fw)/2,6,fw,fw*106/192)
            Put(legacyTitle,legacy,8,130,sidebar-16,34,"Your Legacy")
            Put(legacyHint,legacy,8,164,sidebar-16,26,"Personal Tournament Archive")
            RuleAt(legacyRule,legacy,16,195,sidebar-32)
            local bestValue=m.best and (m.best.placement==1 and "1st" or m.best.placement==2 and "2nd" or "Top "..m.best.placement) or "—"
            local values={m.played,m.won,m.hosted,bestValue}
            if wide then
                for i,v in ipairs(stats) do
                    local y=205+(i-1)*60
                    At(v.icon,legacy,13,y+12,26,25)
                    Put(v.label,legacy,46,y,sidebar-130,50,v.key)
                    Put(v.value,legacy,sidebar-101,y,91,50,tostring(values[i]))
                    At(v.rule,legacy,12,y+55,sidebar-24,1)
                end
            else
                local cw=(sidebar-24)/2
                for i,v in ipairs(stats) do
                    local x=12+((i-1)%2)*cw;local y=205+math.floor((i-1)/2)*60
                    At(v.icon,legacy,x+4,y+12,26,25)
                    Put(v.label,legacy,x+35,y,cw-133,50,v.key)
                    Put(v.value,legacy,x+cw-96,y,89,50,tostring(values[i]))
                    At(v.rule,legacy,x+4,y+55,cw-8,1)
                end
            end
            legacyFoot:SetShown(wide)
            if wide then Put(legacyFoot,legacy,18,457,sidebar-36,76,"A record of your tournament journey, victories, and greatest results.") end
        end
        for i=count+1,#cards do cards[i]:Hide();cards[i].marker:Hide() end
        return total*scale
    end
    return D
end
function A.RunSelfTest()
    local a={id="1",played=true,placement=4};local b={id="2",played=true,placement=1}
    local c={id="3",hosted=true};local d={id="4",played=true,hosted=true,placement=2}
    local m=A.Project({a,b,c,d,b,{id="5"}})
    assert(#m.rows==4 and m.played==3 and m.won==1 and m.hosted==2 and m.best==b)
    assert(A.Project({c}).best==nil and #A.Project({}).rows==0)
    return true
end
