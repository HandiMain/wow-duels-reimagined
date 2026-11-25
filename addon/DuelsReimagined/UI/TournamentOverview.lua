local _,ns=...
-- Tournament Overview: one read-only projection and one responsive native view.
-- The decorative atlas was extracted from the approved Overview concepts.
local O={};ns.TournamentOverview=O
local S,C=ns.Style,ns.Style.color
local ART="Interface\\AddOns\\DuelsReimagined\\Media\\Skin\\TournamentOverviewArt.png"
local GREEN={.53,1,.14,1}
local GOLD=C.pale
local function CountSlots(v)
    if type(v)~="table" or type(v.slots)~="table" then return nil end
    local n=0;for _,guid in ipairs(v.slots) do if type(guid)=="string" then n=n+1 end end
    return n
end
local function RoundName(r,n)
    if r==n then return "Final" elseif r==n-1 then return "Semifinal" elseif r==n-2 then return "Quarterfinal" end
    return "Round "..r
end
local function Minutes(seconds)
    if type(seconds)~="number" then return "Unavailable" end
    if seconds<=0 then return "Now" end
    local m=math.ceil(seconds/60)
    if m>=60 then return math.floor(m/60).."h "..(m%60).."m" end
    return m.." min"
end
-- Read the canonical bracket, never infer a duel result from a bye or forfeit.
local function Results(v,guid)
    local wins,losses,lossRound=0,0,nil
    local gone,roundLosses,roundDone=0,0,true
    local n=CountSlots(v)
    for r,round in ipairs(v.rounds or {}) do
        for _,m in ipairs(round) do
            if m.state=="done" and not m.bye and (m.a==guid or m.b==guid) and m.winner then
                if not m.forfeit then
                    if m.winner==guid then wins=wins+1 else losses=losses+1 end
                end
                if m.winner~=guid then lossRound=r end
            end
        end
    end
    local place="Not finalized"
    if v.state=="completed" and v.champion==guid then place="Champion"
    elseif lossRound then
        if lossRound==#v.rounds then place="Runner-up"
        else
            for r=1,lossRound do
                for _,m in ipairs(v.rounds[r]) do
                    if m.state=="done" then
                        if not m.bye and m.a and m.b and m.winner then
                            gone=gone+1;if r==lossRound then roundLosses=roundLosses+1 end
                        end
                    elseif r==lossRound then roundDone=false end
                end
            end
            if n and roundDone and roundLosses>0 then
                place=(roundLosses>1 and "Tied #" or "#")..(n-gone+1)
            else place=RoundName(lossRound,#v.rounds).." exit" end
        end
    end
    return {placement=place,won=wins,lost=losses,rate=wins+losses>0 and math.floor(wins*100/(wins+losses)+.5).."%" or "—",players=n,eliminated=lossRound~=nil}
end
local function Metric(m,label,value,good)
    m.metrics[#m.metrics+1]={label=label,value=tostring(value or "—"),good=good==true}
end
function O.Project(p,hasListings)
    local m={state="idle",title="No active tournament",banner="Browse tournaments or host your own.",
        heading="Compete",description="Find tournaments, register, and join duels against other players.",
        step=hasListings and 1 or 0,status="No active registration",hint="Browse tournaments to find and join one.",
        primary="Browse Tournaments",primaryAction="browse",summary="Your Tournament Status",metrics={},
        bottom="No upcoming match.",test=hasListings and "LOCAL TEST" or nil}
    if type(p)~="table" then
        if hasListings then m.banner="Local test only - nothing published online." end
        return m
    end
    local ad=p.event;local draft=ad and ad.draft or {}
    local v=p.bracket;local member=p.member
    m.test=p.scope=="SIMULATED" and "LOCAL TEST" or p.scope=="PRIVATE_TEST" and "PRIVATE TEST" or nil
    m.event=draft.name or "Tournament details unavailable"
    m.banner=m.event..(m.test and "  •  "..m.test or "")
    m.bottom="No upcoming match."
    m.bottomAction="details";m.bottomButton="My Tournament"
    if p.role=="host" or p.role=="spectator" then
        local host=p.role=="host"
        m.state=host and "host" or "watching";m.title=host and "Tournament Organizer" or "Watching Tournament"
        m.heading=host and "Organize" or "Spectate";m.description=host and "Manage participants and follow the tournament." or "Follow the bracket and featured matches."
        m.status=v and (v.state=="completed" and "Tournament complete" or "Tournament in progress") or "Registration open"
        m.hint=host and "Open your tournament to manage the event." or "Follow the remaining matches."
        m.primary=host and "Manage Tournament" or "View Bracket";m.primaryAction=host and "manage" or "brackets"
        m.bottomButton=m.primary;m.bottomAction=m.primaryAction
        if ad then Metric(m,"Registered",ad.count);Metric(m,"Format",draft.bestOf and "Best of "..draft.bestOf);Metric(m,"Capacity",draft.capacity) end
        if v and v.state=="completed" and v.champion then Metric(m,"Champion",p.names and p.names[v.champion]) end
        return m
    end
    if not member then
        if p.registrationPending then
            m.state="pending";m.title="Registration pending";m.status="Awaiting organizer confirmation";m.hint="Refresh your tournament to check the response."
            m.bottomButton="My Tournament";m.bottomAction="details";return m
        end
        -- A catalog preview without a confirmed registration is not a competitor.
        m.event=nil;m.title="No active tournament";m.banner=m.test and "Local test only - nothing published online." or m.banner
        m.bottomAction=nil;m.bottomButton=nil;return m
    end
    m.step=member.checkedIn and 3 or 2
    local registered=member.checkedIn and "Checked In" or "Registered"
    local untilStart=type(p.now)=="number" and type(draft.startAt)=="number" and draft.startAt-p.now or nil
    local untilCheck=untilStart and untilStart-1800
    if not v then
        if member.checkedIn then
            m.state="checked";m.title="Checked In - Awaiting Start";m.status="You're checked in!"
            m.hint="The tournament will begin soon. Get ready for your first match!"
            m.banner=m.event.."  •  "..(untilStart and untilStart>0 and "Starts in "..Minutes(untilStart) or untilStart and "Awaiting organizer start" or "Start time unavailable")
            m.bottomButton="View Bracket";m.bottomAction="brackets";m.bottomDisabled=true
        else
            m.state="registered";m.title="Registration Confirmed";m.status="You're registered"
            m.hint="Check-in will open soon. Prepare for the tournament!"
            if untilCheck and untilCheck<=0 and untilStart>0 then
                m.title="Check In Now";m.status="Check-in is open";m.hint="Confirm your participation before the tournament begins."
                m.bottomButton="Check In";m.bottomAction="checkin"
            elseif untilStart and untilStart<=0 then m.hint="The scheduled start has passed. Check your registration status." end
        end
        Metric(m,"Registration","Registered",true)
        Metric(m,member.checkedIn and "Check-In" or "Check-in Opens",member.checkedIn and "Checked In" or (untilCheck and untilCheck<=0 and untilStart<=0 and "Closed" or Minutes(untilCheck)),member.checkedIn)
        if member.checkedIn then Metric(m,"Starts In",Minutes(untilStart)) end
        Metric(m,"Format",draft.bestOf and "Best of "..draft.bestOf)
        Metric(m,"Players",ad and ad.count)
        if not member.checkedIn then Metric(m,"Next Opponent","Not assigned yet") end
        return m
    end
    local result=Results(v,member.guid)
    local champion=v.state=="completed" and v.champion==member.guid
    if champion or result.eliminated then
        m.state=champion and "champion" or "eliminated";m.step=4
        m.title=champion and "TOURNAMENT CHAMPION!" or (v.state=="completed" and "TOURNAMENT COMPLETE" or "YOUR TOURNAMENT HAS ENDED")
        m.heading=champion and "Tournament Complete" or "Tournament Result"
        m.description=champion and "The tournament has ended. Congratulations on your victory!" or "Thank you for your participation!"
        m.status=champion and "Champion" or "Eliminated";m.art=m.state
        m.summary=champion and "Your Tournament Result" or "Your Tournament Summary"
        Metric(m,"Final Placement",result.placement,champion)
        Metric(m,"Matches",result.won.." - "..result.lost)
        Metric(m,"Win Rate",result.rate)
        Metric(m,"Players",result.players)
        m.bottomButton=v.state~="completed" and "Continue Watching" or "View Results";m.bottomAction="brackets"
        m.primary=nil;m.primaryAction=nil
        return m
    end
    local own
    if p.match then
        for _,round in ipairs(v.rounds or {}) do for _,row in ipairs(round) do if row.id==p.match.id then own=row end end end
    end
    if own and own.state=="ready" and (own.a==member.guid or own.b==member.guid) and not p.held and v.state=="running" then
        m.state="upnext";m.step=3;m.title=m.event
        local first=own.a==member.guid;local peer=first and own.b or own.a
        local opponent=p.match.opponent or p.names and p.names[peer] or "Opponent unavailable"
        local ready=p.scope=="SIMULATED" or p.assignmentStatus=="Both players ready" or p.observedDuel
        m.banner=p.observedDuel and "Duel in progress" or ready and "You are up next" or "Your match is ready - check with the organizer"
        m.status=ready and "Remain nearby and prepare for your call." or "Confirm your readiness with the organizer."
        m.hint="";m.primary="View Match Details";m.primaryAction="details"
        m.match={{label="Opponent",value=opponent},{label="Round",value=RoundName(own.round,#v.rounds)},
            {label="Format",value="Best of "..v.bestOf},{label="Series",value=own.wins[first and 1 or 2].." - "..own.wins[first and 2 or 1]}}
        Metric(m,"Registration","Confirmed",true);Metric(m,"Check-In","Confirmed",true)
        Metric(m,"Opponent",opponent);Metric(m,"Match Status",p.observedDuel and "In progress" or ready and "Up next" or "Ready")
        m.bottomButton="View Match";m.bottomAction="details"
        return m
    end
    m.state="waiting";m.title=(p.held or v.state=="disputed") and "Match on hold" or "Waiting for your turn"
    m.status=p.upcoming and "Get ready for the next round" or "Waiting for your match"
    m.hint=p.upcoming and "Your opponent is being decided." or "Follow the bracket while you wait."
    m.primary="View Bracket";m.primaryAction="brackets";m.bottomButton="View Bracket";m.bottomAction="brackets"
    Metric(m,"Registration",registered,true);Metric(m,"Format",draft.bestOf and "Best of "..draft.bestOf);Metric(m,"Players",result.players)
    Metric(m,"Next Opponent","Not assigned yet")
    return m
end

-- Actual crop geometry (1024 x 512 atlas). All dynamic copy/buttons are native.
local rects={bannerL={0,0,456,100},bannerR={464,0,428,100},host={0,112,151,125},trophy={160,112,154,128},
    swords={320,112,59,52},browse={384,112,45,44},register={432,112,45,44},checkin={480,112,43,40},
    compete={528,112,47,44},calendar={576,112,39,40},tick={624,112,24,26},flag={656,112,82,110},
    cornerFlag={752,112,60,159},champion={0,280,512,115},eliminated={0,400,512,112},info={576,160,37,35}}
local function At(f,p,x,y,w,h)
    f:ClearAllPoints();f:SetPoint("TOPLEFT",p,"TOPLEFT",x,-y);f:SetSize(math.max(1,w),math.max(1,h))
end
local function Label(p,sz,color,align)
    local f=S.Text(p,"",sz,color);f:SetJustifyH(align or "LEFT");f:SetJustifyV("MIDDLE");f:SetWordWrap(true);return f
end
local function Text(f,p,x,y,w,h,value,color)
    At(f,p,x,y,w,h);f:SetText(value or "");if color then f:SetTextColor(unpack(color)) end
end
local function Art(p,key,layer)
    local t=p:CreateTexture(nil,layer or "ARTWORK");t:SetTexture(ART);ns.Chrome.Sharp(t)
    local r=rects[key];t:SetTexCoord(r[1]/1024,(r[1]+r[3])/1024,r[2]/512,(r[2]+r[4])/512);return t
end
local function SetArt(t,key)
    local r=rects[key];t:SetTexCoord(r[1]/1024,(r[1]+r[3])/1024,r[2]/512,(r[2]+r[4])/512)
end
local function Panel(p,bright)
    local f=CreateFrame("Frame",nil,p)
    S.Skin(f,C.body,{corner=13,edge=bright and C.gold or C.goldDim,light=C.goldDim,dark=C.window,shine=.12,shade=.16,rim=.96})
    return f
end
local function Button(p,primary,small)
    local palette={text=C.pale,edge=primary and C.gold or C.goldDim,hover=C.gold,tooltip=false,
        fontSize=small and 18 or primary and 23 or 21,minimumFont=13,refitOnText=true,
        feedback={hoverAlpha=.55,downAlpha=.82,downHover=.88,clickAlpha=.86,corner=9}}
    if primary then
        -- Rounded native relief eliminates the old opaque black atlas fringe.
        palette.fill=C.button;palette.light=C.red;palette.dark=C.header
        palette.corner=9;palette.shine=.60;palette.shade=.25;palette.rim=1
    else palette.plate="dark" end
    local b=S.Action(p,"","footer",palette)
    if ns.Tooltips then ns.Tooltips.Bind(b,function(owner)
        if owner:IsEnabled() then return nil end
        return {title=owner.overviewCaption,disabled=owner.overviewReason}
    end) end
    return b
end
local function Bind(b,caption,enabled,action,cb)
    b.overviewCaption=caption;b.overviewReason=action=="brackets" and "The bracket will be available when the tournament starts." or "Unavailable while your current tournament is active."
    b.label:SetText(caption or "");b:SetShown(caption~=nil);b:SetEnabled(enabled==true)
    b:SetScript("OnClick",function()if enabled and action then cb(action) end end)
    b:SetAlpha(enabled and 1 or .52)
end
local function Cell(p)
    return {label=Label(p,14,C.pale,"CENTER"),value=Label(p,19,C.text,"CENTER"),rule=S.Fill(p,C.goldDim,"BORDER")}
end
local function PaintCell(c,p,x,y,w,h,data,divider)
    local show=data~=nil;c.label:SetShown(show);c.value:SetShown(show);c.rule:SetShown(show and divider)
    if not show then return end
    Text(c.label,p,x+3,y,w-6,24,data.label)
    Text(c.value,p,x+3,y+25,w-6,h-25,data.value,data.good and GREEN or C.pale)
    At(c.rule,p,x,y+6,1,h-10);c.rule:SetAlpha(.5)
end
local function Side(parent,icon,title,desc)
    local f=Panel(parent,true)
    return {frame=f,art=Art(f,icon),flag=Art(f,"cornerFlag","BACKGROUND"),title=Label(f,25,C.pale),
        desc=Label(f,16,C.text),button=Button(f,false),name=title,description=desc}
end
local function PaintSide(d,x,y,w,h,caption,enabled,action,cb)
    local f=d.frame;At(f,f:GetParent(),x,y,w,h)
    At(d.flag,f,w-63,6,58,h-12);d.flag:SetAlpha(.75)
    At(d.art,f,19,(h-125)/2,151,125)
    Text(d.title,f,190,15,w-205,36,d.name)
    Text(d.desc,f,190,52,w-212,55,d.description)
    At(d.button,f,190,h-56,w-217,40);Bind(d.button,caption,enabled,action,cb)
end
local steps={{"Browse","Discover available\ntournaments.","browse"},{"Register","Sign up for a\ntournament.","register"},
    {"Check In","Confirm your\nparticipation.","checkin"},{"Compete","Fight through the\nbracket and climb!","compete"}}
function O.New(parent,cb)
    local f=CreateFrame("Frame",nil,parent);f:Hide()
    local banner=Panel(f,true);local l,r=Art(banner,"bannerL"),Art(banner,"bannerR")
    local bannerTitle,bannerText=Label(banner,28,C.pale,"CENTER"),Label(banner,18,C.text,"CENTER")
    local bannerIcon=Art(banner,"info")
    local main=Panel(f,true);local mainIcon=Art(main,"swords")
    local heading,desc=Label(main,28,C.pale),Label(main,16,C.text)
    local line=S.Fill(main,C.goldDim,"BORDER");line:SetAlpha(.6)
    local stepFrames={}
    for i,s in ipairs(steps) do
        stepFrames[i]={art=Art(main,s[3]),tick=Art(main,"tick"),label=Label(main,18,C.pale,"CENTER"),desc=Label(main,15,C.muted,"CENTER"),arrow=i<4 and Label(main,23,C.gold,"CENTER") or nil}
    end
    local primary=Button(main,true)
    local rule=ns.Chrome.Divider(main,400,12)
    local note,subnote=Label(main,20,C.pale,"CENTER"),Label(main,15,C.muted,"CENTER")
    local resultArt=Art(main,"champion")
    local match=Panel(main,false);local matchCells={};for i=1,4 do matchCells[i]=Cell(match) end
    local host=Side(f,"host","Host Tournament","Create and run a custom tournament\nfor your community or friends.")
    local champions=Side(f,"trophy","Hall of Champions","View past tournament champions\nand their achievements.")
    local bottom=Panel(f,false);local flag,calendar=Art(bottom,"flag"),Art(bottom,"calendar")
    local summary,event,scope=Label(bottom,20,C.pale),Label(bottom,23,C.text),Label(bottom,14,C.muted)
    local blank=Label(bottom,16,C.muted);local cells={};for i=1,5 do cells[i]=Cell(bottom) end
    local bottomButton=Button(bottom,true)
    local localEnd=Button(f,false,true)
    local D={};local clockTimer
    local function StopClock() if clockTimer then clockTimer:Cancel();clockTimer=nil end end
    f:HookScript("OnHide",StopClock)
    function D.Hide() StopClock();f:Hide() end
    function D.Show(m,w,can,localTest,refresh)
        local wide=w>=760;local base=wide and 1264 or 710;local scale=w/base
        local gap=12;local bannerH=110;local mainW=wide and 718 or base;local sideW=wide and base-mainW-gap or base
        local midH=364;local sideH=(midH-gap)/2;local bodyY=bannerH+gap
        local bottomY=bodyY+midH+(wide and 0 or 2*(sideH+gap))+gap
        local hasEvent=m.event~=nil;local bottomH=hasEvent and (wide and 118 or 220) or 58
        local total=bottomY+bottomH+(localTest and 43 or 0)
        f:SetScale(scale);At(f,parent,0,0,base,total);f:Show()
        At(banner,f,0,0,base,bannerH)
        local bw=base*(wide and .36 or .29);At(l,banner,4,4,bw,bannerH-8);At(r,banner,base-bw-4,4,bw,bannerH-8)
        -- Center the visible title and icon together, not the icon at the
        -- edge of an oversized invisible label box.
        local showIcon=m.state~="champion" and m.state~="eliminated"
        local icon=(m.state=="registered" or m.state=="checked" or m.state=="upnext") and "tick" or "info"
        local titleW=wide and base*.40 or base*.50
        local shift=showIcon and 19 or 0
        Text(bannerTitle,banner,(base-titleW)/2+shift,12,titleW,52,m.title,GOLD)
        if S.ConstrainText then S.ConstrainText(bannerTitle,titleW,52,18) end
        local width
        if bannerTitle.GetStringWidth then
            local ok,value=pcall(bannerTitle.GetStringWidth,bannerTitle)
            local readable=ok
            if readable and type(issecretvalue)=="function" then
                local checked,secret=pcall(issecretvalue,value);readable=checked and not secret
            end
            if readable and type(value)=="number" and value>0 then width=math.min(value,titleW) end
        end
        width=width or math.min(titleW,#m.title*14)
        SetArt(bannerIcon,icon)
        At(bannerIcon,banner,base/2+shift-width/2-36,24,27,27)
        bannerIcon:SetShown(showIcon)
        Text(bannerText,banner,base*.20,60,base*.60,33,m.banner,m.state=="upnext" and GREEN or C.text)
        At(main,f,0,bodyY,mainW,midH);At(mainIcon,main,20,15,59,52)
        Text(heading,main,91,9,mainW-104,37,m.heading)
        Text(desc,main,91,45,mainW-104,31,m.description)
        At(line,main,14,80,mainW-28,1)
        local stepY=m.state=="eliminated" and 253 or 94
        local compact=m.state=="eliminated";local cellW=(mainW-38)/4
        for i,row in ipairs(stepFrames) do
            local center=19+(i-.5)*cellW
            At(row.art,main,center-22,stepY,44,42)
            At(row.tick,main,center+18,stepY,22,24);row.tick:SetShown(i<=m.step)
            Text(row.label,main,center-cellW/2+2,stepY+42,cellW-4,24,steps[i][1],C.pale)
            Text(row.desc,main,center-cellW/2+3,stepY+65,cellW-6,compact and 35 or 45,steps[i][2])
            if row.arrow then Text(row.arrow,main,center+cellW/2-12,stepY+19,24,32,"»",C.gold) end
        end
        resultArt:SetShown(m.art~=nil);match:SetShown(m.match~=nil)
        if m.art then
            SetArt(resultArt,m.art);At(resultArt,main,18,m.state=="eliminated" and 90 or 216,mainW-36,m.state=="eliminated" and 151 or 140)
        end
        if m.match then
            At(match,main,16,207,mainW-32,75)
            for i,c in ipairs(matchCells) do local cw=(mainW-32)/4;PaintCell(c,match,(i-1)*cw,4,cw,65,m.match[i],i>1) end
        end
        local actionY=m.match and 292 or 225
        At(primary,main,mainW*.19,actionY,mainW*.62,46)
        Bind(primary,m.primary,m.primaryAction and can(m.primaryAction),m.primaryAction,cb)
        rule:SetShown(not m.art and not m.match);At(rule,main,mainW*.08,285,mainW*.84,12)
        note:SetShown(not m.art);subnote:SetShown(not m.art and m.hint~="")
        Text(note,main,12,m.match and 337 or 300,mainW-24,m.match and 22 or 30,m.status,m.step>=2 and GREEN or GOLD)
        Text(subnote,main,15,328,mainW-30,27,m.hint)
        local sx=wide and mainW+gap or 0;local sy=wide and bodyY or bodyY+midH+gap
        PaintSide(host,sx,sy,sideW,sideH,"Host Tournament",can("host"),"host",cb)
        PaintSide(champions,sx,sy+sideH+gap,sideW,sideH,"Hall of Champions",can("champions"),"champions",cb)
        At(bottom,f,0,bottomY,base,bottomH)
        flag:SetShown(hasEvent);calendar:SetShown(not hasEvent)
        At(flag,bottom,12,6,82,106);At(calendar,bottom,21,10,39,40)
        Text(summary,bottom,hasEvent and 106 or 76,hasEvent and 9 or 10,hasEvent and base-120 or 270,38,m.summary)
        event:SetShown(hasEvent);scope:SetShown(hasEvent);blank:SetShown(not hasEvent)
        Text(event,bottom,106,44,wide and 196 or base-125,36,m.event)
        Text(scope,bottom,106,82,wide and 194 or base-125,21,m.test or "")
        Text(blank,bottom,385,10,base-400,38,m.bottom)
        local showAction=hasEvent and m.bottomButton~=nil
        local metricCount=#m.metrics
        if wide then
            local x=310;local endX=base-(showAction and 200 or 12);local cw=metricCount>0 and (endX-x)/metricCount or 0
            for i,c in ipairs(cells) do PaintCell(c,bottom,x+(i-1)*cw,42,cw,63,m.metrics[i],true) end
            At(bottomButton,bottom,base-191,55,177,42)
        else
            local cw=(base-24)/math.max(1,metricCount)
            for i,c in ipairs(cells) do PaintCell(c,bottom,12+(i-1)*cw,114,cw,58,m.metrics[i],i>1) end
            At(bottomButton,bottom,base*.25,177,base*.50,37)
        end
        Bind(bottomButton,showAction and m.bottomButton or nil,showAction and not m.bottomDisabled and can(m.bottomAction),m.bottomAction,cb)
        At(localEnd,f,base-184,total-33,184,29);Bind(localEnd,localTest and "End Local Test" or nil,localTest,"end-test",cb)
        if m.test=="PRIVATE TEST" and (m.state=="registered" or m.state=="checked") and f:IsVisible() and C_Timer and type(C_Timer.NewTimer)=="function" and refresh then
            if not clockTimer then clockTimer=C_Timer.NewTimer(15,function() clockTimer=nil;if f:IsVisible() then refresh() end end) end
        else StopClock() end
        return total*scale
    end
    return D
end

function O.RunSelfTest()
    local p={scope="SIMULATED",role="player",event={count=2,draft={name="Cup",startAt=10000,bestOf=3}},now=7000,
        member={guid="A",checkedIn=false},names={A="You",B="Peer"}}
    assert(O.Project(nil).state=="idle")
    assert(O.Project(p).state=="registered" and O.Project(p).step==2)
    p.now=9000;assert(O.Project(p).bottomAction=="checkin")
    p.member.checkedIn=true;assert(O.Project(p).state=="checked" and O.Project(p).bottomDisabled)
    p.bracket={state="running",bestOf=3,slots={"A","B"},rounds={{{id="R1M1",round=1,a="A",b="B",state="ready",wins={1,0}}}}}
    p.match={id="R1M1"};assert(O.Project(p).state=="upnext" and O.Project(p).match[4].value=="1 - 0")
    local v=p.bracket;local row=v.rounds[1][1];row.state="done";row.winner="A";v.state="completed";v.champion="A"
    assert(O.Project(p).state=="champion" and O.Project(p).metrics[2].value=="1 - 0")
    row.winner="B";v.champion="B";assert(O.Project(p).state=="eliminated" and O.Project(p).bottomButton=="View Results")
    row.forfeit={loser="A"};assert(O.Project(p).metrics[2].value=="0 - 0" and O.Project(p).metrics[3].value=="—")
    p.role="host";assert(O.Project(p).state=="host" and not O.Project(p).art)
    p.role="spectator";assert(O.Project(p).state=="watching" and not O.Project(p).art)
    return true
end
if ns.Diagnostics then
    ns.Diagnostics.Register("Tournament overview / isolated presentation QA","health",function()
        local ok,why=pcall(O.RunSelfTest);return ok and "PASS" or "FAIL",ok and "Overview states, result provenance and controls." or tostring(why)
    end)
end
