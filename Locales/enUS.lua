---@type string, LedgerForeverNamespace
local _, ns = ...

-- English phrases are the keys, so a phrase no locale translates reads as itself.
ns.L = setmetatable({}, {
	__index = function(_, key)
		return key
	end,
})
ns.L["Ledger Forever report"] = "Ledger Forever report"
ns.L["Unknown zone"] = "Unknown zone"
ns.L["Finish story quests"] = "Finish story quests"
ns.L["Discover areas"] = "Discover areas"
ns.L["Reach the next level"] = "Reach the next level"
ns.L["Level %d"] = "Level %d"
ns.L["%s: %s"] = "%s: %s"
ns.L["%s · %d of %d"] = "%s · %d of %d"
ns.L["New orders in %s"] = "New orders in %s"
ns.L["Wanderer"] = "Wanderer"
ns.L["Wayfarer"] = "Wayfarer"
ns.L["Pathfinder"] = "Pathfinder"
ns.L["Trailblazer"] = "Trailblazer"
ns.L["Pioneer"] = "Pioneer"
ns.L["Cartographer"] = "Cartographer"
ns.L["Today's orders"] = "Today's orders"
ns.L["Stamps"] = "Stamps"
ns.L["Track orders"] = "Track orders"
ns.L["Ledger"] = "Ledger"
ns.L["Orders arrive after the next daily reset."] = "Orders arrive after the next daily reset."
ns.L["%d marks · %d stamps · %d orders done"] = "%d marks · %d stamps · %d orders done"
ns.L["Next: %s"] = "Next: %s"
ns.L["%d of %d marks"] = "%d of %d marks"
ns.L["Top rank reached"] = "Top rank reached"
ns.L["Stamped, from explored areas"] = "Stamped, from explored areas"
ns.L["Stamped"] = "Stamped"
ns.L["%d of %d quests"] = "%d of %d quests"
ns.L["%d quests done"] = "%d quests done"
ns.L["%d of %d areas, from explored areas"] = "%d of %d areas, from explored areas"
ns.L["Install QuestieDB so zone stories can be read."] = "Install QuestieDB so zone stories can be read."
ns.L["Reading zone stories..."] = "Reading zone stories..."
ns.L["Next zone: %s"] = "Next zone: %s"
ns.L["Today's orders %d of %d"] = "Today's orders %d of %d"
ns.L["+%d marks so far"] = "+%d marks so far"
ns.L["Stop tracking orders"] = "Stop tracking orders"
ns.L["%s · Level %d"] = "%s · Level %d"
ns.L["Orders"] = "Orders"
ns.L["Show toasts"] = "Show toasts"
ns.L["An order completed and a new rank show an achievement toast. Click it to open the book."] =
	"An order completed and a new rank show an achievement toast. Click it to open the book."
ns.L["Today's orders in the objective tracker."] = "Today's orders in the objective tracker."
ns.L["Ledger Forever"] = "Ledger Forever"
ns.L["%d h %d m"] = "%d h %d m"
ns.L["Order complete"] = "Order complete"
ns.L["New rank"] = "New rank"
ns.L["Settings > Ledger Forever, or the Track orders button in the book"] =
	"Settings > Ledger Forever, or the Track orders button in the book"
