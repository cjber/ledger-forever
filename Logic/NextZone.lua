---@type string, LedgerForeverNamespace
local _, ns = ...

if ns.broken then
	return
end

---@class LedgerNextZone
local NextZone = {}
ns.NextZone = NextZone

local function Earlier(zone, best)
	return not best or zone.lo < best.lo or (zone.lo == best.lo and zone.id < best.id)
end

-- The zone to go to next: among zones the faction may enter that have no stamp yet, the range holding the level with
-- the lowest minimum (then the lowest UiMapID); else the nearest range above the level; else none.
-- zones: { id, lo, hi, territory } with territory 2 Alliance, 4 Horde, 0 contested, 6 both.
---@param zones table[]
---@param level integer
---@param factionBit integer 2 for Alliance, 4 for Horde
---@param stamped table<integer, any>
---@return integer? id
function NextZone.Pick(zones, level, factionBit, stamped)
	local inside, above
	for _, zone in ipairs(zones) do
		local open = not stamped[zone.id] and (zone.territory == 0 or math.floor(zone.territory / factionBit) % 2 == 1)
		if open and zone.lo and zone.hi then
			if zone.lo <= level and level <= zone.hi then
				if Earlier(zone, inside) then
					inside = zone
				end
			elseif zone.lo > level and Earlier(zone, above) then
				above = zone
			end
		end
	end
	local pick = inside or above
	return pick and pick.id
end
