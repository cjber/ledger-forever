-- Run from the repository root: luajit tests/orders_spec.lua
-- Daily orders: issued once per day with their inputs stored, never replaced, completed once, rolled by the server
-- clock passing resetAt, and left alone when the client gives no reset time.
local Env = dofile("tests/ledger_env.lua")
local ns = Env.load(Env.namespace(), { "Logic/Ranks.lua", "Logic/Marks.lua", "Logic/Orders.lua" })
local checks = 0
local function check(condition, label)
	checks = checks + 1
	assert(condition, label)
end

local Orders = ns.Orders
local state = { story = { { zone = 10, open = 5 } }, done = { [10] = 2 }, explored = { [20] = 1 }, level = 10 }
local function Ctx()
	return {
		level = state.level,
		maxLevel = 60,
		story = function()
			return state.story
		end,
		discover = function()
			return { { zone = 20, unexplored = 4 } }
		end,
		storyDone = function(zone)
			return state.done[zone] or 0
		end,
		explored = function(zone)
			return state.explored[zone] or 0
		end,
	}
end

local orders = {}
check(Orders.Ensure(orders, Ctx(), 1000, 3600), "the first call issues orders")
check(orders.resetAt == 4600 and orders.verifier == Orders.VERIFIER, "resetAt and the verifier version are stored")
check(#orders.list == 3, "three orders")
local story, discover, level = orders.list[1], orders.list[2], orders.list[3]
check(story.kind == "story" and story.zone == 10 and story.target == 3 and story.baseline == 2, "story order inputs")
check(
	discover.kind == "discover" and discover.zone == 20 and discover.target == 2 and discover.baseline == 1,
	"discover inputs"
)
check(level.kind == "level" and level.level == 11, "level order is the next level")
check(story.id == "order:4600:1", "an order's mark id carries the day and slot")

check(not Orders.Ensure(orders, Ctx(), 2000, 2600), "the same day issues nothing new")
state.story = { { zone = 99, open = 1 } }
Orders.Ensure(orders, Ctx(), 2100, 2500)
check(orders.list[1] == story and story.zone == 10, "an order is never replaced mid-day")

check(Orders.Progress(story, Ctx()) == 0, "no progress yet")
state.done[10] = 4
check(Orders.Progress(story, Ctx()) == 2, "progress is the count since the baseline")
check(#Orders.Complete(orders, Ctx()) == 0, "not complete")
state.done[10] = 9
local completed = Orders.Complete(orders, Ctx())
check(#completed == 1 and completed[1] == story and story.done, "complete at the target")
check(Orders.Progress(story, Ctx()) == 3, "progress is capped at the target")
check(#Orders.Complete(orders, Ctx()) == 0, "an order completes once")
state.level = 11
check(#Orders.Complete(orders, Ctx()) == 1, "reaching the level completes the level order")
local done, issued = Orders.Count(orders)
check(done == 2 and issued == 3, "count")

-- The day rolls on the server clock, never on a timer.
check(not Orders.NewDay(orders, 4599) and Orders.NewDay(orders, 4600), "a new day is the clock passing resetAt")
state.story = { { zone = 10, open = 5 } }
check(not Orders.Ensure(orders, Ctx(), 5000, nil), "no reset time keeps the current orders and rolls nothing")
check(orders.resetAt == 4600 and orders.list[1] == story, "orders kept")
check(Orders.Ensure(orders, Ctx(), 5000, 70000), "with a reset time the day rolls")
check(orders.resetAt == 75000 and orders.list[1] ~= story and not orders.list[1].done, "new orders for the new day")
check(orders.list[1].id == "order:75000:1", "new day, new ids")

-- Fewer than three is fine: nothing verifiable for a kind means no order for it.
local sparse = {}
state.story = nil
Orders.Ensure(sparse, Ctx(), 1000, 100)
check(sparse.list[1] == nil and sparse.list[2] ~= nil, "no story catalogue yet: no story order")
state.story = { { zone = 10, open = 1 } }
check(
	Orders.Ensure(sparse, Ctx(), 1001, 99) and sparse.list[1].target == 1,
	"the slot fills when the catalogue answers"
)
state.level = 60
local capped = {}
Orders.Ensure(capped, Ctx(), 1000, 100)
check(capped.list[3] == nil, "no level order at the level cap")

-- A day's pick is deterministic.
state.story = { { zone = 5, open = 2 }, { zone = 6, open = 2 }, { zone = 7, open = 2 } }
local a, b = {}, {}
Orders.Ensure(a, Ctx(), 1000, 100)
Orders.Ensure(b, Ctx(), 1000, 100)
check(a.list[1].zone == b.list[1].zone, "the same day picks the same zone")
print(("orders_spec: %d checks"):format(checks))
