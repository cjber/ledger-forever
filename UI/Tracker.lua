---@type string, LedgerForeverNamespace
local addonName, ns = ...

if ns.broken then
	return
end

local L = ns.L
local Section = ForeverCore.TrackerSection --[[@as ForeverTrackerSectionAPI]]

-- One section in the shared tracker column: today's orders with their progress, collapsing to one line when all are
-- done. Clicking the header opens the book. Ledger takes order -6 (Kiln Forever holds -5, WFA-5).
---@class LedgerTracker
local Tracker = {}
ns.Tracker = Tracker

local ORDER = -6
local KEY = "orders"

---@class LedgerTrackerModule : ForeverTrackerModule
---@field blocks table[] the section's text, rebuilt on every ledger change
---@field IsDirty fun(self: LedgerTrackerModule): boolean Blizzard's module model: whether a layout is queued

---@type LedgerTrackerModule?
local module

local Mixin = {}

function Mixin:LayoutContents()
	for _, entry in ipairs(self.blocks or {}) do
		local block = self:GetBlock(entry.key)
		block:SetHeader(entry.title)
		for _, row in ipairs(entry.rows) do
			block:AddObjective(row.key, row.text, nil, true, nil, row.color)
		end
		if not self:LayoutBlock(block) then
			return
		end
	end
end

local function OpenBook()
	return ForeverCore.Open(addonName)
end

-- The tracker template calls this method for block headers.
function Mixin:OnBlockHeaderClick(block, button)
	return ForeverCore.TrackerHost.HandleBlockHeaderClick(self, block, button)
end

---@return table[] blocks the section's text: none when no orders are issued
function Tracker.Build()
	local rows = ns.Ledger.OrderRows()
	if #rows == 0 then
		return {}
	end
	local done = 0
	for _, row in ipairs(rows) do
		done = done + (row.done and 1 or 0)
	end
	local block = { key = KEY, title = L["Today's orders %d of %d"]:format(done, #rows), rows = {} }
	if done == #rows then
		return { block }
	end
	for slot, row in ipairs(rows) do
		block.rows[slot] = {
			key = slot,
			text = L["%s: %s"]:format(row.name, row.sub),
			color = row.done and GRAY_FONT_COLOR or OBJECTIVE_TRACKER_COLOR.Normal,
		}
	end
	return { block }
end

-- Whether the two block lists lay out the same lines, so only their text needs rewriting.
local function SameShape(old, new)
	if #old ~= #new then
		return false
	end
	for index, block in ipairs(new) do
		local was = old[index]
		if was.key ~= block.key or #was.rows ~= #block.rows then
			return false
		end
		for rowIndex, row in ipairs(block.rows) do
			if was.rows[rowIndex].key ~= row.key then
				return false
			end
		end
	end
	return true
end

function Tracker.Refresh()
	if not module then
		return
	end
	local blocks = Tracker.Build()
	local same = SameShape(module.blocks, blocks)
	module.blocks = blocks
	if not same then
		module:MarkDirty()
		return
	end
	if not module:IsDirty() and Section.UpdateText(module, blocks) then
		module:MarkDirty()
	end
end

ns.OnFilesLoaded(function()
	module = Section.Create("LedgerForeverObjectiveTracker", Mixin, {
		order = ORDER,
		lineTemplate = "ObjectiveTrackerAnimLineTemplate",
		header = L["Ledger"],
		contract = {
			menu = function(_, menu)
				menu:Open(L["Ledger"], OpenBook)
			end,
			click = function(_, button)
				if button == "LeftButton" then
					return OpenBook()
				end
			end,
		},
		show = {
			get = function()
				return ns.State.Setting(ns.Ledger.DB(), "tracker")
			end,
			set = function(shown)
				ns.State.SetSetting(ns.Ledger.DB(), "tracker", shown)
			end,
			where = L["Settings > Ledger Forever, or the Track orders button in the book"],
			safeCall = ns.core.SafeCall,
		},
		safeCall = ns.core.SafeCall,
	}) --[[@as LedgerTrackerModule?]]
	if module then
		module.blocks = {}
	end
	ns.Ledger.Subscribe(function()
		Tracker.Refresh()
	end)
end)
