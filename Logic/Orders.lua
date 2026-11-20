---@type string, LedgerForeverNamespace
local _, ns = ...

if ns.broken then
	return
end

-- Three daily orders: finish story quests in a zone, discover areas in a zone, reach the next level. An order is
-- stored with its inputs, its baseline and the verifier version, so a later build never re-reads it differently. An
-- order that cannot be checked is never offered, so fewer than three is fine.
--
-- There is no timer. Each order set stores `resetAt`, the server time of the daily reset when it was issued; a new
-- day is the server clock passing it, checked when something already happens (login, a turned-in quest, a level, the
-- book opening, a tracker refresh). A client that gives no reset time keeps the orders it has and rolls nothing.
--
-- ctx: { level, maxLevel, story() -> { zone, open }[]|nil (nil while the catalogue loads), discover() -> { zone,
-- unexplored }[], storyDone(zone), explored(zone) }
---@class LedgerOrders
local Orders = {}
ns.Orders = Orders

Orders.VERIFIER = 1
Orders.SLOTS = { "story", "discover", "level" }
local STORY_TARGET, DISCOVER_TARGET = 3, 2

-- The day's pick among sorted candidates, the same for the same day.
local function Pick(candidates, seed)
	table.sort(candidates, function(a, b)
		return a.zone < b.zone
	end)
	return candidates[seed % #candidates + 1]
end

---@param kind string
---@param ctx table
---@param seed integer
---@return table?
local function Issue(kind, ctx, seed)
	if kind == "story" then
		local candidates = ctx.story()
		if not candidates or #candidates == 0 then
			return nil
		end
		local pick = Pick(candidates, seed)
		return {
			kind = kind,
			zone = pick.zone,
			target = math.min(STORY_TARGET, pick.open),
			baseline = ctx.storyDone(pick.zone),
		}
	elseif kind == "discover" then
		local candidates = ctx.discover()
		if #candidates == 0 then
			return nil
		end
		local pick = Pick(candidates, seed)
		return {
			kind = kind,
			zone = pick.zone,
			target = math.min(DISCOVER_TARGET, pick.unexplored),
			baseline = ctx.explored(pick.zone),
		}
	end
	if ctx.level >= ctx.maxLevel then
		return nil
	end
	return { kind = "level", level = ctx.level + 1, target = 1, baseline = 0 }
end

---@param order table
---@param ctx table
---@return integer
function Orders.Progress(order, ctx)
	local current
	if order.kind == "story" then
		local done = ctx.storyDone(order.zone)
		if done == nil then
			-- The story catalogue is still being read: the last progress seen stands.
			return order.progress or 0
		end
		current = done - order.baseline
	elseif order.kind == "discover" then
		current = ctx.explored(order.zone) - order.baseline
	else
		current = ctx.level >= order.level and 1 or 0
	end
	return math.max(0, math.min(order.target, current))
end

---@param orders table the character's orders record
---@param now integer
---@return boolean
function Orders.NewDay(orders, now)
	return orders.resetAt ~= nil and now >= orders.resetAt
end

-- Issues the day's orders when a day has rolled, and fills a slot that was not available at the roll (the story
-- catalogue still loading) when it becomes so. Never replaces an order already issued today.
---@param orders table
---@param ctx table
---@param now integer
---@param secondsUntilReset integer? nil when the client gives none
---@return boolean changed
function Orders.Ensure(orders, ctx, now, secondsUntilReset)
	local changed = false
	if not orders.resetAt or Orders.NewDay(orders, now) then
		if not secondsUntilReset then
			return false
		end
		orders.resetAt = now + secondsUntilReset
		orders.verifier = Orders.VERIFIER
		orders.list = {}
		changed = true
	end
	orders.list = orders.list or {}
	for slot, kind in ipairs(Orders.SLOTS) do
		if not orders.list[slot] then
			local order = Issue(kind, ctx, orders.resetAt + slot)
			if order then
				order.slot = slot
				order.id = ("order:%d:%d"):format(orders.resetAt, slot)
				orders.list[slot] = order
				changed = true
			end
		end
	end
	return changed
end

-- Marks every order whose goal is reached as done, once, and returns them for payment.
---@param orders table
---@param ctx table
---@return table[] completed
function Orders.Complete(orders, ctx)
	local completed = {}
	for slot = 1, #Orders.SLOTS do
		local order = orders.list and orders.list[slot]
		if order and not order.done then
			local progress = Orders.Progress(order, ctx)
			order.progress = progress
			if progress >= order.target then
				order.done = true
				completed[#completed + 1] = order
			end
		end
	end
	return completed
end

---@param orders table
---@return integer done
---@return integer issued
function Orders.Count(orders)
	local done, issued = 0, 0
	for slot = 1, #Orders.SLOTS do
		local order = orders.list and orders.list[slot]
		if order then
			issued = issued + 1
			if order.done then
				done = done + 1
			end
		end
	end
	return done, issued
end
