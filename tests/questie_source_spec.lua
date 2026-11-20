-- Run from the repository root: luajit tests/questie_source_spec.lua
-- The QuestieDB read's lifecycle: Questie's ready callback and the fallback timer race, and only the first starts the
-- read; absent, pending and ready are told once.
local Env = dofile("tests/ledger_env.lua")
local checks = 0
local function check(condition, label)
	checks = checks + 1
	assert(condition, label)
end

local timers, readyCallback = {}, nil
_G.C_Timer = {
	After = function(seconds, fn)
		timers[#timers + 1] = { seconds = seconds, fn = fn }
	end,
}
_G.debugprofilestop = function()
	return 0
end
_G.bit = {
	band = function()
		return 0
	end,
}
_G.C_AddOns = {
	GetAddOnMetadata = function()
		return "Forever"
	end,
}
_G.Questie = { API = {
	RegisterOnReady = function(fn)
		readyCallback = fn
	end,
} }

local function Run()
	local due = timers
	timers = {}
	for _, timer in ipairs(due) do
		timer.fn()
	end
end

-- A library whose zone tables can't be read: the read is absent.
local function Setup(library)
	timers, readyCallback = {}, nil
	_G.LibQuestieDB = library
	local ns = Env.namespace()
	Env.load(ns, { "Logic/QuestieSource.lua" })
	local told = 0
	ns.QuestieSource.onReady = function()
		told = told + 1
	end
	return ns.QuestieSource, function()
		return told
	end
end

-- The fallback fires first, then Questie reports ready: one announcement, no second read.
local source, told = Setup(nil)
source.Start()
check(source.State() == "absent" and told() == 0, "nothing is read before Questie is ready or the wait is over")
Run()
check(told() == 1 and source.State() == "absent", "the fallback goes ahead without Questie")
readyCallback()
check(told() == 1, "a late ready does not announce again")

-- Ready first: the fallback does nothing.
source, told = Setup(nil)
source.Start()
readyCallback()
check(told() == 1, "ready starts the read")
Run()
check(told() == 1, "the fallback after ready does nothing")
source.Start()
check(told() == 1, "starting twice does nothing")

-- A readable library: pending, then ready after the slices, never read twice.
local reads = 0
local quests = { 10, 11, 12 }
local zoneChunk = "return { [1] = 100 }"
local library = {
	RequireContract = function()
		return true
	end,
	Quest = {
		GetAllIds = function()
			reads = reads + 1
			return quests
		end,
		GetAll = function()
			return { 0, 0, 100, nil, nil, nil, nil, 0, 0 }
		end,
	},
	Support = {
		Get = function()
			return {
				private = {
					areaIdToUiMapId = zoneChunk,
					areaIdToUiMapIdOverride = "return {}",
					subZoneToParentZone = "return {}",
				},
			}
		end,
	},
}
source, told = Setup(library)
source.Start()
readyCallback()
check(source.State() == "pending", "the catalogue is pending while read")
readyCallback()
Run()
Run()
check(source.State() == "ready" and told() == 1 and reads == 1, "read once, announced once")
print(("questie_source_spec: %d checks"):format(checks))
