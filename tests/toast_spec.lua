-- Run from the repository root: luajit tests/toast_spec.lua
-- Toasts: only an order completed and a rank gained, off when the setting is, through the client's alert system and
-- never a chat line.
local Env = dofile("tests/ledger_env.lua")
local checks = 0
local function check(condition, label)
	checks = checks + 1
	assert(condition, label)
end

local alerts, chat = {}, {}
local template
local touched = false
_G.AlertFrame = setmetatable({}, {
	__index = function()
		touched = true
	end,
	__newindex = function()
		touched = true
	end,
})
_G.UIParent = {}
local flags = {}
_G.CreateFrame = function(_, _, _, inherits)
	assert(inherits == "AlertContainerTemplate", "an addon-owned alert container")
	return {
		SetEnabledFlag = function(_, name, enabled)
			flags[name] = enabled
		end,
		SetSize = function() end,
		SetPoint = function() end,
		Show = function() end,
		AddQueuedAlertFrameSubSystem = function(_, tpl, setup)
			template = { name = tpl, setup = setup }
			return {
				AddAlert = function(_, ...)
					alerts[#alerts + 1] = { ... }
				end,
			}
		end,
	}
end
_G.ForeverCore = { Open = function() end }
local report = print
_G.print = function(...)
	chat[#chat + 1] = { ... }
end
_G.DEFAULT_CHAT_FRAME = {
	AddMessage = function(...)
		chat[#chat + 1] = { ... }
	end,
}

local timers = {}
_G.C_Timer = {
	After = function(_, fn)
		timers[#timers + 1] = fn
	end,
}

local ns = Env.namespace()
local waits = {}
function ns.AfterEvents(callback, ...)
	waits[#waits + 1] = { callback = callback, events = { ... } }
end
local listener
local setting = true
ns.Ledger = {
	DB = function() end,
	Subscribe = function(fn)
		listener = fn
	end,
	Describe = function(order)
		return "order " .. order.slot
	end,
}
ns.State = {
	Setting = function()
		return setting
	end,
}
ns.Style = { PORTRAIT = "portrait" }
ns.Ranks = {
	Name = function(index)
		return "Rank " .. index
	end,
}
Env.load(ns, { "UI/Toast.lua" })

-- The container's own readiness wait never ends when the files run after a loading event (#5): the addon's wait
-- skips the events already past and sets the mixin's flags, the first frame one a frame later.
check(#waits == 1, "the container waits through ns.AfterEvents")
check(
	table.concat(waits[1].events, " ") == "VARIABLES_LOADED PLAYER_ENTERING_WORLD",
	"for the loading events a loader records"
)
check(next(flags) == nil, "alerts stay held until the wait ends")
waits[1].callback()
check(flags.playerEnteredWorld and flags.variablesLoaded and flags.firstFrameRendered == nil, "the world flags first")
timers[1]()
check(flags.firstFrameRendered, "the first frame flag on the frame after")

listener("changed")
listener("stamp", 100)
check(#alerts == 0, "a refresh and a stamp raise no toast")
listener("order", { slot = 2 })
check(#alerts == 1 and alerts[1][1] == "Order complete" and alerts[1][2] == "order 2", "an order completing")
check(template.name == "CriteriaAlertFrameTemplate", "the client's own achievement toast")
listener("rank", 5)
check(#alerts == 2 and alerts[2][1] == "New rank" and alerts[2][2] == "Rank 5", "a rank gained")
setting = false
listener("order", { slot = 1 })
listener("rank", 6)
check(#alerts == 2, "the setting turns toasts off")

local frame = { Unlocked = Env.widget(), Name = Env.widget(), Icon = { Texture = Env.widget() } }
function frame:SetScript() end
template.setup(frame, "Heading", "Name")
check(frame.Unlocked.text == "Heading" and frame.Name.text == "Name", "the toast shows both lines")
check(#chat == 0, "nothing is printed to chat")
check(not touched, "Blizzard's AlertFrame is never called into")
report(("toast_spec: %d checks"):format(checks))
