-- Run from the repository root: luajit tests/events_spec.lua
-- Events only book one refresh for the next frame, held while in combat and run when combat ends, and the character
-- load is tried again at PLAYER_ENTERING_WORLD when the GUID was secret at login.
local Env = dofile("tests/ledger_env.lua")
local checks = 0
local function check(condition, label)
	checks = checks + 1
	assert(condition, label)
end

local timers, combat, refreshes = {}, false, 0
_G.C_Timer = {
	After = function(_, fn)
		timers[#timers + 1] = fn
	end,
}
_G.InCombatLockdown = function()
	return combat
end
local onEvent
_G.CreateFrame = function()
	return {
		RegisterEvent = function() end,
		SetScript = function(_, _, fn)
			onEvent = fn
		end,
	}
end

local ns = Env.namespace()
local char, loads = nil, 0
ns.Ledger = {
	Load = function()
		loads = loads + 1
		char = loads > 1 and {} or nil
		return char ~= nil
	end,
	Char = function()
		return char
	end,
	Refresh = function()
		refreshes = refreshes + 1
	end,
	QuestDone = function() end,
	InvalidateExplored = function() end,
}
ns.QuestieSource = { Start = function() end }
ns.Settings = { Register = function() end }
Env.load(ns, { "Logic/Events.lua" })

local function Frame()
	local due = timers
	timers = {}
	for _, fn in ipairs(due) do
		fn()
	end
end

onEvent(nil, "PLAYER_LOGIN")
check(loads == 1 and char == nil, "a secret GUID at login loads nothing")
onEvent(nil, "PLAYER_ENTERING_WORLD")
check(loads == 2 and char, "the load is tried again when the world is entered")
onEvent(nil, "ZONE_CHANGED_NEW_AREA")
onEvent(nil, "PLAYER_LEVEL_UP")
Frame()
check(refreshes == 1, "events in one frame book one refresh")

combat = true
onEvent(nil, "QUEST_TURNED_IN", 5)
Frame()
check(refreshes == 1, "a refresh is held in combat")
combat = false
onEvent(nil, "PLAYER_REGEN_ENABLED")
Frame()
check(refreshes == 2, "it runs when combat ends")
onEvent(nil, "PLAYER_REGEN_ENABLED")
Frame()
check(refreshes == 2, "leaving combat with nothing held does nothing")
print(("events_spec: %d checks"):format(checks))
