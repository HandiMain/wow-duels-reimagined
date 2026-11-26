local _,ns=...
-- Read-only participant presentation. All actions route through TournamentUI.
local P={};ns.TournamentPlayer=P
local S,C=ns.Style,ns.Style.color
local chrome=ns.TournamentBrowse.Chrome
local ART="Interface\\AddOns\\DuelsReimagined\\Media\\Skin\\TournamentPlayerArt.png"
local GREEN={.59,1,.32,1};local GOLD={1,.79,.33,1};local RED={1,.40,.32,1}
local function Clock(n)
    n=math.max(0,math.floor(n or 0))
    return string.format("%02d:%02d:%02d",math.floor(n/3600),math.floor(n/60)%60,n%60)
end
local function Round(r,total)
    return r and (r==total and "Final" or "Round "..r) or "Not started"
end
function P.Project(p)
    if not p or (p.scope~="SIMULATED" and p.scope~="PRIVATE_TEST") or p.role~="player" or not p.member or not p.event then return nil end
    local d=p.event.draft;local v=p.bracket;local own=p.member.guid
    local private=p.scope=="PRIVATE_TEST"
    local m={name=d.name,location=d.location,players=p.event.count.." / "..d.capacity,
        format="Single elimination · Best of "..d.bestOf,bestOf=d.bestOf,
        levels=(d.minLevel>0 and d.minLevel or "Any").." - "..(d.maxLevel>0 and d.maxLevel or "Any"),
        rules=d.rules~="" and d.rules or "No additional rules",checked=p.member.checkedIn==true,
        round="Not started",score="—",record="—",result="Not started",actions={},step=1}
    if d.minLevel==0 and d.maxLevel==0 then m.levels="Any" end
    local before=d.startAt-p.now
    local check=before-1800
    m.registrationOpen=not v and p.now<d.registrationClosesAt
    m.state="readiness";m.status=m.checked and "Checked in" or "Registered"
    m.step=m.checked and 3 or 2
    if not v then
        if before<=0 then
            m.timerLabel="SCHEDULED START REACHED";m.timer="Ready";m.next=m.checked and "Await the organizer" or "Check-in closed";m.hint=m.checked and "Wait for the organizer to draw the bracket." or "You have not checked in before the start."
        elseif m.checked then
            m.timerLabel="TOURNAMENT STARTS IN";m.timer=Clock(before);m.next="Await tournament start";m.hint="You're checked in. Get ready for your first match."
        elseif check>0 then
            m.timerLabel="CHECK-IN OPENS IN";m.timer=Clock(check);m.next="Check in when it opens";m.hint="Confirm your participation before the tournament starts."
        else
            m.timerLabel="CHECK-IN CLOSES IN";m.timer=Clock(before);m.next="Check in now";m.hint="Confirm your participation before the tournament starts."
        end
    else
        local won,lost,exitRound,lastRound=0,0,nil,nil
        for i,round in ipairs(v.rounds or {}) do
            for _,r in ipairs(round) do
                if r.a==own or r.b==own then
                    if r.state=="done" and not r.bye and r.winner then
                        lastRound=i
                        if not r.forfeit then if r.winner==own then won=won+1 else lost=lost+1 end end
                        if r.winner~=own then exitRound=i end
                    end
                end
            end
        end
        m.record=won.." won / "..lost.." lost";m.step=4;m.state="progress"
        m.round=Round(lastRound,#(v.rounds or {}))
        m.result="In progress"
        if v.state=="completed" and v.champion==own then
            m.status="Tournament champion";m.result="Champion";m.next="Congratulations!";m.hint="You've won the tournament. View the final bracket.";m.timer="Champion";m.timerLabel="FINAL RESULT"
        elseif exitRound or p.state=="eliminated" then
            m.status="Eliminated";m.result=exitRound and Round(exitRound,#v.rounds).." exit" or "Eliminated"
            m.next=v.state=="completed" and "Tournament complete" or "Continue watching";m.hint="Your tournament has ended. View the bracket and remaining results.";m.timer="Eliminated";m.timerLabel="YOUR RESULT"
        elseif p.match and v.state=="running" then
            local r=p.match;m.state="match";m.round=Round(r.round,r.roundCount);m.score=r.score.." - "..r.opponentScore
            m.opponent=r.opponent;m.opponentLevel=p.opponent and p.opponent.level
            m.status="Match ready";m.next="Get ready to duel";m.hint=private and "Check the organizer’s assignment and confirm readiness." or "Your match is assigned. Local test only."
            if private and p.assignmentStatus then m.status=p.assignmentStatus;m.next=m.status end
            if p.offline and p.offline.match==r.id then
                m.status="Waiting for reconnect";m.next=m.status;m.hint=(private and "Organizer-reported reconnect time: " or "Simulated disconnect grace: ")..Clock(p.offline.remaining)
            elseif p.demo and p.demo.match==r.id then m.status="Simulated match in progress";m.next=m.status end
        elseif v.state=="disputed" then
            m.status="Match results under review";m.next="Wait for the organizer";m.hint="A disputed result must be resolved before play continues.";m.timer="Paused";m.timerLabel="TOURNAMENT STATUS"
        elseif v.state=="completed" then
            m.status="Tournament complete";m.result="Complete";m.next="View results";m.hint="The tournament has ended.";m.timer="Complete";m.timerLabel="FINAL RESULT"
        else
            m.status="Awaiting next match";m.next="Wait your turn";m.hint="The next match has not been assigned yet.";m.timer="Waiting";m.timerLabel="NEXT MATCH"
            if p.upcoming then m.round=Round(p.upcoming.round,p.upcoming.roundCount) end
        end
    end
    local function Add(key,label,enabled,reason,primary)
        m.actions[#m.actions+1]={key=key,label=label,enabled=enabled==true,reason=reason,primary=primary}
    end
    if private then
        local enabled=p.canCommunicate==true and not p.pending
        if v and v.state=="completed" and not p.finalized then
            m.hint="Organizer-reported final result. Waiting for finalization."
        elseif p.held then
            m.status="Tournament paused";m.next="Wait for organizer";m.hint="The organizer must resume the tournament."
        end
        if not v then
            if not m.checked then Add("checkin","Check In",enabled and check<=0 and before>0,"Check-in is unavailable.",true) end
            if m.checked then Add("sync","Refresh Bracket",enabled,"Wait for organizer or connection.",true) end
            Add("refresh","Refresh Registration",enabled,"Request pending or connection unavailable.")
            Add("leave","Leave Tournament",enabled and before>0,"The scheduled start has passed.")
        else
            Add("brackets","View Bracket",true,nil,true)
            if p.syncing then Add("stop-sync","Stop Sync",true)
            elseif p.acknowledging then Add("stop-ack","Stop Acknowledgement",true)
            else
                Add("sync","Refresh Bracket",enabled,"Request pending or connection unavailable.")
                if (p.held or v.state=="completed") and not p.finalized then Add("ack","Acknowledge Log",enabled,"Connection unavailable.")
                elseif v.state=="disputed" and v.dispute and not v.dispute.confirmed then Add("consent-replay","Agree to Replay",enabled,"Connection unavailable.")
                elseif p.seat=="reported" then Add("report","Send Result",enabled,"Connection unavailable.")
                elseif p.match and not p.held then
                    Add("offer","Check Assignment",enabled,"Connection unavailable.")
                    if p.offer then Add("ready","Confirm Readiness",enabled,"Connection unavailable.",true) end
                end
            end
        end
        return m
    end
    if not v then
        if check>0 and not m.checked then Add("checkin-time","Test Check-in Time",true) end
        if not m.checked then Add("checkin","Test Check-in",check<=0 and before>0,check>0 and "Check-in opens 30 minutes before start." or "Check-in has closed.",true) end
        if m.checked and p.mode=="join" then Add("start-bracket","Simulate Tournament Start",true,nil,true) end
        Add("leave","Leave Test",before>0,"The scheduled start has passed.")
    else
        Add("brackets",v.state=="completed" and "View Results" or (m.result:find("exit",1,true) or m.status=="Eliminated") and "Continue Watching" or "View Bracket",true,nil,true)
        if v.state=="running" then Add("simulate-game","Simulate Next Game",not p.demo and not p.offline and p.selected~=nil,"Finish the current test first.") end
        if p.match then Add("notice","Preview Match Notification",true) end
    end
    if not p.mode then Add("host","Organizer View",true) end
    return m
end
local function At(f,p,x,y,w,h)
    f:ClearAllPoints();f:SetPoint("TOPLEFT",p,"TOPLEFT",x,-y);f:SetSize(math.max(1,w),math.max(1,h))
end
local function Label(p,size,color,align)
    local t=S.Text(p,"",size,color or C.text);t:SetJustifyH(align or "LEFT");t:SetJustifyV("MIDDLE");t:SetWordWrap(true);return t
end
local function Text(t,p,x,y,w,h,value,color,min)
    At(t,p,x,y,w,h);t:SetText(value or "")
    if color then t:SetTextColor(unpack(color)) end
    if S.ConstrainText then S.ConstrainText(t,w,h,min or 13) end
end
local function Rich(p,kind,corner)
    local f=CreateFrame("Frame",nil,p)
    f.plate=S.Plate(f,kind or "organizerPanel",{corner=corner or 12,layer="BACKGROUND",sublevel=0})
    -- Static inset relief; the atlas owns the outer frame.
    if kind=="organizerHero" or not kind or kind=="organizerPanel" then
        local light=f:CreateTexture(nil,"BACKGROUND",nil,2)
        light:SetPoint("TOPLEFT",f,"TOPLEFT",9,-7);light:SetPoint("TOPRIGHT",f,"TOPRIGHT",-9,-7);light:SetHeight(48)
        light:SetColorTexture(1,1,1,1)
        if light.SetGradient and CreateColor then
            light:SetGradient("VERTICAL",CreateColor(1,.53,.12,0),CreateColor(1,.65,.22,.19))
        else light:Hide() end
        local edge=S.Fill(f,{1,.72,.30,1},"BORDER");edge:ClearAllPoints()
        edge:SetPoint("TOPLEFT",f,"TOPLEFT",13,-3);edge:SetPoint("TOPRIGHT",f,"TOPRIGHT",-13,-3);edge:SetHeight(1);edge:SetAlpha(.65)
    end
    return f
end
local function Art(p,kind)
    local t=p:CreateTexture(nil,"ARTWORK");t:SetTexture(ART);ns.Chrome.Sharp(t)
    if kind=="scene" then t:SetTexCoord(0,1,0,80/128) else t:SetTexCoord(0,46/256,82/128,1) end
    return t
end
local function Section(p,title,icon,kind)
    local f=Rich(p,kind);f.heading=Label(f,22,C.pale);f.heading:SetText(title)
    f.icon=chrome.Art(f,icon);f.rule=S.Fill(f,C.goldDim,"BORDER");f.rule:SetAlpha(.6)
    return f
end
local function Header(f,w)
    At(f.icon,f,13,9,25,25);At(f.heading,f,47,4,w-59,37);At(f.rule,f,12,42,w-24,1)
end
function P.New(parent,callbacks)
    local f=CreateFrame("Frame",nil,parent);f:Hide()
    local community=chrome.NewCommunity(f)
    local hero=Rich(f,"organizerHero",13)
    local scene=Art(hero,"scene");local elwynn=chrome.Art(hero,"landscape")
    local logo=chrome.Art(hero,"logo")
    local name=Label(hero,32,C.pale);local location=Label(hero,22,GOLD)
    local pin=chrome.Art(hero,"location")
    local badge=Rich(hero,"organizerStageActive",12);local badgeText=Label(badge,21,GREEN,"CENTER")
    local roundBox=Rich(hero,"organizerStageDone",12);local roundText=Label(roundBox,23,C.pale,"CENTER")
    local seriesText=Label(roundBox,17,C.text,"CENTER")
    local track=CreateFrame("Frame",nil,f)
    local nodes,links={},{ }
    for i=1,3 do
        links[i]=S.Fill(track,C.goldDim,"BACKGROUND")
    end
    for i,title in ipairs({"Registration","Check-in","Bracket","Compete"}) do
        local frame=Rich(track,"organizerStageIdle",19)
        nodes[i]={frame=frame,icon=chrome.Art(frame,i==1 and "players" or i==2 and 2 or i==3 and "flag" or "swords"),
            heading=Label(track,19,C.pale,"CENTER"),status=Label(track,16,C.muted,"CENTER"),title=title}
    end
    local timerCard=Rich(f,"organizerHero",12)
    local la=chrome.Art(timerCard,"laurelL");local ra=chrome.Art(timerCard,"laurelR")
    local clockLabel=Label(timerCard,18,C.pale,"CENTER");local clock=Label(timerCard,43,GOLD,"CENTER")
    local nextCard=Section(f,"Your Next Action",1,"organizerPanel");local nextText=Label(nextCard,22,C.pale);local hint=Label(nextCard,19,C.text)
    local info=Section(f,"Tournament Details","swords")
    local infoRows={}
    for i,icon in ipairs({"location","players","swords",5,6,1,2}) do infoRows[i]={icon=chrome.Art(info,icon),text=Label(info,18,C.text)} end
    local progress=Section(f,"My Progress",7,"organizerPanel")
    local progressRound=Label(progress,23,C.pale,"CENTER");local progressScore=Label(progress,35,GOLD,"CENTER")
    local progressRecord=Label(progress,17,C.text,"CENTER");local progressResult=Label(progress,19,C.pale,"CENTER")
    local pl=chrome.Art(progress,"laurelL");local pr=chrome.Art(progress,"laurelR")
    local match=Rich(f,"organizerHero",13)
    local matchTitle=Rich(match,"organizerStageDone",13);local matchTitleText=Label(matchTitle,20,GOLD,"CENTER")
    local youPortrait=Art(match,"portrait");local otherPortrait=Art(match,"portrait")
    local youName=Label(match,25,C.pale);local youSub=Label(match,18,C.muted)
    local otherName=Label(match,25,C.pale);local otherSub=Label(match,18,C.muted)
    local vs=Label(match,40,GOLD,"CENTER")
    local scoreBox=Rich(match,"organizerStageDone",13);local scoreCaption=Label(scoreBox,17,C.pale,"CENTER")
    local score=Label(scoreBox,31,GOLD,"CENTER")
    local opponentButton=chrome.Action(match,false,18);opponentButton.label:SetText("Player Card")
    opponentButton:SetScript("OnClick",callbacks.profile)
    local ready=Rich(f,"organizerStageActive",13);local readyText=Label(ready,21,GREEN,"CENTER")
    local footer=Rich(f,"organizerPanel",10);local testLabel=Label(footer,18,GOLD)
    local feedbackLabel=Label(f,16,C.muted,"CENTER")
    local buttons={}
    for i=1,5 do
        buttons[i]=chrome.Action(footer,false,18)
        ns.Tooltips.Bind(buttons[i],function(owner) if not owner:IsEnabled() then return {title=owner.caption,disabled=owner.reason} end end)
    end
    local current,model,clockTimer,confirm,eventId
    local function Stop() if clockTimer then clockTimer:Cancel();clockTimer=nil end end
    local function Arm()
        if clockTimer or not current or current.bracket or (current.mode~="join" and current.scope~="PRIVATE_TEST") or current.now>=current.event.draft.startAt or not f:IsVisible() or not C_Timer or type(C_Timer.NewTimer)~="function" then return end
        clockTimer=C_Timer.NewTimer(1,function()
            clockTimer=nil
            if not current or not f:IsVisible() or current.bracket then return end
            local now
            if current.scope=="PRIVATE_TEST" then now=ns.TournamentSession.Now() else now=ns.TournamentRegistration.SyncPlayerPreviewClock(current.event.id) end
            if not now then return end
            current.now=now
            local m=P.Project(current)
            if not m then return end
            if model.timerLabel~=m.timerLabel or model.registrationOpen~=m.registrationOpen then callbacks.refresh();return end
            model=m;clock:SetText(m.timer or "")
            nodes[2].status:SetText(m.checked and "Complete" or m.next=="Check in now" and "Open now" or "In "..m.timer)
            Arm()
        end)
    end
    f:HookScript("OnHide",function()
        Stop();confirm=nil
        if ns.CompetitiveUI then ns.CompetitiveUI.CloseTournamentPlayerCard() end
    end)
    local D={}
    function D.Hide() Stop();f:Hide();current=nil end
    local function PaintHero(p,m,scope,base,wide,top,heroH,stageY,isMatch)
        chrome.PaintCommunity(community,scope or {},base,wide)
        At(hero,f,0,top,base,heroH);At(logo,hero,20,18,140,130)
        scene:SetShown(m.location=="Dun Morogh" and scope and scope.faction=="Alliance")
        elwynn:SetShown(m.location=="Elwynn Forest" and scope and scope.faction=="Alliance")
        At(scene,hero,base*.48,5,base*.51-5,heroH-10);At(elwynn,hero,base*.63,5,base*.36-5,heroH-10)
        local titleW=isMatch and base-440 or base-187
        Text(name,hero,176,12,titleW-11,49,m.name,C.pale,20)
        At(pin,hero,176,70,20,23);Text(location,hero,203,58,titleW-38,40,m.location,GOLD,15)
        badge:SetShown(not isMatch);roundBox:SetShown(isMatch)
        if not isMatch then
            badge.plate:SetStyle(m.status=="Eliminated" and "organizerStageWarning" or "organizerStageActive")
            At(badge,hero,176,112,math.min(titleW-11,350),42);Text(badgeText,badge,10,1,math.min(titleW-11,350)-20,39,m.status,m.status=="Eliminated" and RED or GREEN,14)
        else
            At(roundBox,hero,base-245,14,222,96);Text(roundText,roundBox,8,7,206,43,m.round,C.pale,18)
            Text(seriesText,roundBox,8,52,206,32,"Best of "..m.bestOf,C.text)
        end
        track:SetShown(not isMatch)
        if not isMatch then
            At(track,f,0,stageY,base,130)
            local labels={m.registrationOpen and "Open" or "Confirmed",m.checked and "Complete" or m.next=="Check in now" and "Open now" or p.now>=p.event.draft.startAt and "Closed" or "In "..m.timer,p.bracket and "Drawn" or "Pending",p.bracket and m.status or "Not started"}
            local cell=base/4
            for i,node in ipairs(nodes) do
                local x=(i-.5)*cell
                local active=i==m.step;local done=i<m.step
                if i==3 and not p.bracket then active=false;done=false end
                if i==2 and not m.checked then done=false end
                node.frame.plate:SetStyle(done and "organizerStageActive" or active and "organizerStageDone" or "organizerStageIdle")
                At(node.frame,track,x-34,4,68,66);At(node.icon,node.frame,15,14,38,38)
                Text(node.heading,track,x-cell/2+4,76,cell-8,24,node.title,done and GREEN or active and GOLD or C.pale,14)
                Text(node.status,track,x-cell/2+4,103,cell-8,22,labels[i],done and GREEN or active and GOLD or C.muted,12)
                if i<4 then
                    At(links[i],track,x+34,35,cell-68,5)
                    links[i]:SetColorTexture(unpack(done and GREEN or active and GOLD or C.goldDim))
                end
            end
        end
    end
    local function PaintBody(p,m,base,wide,isMatch,isProgress,contentY,infoH,left,matchH)
        timerCard:SetShown(not isMatch and not isProgress);nextCard:SetShown(not isMatch);progress:SetShown(isProgress)
        match:SetShown(isMatch);ready:SetShown(isMatch)
        if isMatch then
            At(match,f,0,contentY,base,matchH)
            At(matchTitle,match,base*.26,8,base*.48,37);Text(matchTitleText,matchTitle,6,0,base*.48-12,37,p.scope=="PRIVATE_TEST" and "UPCOMING MATCH — PRIVATE TEST" or "UPCOMING MATCH — LOCAL TEST",GOLD,15)
            if base<760 then
                local half=base*.5
                At(youPortrait,match,half*.5-39,52,78,78)
                At(otherPortrait,match,half*1.5-39,52,78,78)
                youName:SetJustifyH("CENTER");youSub:SetJustifyH("CENTER");otherName:SetJustifyH("CENTER");otherSub:SetJustifyH("CENTER")
                Text(youName,match,12,132,half-24,34,"Yourself",C.pale,16)
                Text(youSub,match,12,166,half-24,29,"Participant",C.muted,13)
                Text(otherName,match,half+12,132,half-24,34,m.opponent,C.pale,16)
                Text(otherSub,match,half+12,166,half-24,29,m.opponentLevel and "Level "..m.opponentLevel or "Level unavailable",C.muted,13)
                Text(vs,match,half-32,62,64,55,"VS",GOLD,26)
                At(opponentButton,match,half+25,196,half-50,30)
            else
                youName:SetJustifyH("LEFT");youSub:SetJustifyH("LEFT");otherName:SetJustifyH("LEFT");otherSub:SetJustifyH("LEFT")
                At(youPortrait,match,20,58,94,94);At(otherPortrait,match,base*.58,58,94,94)
                Text(youName,match,125,62,base*.37-126,37,"Yourself",C.pale,18)
                Text(youSub,match,125,103,base*.32-106,33,"Participant",C.muted,13)
                Text(vs,match,base*.44,63,base*.12,74,"VS",GOLD,26)
                local ox=base*.58+106
                Text(otherName,match,ox,58,base-ox-12,38,m.opponent,C.pale,16)
                Text(otherSub,match,ox,99,base-ox-12,27,m.opponentLevel and "Level "..m.opponentLevel or "Level unavailable",C.muted,13)
                At(opponentButton,match,ox,133,base-ox-15,32)
            end
            opponentButton:SetEnabled(p.opponent~=nil);opponentButton:SetAlpha(p.opponent and 1 or .5)
            At(scoreBox,match,base*.36,matchH-70,base*.28,60);Text(scoreCaption,scoreBox,5,1,base*.28-10,23,"SERIES SCORE",C.pale,13)
            Text(score,scoreBox,5,24,base*.28-10,32,m.score,GOLD,20)
            At(ready,f,base*.28,contentY+matchH+12,base*.44,35)
            ready.plate:SetStyle(m.status=="Match ready" and "organizerStageActive" or "organizerStageDone")
            Text(readyText,ready,6,0,base*.44-12,35,m.status,m.status=="Match ready" and GREEN or GOLD,15)
        elseif isProgress then
            local iw=wide and base*.36 or base
            local pw=wide and base*.31-12 or base
            local px=wide and iw+12 or 0
            local py=wide and contentY or contentY+infoH+12
            At(progress,f,px,py,pw,wide and infoH or 174);Header(progress,pw)
            At(pl,progress,12,59,35,63);At(pr,progress,pw-47,59,35,63)
            Text(progressRound,progress,48,47,pw-96,39,m.round,C.pale,17)
            Text(progressScore,progress,48,88,pw-96,42,m.score,GOLD,20)
            Text(progressRecord,progress,8,135,pw-16,32,m.record,C.text,13)
            Text(progressResult,progress,8,wide and 185 or 0,pw-16,wide and 44 or 1,m.result,C.pale,14);progressResult:SetShown(wide)
            local nx=wide and iw+pw+24 or 0;local nw=wide and base-nx or base;local ny=wide and contentY or py+186
            At(nextCard,f,nx,ny,nw,wide and infoH or 166);Header(nextCard,nw)
            Text(nextText,nextCard,12,48,nw-24,wide and 70 or 45,m.next,GOLD,16)
            Text(hint,nextCard,12,wide and 120 or 94,nw-24,wide and infoH-132 or 60,m.hint,C.text,14)
        else
            local tw=wide and left or base;local nw=wide and base-left-12 or base
            At(timerCard,f,0,contentY,tw,174)
            At(la,timerCard,16,53,55,96);At(ra,timerCard,tw-71,53,55,96)
            Text(clockLabel,timerCard,75,16,tw-150,36,m.timerLabel,C.pale,15)
            Text(clock,timerCard,75,58,tw-150,93,m.timer,GOLD,26)
            At(nextCard,f,wide and left+12 or 0,wide and contentY or contentY+188,nw,wide and 174 or 148);Header(nextCard,nw)
            Text(nextText,nextCard,18,53,nw-36,42,m.next,GOLD,16)
            Text(hint,nextCard,18,99,nw-36,wide and 60 or 39,m.hint,C.text,13)
        end
    end
    function D.Show(p,width,scope,feedback)
        if eventId~=p.event.id then eventId=p.event.id;confirm=nil end
        current=p;model=P.Project(p)
        if not model then D.Hide();return 1 end
        local m=model;local base,wide,scale=chrome.LayoutWidth(width,1060)
        local top=wide and 77 or 132
        local isMatch=m.state=="match";local isProgress=m.state=="progress"
        local heroH=isMatch and 164 or 174
        local stageY=top+heroH+16
        local contentY=stageY+(isMatch and 0 or 146)
        local infoY,infoH,footerY
        local matchH=base<760 and 306 or 246
        local ruleWidth=isProgress and wide and base*.36-63 or wide and (base-24)/2-39 or base-63
        local rulesExtra=math.min(160,math.max(0,math.ceil(#m.rules/math.max(16,math.floor(ruleWidth/9)))-1)*22)
        local left=math.floor((base-12)*.51)
        if isMatch then infoY=contentY+matchH+63;infoH=wide and 202+rulesExtra or 304+rulesExtra;footerY=infoY+infoH+12
        elseif isProgress then infoY=contentY;infoH=wide and 304+rulesExtra or 304+rulesExtra;footerY=contentY+(wide and infoH or infoH+364)+12
        else infoY=contentY+(wide and 190 or 352);infoH=wide and 202+rulesExtra or 304+rulesExtra;footerY=infoY+infoH+12 end
        local footerH=wide and 60 or 50+math.ceil(#m.actions/2)*45
        local total=footerY+footerH+(feedback~="" and 42 or 8)
        f:SetScale(scale);At(f,parent,0,0,base,total);f:Show()
        PaintHero(p,m,scope,base,wide,top,heroH,stageY,isMatch)
        PaintBody(p,m,base,wide,isMatch,isProgress,contentY,infoH,left,matchH)
        local iw=isProgress and wide and base*.36 or base
        At(info,f,0,infoY,iw,infoH);Header(info,iw)
        local times=ns.TournamentState.GetSchedulePreview(p.event.draft.startUTC,p.event.draft.closeBefore)
        local vals={m.location,m.players.." Players",m.format,"Level: "..m.levels,m.rules,
            "Starts: "..(times and times.starts or p.event.draft.startUTC.." UTC"),
            "Registration closes: "..(times and times.closes or "Unavailable")}
        local cols=wide and not isProgress and 2 or 1
        local cellW=(iw-24)/cols
        local y=53
        for i,row in ipairs(infoRows) do
            local col=cols==2 and (i>=4 and 1 or 0) or 0
            local yy=cols==2 and (i>=4 and i-4 or i-1) or i-1
            local x=12+col*cellW
            local ry=y+yy*(cols==2 and 34 or 34)+(i>=6 and rulesExtra or 0)
            At(row.icon,info,x,ry+4,22,22)
            Text(row.text,info,x+30,ry,cellW-39,32+(i==5 and rulesExtra or 0),vals[i],C.text,13)
        end
        At(footer,f,0,footerY,base,footerH);Text(testLabel,footer,12,5,wide and 144 or base-24,wide and 50 or 39,p.scope=="PRIVATE_TEST" and "PRIVATE TEST" or "LOCAL TEST",GOLD,15)
        for i,b in ipairs(buttons) do
            local action=m.actions[i];b:SetShown(action~=nil)
            if action then
                local cols=wide and #m.actions or 2
                local x=wide and 165 or 12;local bw=(base-x-12-(cols-1)*9)/cols
                At(b,footer,x+((i-1)%cols)*(bw+9),wide and 11 or 45+math.floor((i-1)/cols)*45,bw,38)
                local confirmation=p.event.id..":"..action.key
                local text=confirm==confirmation and ("Confirm "..(action.key=="leave" and "Leave" or "Replay")) or action.label
                b.label:SetText(text);b.caption=text;b.reason=action.reason;b:SetEnabled(action.enabled);b:SetAlpha(action.enabled and 1 or .52)
                b.plate:SetStyle(action.key=="leave" and "browsePrimary" or action.primary and "gold" or "browseCard")
                b:SetScript("OnClick",function()
                    if not action.enabled then return end
                    if (action.key=="leave" or action.key=="consent-replay") and confirm~=confirmation then confirm=confirmation;b.label:SetText(action.key=="leave" and "Confirm Leave" or "Confirm Replay");return end
                    confirm=nil;callbacks.action(action.key)
                end)
            end
        end
        feedbackLabel:SetShown(feedback and feedback~="");Text(feedbackLabel,f,10,footerY+footerH+3,base-20,32,feedback or "",C.muted,13)
        Stop();Arm()
        return total*scale
    end
    return D
end
function P.RunSelfTest()
    local p={scope="SIMULATED",role="player",member={guid="a",checkedIn=false},mode="join",now=100,event={count=6,draft={name="Cup",location="Dun Morogh",capacity=8,bestOf=3,minLevel=0,maxLevel=0,rules="",startAt=4000,registrationClosesAt=3100}}}
    local m=P.Project(p);assert(m.state=="readiness" and m.timer=="00:35:00" and m.score=="—" and not m.actions[2].enabled)
    p.now=2300;m=P.Project(p);assert(m.next=="Check in now" and m.actions[1].enabled)
    p.member.checkedIn=true;assert(P.Project(p).timer=="00:28:20")
    p.bracket={state="running",rounds={{ {id="R1M1",state="ready",a="a",b="b"} }}};p.match={id="R1M1",round=1,roundCount=1,score=1,opponentScore=0,opponent="Peer"};p.selected="R1M1"
    m=P.Project(p);assert(m.state=="match" and m.score=="1 - 0" and m.opponent=="Peer")
    p.match=nil;p.bracket.rounds[1][1].state="done";p.bracket.rounds[1][1].winner="b";p.state="eliminated"
    assert(P.Project(p).status=="Eliminated")
    p.bracket.state="completed";p.bracket.champion="a";p.bracket.rounds[1][1].winner="a";assert(P.Project(p).status=="Tournament champion")
    p.scope="PRIVATE_TEST";p.canCommunicate=true;p.finalized=false
    m=P.Project(p);assert(m.actions[3].key=="ack" and m.actions[3].enabled)
    p.finalized=true;m=P.Project(p);assert(#m.actions==2)
    p.bracket=nil;p.state=nil;p.member.checkedIn=false;p.now=2300
    m=P.Project(p);assert(m.actions[1].key=="checkin" and m.actions[1].enabled)
    p.pending=true;m=P.Project(p);assert(not m.actions[1].enabled)
    for _,a in ipairs(m.actions) do assert(a.key~="simulate-game" and a.key~="notice") end
    return true
end
