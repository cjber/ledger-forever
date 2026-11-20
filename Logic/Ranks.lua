---@type string, LedgerForeverNamespace
local _, ns = ...

if ns.broken then
	return
end

local L = ns.L

-- The cosmetic ladder: six ranks of three steps each, by cumulative marks. These thresholds are product data, in
-- one table so the pace is tuned in one place.
---@class LedgerRanks
local Ranks = {}
ns.Ranks = Ranks

Ranks.Names = {
	L["Wanderer"],
	L["Wayfarer"],
	L["Pathfinder"],
	L["Trailblazer"],
	L["Pioneer"],
	L["Cartographer"],
}

Ranks.STEPS = 3
Ranks.Thresholds = { 0, 8, 18, 30, 45, 62, 85, 110, 140, 180, 225, 275, 335, 400, 470, 550, 650, 760 }

local NUMERALS = { "I", "II", "III" }

-- The rank index (1 to 18) a mark total reaches.
---@param marks integer
---@return integer
function Ranks.Index(marks)
	local index = 1
	for step, threshold in ipairs(Ranks.Thresholds) do
		if marks >= threshold then
			index = step
		end
	end
	return index
end

---@param index integer
---@return integer tier 1 to 6
---@return integer step 1 to 3
function Ranks.Split(index)
	return math.floor((index - 1) / Ranks.STEPS) + 1, (index - 1) % Ranks.STEPS + 1
end

---@param index integer
---@return string
function Ranks.Name(index)
	local tier, step = Ranks.Split(index)
	return Ranks.Names[tier] .. " " .. NUMERALS[step]
end

-- The marks the next step needs, or nil at the top.
---@param index integer
---@return integer?
function Ranks.NextThreshold(index)
	return Ranks.Thresholds[index + 1]
end

-- Progress inside the current step as 0 to 1; the top step is full.
---@param marks integer
---@return number
function Ranks.Fraction(marks)
	local index = Ranks.Index(marks)
	local top = Ranks.Thresholds[index + 1]
	if not top then
		return 1
	end
	local low = Ranks.Thresholds[index]
	return (marks - low) / (top - low)
end
