---@type string, LedgerForeverNamespace
local _, ns = ...

-- The game still loads this addon when ForeverCore is absent or older (## OptionalDeps), so this file decides whether
-- the loaded core has every member Ledger Forever calls and hands the warning to Core/ForeverRequire.lua, shared by
-- every Forever addon: one line on screen naming the addon to update, never a chat message. A core is out of date when
-- a member is missing, never by a version comparison (ForeverCore.API stays at 1 while it adds members).
--
-- Register and Open carry the one opener the slash command, addon compartment, tracker header and
-- settings button share. TrackerSection, TrackerHost and TrackerLine are the tracker section's contract, SettingsPage
-- the settings page that calls AddTrackerAttach, ContextMenu the book's menus, and Art and Credits the shared look
-- and Thanks page. A missing member stops the addon's files here instead of failing in the first file that calls it.
local function has(table, ...)
	if type(table) ~= "table" then
		return false
	end
	for _, name in ipairs({ ... }) do
		if table[name] == nil then
			return false
		end
	end
	return true
end

local core = ForeverCore
local ready = core ~= nil
	and type(core.Register) == "function"
	and type(core.Open) == "function"
	and has(core, "TrackerSection", "TrackerHost", "TrackerLine", "SettingsPage", "ContextMenu", "Art", "Credits")
	and type(core.TrackerHost.HandleBlockHeaderClick) == "function"
	and type(core.TrackerSection.Create) == "function"
	and type(core.TrackerSection.UpdateText) == "function"
	and type(core.SettingsPage.Register) == "function"
	and type(core.Credits.Register) == "function"

-- Core/Core.lua's slash words; the pin gate (forever_tools.require_slash) keeps the two lists equal. A stopped addon
-- still answers them with the line that names the fix, as its addon compartment entry does.
ns.Slash = { key = "LEDGERFOREVER", "/ledger", "/ledgerforever" }

ns.ForeverRequire(ready, ns.Slash)
