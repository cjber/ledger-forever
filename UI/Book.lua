---@type string, LedgerForeverNamespace
local _, ns = ...

if ns.broken then
	return
end

local L = ns.L
local Style, Art = ns.Style, ns.Art

-- The book: today's orders on the left, the rank card and the stamps on the right, one bar of totals under both. It
-- is an addon-owned frame that opens itself: ShowUIPanel and HideUIPanel taint the client's gamepad bookkeeping, so
-- Escape closes it through UISpecialFrames instead.
---@class LedgerBook
local Book = {}
ns.Book = Book

local FRAME_NAME = "LedgerForeverFrame"
local WIDTH, HEIGHT = 780, 560
local LEFT_WIDTH, PANEL_HEIGHT = 270, 400
local ORDER_ROW, STAMP_ROW, STAMP_VISIBLE = 66, 46, 5

if type(UISpecialFrames) == "table" then
	table.insert(UISpecialFrames, FRAME_NAME)
end

---@class LedgerBookFrame : Frame
---@field SetTitle fun(self: LedgerBookFrame, title: string)
---@field SetPortraitToAsset fun(self: LedgerBookFrame, asset: string)
---@field CloseButton Button

---@type LedgerBookFrame?
local frame
local parts = { orders = {}, stamps = {}, tiers = {} }
local stampOffset = 0

---@param parent Frame
local function BuildOrders(parent)
	local left = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
	left:SetPoint("TOPLEFT", 18, -70)
	left:SetSize(LEFT_WIDTH, PANEL_HEIGHT)
	local title = Style.Text(left, "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 14, -12)
	title:SetText(L["Today's orders"])
	for slot = 1, 3 do
		local row = CreateFrame("Frame", nil, left)
		row:SetSize(LEFT_WIDTH - 20, ORDER_ROW)
		row:SetPoint("TOPLEFT", 10, -40 - (slot - 1) * ORDER_ROW)
		row.mark = row:CreateTexture(nil, "ARTWORK")
		row.mark:SetPoint("LEFT", 4, 0)
		row.name = Style.Text(row, "GameFontHighlight")
		row.name:SetPoint("TOPLEFT", 52, -12)
		row.name:SetWidth(LEFT_WIDTH - 90)
		row.name:SetJustifyH("LEFT")
		row.sub = Style.Text(row, "GameFontDisableSmall")
		row.sub:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -4)
		row.sub:SetWidth(LEFT_WIDTH - 90)
		row.sub:SetJustifyH("LEFT")
		parts.orders[slot] = row
	end
	parts.reset = Style.Text(left, "GameFontDisableSmall")
	parts.reset:SetPoint("BOTTOMLEFT", 14, 14)
end

---@param parent Frame
local function BuildCard(parent)
	local card = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
	card:SetPoint("TOPLEFT", 18 + LEFT_WIDTH + 10, -70)
	card:SetSize(WIDTH - LEFT_WIDTH - 56, 130)
	parts.laurel = card:CreateTexture(nil, "ARTWORK")
	parts.laurel:SetPoint("TOPLEFT", 14, -12)
	Art.Fit(parts.laurel, Style.Atlas.laurel, 64, 64)
	parts.rank = Style.Text(card, "GameFontNormalHuge")
	parts.rank:SetPoint("TOPLEFT", 90, -14)
	parts.totals = Style.Text(card, "GameFontHighlight")
	parts.totals:SetPoint("TOPLEFT", parts.rank, "BOTTOMLEFT", 0, -6)
	parts.next = Style.Text(card, "GameFontDisableSmall")
	parts.next:SetPoint("TOPLEFT", parts.totals, "BOTTOMLEFT", 0, -4)
	parts.bar = Style.Bar(card, WIDTH - LEFT_WIDTH - 90, 14)
	parts.bar:SetPoint("BOTTOMLEFT", 16, 30)
	for tier = 1, #ns.Ranks.Names do
		local label = Style.Text(card, "GameFontDisableSmall")
		label:SetText(ns.Ranks.Names[tier])
		label:SetPoint("BOTTOMLEFT", 16 + (tier - 1) * ((WIDTH - LEFT_WIDTH - 90) / #ns.Ranks.Names), 10)
		parts.tiers[tier] = label
	end
end

---@param parent Frame
local function BuildStamps(parent)
	local pane = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
	pane:SetPoint("TOPLEFT", 18 + LEFT_WIDTH + 10, -208)
	pane:SetSize(WIDTH - LEFT_WIDTH - 56, PANEL_HEIGHT - 138)
	local title = Style.Text(pane, "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 14, -12)
	title:SetText(L["Stamps"])
	parts.notice = Style.Text(pane, "GameFontDisableSmall")
	parts.notice:SetPoint("TOPRIGHT", -14, -16)
	parts.notice:SetWidth(280)
	parts.notice:SetJustifyH("RIGHT")
	for index = 1, STAMP_VISIBLE do
		local row = CreateFrame("Frame", nil, pane)
		row:SetSize(WIDTH - LEFT_WIDTH - 80, STAMP_ROW)
		row:SetPoint("TOPLEFT", 10, -40 - (index - 1) * STAMP_ROW)
		row.border = row:CreateTexture(nil, "BACKGROUND")
		row.border:SetPoint("LEFT", 4, 0)
		row.seal = row:CreateTexture(nil, "ARTWORK")
		row.seal:SetPoint("CENTER", row.border, "CENTER")
		row.name = Style.Text(row, "GameFontHighlight")
		row.name:SetPoint("LEFT", 56, 6)
		row.sub = Style.Text(row, "GameFontDisableSmall")
		row.sub:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2)
		parts.stamps[index] = row
	end
	pane:EnableMouseWheel(true)
	pane:SetScript("OnMouseWheel", function(_, delta)
		stampOffset = math.max(0, stampOffset - delta)
		Book.Refresh()
	end)
end

---@param parent Frame
local function BuildBottom(parent)
	local bar = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
	bar:SetPoint("BOTTOMLEFT", 18, 12)
	bar:SetSize(WIDTH - 36, 66)
	parts.today = Style.Text(bar, "GameFontNormalLarge")
	parts.today:SetPoint("TOPLEFT", 14, -8)
	parts.todayBar = Style.Bar(bar, 300, 14)
	parts.todayBar:SetPoint("TOPLEFT", 14, -34)
	parts.earned = Style.Text(bar, "GameFontHighlight")
	parts.earned:SetPoint("LEFT", parts.todayBar, "RIGHT", 14, 0)
	local track = CreateFrame("Button", nil, bar, "SharedButtonSmallTemplate")
	track:SetSize(150, 26)
	track:SetPoint("RIGHT", -12, 0)
	track:SetText(L["Track orders"])
	track:SetScript("OnClick", function()
		local on = not ns.State.Setting(ns.Ledger.DB(), "tracker")
		ns.State.SetSetting(ns.Ledger.DB(), "tracker", on)
		ns.Tracker.Refresh()
		Book.Refresh()
	end)
	parts.track = track
end

local function Create()
	if frame then
		return frame
	end
	frame = CreateFrame("Frame", FRAME_NAME, UIParent, "PortraitFrameTemplate") --[[@as LedgerBookFrame]]
	frame:SetSize(WIDTH, HEIGHT)
	frame:SetPoint("CENTER")
	frame:SetToplevel(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function(self)
		self:StartMoving()
	end)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
	end)
	frame:Hide()
	frame:SetTitle(L["Ledger"])
	frame:SetPortraitToAsset(Style.PORTRAIT)
	-- The close button is the client's, whose click goes through HideUIPanel: close the frame directly instead.
	frame.CloseButton:SetScript("OnClick", Book.Hide)
	parts.subtitle = Style.Text(frame, "GameFontHighlight")
	parts.subtitle:SetPoint("TOPLEFT", 74, -34)
	BuildOrders(frame)
	BuildCard(frame)
	BuildStamps(frame)
	BuildBottom(frame)
	return frame
end

local function PaintOrders()
	local rows = ns.Ledger.OrderRows()
	for slot, row in ipairs(parts.orders) do
		local data = rows[slot]
		row:SetShown(data ~= nil)
		if data then
			Art.Fit(row.mark, data.done and Style.Seal() or Style.Atlas.borderUncollected, 40, 40)
			row.mark:SetDesaturated(not data.done)
			row.name:SetText(data.name)
			row.sub:SetText(data.sub)
		end
	end
	parts.reset:SetText(ns.Ledger.ResetText() or L["Orders arrive after the next daily reset."])
end

local function PaintCard(char)
	local marks = char.marks
	local index = ns.Ranks.Index(marks)
	parts.rank:SetText(ns.Ranks.Name(index))
	parts.totals:SetText(
		L["%d marks · %d stamps · %d orders done"]:format(marks, ns.Ledger.StampCount(), ns.Ledger.OrdersDone())
	)
	local threshold = ns.Ranks.NextThreshold(index)
	if threshold then
		parts.next:SetText(
			L["Next: %s"]:format(ns.Ranks.Name(index + 1)) .. "  " .. L["%d of %d marks"]:format(marks, threshold)
		)
	else
		parts.next:SetText(L["Top rank reached"])
	end
	parts.bar:SetValue(ns.Ranks.Fraction(marks))
	local tier = ns.Ranks.Split(index)
	for number, label in ipairs(parts.tiers) do
		if number == tier then
			label:SetTextColor(1, 0.82, 0)
		else
			label:SetTextColor(0.5, 0.5, 0.5)
		end
	end
end

local function PaintStamps()
	local rows = ns.Ledger.StampRows()
	stampOffset = math.max(0, math.min(stampOffset, #rows - STAMP_VISIBLE))
	for index, row in ipairs(parts.stamps) do
		local data = rows[stampOffset + index]
		row:SetShown(data ~= nil)
		if data then
			Art.Fit(row.border, data.stamped and Style.Atlas.borderCollected or Style.Atlas.borderUncollected, 40, 40)
			Art.Fit(row.seal, Style.Seal(), 28, 28)
			row.seal:SetDesaturated(not data.stamped)
			row.seal:SetAlpha(data.stamped and 1 or 0.45)
			row.name:SetText(data.name)
			local sub
			if data.stamped then
				sub = data.source == "areas" and L["Stamped, from explored areas"] or L["Stamped"]
			elseif data.source == "story" and data.proven then
				sub = L["%d of %d quests"]:format(data.done, data.required)
			elseif data.source == "story" then
				sub = L["%d quests done"]:format(data.done)
			else
				sub = L["%d of %d areas, from explored areas"]:format(data.done, data.required)
			end
			row.sub:SetText(sub)
		end
	end
	local catalogue = ns.Ledger.Catalogue()
	if catalogue == "absent" then
		parts.notice:SetText(L["Install QuestieDB so zone stories can be read."])
	elseif catalogue == "pending" then
		parts.notice:SetText(L["Reading zone stories..."])
	else
		local zone = ns.Ledger.NextZone()
		parts.notice:SetText(zone and L["Next zone: %s"]:format(ns.Ledger.ZoneName(zone)) or "")
	end
end

local function PaintBottom(char)
	local done, issued = ns.Orders.Count(char.orders)
	parts.today:SetText(L["Today's orders %d of %d"]:format(done, math.max(issued, 3)))
	parts.todayBar:SetValue(issued > 0 and done / issued or 0)
	parts.earned:SetText(L["+%d marks so far"]:format(done * ns.Marks.Value.order))
	parts.track:SetText(ns.State.Setting(ns.Ledger.DB(), "tracker") and L["Stop tracking orders"] or L["Track orders"])
end

function Book.Refresh()
	local char = ns.Ledger.Char()
	if not (frame and frame:IsShown() and char) then
		return
	end
	parts.subtitle:SetText(L["%s · Level %d"]:format(ns.Client.Name() or "", ns.Client.Level()))
	PaintOrders()
	PaintCard(char)
	PaintStamps()
	PaintBottom(char)
end

-- The opener ForeverCore calls for the slash command, the compartment entry, the tracker header and settings.
---@return boolean
function Book.Toggle()
	local window = Create()
	if window:IsShown() then
		window:Hide()
		return true
	end
	window:Show()
	ns.Events.Request()
	Book.Refresh()
	return true
end

function Book.Hide()
	if frame then
		frame:Hide()
	end
end

---@return boolean
function Book.IsShown()
	return frame ~= nil and frame:IsShown()
end

ns.Ledger.Subscribe(function()
	Book.Refresh()
end)
