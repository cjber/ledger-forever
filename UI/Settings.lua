---@type string, LedgerForeverNamespace
local _, ns = ...

if ns.broken then
	return
end

local L = ns.L

-- The page's chrome is ForeverCore's SettingsPage; what stays here is this addon's rows.
---@class LedgerSettings
local Settings = {}
ns.Settings = Settings

---@param panel Frame
---@param page table
local function Build(panel, page)
	page.AddHeader(panel, L["Orders"])
	page.AddCheck(panel, L["Show toasts"], function()
		return ns.State.Setting(ns.Ledger.DB(), "toasts")
	end, function(checked)
		ns.State.SetSetting(ns.Ledger.DB(), "toasts", checked)
	end, L["An order completed and a new rank show an achievement toast. Click it to open the book."])
	page.AddCheck(panel, L["Track orders"], function()
		return ns.State.Setting(ns.Ledger.DB(), "tracker")
	end, function(checked)
		ns.State.SetSetting(ns.Ledger.DB(), "tracker", checked)
		ns.Tracker.Refresh()
	end, L["Today's orders in the objective tracker."])
	if page.AddTrackerAttach then
		page.AddTrackerAttach(panel)
	end
end

function Settings.Register()
	if Settings.panel then
		return
	end
	local _, panel = ForeverCore.SettingsPage.Register(L["Ledger Forever"], Build, L, ns.core.SafeCall)
	Settings.panel = panel
end
