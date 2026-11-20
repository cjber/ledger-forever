-- Run from the repository root: luajit tests/ledger_spec.lua
-- The state machine over a fake client: login catch-up, stamps from stories and from explored areas (with the
-- QuestieDB catalogue absent, pending and ready), level marks paid once, orders paying marks once, the daily roll on
-- the server clock and the events surfaces subscribe to.
local Env = dofile("tests/ledger_env.lua")
local checks = 0
local function check(condition, label)
	checks = checks + 1
	assert(condition, label)
end

local FILES = {
	"Core/State.lua",
	"Logic/Zones.lua",
	"Logic/Chains.lua",
	"Logic/Stamps.lua",
	"Logic/Ranks.lua",
	"Logic/Marks.lua",
	"Logic/Orders.lua",
	"Logic/NextZone.lua",
	"Logic/Ledger.lua",
}

local function Build(options)
	options = options or {}
	_G.LedgerForeverDB = options.saved
	local ns = Env.namespace()
	Env.load(ns, FILES)
	local client, state = Env.client(options.client)
	ns.Client = client
	ns.Style = {
		Duration = function(seconds)
			return tostring(seconds)
		end,
	}
	ns.ZoneRanges = { [100] = { 1, 10 }, [200] = { 10, 20 } }
	ns.Data = { territory = { [100] = 6, [200] = 6 } }
	ns.Areas = { [100] = { ["1:1:1:1"] = true, ["2:2:2:2"] = true }, [200] = { ["3:3:3:3"] = true } }
	local catalogue = { state = options.catalogue or "ready", records = options.records or {} }
	ns.QuestieSource = {
		State = function()
			return catalogue.state
		end,
		Records = function()
			return catalogue.records
		end,
	}
	local events = {}
	ns.Ledger.Subscribe(function(event, payload)
		events[#events + 1] = { event, payload }
	end)
	return ns, state, catalogue, events
end

local function Count(events, name)
	local n = 0
	for _, entry in ipairs(events) do
		n = n + (entry[1] == name and 1 or 0)
	end
	return n
end

local story = {
	[1] = { zone = 100, races = 0, classes = 0, next = 2 },
	[2] = { zone = 100, races = 0, classes = 0, next = 3 },
	[3] = { zone = 100, races = 0, classes = 0 },
}

-- No QuestieDB: zones stamp from explored areas, labelled so.
do
	local ns, state, _, events = Build({ catalogue = "absent" })
	check(ns.Ledger.Load(), "loads with a readable GUID")
	state.explored[100] = { ["1:1:1:1"] = true }
	ns.Ledger.Refresh()
	check(ns.Ledger.StampCount() == 0, "half the areas stamp nothing")
	state.explored[100]["2:2:2:2"] = true
	ns.Ledger.InvalidateExplored()
	ns.Ledger.Refresh()
	local char = ns.Ledger.Char()
	check(char.stamps[100] and char.stamps[100].source == "areas", "all areas explored stamp, from explored areas")
	check(char.txns["stamp:100"] == ns.Marks.Value.stamp, "the stamp pays its mark")
	check(Count(events, "stamp") == 1, "a stamp event")
	local marks = char.marks
	ns.Ledger.Refresh()
	ns.Ledger.Refresh()
	check(char.marks == marks and marks >= ns.Marks.Value.stamp, "marks never repeat")
	check(Count(events, "stamp") == 1, "a stamp is announced once")
	local rows = ns.Ledger.StampRows()
	check(rows[1].zone == 100 and rows[1].stamped and rows[1].source == "areas", "stamped zones list first")
	check(ns.Ledger.Catalogue() == "absent", "the book can say what to install")
end

-- With the catalogue: the story decides, finished at login counts, and a partial story is not a stamp.
do
	local ns, state, _, events = Build({ records = story, client = { completed = { [1] = true, [2] = true } } })
	ns.Ledger.Load()
	state.explored[100] = { ["1:1:1:1"] = true, ["2:2:2:2"] = true }
	ns.Ledger.Refresh()
	check(not ns.Ledger.Char().stamps[100], "all areas explored do not stamp a zone whose story is unfinished")
	local rows = ns.Ledger.StampRows()
	check(rows[1].done == 2 and rows[1].required == 3 and rows[1].proven, "story progress is shown as proven")
	ns.Ledger.QuestDone(3)
	ns.Ledger.Refresh()
	check(ns.Ledger.Char().stamps[100].source == "story", "turning in the last quest stamps the zone")
	check(Count(events, "stamp") == 1, "one stamp event")

	-- Orders: the story order counts quests turned in after it was issued.
	local ns2, state2, _, events2 = Build({ records = story, client = { map = 100 } })
	ns2.Ledger.Load()
	ns2.Ledger.Refresh()
	local list = ns2.Ledger.Char().orders.list
	check(list[1] and list[1].kind == "story" and list[1].zone == 100, "a story order in the current zone")
	ns2.Ledger.QuestDone(1)
	ns2.Ledger.QuestDone(2)
	ns2.Ledger.QuestDone(3)
	ns2.Ledger.Refresh()
	check(list[1].done, "three quests complete a story order")
	local char = ns2.Ledger.Char()
	check(char.txns[list[1].id] == ns2.Marks.Value.order, "the order paid its mark")
	local marks = char.marks
	ns2.Ledger.Refresh()
	check(char.marks == marks, "refreshing again pays nothing")
	check(Count(events2, "order") >= 1 and Count(events2, "stamp") == 1, "events for the order and the stamp")
	check(ns2.Ledger.OrdersDone() >= 1, "orders done counts paid orders")
	local order = ns2.Ledger.OrderRows()[1]
	check(order.done and order.progress == order.target, "a finished row shows full progress")

	-- The daily roll is the server clock passing resetAt.
	local resetAt = char.orders.resetAt
	state2.now = resetAt - 1
	ns2.Ledger.Refresh()
	check(char.orders.resetAt == resetAt and list[1].done, "before the reset nothing rolls")
	state2.now = resetAt
	ns2.Ledger.Refresh()
	check(char.orders.resetAt > resetAt and char.orders.list[1] ~= list[1], "at the reset new orders are issued")
	check(char.marks >= marks, "marks never decrease across a roll")
	state2.now = char.orders.resetAt + 5
	state2.reset = nil
	local kept = char.orders.list
	ns2.Ledger.Refresh()
	check(char.orders.list == kept, "no reset seconds from the client: orders are kept")
end

-- Level marks are paid for levels gained after the first sight, once each.
do
	local ns, state, _, events = Build({ catalogue = "absent", client = { level = 10 } })
	ns.Ledger.Load()
	ns.Ledger.Refresh()
	check(ns.Ledger.Char().levelSeen == 10 and not ns.Ledger.Char().txns["level:10"], "the starting level pays nothing")
	state.level = 12
	ns.Ledger.Refresh()
	check(ns.Ledger.Char().txns["level:11"] and ns.Ledger.Char().txns["level:12"], "each level gained pays")
	ns.Ledger.Refresh()
	check(ns.Ledger.Char().marks >= 2, "marks stay")
	-- A rank-up is announced.
	state.level = 40
	ns.Ledger.Refresh()
	check(Count(events, "rank") >= 1, "a rank event when a payment crosses a threshold")
end

-- A newer database is never written; an unreadable GUID tracks nothing.
do
	local ns = Build({ saved = { version = 99, chars = {} }, catalogue = "absent" })
	ns.Ledger.Load()
	ns.Ledger.Refresh()
	check(ns.Ledger.ReadOnly() and next(ns.Ledger.DB().chars) == nil, "a read-only database is left alone")
	local locked = Build({ catalogue = "absent", client = { guid = false } })
	check(not locked.Ledger.Load() and locked.Ledger.Char() == nil, "a secret GUID tracks nothing")
	locked.Ledger.Refresh()
	check(#locked.Ledger.OrderRows() == 0, "no orders without a character")
end

-- A map with an exploration list and no level range is a stamp zone too.
do
	local ns, state, _, events = Build({ catalogue = "absent" })
	ns.Areas[300] = { ["4:4:4:4"] = true }
	ns.Data.territory[300] = 0
	ns.Ledger.Load()
	state.explored[300] = { ["4:4:4:4"] = true }
	ns.Ledger.Refresh()
	check(ns.Ledger.Char().stamps[300], "an area-only map stamps once explored")
	check(Count(events, "stamp") == 1, "and announces it")
end

-- The completed-quest history is asked for again until it answers, and a quest turned in meanwhile is kept.
do
	local ns, state = Build({ records = story })
	ns.Ledger.Load()
	ns.Ledger.QuestDone(3)
	ns.Ledger.Refresh()
	state.completed = { [1] = true, [2] = true }
	ns.Ledger.Refresh()
	check(ns.Ledger.StampRows()[1].done == 3, "history that answers late is counted with the quest turned in meanwhile")
	state.completed = {}
	ns.Ledger.Refresh()
	check(ns.Ledger.StampRows()[1].done == 3, "once read, the history is not read again")
end

-- While the catalogue is read a story order keeps the progress it had.
do
	local ns, _, catalogue = Build({ records = story, client = { map = 100 } })
	ns.Ledger.Load()
	ns.Ledger.Refresh()
	local order = ns.Ledger.Char().orders.list[1]
	check(order.kind == "story", "a story order")
	ns.Ledger.QuestDone(1)
	ns.Ledger.Refresh()
	check(ns.Ledger.OrderRows()[1].progress == 1, "one quest counted")
	catalogue.state = "pending"
	ns.Ledger.Refresh()
	check(ns.Ledger.OrderRows()[1].progress == 1, "the order does not read zero while the catalogue is read")
end

-- The next zone follows the level and the stamps.
do
	local ns = Build({ catalogue = "absent", client = { level = 5 } })
	ns.Ledger.Load()
	check(ns.Ledger.NextZone() == 100, "the zone for the level")
	ns.Ledger.Char().stamps[100] = { at = 1, source = "story" }
	check(ns.Ledger.NextZone() == 200, "a stamped zone is skipped")
end
print(("ledger_spec: %d checks"):format(checks))
