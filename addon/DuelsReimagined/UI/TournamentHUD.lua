local _,ns=...
-- A distinct presentation, not a new duel engine. DuelHUD alone selects
-- which HUD is active. This view consumes a detached tournament snapshot.
local B={};ns.TournamentHUD=B
local W,H=900,156
local S=ns.Style
local C=S and S.color
local Settings=ns.Settings
local root,fields,draft,editing
local fixtureTimer
local function Round(m)
    local remaining=m.roundCount-m.round
    return remaining==0 and "Final" or remaining==1 and "Semifinal" or remaining==2 and "Quarterfinal" or "Round of "..2^(remaining+1)
end
function B.Project(p)
    if type(p)~="table" or p.scope~="SIMULATED" or (p.role~="player" and p.role~="host" and p.role~="spectator")
        or type(p.bracket)~="table" or type(p.event)~="table" or type(p.event.id)~="string"
        or type(p.event.draft)~="table" or type(p.event.draft.name)~="string" then return nil end
    local v=p.bracket
    if v.state~="running" and v.state~="disputed" then return nil end
    local rows=v.rounds
    if type(rows)~="table" or #rows<1 or #rows>6 then return nil end
    local m
    for _,round in ipairs(rows) do
        for _,row in ipairs(round) do
            if row.id==p.selected and row.state=="ready" then m=row;break end
        end
    end
    if not m and v.dispute then
        for _,round in ipairs(rows) do for _,row in ipairs(round) do if row.id==v.dispute.match then m=row end end end
    end
    if not m then
        return {title=p.event.draft.name,round="Tournament",left="Awaiting match",right="Awaiting match",
            bestOf=v.bestOf,score=0,opponentScore=0,game=1,status="Waiting for next match",key=p.event.id..":waiting",
            scope="SIMULATED",broadcast=p.broadcast,canPlay=false,viewer=p.role}
    end
    local function Whole(n,lo,hi) return type(n)=="number" and n>=lo and n<=hi and n==math.floor(n) end
    local best=v.bestOf
    if not (best==1 or best==3 or best==5) or not Whole(m.round,1,#rows) or type(m.wins)~="table" then return nil end
    local needed=math.floor(best/2)+1
    if not Whole(m.wins[1],0,needed) or not Whole(m.wins[2],0,needed) then return nil end
    local names=p.names or {}
    local own=p.role=="player" and p.match and p.match.id==m.id
    local swap=own and p.member and m.b==p.member.guid and not p.broadcast
    local left,right=swap and m.b or m.a,swap and m.a or m.b
    local sa,sb=m.wins[swap and 2 or 1],m.wins[swap and 1 or 2]
    local status
    if v.state=="disputed" then status="Match on hold"
    elseif p.broadcast or p.role=="spectator" then status="Featured match ready"
    elseif own then status="It's your turn!"
    elseif p.role=="host" then status="Featured match ready"
    elseif p.state=="eliminated" then status="Eliminated - watching"
    else status="Waiting for your turn" end
    local demo=p.demo and p.demo.match==m.id and p.demo
    local offline=p.offline and p.offline.match==m.id and p.offline
    local hpA,hpB,elapsed
    if demo then
        elapsed=demo.elapsed
        local progress=math.min(1,elapsed/demo.duration)
        hpA=math.floor(100-progress*(demo.winner==left and 54 or 100))
        hpB=math.floor(100-progress*(demo.winner==right and 54 or 100))
        status="Simulated fight"
    elseif offline then
        status="Reconnecting "..string.format("%02d:%02d",math.floor(offline.remaining/60),offline.remaining%60)
    end
    return {title=p.event.draft.name,round=Round({round=m.round,roundCount=#rows}),bestOf=best,
        game=sa+sb+1,left=names[left] or "Awaiting player",right=names[right] or "Awaiting player",
        score=sa,opponentScore=sb,status=status,key=p.event.id..":"..m.id,scope="SIMULATED",
        own=not not own,matchID=m.id,canPlay=v.state=="running",broadcast=p.broadcast,viewer=p.role,
        readyCount=p.readyCount or 0,leftGuid=left,rightGuid=right,
        demo=not not demo,offline=not not offline,hpA=hpA,hpB=hpB,elapsed=elapsed}
end
local function At(f,p,x,y,w,h)
    f:ClearAllPoints();f:SetPoint("TOPLEFT",p,"TOPLEFT",x,-y);f:SetSize(w,h)
end
local function Text(p,x,y,w,h,size,color,align)
    local f=S.Text(p,"",size,color)
    f:SetJustifyH(align or "CENTER");f:SetWordWrap(false)
    At(f,p,x,y,w,h)
    return f
end
local function Emblem(p,x,y,w,h)
    local t=p:CreateTexture(nil,"OVERLAY")
    ns.TournamentUI.PaintEmblem(t);At(t,p,x,y,w,h)
    return t
end
local function Side(p,enemy)
    local side={}
    local cx=enemy and 776 or 124
    local tx=enemy and 566 or 156
    local ring=CreateFrame("Frame",nil,p);At(ring,p,cx-24,54,48,48)
    side.icon=ring:CreateTexture(nil,"ARTWORK")
    At(side.icon,ring,1,1,46,46)
    if ring.CreateMaskTexture and side.icon.AddMaskTexture then
        pcall(function()
            local mask=ring:CreateMaskTexture()
            mask:SetTexture("Interface\\AddOns\\DuelsReimagined\\Media\\Skin\\DuelHUDPortraitMask.png","CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE")
            mask:SetAllPoints(side.icon);side.icon:AddMaskTexture(mask);side.mask=mask
        end)
    end
    side.name=Text(p,tx,61,178,21,16,C.pale,enemy and "RIGHT" or "LEFT")
    if S.ConstrainText then S.ConstrainText(side.name,178,21,10) end
    local track=CreateFrame("Frame",nil,p);At(track,p,tx,85,178,17)
    local skin=track:CreateTexture(nil,"BACKGROUND")
    skin:SetTexture("Interface\\AddOns\\DuelsReimagined\\Media\\Skin\\DuelHUDPremiumParts.png")
    skin:SetTexCoord(26.5/1024,309.5/1024,292.5/512,329.5/512);skin:SetAllPoints(track)
    side.hp=CreateFrame("StatusBar",nil,track);At(side.hp,track,4,3,170,11)
    side.hp:SetStatusBarTexture("Interface\\AddOns\\DuelsReimagined\\Media\\Skin\\DuelHUDHealthFill.png")
    side.hp:SetMinMaxValues(0,100);side.hp:SetStatusBarColor(1,1,1)
    local overlay=CreateFrame("Frame",nil,track)
    overlay:SetFrameLevel(side.hp:GetFrameLevel()+1);overlay:SetAllPoints(track)
    side.health=Text(overlay,0,0,178,17,10,C.text)
    return side
end
local function Build()
    if root then return end
    root=CreateFrame("Frame","DuelsReimaginedTournamentHUD",UIParent)
    root:SetSize(W,H);root:SetFrameStrata("MEDIUM");root:SetClampedToScreen(true);root:EnableMouse(false);root:Hide()
    if ns.DiagnosticAudit then ns.DiagnosticAudit.RegisterUIRoot("Tournament HUD",root) end
    local art=root:CreateTexture(nil,"BACKGROUND")
    art:SetTexture("Interface\\AddOns\\DuelsReimagined\\Media\\Skin\\DuelTournamentScoreboard.tga")
    art:SetTexCoord(0,900/1024,0,156/256);art:SetAllPoints(root)
    ns.Chrome.Sharp(art)
    local front=CreateFrame("Frame",nil,root);front:SetAllPoints(root)
    front:SetFrameLevel(root:GetFrameLevel()+2);front:EnableMouse(false)
    Emblem(front,48,66,40,32);Emblem(front,812,66,40,32)
    Emblem(front,428,0,44,31)
    local left=Side(front,false);local right=Side(front,true)
    local vs=Text(front,402,67,96,38,24,C.gold);vs:SetText("VS")
    local title=Text(front,310,23,280,22,19,C.pale)
    if S.ConstrainText then S.ConstrainText(title,280,22,11) end
    local format=Text(front,310,43,280,15,11,C.pale)
    local score=Text(front,350,67,44,34,24,C.text)
    local opponentScore=Text(front,506,67,44,34,24,C.text)
    local game=Text(front,173,113,166,23,12,C.pale)
    local status=Text(front,340,110,220,29,17,C.gold)
    local sim=S.Action(front,"Simulate game","footer",{plate="dark",text=C.pale,edge=C.goldDim,hover=C.gold,tooltip=false})
    At(sim,front,574,113,149,23)
    sim:SetScript("OnClick",function()
        if editing or not ns.DuelHUD or not ns.DuelHUD.IsTournamentHUDActive() then return end
        local ok,why=B.RequestGame()
        if not ok and ns.Feedback then ns.Feedback.Toast(why or "Test game unavailable",sim) end
    end)
    local test=Text(front,10,129,134,20,10,C.muted);test:SetText("LOCAL TEST")
    fields={left=left,right=right,title=title,format=format,score=score,opponentScore=opponentScore,game=game,status=status,sim=sim}
end
local function Layout()
    Build()
    local x,y,scale=Settings.GetVisualLayout("tournamentHUD")
    if draft then x,y,scale=unpack(draft) end
    local w,h=UIParent:GetWidth(),UIParent:GetHeight()
    x,y,scale=Settings.ClampVisualLayout(x,y,scale,w,h,W,H)
    if not x then return end
    root:SetScale(scale);root:ClearAllPoints()
    root:SetPoint("CENTER",UIParent,"BOTTOMLEFT",w*x/scale,h*y/scale)
end
local function Paint(m)
    fields.title:SetText(m.title);fields.format:SetText(m.round.."  -  Best of "..m.bestOf)
    fields.left.name:SetText(m.left);fields.right.name:SetText(m.right)
    fields.score:SetText(tostring(m.score));fields.opponentScore:SetText(tostring(m.opponentScore))
    fields.game:SetText(m.elapsed and string.format("%02d:%02d",math.floor(m.elapsed/60),m.elapsed%60) or m.bestOf==1 and "" or "Game "..m.game)
    fields.status:SetText(m.status)
    -- Class icons are illustrative, never a real player/class lookup.
    local classes={"WARRIOR","MAGE","ROGUE","PRIEST","DRUID","SHAMAN","WARLOCK","HUNTER","PALADIN"}
    local function Icon(side,name)
        local seed=0;for i=1,#name do seed=seed+name:byte(i) end
        local path="Interface\\Icons\\ClassIcon_"..classes[seed%#classes+1]
        if not SetPortraitToTexture or not pcall(SetPortraitToTexture,side.icon,path) then side.icon:SetTexture(path) end
    end
    Icon(fields.left,m.left);Icon(fields.right,m.right)
    for i,side in ipairs({fields.left,fields.right}) do
        local hp=i==1 and m.hpA or m.hpB
        if hp~=nil then
            side.hp:SetValue(hp);side.hp:Show();side.health:SetText(hp.."% (test)")
        else
            side.hp:SetValue(0);side.hp:Hide();side.health:SetText("Health unavailable")
        end
    end
    fields.sim:SetShown(not editing and m.canPlay==true and not m.broadcast)
    fields.sim:SetEnabled(not m.demo and not m.offline)
end
local function SafeIdle()
    local ok,v=pcall(InCombatLockdown)
    if not ok then return false end
    if type(issecretvalue)=="function" then
        local safe,secret=pcall(issecretvalue,v)
        if not safe or secret then return false end
    end
    if v~=false then return false end
    local d=ns.DuelDetection.GetSnapshot()
    return d and d.state=="idle" and not d.active and not d.challenge
end
-- The existing countdown timer owns completion; no second timer or
-- fabricated detector events. Revalidate the assignment before scoring.
local function StopFixtureTimer()
    if fixtureTimer then fixtureTimer:Cancel();fixtureTimer=nil end
end
local function PresentResult(result)
    if result and ns.DuelResult then ns.DuelResult.ShowTournamentPreview(result) end
end
local function RefreshFixtureTimer(m)
    if not m or not (m.demo or m.offline) or editing then StopFixtureTimer();return end
    if fixtureTimer or not C_Timer or type(C_Timer.NewTimer)~="function" then return end
    local action=m.demo and "tick-demo" or "tick-grace"
    fixtureTimer=C_Timer.NewTimer(1,function()
        fixtureTimer=nil
        if not ns.DuelHUD.IsTournamentHUDActive() or not SafeIdle() then
            ns.TournamentRegistration.CancelBroadcastFixture();ns.DuelHUD.Refresh();return
        end
        local ok,why,result,notice=ns.TournamentRegistration.PreviewAction(action)
        if ns.TournamentUI.RefreshActive then ns.TournamentUI.RefreshActive() end
        if notice and ns.Notifications and ns.Notifications.OnTournamentGrace then ns.Notifications.OnTournamentGrace(notice) end
        if ok then PresentResult(result) else
            ns.TournamentRegistration.CancelBroadcastFixture();ns.DuelHUD.Refresh()
        end
    end)
end
function B.GetDiagnosticResources() return {subscriptions=0,timers=fixtureTimer and 1 or 0} end
function B.RequestGame()
    if editing or not ns.DuelHUD.IsTournamentHUDActive() or not SafeIdle() then return false,"No assigned test match." end
    local R=ns.TournamentRegistration
    local m=B.Project(R.PreviewSnapshot())
    if not m or not m.canPlay or m.demo or m.offline then return false,"No ready test match." end
    local function Finish()
        local current=B.Project(R.PreviewSnapshot())
        if not ns.DuelHUD.IsTournamentHUDActive() or not current or not current.canPlay or current.key~=m.key or current.game~=m.game or not SafeIdle() then return false,"Test match changed." end
        local ok,why=R.PreviewAction("start-demo")
        if ns.TournamentUI.RefreshActive then ns.TournamentUI.RefreshActive() end
        return ok,why
    end
    if ns.DuelCountdown.IsTournamentPreviewRunning() then return false,"Countdown already running." end
    if ns.DuelResult then ns.DuelResult.ClearTournamentPreview() end
    if not Settings.Get("duelCountdownVisual") then return Finish() end
    return ns.DuelCountdown.PreviewTournament(Finish)
end
function B.Frame() return root end
function B.Show(m)
    Build()
    if not editing then Layout();Paint(m);RefreshFixtureTimer(m) end
    root:Show()
    return root
end
function B.Hide()
    if root and not editing then root:Hide() end
    StopFixtureTimer()
    if ns.TournamentRegistration then ns.TournamentRegistration.CancelBroadcastFixture() end
    if ns.DuelCountdown then ns.DuelCountdown.CancelTournamentPreview() end
end
function B.Relayout()
    if root and root:IsShown() then Layout() end
end
function B.IsEditing() return editing==true end
function B.LayoutSize() return W,H end
function B.SetLayoutDraft(x,y,scale)
    if not editing then
        StopFixtureTimer()
        ns.TournamentRegistration.CancelBroadcastFixture()
        ns.DuelCountdown.CancelTournamentPreview()
    end
    editing=true;draft={x,y,scale};Layout()
end
function B.ShowLayoutSample()
    if not editing then return false end
    Build();Layout()
    Paint({title="Iron Ring Cup",round="Semifinal",bestOf=3,game=2,left="Test player",right="Ashwarden",score=1,opponentScore=0,status="Match ready"})
    -- Explicit editor-only sample values, never copied to the actual HUD.
    for _,side in ipairs({fields.left,fields.right}) do side.hp:SetValue(100);side.hp:Show();side.health:SetText("100%") end
    root:Show();return true
end
function B.EndLayoutDraft()
    editing=nil;draft=nil
    if root then root:Hide() end
    if ns.DuelHUD then ns.DuelHUD.Refresh() end
end
function B.RunSelfTest(emit)
    emit=type(emit)=="function" and emit or function()end
    local pass,fail=0,0
    local function Case(name,fn)
        local ok,err=pcall(fn);if ok then pass=pass+1 else fail=fail+1 end
        emit("DR | SIMULATED | "..(ok and "PASS " or "FAIL ")..name..(ok and "" or ": "..tostring(err)))
    end
    local function Fixture()
        return {scope="SIMULATED",role="player",state="competing",event={id="test",draft={name="Test Cup"}},
            member={name="You",guid="A"},names={A="You",B="Other",C="Third",D="Fourth"},
            bracket={state="running",bestOf=3,rounds={{},{ {id="m1",round=2,state="ready",a="B",b="A",wins={0,1}} },{}}},
            match={id="m1"},selected="m1",readyCount=1}
    end
    Case("persistent competitor, organizer and spectator projection",function()
        local p=Fixture();assert(B.Project(p).own)
        p.role="host";p.match=nil;assert(B.Project(p).viewer=="host")
        p.role="spectator";p.broadcast=true;assert(B.Project(p).broadcast)
        p.role="player";p.broadcast=false;p.state="eliminated";assert(B.Project(p).status=="Eliminated - watching")
        p.bracket.state="completed";assert(not B.Project(p))
        p=Fixture();p.scope="LOCAL";assert(not B.Project(p))
    end)
    Case("series score, game, round and viewing priority",function()
        local p=Fixture();local m=B.Project(p)
        assert(m.game==2 and m.round=="Semifinal" and m.score==1 and m.opponentScore==0 and m.left=="You")
        p.broadcast=true;m=B.Project(p);assert(m.left=="Other" and m.score==0)
        p.bracket.rounds={{ {id="m1",round=1,state="ready",a="A",b="B",wins={0,0}} }}
        p.bracket.bestOf=1;m=B.Project(p);assert(m.game==1 and m.round=="Final" and m.bestOf==1)
        p.selected=nil;p.match=nil;m=B.Project(p);assert(m and not m.canPlay)
    end)
    return pass,fail
end
if ns.Diagnostics then
    ns.Diagnostics.Register("Tournament scoreboard / isolated projection QA","deep",function()
        local log={};local p,f=B.RunSelfTest(function(line)log[#log+1]=line end)
        return f==0 and p==2 and "PASS" or "FAIL",string.format("%d passed / %d failed (SIMULATED)\n",p,f)..table.concat(log,"\n")
    end)
end
