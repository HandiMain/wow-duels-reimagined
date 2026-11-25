-- Isolated shared review QA; no game API or SavedVariables.
local root=(arg and arg[1] or "addon/DuelsReimagined").."/Core/"
local ns={}
for _,name in ipairs({"CompetitiveManifest","CompetitiveIntegrity"}) do
    assert(loadfile(root..name..".lua"))("DuelsReimagined",ns)
end
local p,f=ns.CompetitiveIntegrity.RunReviewSelfTest(print)
assert(p==13 and f==0,"shared integrity review QA")
print("13 isolated shared review checks passed")
