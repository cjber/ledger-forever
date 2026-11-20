-- Run from the repository root: luajit tests/tracker_spec.lua
-- The tracker section: Ledger takes order -6, shows three order lines with progress, collapses to one line when all
-- are done, rewrites text without a new layout when only text changed, and a click on the header opens the book.
local Env = dofile("tests/ledger_env.lua")
local checks = 0
local function check(condition, label)
	checks = checks + 1
	assert(condition, label)
end

_G.GRAY_FONT_COLOR = { name = "gray" }
_G.OBJECTIVE_TRACKER_COLOR = { Normal = { name = "normal" } }
local created, updates, opened = nil, 0, {}
local resized = false
_G.ForeverCore = {
	Open = function(name)
		opened[#opened + 1] = name
	end,
	TrackerSection = {
		Create = function(name, mixin, opts)
			local module = { name = name, dirty = 0, opts = opts }
			for key, value in pairs(mixin) do
				module[key] = value
			end
			function module:MarkDirty()
				self.dirty = self.dirty + 1
				self.dirtyFlag = true
			end
			function module:IsDirty()
				return self.dirtyFlag
			end
			created = module
			return module
		end,
		UpdateText = function()
			updates = updates + 1
			return resized
		end,
	},
}

local ns = Env.namespace()
local rows = {}
local subscribers = {}
ns.Ledger = {
	OrderRows = function()
		return rows
	end,
	DB = function() end,
	Subscribe = function(fn)
		subscribers[#subscribers + 1] = fn
	end,
}
ns.State = {
	Setting = function()
		return true
	end,
	SetSetting = function() end,
}
local deferred
ns.OnFilesLoaded = function(fn)
	deferred = fn
end
Env.load(ns, { "UI/Tracker.lua" })
deferred()

check(created and created.name == "LedgerForeverObjectiveTracker", "the section is created")
check(created.opts.order == -6, "Ledger takes order -6")
check(#subscribers == 1, "the tracker follows the ledger")
check(created.opts.show.get() == true, "the show switch reads the setting")

local function Row(name, done, progress)
	return { name = name, sub = "Zone", done = done, progress = progress, target = 3 }
end
rows = { Row("Story", false, 1), Row("Discover", false, 0), Row("Level", true, 1) }
local blocks = ns.Tracker.Build()
check(#blocks == 1 and #blocks[1].rows == 3, "one block with three order lines")
check(blocks[1].title == ("Today's orders %d of %d"):format(1, 3), "the header counts done orders")
check(
	blocks[1].rows[3].color == GRAY_FONT_COLOR and blocks[1].rows[1].color == OBJECTIVE_TRACKER_COLOR.Normal,
	"done lines are grey"
)

ns.Tracker.Refresh()
check(created.dirty == 1, "a new set of lines lays out")
created.dirtyFlag = false
rows[1].sub = "Zone, one more"
ns.Tracker.Refresh()
check(created.dirty == 1 and updates == 1, "changed text only rewrites the text")
resized = true
ns.Tracker.Refresh()
check(created.dirty == 2, "a line that outgrew its height lays out again")
resized = false
created.dirtyFlag = true
local before = updates
ns.Tracker.Refresh()
check(updates == before, "a pending layout is not rewritten under")

rows = { Row("Story", true, 3), Row("Discover", true, 2), Row("Level", true, 1) }
created.dirtyFlag = false
blocks = ns.Tracker.Build()
check(#blocks == 1 and #blocks[1].rows == 0, "all done collapses to one line")
ns.Tracker.Refresh()
check(created.dirty == 3, "collapsing lays out")
rows = {}
check(#ns.Tracker.Build() == 0, "no orders, no lines")

-- The layout the mixin builds: header then one objective per row.
local calls = {}
local block = {}
function block:SetHeader(text)
	calls[#calls + 1] = "header " .. text
end
function block:AddObjective(key, text)
	calls[#calls + 1] = "line " .. key .. " " .. text
end
function created:GetBlock()
	return block
end
function created:LayoutBlock()
	calls[#calls + 1] = "layout"
	return true
end
created.blocks = { { key = "orders", title = "T", rows = { { key = 1, text = "a" }, { key = 2, text = "b" } } } }
created:LayoutContents()
check(
	table.concat(calls, "|") == "header T|line 1 a|line 2 b|layout",
	"the layout draws the header, the lines, then lays out"
)

created:OnBlockHeaderClick(block, "LeftButton")
check(opened[1] == "LedgerForever", "a click opens the book through the one opener")
created:OnBlockHeaderClick(block, "RightButton")
check(#opened == 1, "a right click is left to the column's menu")
print(("tracker_spec: %d checks"):format(checks))
