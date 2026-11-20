-- Run from the repository root: luajit tests/data_spec.lua
-- The generated tables parse and have the shapes Logic/Zones.lua reads: level ranges, faction masks, and exploration
-- key sets by UiMapID, with every zone that has a range also having a territory.
local Env = dofile("tests/ledger_env.lua")
local ns = Env.namespace()
ns.Data = {}
Env.load(ns, { "Data/ZoneLevels.lua", "Data/Territory.lua", "Data/Areas.lua" })
local checks = 0
local function check(condition, label)
	checks = checks + 1
	assert(condition, label)
end

local ranges = 0
for id, range in pairs(ns.ZoneRanges) do
	ranges = ranges + 1
	check(type(id) == "number", "range key is a map id")
	check(
		type(range[1]) == "number" and type(range[2]) == "number" and range[1] <= range[2],
		"range " .. id .. " is ordered"
	)
	check(range[1] >= 1 and range[2] <= 80, "range " .. id .. " is a level range")
end
check(ranges > 20, "level ranges are not empty")

for id, mask in pairs(ns.Data.territory) do
	check(
		type(id) == "number" and (mask == 0 or mask == 2 or mask == 4 or mask == 6),
		"territory " .. id .. " is a faction mask"
	)
end
for id in pairs(ns.ZoneRanges) do
	check(ns.Data.territory[id] ~= nil, "zone " .. id .. " has a territory")
end

local areas = 0
for id, keys in pairs(ns.Areas) do
	areas = areas + 1
	check(type(id) == "number" and next(keys) ~= nil, "zone " .. id .. " has area keys")
	for key, flag in pairs(keys) do
		check(
			flag == true and key:match("^%-?%d+:%-?%d+:%d+:%d+$"),
			"area key " .. key .. " is offsetX:offsetY:width:height"
		)
	end
end
check(areas > 20, "area keys are not empty")

-- Logic/Zones.lua reads all three.
Env.load(ns, { "Logic/Zones.lua" })
ns.Client = {
	MapLevels = function()
		return nil, nil
	end,
}
local list = ns.Zones.List()
local listed = {}
for _, zone in ipairs(list) do
	listed[zone.id] = zone
end
for id in pairs(ns.ZoneRanges) do
	check(listed[id], "every range is a listed zone")
end
for id in pairs(ns.Areas) do
	check(listed[id], "every exploration list is a listed zone, so its map can stamp")
	check(ns.ZoneRanges[id] or listed[id].lo == nil, "a map without a range lists no range")
end
check(list[1].id < list[#list].id, "zones are listed by map id")
local lo, hi = ns.Zones.Range(list[1].id)
check(
	lo == ns.ZoneRanges[list[1].id][1] and hi == ns.ZoneRanges[list[1].id][2],
	"the table range answers without a client range"
)
ns.Client.MapLevels = function()
	return 3, 4
end
lo, hi = ns.Zones.Range(list[1].id)
check(lo == 3 and hi == 4, "the client's range wins")
check(ns.Zones.Territory(-1) == 0 and next(ns.Zones.AreaKeys(-1)) == nil, "an unknown map is contested with no areas")
print(("data_spec: %d checks"):format(checks))
