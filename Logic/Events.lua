---@type string, LedgerForeverNamespace
local _, ns = ...

if ns.broken then
	return
end

-- Everything runs from client events: no timers. Events only mark work to do; one refresh is booked for the next
-- frame, and held until combat ends so no surface is touched mid-fight.
---@class LedgerEvents
local Events = {}
ns.Events = Events

local booked, waiting = false, false

local function Run()
	booked = false
	if InCombatLockdown() then
		waiting = true
		return
	end
	ns.core.SafeCall("refresh", ns.Ledger.Refresh)
end

function Events.Request()
	if not booked then
		booked = true
		C_Timer.After(0, Run)
	end
end

local handlers = {}

function handlers.PLAYER_LOGIN()
	ns.Ledger.Load()
	ns.QuestieSource.onReady = Events.Request
	ns.QuestieSource.Start()
	ns.core.SafeCall("settings", ns.Settings.Register)
end

function handlers.PLAYER_ENTERING_WORLD()
	if not ns.Ledger.Char() then
		ns.Ledger.Load()
	end
	Events.Request()
end

function handlers.QUEST_TURNED_IN(questID)
	-- Recorded at once, even in combat; the refresh that counts it waits.
	if type(questID) == "number" then
		ns.Ledger.QuestDone(questID)
	end
	Events.Request()
end

function handlers.PLAYER_LEVEL_UP()
	Events.Request()
end

function handlers.MAP_EXPLORATION_UPDATED()
	ns.Ledger.InvalidateExplored()
	Events.Request()
end

function handlers.ZONE_CHANGED_NEW_AREA()
	Events.Request()
end

function handlers.PLAYER_REGEN_ENABLED()
	if waiting then
		waiting = false
		Events.Request()
	end
end

local frame = CreateFrame("Frame")
for event in pairs(handlers) do
	frame:RegisterEvent(event)
end
frame:SetScript("OnEvent", function(_, event, ...)
	ns.core.SafeCall(event, handlers[event], ...)
end)
