---@type string, LedgerForeverNamespace
local _, ns = ...

if ns.broken then
	return
end

local L = ns.L

-- The addon's state machine: reads the client through ns.Client, keeps the character's record, and tells the
-- surfaces (book, tracker, toast) when something changed. It draws nothing itself.
---@class LedgerLedger
local Ledger = {}
ns.Ledger = Ledger

local db, readOnly, char
local completed, chains, zoneStory, exploredCache = {}, {}, {}, {}
local listeners = {}
local sweptCompleted, chainsBuilt = false, false
-- The story only moves when a quest is turned in or the catalogue's state changes; a zone change leaves it be.
local storyDirty, storyState = true, nil

---@param fn fun(event: string, payload: any)
function Ledger.Subscribe(fn)
	listeners[#listeners + 1] = fn
end

local function Emit(event, payload)
	for _, fn in ipairs(listeners) do
		ns.core.SafeCall("ledger " .. event, fn, event, payload)
	end
end

---@return table db
function Ledger.DB()
	return db
end

---@return table? char the current character's record
function Ledger.Char()
	return char
end

---@return boolean
function Ledger.ReadOnly()
	return readOnly
end

-- Loads the saved variable, migrating it, and picks up this character's record. False when the client gives no
-- readable GUID (a secret value), in which case nothing is tracked until it does.
---@return boolean
function Ledger.Load()
	LedgerForeverDB, readOnly = ns.State.Migrate(LedgerForeverDB)
	db = LedgerForeverDB
	local guid = ns.Client.Guid()
	if not guid then
		return false
	end
	char = ns.State.Char(db, guid, readOnly)
	return true
end

-- Whether the story catalogue answers: the zone stories need QuestieDB's quests, read over a few frames.
---@return "absent"|"pending"|"ready"
function Ledger.Catalogue()
	return ns.QuestieSource.State()
end

local function RebuildStory()
	local state = ns.QuestieSource.State()
	if not storyDirty and state == storyState then
		return
	end
	storyDirty, storyState = false, state
	if state ~= "ready" then
		chains, zoneStory = {}, {}
		return
	end
	local records = ns.QuestieSource.Records()
	if not chainsBuilt then
		chains, chainsBuilt = ns.Chains.Build(records), true
	end
	zoneStory = ns.Stamps.Zones(records, chains, completed, ns.Client.RaceBit(), ns.Client.ClassBit())
end

---@param id integer a quest just turned in
function Ledger.QuestDone(id)
	completed[id] = true
	storyDirty = true
end

function Ledger.InvalidateExplored()
	exploredCache = {}
end

---@param zone integer
---@return integer explored
---@return integer total
local function Explored(zone)
	local cached = exploredCache[zone]
	if not cached then
		local known, count, total = ns.Client.ExploredKeys(zone), 0, 0
		for key in pairs(ns.Zones.AreaKeys(zone)) do
			total = total + 1
			if known[key] then
				count = count + 1
			end
		end
		cached = { count, total }
		exploredCache[zone] = cached
	end
	return cached[1], cached[2]
end

-- What the order checks read from the client and the story, as Orders takes them.
---@return table
local function Context()
	local level = ns.Client.Level()
	local current = ns.Client.CurrentMap()
	local ctx = { level = level, maxLevel = ns.Client.MaxLevel() }
	function ctx.story()
		if ns.QuestieSource.State() == "pending" then
			return nil
		end
		local list = {}
		for zone, story in pairs(zoneStory) do
			if not char.stamps[zone] and #story.open > 0 and (zone == current or story.done > 0) then
				list[#list + 1] = { zone = zone, open = #story.open }
			end
		end
		return list
	end
	function ctx.discover()
		local list = {}
		for _, zone in ipairs(ns.Zones.List()) do
			if not char.stamps[zone.id] and zone.lo and zone.lo <= level and level <= zone.hi then
				local explored, total = Explored(zone.id)
				if total > explored then
					list[#list + 1] = { zone = zone.id, unexplored = total - explored }
				end
			end
		end
		return list
	end
	function ctx.storyDone(zone)
		if ns.QuestieSource.State() == "pending" then
			return nil
		end
		return zoneStory[zone] and zoneStory[zone].done or 0
	end
	function ctx.explored(zone)
		return (Explored(zone))
	end
	return ctx
end

local function Sweep(now)
	local catalogue = ns.QuestieSource.State()
	if catalogue == "pending" then
		return
	end
	for _, id in ipairs(ns.Zones.Ids()) do
		if not char.stamps[id] then
			local explored, total = Explored(id)
			local source = ns.Stamps.Earned(zoneStory[id], total > 0 and explored == total)
			if source then
				char.stamps[id] = { at = now, source = source }
				local _, rank = ns.Marks.Pay(char, "stamp:" .. id, "stamp")
				Emit("stamp", id)
				if rank then
					Emit("rank", rank)
				end
			end
		end
	end
end

-- One pass over everything that can have changed. Safe to call as often as events arrive; each step is a no-op when
-- nothing moved.
function Ledger.Refresh()
	if not char or readOnly then
		return
	end
	if not sweptCompleted then
		-- An empty answer is the history not loaded yet, asked for again at the next refresh; a quest turned in
		-- meanwhile is kept.
		local history = ns.Client.CompletedQuests()
		sweptCompleted = next(history) ~= nil
		for id in pairs(completed) do
			history[id] = true
		end
		completed, storyDirty = history, true
	end
	RebuildStory()
	local now = ns.Client.Now()
	local ctx = Context()
	local level = ctx.level
	if not char.levelSeen then
		char.levelSeen = level
	end
	for n = char.levelSeen + 1, level do
		local _, rank = ns.Marks.Pay(char, "level:" .. n, "level")
		if rank then
			Emit("rank", rank)
		end
	end
	char.levelSeen = math.max(char.levelSeen, level)
	Sweep(now)
	ns.Orders.Ensure(char.orders, ctx, now, ns.Client.SecondsUntilReset())
	for _, order in ipairs(ns.Orders.Complete(char.orders, ctx)) do
		local _, rank = ns.Marks.Pay(char, order.id, "order")
		Emit("order", order)
		if rank then
			Emit("rank", rank)
		end
	end
	Emit("changed")
end

---@param zone integer
---@return string
function Ledger.ZoneName(zone)
	return ns.Client.MapName(zone) or L["Unknown zone"]
end

---@param order table
---@return string name
---@return string sub
local function Text(order)
	if order.kind == "story" then
		return L["Finish story quests"], Ledger.ZoneName(order.zone)
	elseif order.kind == "discover" then
		return L["Discover areas"], Ledger.ZoneName(order.zone)
	end
	return L["Reach the next level"], L["Level %d"]:format(order.level)
end

---@param order table
---@return string
function Ledger.Describe(order)
	return L["%s: %s"]:format(Text(order))
end

-- The three order lines as the book and the tracker show them.
---@return table[] rows { name, sub, done, progress, target }
function Ledger.OrderRows()
	local rows = {}
	if not char then
		return rows
	end
	local ctx = Context()
	for slot = 1, #ns.Orders.SLOTS do
		local order = char.orders.list and char.orders.list[slot]
		if order then
			local progress = order.done and order.target or ns.Orders.Progress(order, ctx)
			local name, sub = Text(order)
			rows[#rows + 1] = {
				name = name,
				sub = L["%s · %d of %d"]:format(sub, progress, order.target),
				done = order.done == true,
				progress = progress,
				target = order.target,
			}
		end
	end
	return rows
end

-- Nil when no orders are issued yet.
---@return string?
function Ledger.ResetText()
	local resetAt = char and char.orders.resetAt
	if not resetAt then
		return nil
	end
	return L["New orders in %s"]:format(ns.Style.Duration(math.max(0, resetAt - ns.Client.Now())))
end

-- Stamps for the book: every zone with a story or an area list, stamped first, in zone order.
---@return table[] rows { zone, name, stamped, source, done, required, proven }
function Ledger.StampRows()
	local rows = {}
	if not char then
		return rows
	end
	local seen = {}
	local function Add(zone)
		if seen[zone] then
			return
		end
		seen[zone] = true
		local story = zoneStory[zone]
		local stamp = char.stamps[zone]
		if stamp or story or next(ns.Zones.AreaKeys(zone)) then
			local explored, total = Explored(zone)
			rows[#rows + 1] = {
				zone = zone,
				name = Ledger.ZoneName(zone),
				stamped = stamp ~= nil,
				source = stamp and stamp.source or (story and "story" or "areas"),
				done = story and story.done or explored,
				required = story and story.required or total,
				proven = story and story.proven or false,
			}
		end
	end
	for zone in pairs(char.stamps) do
		Add(zone)
	end
	for _, zone in ipairs(ns.Zones.Ids()) do
		Add(zone)
	end
	table.sort(rows, function(a, b)
		if a.stamped ~= b.stamped then
			return a.stamped
		end
		return a.zone < b.zone
	end)
	return rows
end

---@return integer? zone
function Ledger.NextZone()
	if not char then
		return nil
	end
	return ns.NextZone.Pick(ns.Zones.List(), ns.Client.Level(), ns.Client.FactionBit(), char.stamps)
end

---@return integer count
function Ledger.StampCount()
	local count = 0
	for _ in pairs(char and char.stamps or {}) do
		count = count + 1
	end
	return count
end

---@return integer
function Ledger.OrdersDone()
	local count = 0
	for id in pairs(char and char.txns or {}) do
		count = count + (id:sub(1, 6) == "order:" and 1 or 0)
	end
	return count
end
