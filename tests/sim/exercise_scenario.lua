-- luacheck: read globals scenario
-- Every surface, in and out of combat and across a reload, starting from a save that predates the database version.
-- The exercise also runs with the gamepad interface on, secret values on and the stock tracker beside the section.
scenario("every surface, in and out of combat and across a reload", function(sim)
	dofile("tests/sim/forever_core.lua").install(sim)
	sim:exercise({ savedVariables = "tests/sim/fixtures/old_save.lua" })
end)
