---@type string, LedgerForeverNamespace
local _, ns = ...

if ns.broken then
	return
end

local L = ns.L
local Style = ns.Style

-- The book: today's orders on the left, the rank card and the stamps on the right, one bar of totals under both. It
-- is an addon-owned frame that opens itself: ShowUIPanel and HideUIPanel taint the client's gamepad bookkeeping, so
-- Escape closes it through UISpecialFrames instead.
---@class LedgerBook
local Book = {}
ns.Book = Book

local FRAME_NAME = "LedgerForeverFrame"
local WIDTH, NARROW_WIDTH, HEIGHT = 780, 680, 560
local PANEL_HEIGHT = 400
local ORDER_ROW, STAMP_ROW, STAMP_VISIBLE = 48, 42, 5

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
---@param width number
local function BuildOrders(parent, width)
	local left = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
	left:SetPoint("TOPLEFT", 18, -70)
	left:SetSize(width, PANEL_HEIGHT)
	local title = Style.Text(left, "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 14, -12)
	title:SetText(L["Today's orders"])
	for slot = 1, 3 do
		local row = CreateFrame("Frame", nil, left)
		row:SetSize(width - 28, ORDER_ROW)
		row:SetPoint("TOPLEFT", 14, -40 - (slot - 1) * ORDER_ROW)
		row.name = Style.Text(row, "GameFontHighlight")
		row.name:SetPoint("TOPLEFT")
		row.name:SetWidth(width - 28)
		row.name:SetJustifyH("LEFT")
		row.sub = Style.Text(row, "GameFontHighlightSmall")
		row.sub:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -4)
		row.sub:SetWidth(width - 28)
		row.sub:SetJustifyH("LEFT")
		parts.orders[slot] = row
	end
	parts.reset = Style.Text(left, "GameFontHighlightSmall")
	parts.reset:SetPoint("BOTTOMLEFT", 14, 14)
	parts.reset:SetWidth(width - 28)
	parts.reset:SetJustifyH("LEFT")
end

---@param parent Frame
---@param leftWidth number
---@param width number
local function BuildCard(parent, leftWidth, width)
	local card = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
	card:SetPoint("TOPLEFT", 18 + leftWidth + 10, -70)
	card:SetSize(width, 130)
	parts.rank = Style.Text(card, "GameFontNormalHuge")
	parts.rank:SetPoint("TOPLEFT", 14, -12)
	parts.totals = Style.Text(card, "GameFontHighlight")
	parts.totals:SetPoint("TOPLEFT", parts.rank, "BOTTOMLEFT", 0, -6)
	parts.next = Style.Text(card, "GameFontHighlightSmall")
	parts.next:SetPoint("TOPLEFT", parts.totals, "BOTTOMLEFT", 0, -4)
	parts.bar = Style.Bar(card, width - 28, 14)
	parts.bar:SetPoint("BOTTOMLEFT", 14, 30)
	local totalWidth = 0
	for tier, name in ipairs(ns.Ranks.Names) do
		local label = Style.Text(card, "GameFontHighlightSmall")
		label:SetText(name)
		parts.tiers[tier] = label
		totalWidth = totalWidth + label:GetStringWidth()
	end
	-- Share the remaining width between labels so longer translated rank names have room.
	local gap = math.max(0, (width - 28 - totalWidth) / (#parts.tiers - 1))
	local offset = 14
	for _, label in ipairs(parts.tiers) do
		label:SetPoint("BOTTOMLEFT", offset, 10)
		offset = offset + label:GetStringWidth() + gap
	end
end

---@param parent Frame
---@param leftWidth number
---@param width number
local function BuildStamps(parent, leftWidth, width)
	local pane = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
	pane:SetPoint("TOPLEFT", 18 + leftWidth + 10, -208)
	pane:SetSize(width, PANEL_HEIGHT - 138)
	local title = Style.Text(pane, "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 14, -12)
	title:SetText(L["Stamps"])
	parts.notice = Style.Text(pane, "GameFontHighlightSmall")
	parts.notice:SetPoint("TOPRIGHT", -14, -16)
	parts.notice:SetWidth(width - 112)
	parts.notice:SetJustifyH("RIGHT")
	for index = 1, STAMP_VISIBLE do
		local row = CreateFrame("Frame", nil, pane)
		row:SetSize(width - 28, STAMP_ROW)
		row:SetPoint("TOPLEFT", 14, -40 - (index - 1) * STAMP_ROW)
		row.name = Style.Text(row, "GameFontHighlight")
		row.name:SetPoint("TOPLEFT")
		row.sub = Style.Text(row, "GameFontHighlightSmall")
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
---@param width number
local function BuildBottom(parent, width)
	local bar = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
	bar:SetPoint("BOTTOMLEFT", 18, 12)
	bar:SetSize(width - 36, 66)
	parts.today = Style.Text(bar, "GameFontNormalLarge")
	parts.today:SetPoint("TOPLEFT", 14, -8)
	parts.todayBar = Style.Bar(bar, width - 480, 14)
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
	local width = math.max(NARROW_WIDTH, math.min(WIDTH, UIParent:GetWidth() - 32))
	frame:SetSize(width, HEIGHT)
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
	local leftWidth = 270 - (WIDTH - width) / 2
	local rightWidth = width - leftWidth - 46
	BuildOrders(frame, leftWidth)
	BuildCard(frame, leftWidth, rightWidth)
	BuildStamps(frame, leftWidth, rightWidth)
	BuildBottom(frame, width)
	return frame
end

local function PaintOrders()
	local rows = ns.Ledger.OrderRows()
	for slot, row in ipairs(parts.orders) do
		local data = rows[slot]
		row:SetShown(data ~= nil)
		if data then
			row.name:SetFontObject(data.done and "GameFontNormal" or "GameFontHighlight")
			row.name:SetJustifyH("LEFT")
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
		label:SetFontObject(number == tier and "GameFontNormalSmall" or "GameFontHighlightSmall")
	end
end

local function PaintStamps()
	local rows = ns.Ledger.StampRows()
	stampOffset = math.max(0, math.min(stampOffset, #rows - STAMP_VISIBLE))
	for index, row in ipairs(parts.stamps) do
		local data = rows[stampOffset + index]
		row:SetShown(data ~= nil)
		if data then
			row.name:SetFontObject(data.stamped and "GameFontNormal" or "GameFontHighlight")
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
