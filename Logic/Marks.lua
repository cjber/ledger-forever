---@type string, LedgerForeverNamespace
local _, ns = ...

if ns.broken then
	return
end

-- Marks are idempotent transactions keyed by id (`order:<day>:<slot>`, `stamp:<uiMapID>`, `level:<n>`): paying the
-- same id twice changes nothing, and a total never goes down.
---@class LedgerMarks
local Marks = {}
ns.Marks = Marks

Marks.Value = { order = 3, stamp = 10, level = 1 }

---@param char table
---@param id string
---@param kind "order"|"stamp"|"level"
---@return boolean paid false when the id was already paid
---@return integer? newRank the rank index when this payment raised it
function Marks.Pay(char, id, kind)
	if char.txns[id] then
		return false
	end
	local value = Marks.Value[kind]
	char.txns[id] = value
	char.marks = char.marks + value
	local index = ns.Ranks.Index(char.marks)
	if index > char.rank then
		char.rank = index
		return true, index
	end
	return true
end
