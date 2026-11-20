-- Run from the repository root: luajit tests/chains_spec.lua
-- Adventure Guide's chain rule, and the stamp rule on top of it: eligible chain quests per zone, exclusive
-- alternatives, repeatables, missing masks, Skyborne bits past 32 and the explored-areas fallback.
local Env = dofile("tests/ledger_env.lua")
local ns = Env.load(Env.namespace(), { "Logic/Chains.lua", "Logic/Stamps.lua" })
local checks = 0
local function check(condition, label)
	checks = checks + 1
	assert(condition, label)
end

local function Heads(chains)
	local heads = {}
	for _, chain in ipairs(chains) do
		heads[chain.head] = chain
	end
	return heads
end

-- 1 -> 2 -> 3, a pair 10 -> 11, a lone quest 20, a fork 30 -> 32 <- 31, a loop 40 -> 41 -> 40.
local records = {
	[1] = { next = 2 },
	[2] = { next = 3, pre = { 1 } },
	[3] = { pre = { 2 } },
	[10] = { next = 11 },
	[11] = { pre = { 10 } },
	[20] = {},
	[30] = { next = 32 },
	[31] = { next = 32 },
	[32] = {},
	[40] = { next = 41 },
	[41] = { next = 40 },
}
local heads = Heads(ns.Chains.Build(records))
check(heads[1] and #heads[1].members == 3, "a chain walks its next links")
check(heads[1].total == 3, "a chain whose steps each have one prerequisite and an end has a proven total")
check(heads[10] and #heads[10].members == 2, "two quests are a chain")
check(not heads[20], "a lone quest is not a chain")
check(not heads[30] and not heads[31] and not heads[32], "a fork is not a chain")
check(not heads[40] and not heads[41], "a loop is not a chain")

records = { [1] = { next = 2 }, [2] = { next = 3, preAny = { 1, 9 } }, [3] = {} }
check(Heads(ns.Chains.Build(records))[1].total == nil, "an any-of prerequisite leaves the total unproven")
records = { [1] = { next = 2 }, [2] = { next = 3, pre = { 1, 7 } }, [3] = {} }
check(Heads(ns.Chains.Build(records))[1].total == nil, "two prerequisites leave the total unproven")
records = { [1] = { next = 2 }, [2] = { next = 99 } }
check(Heads(ns.Chains.Build(records))[1].total == nil, "a chain that runs into an unknown quest is unproven")

-- Stamps.
local Stamps = ns.Stamps
local ALLIANCE_HUMAN, WARRIOR = 1, 1
local function Story(extra)
	local zone = 100
	local quests = {
		[1] = { zone = zone, races = 0, classes = 0, next = 2 },
		[2] = { zone = zone, races = 0, classes = 0, next = 3 },
		[3] = { zone = zone, races = 0, classes = 0 },
	}
	for id, record in pairs(extra or {}) do
		quests[id] = record
	end
	return quests, ns.Chains.Build(quests)
end

local quests, chains = Story()
local zones = Stamps.Zones(quests, chains, { [1] = true, [2] = true }, ALLIANCE_HUMAN, WARRIOR)
check(zones[100].required == 3 and zones[100].done == 2, "two of three")
check(Stamps.Earned(zones[100], false) == nil, "an unfinished story earns nothing")
zones = Stamps.Zones(quests, chains, { [1] = true, [2] = true, [3] = true }, ALLIANCE_HUMAN, WARRIOR)
check(Stamps.Earned(zones[100], false) == "story", "a finished story earns the stamp")
check(zones[100].proven, "the zone's total is proven")

quests, chains = Story({ [3] = { zone = 100, races = 2, classes = 0 } })
zones = Stamps.Zones(quests, chains, { [1] = true, [2] = true }, ALLIANCE_HUMAN, WARRIOR)
check(Stamps.Earned(zones[100], false) == "story", "a quest for another race is not required")
quests, chains = Story({ [3] = { zone = 100, races = 1, classes = 1 } })
zones = Stamps.Zones(quests, chains, { [1] = true, [2] = true }, ALLIANCE_HUMAN, WARRIOR)
check(Stamps.Earned(zones[100], false) == nil, "a quest whose race and class both fit is required")
zones = Stamps.Zones(quests, chains, { [1] = true, [2] = true }, ALLIANCE_HUMAN, 2)
check(Stamps.Earned(zones[100], false) == "story", "a quest for another class is not required")

quests, chains = Story({ [3] = { zone = 100, races = nil, classes = 0 } })
zones = Stamps.Zones(quests, chains, { [1] = true, [2] = true }, ALLIANCE_HUMAN, WARRIOR)
check(Stamps.Earned(zones[100], false) == "story", "a record with a missing mask is not story")
quests, chains = Story({ [3] = { zone = 100, races = 0, classes = 0, repeatable = true } })
zones = Stamps.Zones(quests, chains, { [1] = true, [2] = true }, ALLIANCE_HUMAN, WARRIOR)
check(Stamps.Earned(zones[100], false) == "story", "a repeatable is not story")

quests, chains = Story({ [3] = { zone = 100, races = 0, classes = 0, exclusive = { 50 } } })
zones = Stamps.Zones(quests, chains, { [1] = true, [2] = true, [50] = true }, ALLIANCE_HUMAN, WARRIOR)
check(Stamps.Earned(zones[100], false) == "story", "one alternative of an exclusive group is enough")

-- A character with no race or class bit is admitted by no restricted mask, and nothing divides by zero.
quests, chains = Story({ [3] = { zone = 100, races = 1, classes = 0 } })
zones = Stamps.Zones(quests, chains, { [1] = true, [2] = true }, nil, WARRIOR)
check(Stamps.Earned(zones[100], false) == "story", "a restricted quest does not admit a race with no bit")
quests, chains = Story({ [3] = { zone = 100, races = 0, classes = 0 } })
zones = Stamps.Zones(quests, chains, { [1] = true, [2] = true }, nil, nil)
check(Stamps.Earned(zones[100], false) == nil, "an open quest still admits a character with no bits")

-- Skyborne bits sit past 32: no 32-bit arithmetic.
local SKYBORNE = 2 ^ 32
quests, chains = Story({ [3] = { zone = 100, races = SKYBORNE + 1, classes = 0 } })
zones = Stamps.Zones(quests, chains, { [1] = true, [2] = true }, SKYBORNE, WARRIOR)
check(Stamps.Earned(zones[100], false) == nil, "a Skyborne race bit is read")
zones = Stamps.Zones(quests, chains, { [1] = true, [2] = true }, 2 ^ 31, WARRIOR)
check(Stamps.Earned(zones[100], false) == "story", "another race does not match a high bit")

-- A zone with no chain stamps from explored areas, and says so.
check(Stamps.Earned(nil, true) == "areas", "explored areas stamp a zone with no chain")
check(Stamps.Earned(nil, false) == nil, "partly explored earns nothing")
check(
	Stamps.Earned({ required = 0, done = 0 }, true) == "areas",
	"a zone whose chain quests are all ineligible falls back"
)
print(("chains_spec: %d checks"):format(checks))
