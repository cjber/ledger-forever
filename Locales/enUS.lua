---@type string, LedgerForeverNamespace
local _, ns = ...

-- English phrases are the keys, so a phrase no locale translates reads as itself.
ns.L = setmetatable({}, {
	__index = function(_, key)
		return key
	end,
})
ns.L["Ledger Forever report"] = "Ledger Forever report"
