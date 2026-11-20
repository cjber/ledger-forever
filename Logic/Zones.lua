---@type string, LedgerForeverNamespace
local _, ns = ...

if ns.broken then
	return
end

-- The one reader of the generated tables: ns.ZoneRanges[uiMapID] = { lo, hi } (Data/ZoneLevels.lua),
-- ns.Data.territory[uiMapID] = mask (Data/Territory.lua, 2 Alliance, 4 Horde, 0 contested, 6 both) and
-- ns.Areas[uiMapID] = { ["x:y:width:height"] = true, ... } (Data/Areas.lua), the exploration keys of a zone.
---@class LedgerZones
local Zones = {}
ns.Zones = Zones

---@return integer[] ids every zone with a level range or an exploration list, ascending
function Zones.Ids()
	local ids = {}
	for id in pairs(ns.ZoneRanges) do
		ids[#ids + 1] = id
	end
	for id in pairs(ns.Areas) do
		if not ns.ZoneRanges[id] then
			ids[#ids + 1] = id
		end
	end
	table.sort(ids)
	return ids
end

---@param id integer
---@return integer? lo
---@return integer? hi
function Zones.Range(id)
	local range = ns.ZoneRanges[id]
	if not range then
		return nil, nil
	end
	local lo, hi = ns.Client.MapLevels(id)
	return lo or range[1], hi or range[2]
end

---@param id integer
---@return integer mask 0 when unknown
function Zones.Territory(id)
	return ns.Data.territory[id] or 0
end

---@param id integer
---@return table<string, boolean> keys the zone's exploration keys, empty when it has none
function Zones.AreaKeys(id)
	return ns.Areas[id] or {}
end

-- Zones the character's faction may enter that have an exploration list or a level range, as NextZone.Pick takes.
---@return table[]
function Zones.List()
	local list = {}
	for _, id in ipairs(Zones.Ids()) do
		local lo, hi = Zones.Range(id)
		list[#list + 1] = { id = id, lo = lo, hi = hi, territory = Zones.Territory(id) }
	end
	return list
end
