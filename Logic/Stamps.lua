---@type string, LedgerForeverNamespace
local _, ns = ...

if ns.broken then
	return
end

-- A zone's stamp is earned when every eligible story-chain quest there is completed. A quest is eligible when its
-- race and class masks admit the character (a record with a missing mask is not story, nor is a repeatable); an
-- `exclusiveTo` group asks for one alternative. A stamp, once earned, is stored and never lost.
---@class LedgerStamps
local Stamps = {}
ns.Stamps = Stamps

-- Whether mask has bit `value` (a power of two) set. Skyborne bits sit past 32, so no bit library.
---@param mask number
---@param value number
---@return boolean
local function Has(mask, value)
	return math.floor(mask / value) % 2 == 1
end

---@param mask number? nil is a missing mask, 0 admits everyone
---@param value number? the character's bit; nil when it has none, which no restricted mask admits
---@return boolean
local function Admits(mask, value)
	return mask ~= nil and (mask == 0 or (value ~= nil and Has(mask, value)))
end

---@param record table
---@param raceBit number?
---@param classBit number?
---@return boolean
local function Eligible(record, raceBit, classBit)
	return not record.repeatable and Admits(record.races, raceBit) and Admits(record.classes, classBit)
end

---@param record table
---@param id integer
---@param completed table<integer, boolean>
---@return boolean
local function Satisfied(record, id, completed)
	if completed[id] then
		return true
	end
	for _, other in ipairs(record.exclusive or {}) do
		if completed[other] then
			return true
		end
	end
	return false
end

-- Required and finished story quests per zone: zones[uiMapID] = { required = n, done = n, proven = bool }.
---@param records table<integer, table>
---@param chains table[]
---@param completed table<integer, boolean>
---@param raceBit number?
---@param classBit number?
---@return table<integer, table>
function Stamps.Zones(records, chains, completed, raceBit, classBit)
	local zones = {}
	for _, chain in ipairs(chains) do
		for _, id in ipairs(chain.members) do
			local record = records[id]
			if record.zone and Eligible(record, raceBit, classBit) then
				local zone = zones[record.zone] or { required = 0, done = 0, proven = true, open = {} }
				zones[record.zone] = zone
				zone.required = zone.required + 1
				if Satisfied(record, id, completed) then
					zone.done = zone.done + 1
				else
					zone.open[#zone.open + 1] = id
				end
				if not chain.total then
					zone.proven = false
				end
			end
		end
	end
	return zones
end

-- The stamp source for a zone: "story" when its eligible chain is finished, "areas" when it has no chain and every
-- area key is explored, nil otherwise.
---@param story table? the zone's entry from Stamps.Zones
---@param exploredAll boolean whether every Areas key of the zone is explored
---@return "story"|"areas"|nil
function Stamps.Earned(story, exploredAll)
	if story and story.required > 0 then
		return story.done >= story.required and "story" or nil
	end
	return exploredAll and "areas" or nil
end
