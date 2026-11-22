---@type string, LedgerForeverNamespace
local addonName, ns = ...

if ns.broken then
	return
end

local L = ns.L

-- Blizzard's own achievement-progress toast (its Mini background), queued and stacked by this addon's own alert
-- container, so nothing here calls a method on Blizzard's AlertFrame or writes to a pooled Blizzard toast. Only an
-- order completed and a rank gained ask for one, and a setting turns them off. Nothing goes to chat.
---@class LedgerToast
local Toast = {}
ns.Toast = Toast

-- AlertContainerTemplate's OnLoad registers EventUtil.ContinueAfterAllEvents, which never calls back if the addon
-- loads after VARIABLES_LOADED. Use a plain addon-owned frame with AlertContainerMixin and the state OnLoad sets.
---@type table
local anchor = CreateFrame("Frame", "LedgerForeverToastAnchor", UIParent)
Mixin(anchor, AlertContainerMixin)
anchor.alertFrameSubSystems = {}
anchor.reasonsToBlockLeftClickingAlerts = {}
anchor.fullscreenFrame = UIParent
anchor.fullscreenStrata = DEFAULT_FULLSCREEN_STRATA
anchor.baseAnchorFrame = anchor
anchor.shouldQueueAlertsFlags = {
	playerEnteredWorld = false,
	variablesLoaded = false,
	firstFrameRendered = false,
}

-- The client lays out no sizeless single-point frame, so use AlertFrame's 10x10 box at the game's first toast position.
anchor:SetSize(10, 10)
anchor:SetPoint("TOP", BottomManagedFrameContainer or AlertFrame or UIParent, "TOP", 0, 0)
anchor:Show()

-- Alerts stay queued until all three flags are true. Our wait skips loading events that already fired, as they do
-- before these files run in a package carrying ForeverCore (#5). It sets the world and variables flags, then enables
-- firstFrameRendered on the next frame because no loader records FIRST_FRAME_RENDERED.
ns.AfterEvents(function()
	anchor:SetEnabledFlag("playerEnteredWorld", true)
	anchor:SetEnabledFlag("variablesLoaded", true)
	C_Timer.After(0, function()
		anchor:SetEnabledFlag("firstFrameRendered", true)
	end)
end, "VARIABLES_LOADED", "PLAYER_ENTERING_WORLD")

---@param frame table
---@param heading string
---@param name string
local function SetUp(frame, heading, name)
	frame.Unlocked:SetText(heading)
	frame.Name:SetText(name)
	-- art-ok: the stock toast sizes its icon square, and the book icon is a square client icon
	frame.Icon.Texture:SetTexture(ns.Style.PORTRAIT)
	frame:SetScript("OnClick", function()
		ForeverCore.Open(addonName)
	end)
end

---@type table?
local toasts

---@param heading string
---@param name string
function Toast.Show(heading, name)
	if not ns.State.Setting(ns.Ledger.DB(), "toasts") then
		return
	end
	if not toasts then
		if not anchor.AddQueuedAlertFrameSubSystem then
			return
		end
		toasts = anchor:AddQueuedAlertFrameSubSystem("CriteriaAlertFrameTemplate", SetUp, 2, 6)
	end
	toasts:AddAlert(heading, name)
end

ns.Ledger.Subscribe(function(event, payload)
	if event == "order" then
		Toast.Show(L["Order complete"], ns.Ledger.Describe(payload))
	elseif event == "rank" then
		Toast.Show(L["New rank"], ns.Ranks.Name(payload))
	end
end)
