---@type string, LedgerForeverNamespace
local _, ns = ...

if ns.broken then
	return
end

-- The look the book, tracker and toast share: the client's own art by name, drawn at native aspect through Art.
---@class LedgerStyle
local Style = {}
ns.Style = Style

-- The book's portrait and the toast's mark: the TOC's X-Forever-Icon, read once in Core/Core.lua.
Style.PORTRAIT = ns.icon

---@param parent Frame
---@param font string
---@return FontString
function Style.Text(parent, font)
	return parent:CreateFontString(nil, "ARTWORK", font)
end

-- A filled bar, 0 to 1.
---@param parent Frame
---@param width number
---@param height number
---@return StatusBar
function Style.Bar(parent, width, height)
	local bar = CreateFrame("StatusBar", nil, parent)
	bar:SetSize(width, height)
	bar:SetStatusBarTexture("common-stat-bar-white")
	bar:SetStatusBarColor(0.85, 0.68, 0.25)
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0)
	local back = bar:CreateTexture(nil, "BACKGROUND")
	back:SetPoint("TOPLEFT", -2, 1)
	back:SetPoint("BOTTOMRIGHT", 2, -1)
	back:SetAtlas("common-stat-bar-BG") -- art-ok: bar rim follows the size of its fill
	return bar
end

---@param seconds integer
---@return string
function Style.Duration(seconds)
	return ns.L["%d h %d m"]:format(math.floor(seconds / 3600), math.floor(seconds % 3600 / 60))
end
