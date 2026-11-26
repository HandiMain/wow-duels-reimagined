-- Actual deterministic competitive fixtures and page controllers, mocked
-- frame APIs only. Not a WoW render, API availability or live PvP test.
local base="addon/DuelsReimagined/"
local ns={}
for _,name in ipairs({"ResultConfirmation","MatchLedger","PersonalHistory","CompetitiveStorage","CompetitiveRules","SeasonRules","RatingEngine","LeaderboardSync","CompetitiveManifest","CompetitiveIntegrity","SyncProtocol"}) do
    assert(loadfile(base.."Core/"..name..".lua"))("DuelsReimagined",ns)
end
assert(loadfile(base.."UI/CompetitivePreview.lua"))("DuelsReimagined",ns)
local P=ns.CompetitivePreview
assert(not P.IsActive())
for _,client in ipairs({"forever","retail"}) do
    local empty=P.Build(client)
    assert(empty.scope=="SIMULATED" and empty.current==1 and #empty.matches==0)
    assert(empty.view.Leaderboard(1,0,100,"","rating").total==0)
    local events={}
    for i=1,5 do
        events[i]={outcome=i==2 and "lost" or "won",opponent=i}
        local d=P.Build(client,events)
        local p=assert(d.view.ProfileSummary(d.me,1))
        assert(d.personal.total==i and #d.matches==i and p.credit==i*4 and p.rivalCount==i)
        assert(p.rank.provisional==(i<5))
        assert(d.view.Leaderboard(1,0,100,"","rating").total==(i==5 and 1 or 0))
        assert(d.matches[1].outcome==events[i].outcome and d.matches[1].category=="Ranked")
        assert(d.matches[1].delta==d.matches[1].after-d.matches[1].before)
    end
    local repeated={}
    for i=1,8 do repeated[i]={outcome="won",opponent=1} end
    local d=P.Build(client,repeated);local p=d.view.ProfileSummary(d.me,1)
    assert(p.rank.provisional and p.rivalCount==1 and p.credit<32)
    assert(d.matches[1].category=="Rating capped" and d.matches[1].delta==0)
    local unranked=P.Build(client,{{outcome="won",mode="unranked",opponent=1}})
    assert(unranked.personal.total==1 and unranked.personal.wins==1)
    assert(unranked.matches[1].category=="Unranked" and unranked.matches[1].delta==nil)
    assert(unranked.matches[1].identity.name=="Test Rival 1")
    assert(not unranked.view.ProfileSummary(unranked.me,1))
    assert(unranked.view.Leaderboard(1,0,100,"","rating").total==0)
    local mixed=P.Build(client,{{outcome="won",mode="practice",opponent=1},
        {outcome="lost",mode="unranked",opponent=2},{outcome="unknown",opponent=3},
        {outcome="fled",opponent=4},{outcome="won",mode="pending",opponent=5}})
    assert(mixed.personal.total==5 and mixed.personal.wins==2 and mixed.personal.losses==2 and mixed.personal.unknown==1)
    assert(mixed.matches[5].category=="Unranked" and mixed.matches[5].delta==nil)
    assert(mixed.matches[1].category=="Pending" and mixed.matches[1].delta==nil)
    assert(mixed.view.Leaderboard(1,0,100,"","rating").total==0)
    assert(mixed.matches[1].identity.name=="Test Rival 5")
    local both=P.Build(client,{{outcome="won",mode="ranked",opponent=1},
        {outcome="won",mode="unranked",opponent=2},{outcome="lost",mode="pending",opponent=3}})
    assert(both.personal.total==3 and both.personal.wins==2 and both.personal.losses==1)
    assert(both.view.ProfileSummary(both.me,1).stats.games==1)
    assert(both.view.ProfileSummary(both.matches[3].peer,1).identity.name=="Test Rival 1")
    assert(not both.view.ProfileSummary(both.matches[2].peer,1))
    assert(not both.view.ProfileSummary(both.matches[1].peer,1))
    assert(both.matches[2].identity.name=="Test Rival 2" and both.matches[1].identity.name=="Test Rival 3")
end
-- Minimal frame mock: tracks scripts, visibility, sizes and text; rendering
-- is deliberately not certified here. Parent anchors get content dimensions.
local frames={}
local noop=function()end
local methods={}
function methods:SetSize(w,h)self.w=w;self.h=h end
function methods:SetWidth(w)self.w=w end
function methods:SetHeight(h)self.h=h end
function methods:GetWidth()return self.w or 0 end
function methods:GetHeight()return self.h or 0 end
function methods:SetPoint(...)self.point={...};if not self.w then self.w=960 end;if not self.h then self.h=620 end end
function methods:ClearAllPoints()self.point=nil end
function methods:SetAllPoints()end
function methods:SetScript(k,f)self.scripts[k]=f end
function methods:HookScript(k,f)local old=self.scripts[k];self.scripts[k]=function(...)if old then old(...)end;f(...)end end
function methods:SetShown(v)if v then self:Show()else self:Hide()end end
function methods:Show()local old=self.shown;self.shown=true;if not old and self.scripts.OnShow then self.scripts.OnShow(self)end end
function methods:Hide()local old=self.shown;self.shown=false;if old and self.scripts.OnHide then self.scripts.OnHide(self)end end
function methods:IsShown()return self.shown end
function methods:IsVisible()return self.shown and (not self.parent or self.parent:IsVisible()) end
function methods:SetText(t)self.text=t end
function methods:GetText()return self.text end
function methods:GetAlpha()return self.alpha or 1 end
function methods:SetAlpha(a)self.alpha=a end
function methods:GetFrameLevel()return 1 end
function methods:GetEffectiveScale()return 1 end
local function Frame(parent)
    local f=setmetatable({parent=parent,scripts={},shown=true}, {__index=function(_,k)return methods[k] or (type(k)=="string" and k:match("^[A-Z]") and noop or nil) end})
    frames[#frames+1]=f;return f
end
function methods:CreateTexture()return Frame(self)end
function methods:CreateFontString()return Frame(self)end
CreateFrame=function(_,name,parent)local f=Frame(parent);if name then _G[name]=f end;return f end
local C=setmetatable({}, {__index=function(t,k)local v={1,1,1,1};rawset(t,k,v);return v end})
ns.Style={color=C,Text=function(parent,t)local f=Frame(parent);f:SetText(t);return f end,Fill=function(parent)return Frame(parent)end,
    Skin=noop,Plate=noop,Action=function(parent,t)local f=Frame(parent);f.label=Frame(f);f.label:SetText(t);return f end,BindFont=noop}
local activeTweens={}
local revealStarts=0
ns.Motion={
    Fade=function(f,a) f:SetAlpha(a) end,
    Stop=function(f,a) activeTweens[f]=nil;f:SetAlpha(a or 0) end,
    Value=function(f,from,to,_,apply)
        revealStarts=revealStarts+1
        activeTweens[f]=function() apply(f,to) end
        apply(f,from)
    end,
}
local function FinishTweens()
    for f,finish in pairs(activeTweens) do activeTweens[f]=nil;finish() end
end
ns.Chrome={Sharp=noop,Icon=function(parent)return Frame(parent)end,Divider=function(parent)return Frame(parent)end}
ns.Widgets={PressFeedback=noop,ChoiceControl=function(parent)local f=Frame(parent);return f,Frame(f)end,OpenChoices=noop,
    CloseChoices=noop,ScrollBar=function(parent)local f=Frame(parent);f.Refresh=noop;return f end}
UIParent=Frame(nil);UIParent:SetSize(1440,900)
local main=Frame(UIParent)
ns.Window={frame=main,content=Frame(main)}
ns.Window.content:SetSize(960,620)
ns.Header={CreateCloseButton=function(parent)return Frame(parent)end}
UISpecialFrames={"OtherBefore","DuelsReimaginedWindow","OtherAfter"}
ns.DiagnosticAudit={RegisterUIRoot=noop}
ns.Diagnostics={Record=function(_,detail)error(detail)end}
local navigations=0
ns.Navigation={SelectKey=function()navigations=navigations+1 end}
ns.Client={Kind=function()return "retail" end}
ns.Group={ReadPlayerIdentity=function()return {guid="Player-1-LOCAL"}end}
assert(not P.IsActive() and P.Get().scope=="LOCAL")
assert(not P.Command("win"))
assert(P.Command("start") and P.IsActive())
assert(P.Get().personal.total==0)
assert(loadfile(base.."UI/CompetitiveUI.lua"))("DuelsReimagined",ns)
local U=ns.CompetitiveUI
local count=#frames
U.Show("overview")
local function HasText(t)
    for _,f in ipairs(frames) do if f.text==t and f:IsVisible() then return true end end
end
assert(HasText("Placement Matches") and HasText("0 / 5 completed"))
assert(HasText("Unique opponents: 0 / 3"))
for i=1,5 do
    assert(P.Command(i==2 and "loss" or "win"))
    assert(#P.Get().matches==i)
    if i<5 then assert(HasText("Placement Matches") and HasText(i.." / 5 completed")) end
end
assert(HasText("5 / 5 completed") and revealStarts==1)
U.Refresh();assert(revealStarts==1,"refresh restarted placement reveal")
FinishTweens()
assert(not HasText("Placement Matches"))
assert(not P.Command("win 21") and #P.Get().matches==5)
for _,key in ipairs({"overview","standings","history","standings","overview"}) do
    U.Show(key);U.Refresh();U.SetPageScroll(key,3)
end
U.Show("standings");U.SetPageScroll("standings",3)
local before=U.GetPageScroll("standings")
local d=P.Get()
local row=d.view.Leaderboard(d.current,0,5,"","rating").rows[1]
U.OpenPlayerCard(row.id)
assert(U.IsPlayerCardOpen() and navigations==0 and U.GetPageScroll("standings")==before)
assert(table.concat(UISpecialFrames,",")=="OtherBefore,OtherAfter,DuelsReimaginedPlayerCard")
U.OpenPlayerCard(d.me);U.Refresh()
assert(U.IsPlayerCardOpen() and navigations==0)
assert(table.concat(UISpecialFrames,",")=="OtherBefore,OtherAfter,DuelsReimaginedPlayerCard")
U.ClosePlayerCard()
assert(not U.IsPlayerCardOpen() and U.GetPageScroll("standings")==before)
assert(table.concat(UISpecialFrames,",")=="OtherBefore,DuelsReimaginedWindow,OtherAfter")
U.OpenPlayerCard(d.me);main:Hide()
assert(not U.IsPlayerCardOpen() and table.concat(UISpecialFrames,",")=="OtherBefore,DuelsReimaginedWindow,OtherAfter")
main:Show()
U.Show("overview")
assert(P.Command("reset") and #P.Get().matches==0 and HasText("Placement Matches"))
assert(P.Command("stop") and not P.IsActive() and P.Get().scope=="LOCAL")
assert(HasText("Placement Matches") and HasText("0 / 5 completed"))
-- This mock never loads the live SavedVariables roots. Preserve the
-- unavailable-data label instead of claiming a successfully read empty store.
assert(P.Get().storageReason and HasText("Local history unavailable"))
assert(P.Get().current==0 and #P.Get().matches==0)
assert(P.Command("start"))
for i=1,5 do assert(P.Command("win")) end
assert(next(activeTweens))
U.Show("history")
assert(not next(activeTweens),"page hide must cancel reveal")
U.Show("overview")
assert(not HasText("Placement Matches"),"ranked state must reopen without replaying reveal")
assert(P.Command("stop"))
U.Show(nil)
assert(#frames==count,"page navigation must reuse frames")
assert(_G.DuelsReimaginedCompetitiveDB==nil and _G.DuelsReimaginedCharacterDB==nil)
print("Competitive UI simulated data and mocked page controllers: PASS")

-- Run the actual Achievements controller against the same reusable frame
-- mock and the actual simulation provider. No artwork rendering claimed.
assert(loadfile(base.."Core/Achievements.lua"))("DuelsReimagined",ns)
ns.Style.Plate=function()return {SetStyle=noop}end
ns.Style.FeedbackOverlay=function()return Frame(main)end
ns.Motion.Duration=function()return .1 end
assert(loadfile(base.."UI/AchievementUI.lua"))("DuelsReimagined",ns)
local Ach=ns.AchievementUI
local beforeAchievements=#frames
Ach.Show(false);Ach.Refresh();assert(Ach.GetPageScroll()==0 and #frames==beforeAchievements)
assert(P.Command("start"))
assert(#frames==beforeAchievements,"background progression must not construct page")
Ach.Show(true)
local frameCount=#frames
assert(frameCount>beforeAchievements,"first open constructs the view")
assert(HasText("Achievements") and HasText("The Beginning") and HasText("SOLO TEST - SIMULATED"))
assert(not HasText("Completed"))
assert(P.Command("win"))
assert(HasText("Completed") and HasText("1 / 1"))
Ach.SetPageScroll("achievements",15)
assert(Ach.GetPageScroll()>0)
Ach.SetPageScroll("achievements",0)
assert(HasText("The Beginning"))
local selected=false
local categoryButton
for _,f in ipairs(frames) do
    if f.text=="Competitive" and f:IsVisible() and f.parent and f.parent.scripts.OnClick then
        categoryButton=f.parent
        local b=categoryButton
        assert(b.achievementHover:GetAlpha()==0 and b.achievementSelected:GetAlpha()==0)
        b.scripts.OnEnter();assert(b.achievementHover:GetAlpha()==.42)
        b.scripts.OnLeave();assert(b.achievementHover:GetAlpha()==0)
        b.scripts.OnClick();selected=true
        assert(b.chosen and b.achievementSelected:GetAlpha()==.13)
        b.scripts.OnEnter();assert(b.achievementHover:GetAlpha()==.16)
        Ach.Refresh();assert(b.achievementHover:GetAlpha()==.16,"refresh must not restart feedback")
        break
    end
end
assert(selected and HasText("Into the Arena") and not HasText("The Beginning"))
assert(P.Command("stop"))
assert(HasText("Local history unavailable") and not HasText("Completed"))
Ach.Show(false);assert(categoryButton.achievementHover:GetAlpha()==0)
Ach.Show(true);Ach.Show(false)
assert(#frames==frameCount,"Achievement navigation must reuse frames")
assert(_G.DuelsReimaginedCompetitiveDB==nil and _G.DuelsReimaginedCharacterDB==nil)
print("Achievements UI mocked controllers: PASS (scope, updates, filters, scroll, reuse)")

-- Patch notes unread state works without allocating the page at login.
local patchAllocations=#frames
local reminder
local patchNS={Style=ns.Style,Chrome=ns.Chrome,Widgets=ns.Widgets,Motion=ns.Motion,Window=ns.Window,
    Search={entries={}},Settings={Get=function()return true end,GetPatchNotesSeenId=function()return nil end},
    Navigation={SetPatchUnread=function(v)reminder=v end},DiagnosticAudit={RegisterDeferredUIRoot=noop,RegisterUIRoot=noop}}
assert(loadfile(base.."UI/PatchNotesData.lua"))("DuelsReimagined",patchNS)
assert(loadfile(base.."UI/PatchNotes.lua"))("DuelsReimagined",patchNS)
assert(reminder==true and #frames==patchAllocations)
patchNS.PatchNotes.Show(nil);patchNS.PatchNotes.SetPageScroll("v0-1-2",50);patchNS.PatchNotes.RefreshReminder()
assert(patchNS.PatchNotes.GetPageScroll("v0-1-2")==0 and #frames==patchAllocations)
print("Deferred Patch Notes: PASS (unread reminder and hidden navigation allocate no view)")
