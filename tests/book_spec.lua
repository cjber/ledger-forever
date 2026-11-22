-- Run from the repository root: luajit tests/book_spec.lua
-- The book: one opener serves every entry point and refuses combat through core, Escape closes it without the
-- panel manager, it paints the rank card, orders and stamps, says what to install without QuestieDB, and a hidden
-- book does no work.
local Env = dofile("tests/ledger_env.lua")
local checks = 0
local function check(condition, label)
	checks = checks + 1
	assert(condition, label)
end

local frames = {}
_G.UISpecialFrames = {}
_G.UIParent = Env.widget("UIParent")
_G.UIParent.GetWidth = function()
	return 712
end
_G.C_Texture = {
	GetAtlasInfo = function()
		return { width = 64, height = 64 }
	end,
}
_G.CreateFrame = function(kind, name)
	local frame = Env.widget(kind)
	frame.name = name
	frame.CloseButton = Env.widget("Button")
	frames[#frames + 1] = frame
	return frame
end
_G.ShowUIPanel = function()
	error("the panel manager taints the gamepad bookkeeping")
end
_G.HideUIPanel = _G.ShowUIPanel
local registered
_G.ForeverCore = {
	Register = function(name, spec)
		registered = { name = name, spec = spec }
		return {
			SafeCall = function(_, fn, ...)
				return fn(...)
			end,
		}
	end,
	Open = function() end,
	Credits = { Register = function() end },
}
_G.SlashCmdList = {}
_G.strtrim = function(text)
	return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

local ns = Env.namespace()
ns.Slash = { "/ledger", "/ledgerforever" }
ns.Credits = {}
local catalogue, requested = "ready", 0
local char = { marks = 30, rank = 4, txns = {}, stamps = {}, orders = { list = { { done = true }, { done = false } } } }
local setting = true
ns.Client = Env.client()
ns.Events = {
	Request = function()
		requested = requested + 1
	end,
}
ns.Tracker = { Refresh = function() end }
ns.State = {
	Setting = function()
		return setting
	end,
	SetSetting = function(_, _, value)
		setting = value
	end,
}
ns.Ledger = {
	Subscribe = function() end,
	Char = function()
		return char
	end,
	DB = function() end,
	OrderRows = function()
		return {
			{ name = "Story", sub = "Zone · 1 of 3", done = false },
			{ name = "Level", sub = "Level 11 · 1 of 1", done = true },
		}
	end,
	ResetText = function()
		return "New orders in 9 h"
	end,
	StampCount = function()
		return 1
	end,
	OrdersDone = function()
		return 4
	end,
	StampRows = function()
		return {
			{ name = "Durotar", stamped = true, source = "story" },
			{ name = "Mulgore", stamped = false, source = "story", proven = true, done = 11, required = 17 },
			{ name = "Barrens", stamped = false, source = "areas", done = 1, required = 4 },
		}
	end,
	Catalogue = function()
		return catalogue
	end,
	NextZone = function()
		return 1413
	end,
	ZoneName = function(zone)
		return "Zone " .. zone
	end,
}
_G.C_AddOns = {
	GetAddOnMetadata = function()
		return "icon"
	end,
}
Env.load(ns, { "Core/Art.lua" })
Env.load(
	ns,
	{ "Logic/Ranks.lua", "Logic/Marks.lua", "Logic/Orders.lua", "UI/Style.lua", "UI/Book.lua", "Core/Core.lua" }
)

check(UISpecialFrames[1] == "LedgerForeverFrame", "Escape closes the book")
check(
	registered.name == "LedgerForever" and registered.spec.openSecure == true,
	"the opener refuses combat through core"
)
check(#frames == 0, "nothing is built before the first open")
ns.Book.Refresh()
check(#frames == 0, "a hidden book does no work")

check(registered.spec.open() == true, "the registered opener opens the book")
check(ns.Book.IsShown() and requested == 1, "the book is shown and asks for a fresh refresh")
local function Has(text)
	for _, frame in ipairs(Env.widgets) do
		if frame.text == text then
			return true
		end
	end
	return false
end
check(
	Has("Wayfarer I") or Has("Pathfinder I") or Has("Wayfarer II") or Has("Pathfinder II"),
	"the rank card names the rank"
)
check(Has("30 marks · 1 stamps · 4 orders done"), "the totals line")
check(Has("Today's orders 1 of 3") and Has("+3 marks so far"), "the bottom bar counts the day")
check(Has("Stamped") and Has("11 of 17 quests") and Has("1 of 4 areas, from explored areas"), "the stamp rows")
check(Has("Next zone: Zone 1413"), "the next zone line")
check(Has("New orders in 9 h"), "the reset line")

catalogue = "absent"
ns.Book.Refresh()
check(Has("Install QuestieDB so zone stories can be read."), "without QuestieDB the book says what to install")
catalogue = "pending"
ns.Book.Refresh()
check(Has("Reading zone stories..."), "while the catalogue loads it says so")

ns.Book.Toggle()
check(not ns.Book.IsShown(), "a second open closes it")
local before = requested
ns.Book.Refresh()
check(requested == before, "refreshing a closed book does nothing")
frames[1].CloseButton.scripts.OnClick()
check(not ns.Book.IsShown(), "the close button hides the frame directly")
print(("book_spec: %d checks"):format(checks))
