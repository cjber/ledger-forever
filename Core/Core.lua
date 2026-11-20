---@type string, LedgerForeverNamespace
local addonName, ns = ...

if ns.broken then
	return
end

local L = ns.L

-- The generated tables in Data/ hang off one table; Data/Territory.lua fills `territory`.
ns.Data = {}

-- The TOC's identity icon (WFA-8): the book and the toast wear the file the addon list shows.
ns.icon = C_AddOns.GetAddOnMetadata(addonName, "X-Forever-Icon") or ""

-- The addon's own ForeverCore services: the error journal, the debug log and the report window. Registering the one
-- opener here is what the slash command, the addon compartment entry and (later) the tracker header and settings
-- button all call, so a refusal in combat is core's own localized line and never a second code path (WFA-38).
-- The book toggles; `openSecure` refuses the open in combat with core's own line.
ns.core = ForeverCore.Register(addonName, {
	title = L["Ledger Forever report"],
	open = function()
		return ns.Book.Toggle()
	end,
	openSecure = true,
})

-- Hands the generated player credits to the shared Thanks page (WFA-31).
ns.core.SafeCall("credits", ForeverCore.Credits.Register, "Ledger Forever", ns.Credits)

local function Open()
	ForeverCore.Open(addonName)
end

-- Words listed in Core/Require.lua, so a stopped addon answers them too. Nothing is printed to chat: the book opens.
SLASH_LEDGERFOREVER1 = ns.Slash[1]
SLASH_LEDGERFOREVER2 = ns.Slash[2]
local function Slash(msg)
	local command, argument = strtrim(msg or ""):lower():match("^(%S*)%s*(.-)$")
	-- ForeverCore's shared `report` and `issue` words come first; anything else opens the book.
	if ns.core.Report and ns.core.Report.Command and ns.core.Report.Command(command, argument) then
		return
	end
	Open()
end
SlashCmdList.LEDGERFOREVER = function(msg)
	ns.core.SafeCall("slash command", Slash, msg)
end

LedgerForever_OnAddonCompartmentClick = Open
