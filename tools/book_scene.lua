-- Capture Ledger's book after opening it through the slash command. The sample character is illustrative.
local requestedWidth = assert(tonumber(arg[1]))
local empty = arg[3] == "empty"
local sim = dofile("tools/forever_sim/sim.lua").new()
sim:addon(".", "LedgerForever")
dofile("tests/sim/forever_core.lua").install(sim)
sim:login()

local addon = assert(sim.loader.addons[1])
assert(addon.name == "LedgerForever")
local ns = addon.ns
sim:runAs(
	"LedgerForever",
	[[
	local ns, width, empty = ...
	UIParent:SetWidth(width + 32)
	local char = ns.Ledger.Char()
	char.marks = 52
	char.orders.list = {
		{ kind = "story", zone = 1436, target = 3, baseline = 0, done = true },
		{ kind = "discover", zone = 1431, target = 3, baseline = 0 },
		{ kind = "level", level = 25, target = 1 },
	}
	ns.Client.Name = function() return "Alyra" end
	ns.Client.Level = function() return 24 end
	ns.Ledger.OrderRows = function()
		if empty then return {} end
		return {
			{ name = "Finish story quests", sub = "Westfall · 3 of 3", done = true },
			{ name = "Discover areas", sub = "Duskwood · 1 of 3", done = false },
			{ name = "Reach the next level", sub = "Level 25 · 0 of 1", done = false },
		}
	end
	if empty then char.orders.list = {} end
	ns.Ledger.ResetText = function() return "New orders in 9 h" end
	ns.Ledger.StampCount = function() return 1 end
	ns.Ledger.OrdersDone = function() return 4 end
	ns.Ledger.StampRows = function()
		return {
			{ name = "Westfall", stamped = true, source = "story" },
			{ name = "Duskwood", source = "story", proven = true, done = 9, required = 12 },
			{ name = "Redridge Mountains", source = "story", proven = true, done = 6, required = 7 },
			{ name = "Loch Modan", source = "areas", done = 3, required = 12 },
			{ name = "Wetlands", source = "areas", done = 1, required = 14 },
		}
	end
	ns.Ledger.Catalogue = function() return "ready" end
	ns.Ledger.NextZone = function() return 1431 end
	ns.Ledger.ZoneName = function() return "Duskwood" end
]],
	ns,
	requestedWidth,
	empty
)

sim:slash("/ledger")
local book = assert(sim.G.LedgerForeverFrame, "the Ledger slash command opens the book")
assert(book:IsShown())
-- The old book has a fixed width. Constrain its outer frame for the same-size before mock.
if arg[2] == "constrain" then
	sim.run(function()
		book:SetWidth(requestedWidth)
	end)
end
local bx, by, bw, bh = book:GetRect()
assert(bw == requestedWidth)
local function emit(...)
	local fields = { ... }
	for i, field in ipairs(fields) do
		fields[i] = tostring(field)
	end
	print("BOOK\t" .. table.concat(fields, "\t"))
end

local function pos(widget)
	local x, y, w, h = widget:GetRect()
	return x - bx, by + bh - y - h, w, h
end

local function content(frame)
	for _, region in ipairs({ frame:GetRegions() }) do
		if region:IsObjectType("FontString") and region:IsVisible() and (region:GetText() or "") ~= "" then
			local x, y, w, h = pos(region)
			local font = region:GetFontObject():GetName()
			local r, g, b = region:GetTextColor()
			emit("text", x, y, w, h, font, region:GetJustifyH(), r, g, b, region:GetText())
		elseif region:IsObjectType("Texture") and region:IsVisible() and region:GetAtlas() then
			local x, y, w, h = pos(region)
			emit("atlas", x, y, w, h, region:GetAtlas(), region:GetAlpha())
		end
	end
end

local function children(frame)
	for _, child in ipairs({ frame:GetChildren() }) do
		if child:IsVisible() and child ~= frame.NineSlice then
			local x, y, w, h = pos(child)
			if child:IsObjectType("StatusBar") then
				local fill = child:GetStatusBarTexture()
				for _, region in ipairs({ child:GetRegions() }) do
					if region ~= fill and region:GetAtlas() then
						local tx, ty, tw, th = pos(region)
						emit("track", tx, ty, tw, th, region:GetAtlas())
					end
				end
				emit("bar", x, y, w, h, fill:GetTexture(), child:GetValue(), child:GetStatusBarColor())
			elseif child:IsObjectType("Button") then
				emit("button", x, y, w, h, child:GetText())
			else
				content(child)
			end
		end
	end
end

emit("window", bw, bh, book.TitleContainer.TitleText:GetText(), ns.icon)
for _, child in ipairs({ book:GetChildren() }) do
	if child.NineSlice and child:IsVisible() then
		emit("inset", pos(child))
		content(child)
		children(child)
	end
end
content(book)
sim:expectNoErrors("LedgerForever")
