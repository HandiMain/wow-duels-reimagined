local _,ns=...
-- A distinct presentation, not a new duel engine. DuelHUD alone selects
-- which HUD is active. This view consumes a detached tournament snapshot.
local B={};ns.TournamentHUD=B
local W,H=900,148
local S=ns.Style
local C=S and S.color
local Settings=ns.Settings
local root,fields,draft,editing
local function Round(m)
    local remaining=m.roundCount-m.round
    return remaining==0 and "Final" or remaining==1 and "Semifinal" or remaining==2 and "Quarterfinal" or "Round of "..2^(remaining+1)
end
function B.Project(p)
    if type(p)~="table" or p.scope~="SIMULATED" or p.role~="player" or not p.match or not p.bracket or p.bracket.state~="running" then return nil end
    local m=p.match
    local function Whole(n,lo,hi) return type(n)=="number" and n>=lo and n<=hi and n==math.floor(n) end
    if not Whole(m.roundCount,1,6) or not Whole(m.round,1,m.roundCount) or
        not (m.bestOf==1 or m.bestOf==3 or m.bestOf==5) then return nil end
    local needed=math.floor(m.bestOf/2)+1
    if not Whole(m.score,0,needed-1) or not Whole(m.opponentScore,0,needed-1) or
        type(m.opponent)~="string" or type(p.event)~="table" or type(p.event.draft)~="table" or type(p.event.draft.name)~="string" then return nil end
    return {title=p.event.draft.name,round=Round(m),bestOf=m.bestOf,
        game=m.score+m.opponentScore+1,left=p.member and p.member.name or "You (local test)",
        right=m.opponent,score=m.score,opponentScore=m.opponentScore,status="Match ready",
        key=p.event.id..":"..m.id,scope="SIMULATED"}
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
local function Plate(p,x,y,w,h,kind,corner)
    local f=CreateFrame("Frame",nil,p);At(f,p,x,y,w,h)
    S.Plate(f,kind,{corner=corner or 12,layer="BACKGROUND",sublevel=1})
    return f
end
local function Wing(p,x)
    local f=CreateFrame("Frame",nil,p);At(f,p,x,34,62,86)
    S.Skin(f,C.button,{corner=12,edge=C.goldDim,light=C.gold,dark=C.window,shine=.34,shade=.35,rim=.92})
    S.Plate(f,"shellCopper",{corner=12})
    Emblem(f,9,22,44,36)
    local top=Plate(f,-8,-5,78,12,"gold",5)
    return f
end
local function Side(p,x,enemy)
    local side={}
    local ix=enemy and 190 or 0
    local tx=enemy and 0 or 54
    local ring=Plate(p,x+ix,46,48,48,"gold",15)
    side.icon=ring:CreateTexture(nil,"ARTWORK")
    At(side.icon,ring,5,5,38,38)
    side.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    side.name=Text(p,x+tx,49,184,26,17,C.pale,enemy and "RIGHT" or "LEFT")
    local track=Plate(p,x+tx,78,184,23,"dark",9)
    side.hp=CreateFrame("StatusBar",nil,track)
    At(side.hp,track,4,5,176,13)
    side.hp:SetStatusBarTexture("Interface\\AddOns\\DuelsReimagined\\Media\\Skin\\DuelHUDHealthFill.png")
    side.hp:SetMinMaxValues(0,100);side.hp:SetStatusBarColor(1,1,1)
    local overlay=CreateFrame("Frame",nil,track)
    overlay:SetFrameLevel(side.hp:GetFrameLevel()+1);overlay:SetAllPoints(track)
    side.health=Text(overlay,0,0,184,23,11,C.text)
    return side
end
local function Build()
    if root then return end
    root=CreateFrame("Frame","DuelsReimaginedTournamentHUD",UIParent)
    root:SetSize(W,H);root:SetFrameStrata("MEDIUM");root:SetClampedToScreen(true);root:EnableMouse(false);root:Hide()
    if ns.DiagnosticAudit then ns.DiagnosticAudit.RegisterUIRoot("Tournament HUD",root) end
    local body=Plate(root,44,34,812,79,"cardBody",18)
    S.Plate(body,"shellCopper",{corner=18})
    local lower=Plate(root,152,104,596,43,"dark",17)
    S.Plate(lower,"shellCopper",{corner=17})
    Wing(root,10);Wing(root,828)
    local crest=Plate(root,276,16,348,47,"hall",14)
    S.Plate(crest,"shellCopper",{corner=14})
    Emblem(root,428,0,44,31)
    local left=Side(root,79,false)
    local right=Side(root,583,true)
    local leftScore=Plate(root,345,65,43,40,"hall",10)
    local rightScore=Plate(root,512,65,43,40,"hall",10)
    local vs=Text(root,390,65,120,37,25,C.gold)
    vs:SetText("VS")
    local title=Text(crest,12,4,324,23,20,C.pale)
    local format=Text(crest,12,26,324,17,12,C.pale)
    local score=Text(leftScore,0,0,43,40,25,C.text)
    local opponentScore=Text(rightScore,0,0,43,40,25,C.text)
    local game=Text(lower,11,6,168,30,13,C.pale)
    local status=Text(lower,181,4,234,34,19,C.gold)
    local sim=S.Action(lower,"Simulate game","footer",{plate="dark",text=C.pale,edge=C.goldDim,hover=C.gold,tooltip=false})
    At(sim,lower,426,7,157,27)
    sim:SetScript("OnClick",function()
        if editing or not ns.DuelHUD or not ns.DuelHUD.IsTournamentHUDActive() then return end
        local ok,why=ns.TournamentRegistration.PreviewAction("simulate-game")
        if ns.TournamentUI.RefreshActive then ns.TournamentUI.RefreshActive() end
        if not ok and ns.Feedback then ns.Feedback.Toast(why or "Test game unavailable",sim) end
    end)
    local test=Text(root,8,117,134,22,11,C.muted);test:SetText("LOCAL TEST")
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
    fields.game:SetText(m.bestOf==1 and m.round or "Game "..m.game.."  /  Best of "..m.bestOf)
    fields.status:SetText(m.status)
    for _,side in ipairs({fields.left,fields.right}) do
        -- No opponent unit is observed in a local test. Do not show a
        -- fabricated live health percentage, even when a real target exists.
        side.hp:SetValue(0);side.hp:Hide();side.health:SetText("Health unavailable")
    end
    fields.sim:SetShown(not editing)
end
function B.Frame() return root end
function B.Show(m)
    Build()
    if not editing then Layout();Paint(m) end
    root:Show()
    return root
end
function B.Hide()
    if root and not editing then root:Hide() end
end
function B.Relayout()
    if root and root:IsShown() then Layout() end
end
function B.IsEditing() return editing==true end
function B.LayoutSize() return W,H end
function B.SetLayoutDraft(x,y,scale)
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
        return {scope="SIMULATED",role="player",event={id="test",draft={name="Test Cup"}},member={name="You"},
            bracket={state="running"},match={id="m1",round=2,roundCount=3,opponent="Other",score=1,opponentScore=0,bestOf=3}}
    end
    Case("scoreboard only for assigned player match",function()
        local p=Fixture();assert(B.Project(p))
        p.role="host";assert(not B.Project(p));p.role="player";p.match=nil;assert(not B.Project(p))
        p=Fixture();p.bracket.state="completed";assert(not B.Project(p))
        p=Fixture();p.scope="LOCAL";assert(not B.Project(p))
    end)
    Case("series score, game and round are derived",function()
        local p=Fixture();local m=B.Project(p)
        assert(m.game==2 and m.round=="Semifinal" and m.score==1 and m.opponentScore==0)
        p.match.round=3;p.match.bestOf=1;p.match.score=0;m=B.Project(p)
        assert(m.game==1 and m.round=="Final" and m.bestOf==1)
        p.match.score=1;assert(not B.Project(p))
    end)
    return pass,fail
end
if ns.Diagnostics then
    ns.Diagnostics.Register("Tournament scoreboard / isolated projection QA","deep",function()
        local log={};local p,f=B.RunSelfTest(function(line)log[#log+1]=line end)
        return f==0 and p==2 and "PASS" or "FAIL",string.format("%d passed / %d failed (SIMULATED)\n",p,f)..table.concat(log,"\n")
    end)
end
