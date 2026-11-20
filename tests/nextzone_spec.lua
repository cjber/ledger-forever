-- Run from the repository root: luajit tests/nextzone_spec.lua
local Env = dofile("tests/ledger_env.lua")
local ns = Env.load(Env.namespace(), { "Logic/NextZone.lua" })
local checks = 0
local function check(condition, label)
	checks = checks + 1
	assert(condition, label)
end

local Pick = ns.NextZone.Pick
local zones = {
	{ id = 3, lo = 1, hi = 10, territory = 2 },
	{ id = 1, lo = 5, hi = 12, territory = 0 },
	{ id = 2, lo = 5, hi = 12, territory = 6 },
	{ id = 4, lo = 8, hi = 20, territory = 4 },
	{ id = 5, lo = 30, hi = 40, territory = 2 },
	{ id = 6, lo = 20, hi = 29, territory = 2 },
}
check(Pick(zones, 6, 2, {}) == 3, "the range holding the level with the lowest minimum")
check(Pick(zones, 7, 2, { [3] = true }) == 1, "ties go to the lowest map id")
check(Pick(zones, 9, 4, { [1] = true, [2] = true, [3] = true }) == 4, "a Horde character reaches Horde zones")
check(
	Pick(zones, 9, 2, { [1] = true, [2] = true, [3] = true }) == 6,
	"an Alliance one does not, so the nearest range above"
)
check(Pick(zones, 50, 2, {}) == nil, "nothing at or above the level: no line")
check(Pick(zones, 9, 2, { [1] = true, [2] = true, [3] = true, [6] = true }) == 5, "stamped zones are skipped")
check(Pick({}, 9, 2, {}) == nil, "no zones")
check(Pick({ { id = 1, territory = 0 } }, 9, 2, {}) == nil, "a zone with no level range is never picked")
print(("nextzone_spec: %d checks"):format(checks))
