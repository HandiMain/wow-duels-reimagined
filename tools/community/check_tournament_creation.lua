-- Isolated creation and navigation QA. No WoW API, persistence or network.
local ns={Client={Kind=function()return "forever" end,IsSupported=function()return true end}}
local root=(arg and arg[1] or "addon/DuelsReimagined")
assert(loadfile(root.."/Core/CompetitiveScope.lua"))("DuelsReimagined",ns)
local sp,sf=ns.CompetitiveScope.RunSelfTest(print)
assert(sp==7 and sf==0,"population QA failed")
assert(loadfile(root.."/Core/TournamentState.lua"))("DuelsReimagined",ns)
assert(loadfile(root.."/Core/TournamentRegistration.lua"))("DuelsReimagined",ns)
local rp,rf=ns.TournamentRegistration.RunSelfTest(print)
assert(rp==13 and rf==0,"registration QA failed")
local T=ns.TournamentState
assert(T.RunSelfTest()==10)
local p,f=T.RunCreationSelfTest(print)
assert(p==15 and f==0,"creation QA failed")
print("15 creation and 10 navigation checks passed")
