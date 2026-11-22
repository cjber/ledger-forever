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
local anchor
_G.DEFAULT_FULLSCREEN_STRATA = "FULLSCREEN_DIALOG"
_G.EventUtil = {
	ContinueAfterAllEvents = function()
		error("the toast anchor registered a Blizzard event wait")
	end,
}
_G.Mixin = function(frame, mixin)
	for key, value in pairs(mixin) do
		frame[key] = value
	end
end
_G.AlertContainerMixin = {
	OnLoad = function()
		_G.EventUtil.ContinueAfterAllEvents()
	end,
	SetEnabledFlag = function(self, name, enabled)
		self.shouldQueueAlertsFlags[name] = enabled
	end,
	AddQueuedAlertFrameSubSystem = function(_, tpl, setup)
		template = { name = tpl, setup = setup }
		return {
			AddAlert = function(_, ...)
				alerts[#alerts + 1] = { ... }
			end,
		}
	end,
}
_G.CreateFrame = function(_, _, _, inherits)
	anchor = {
		SetSize = function() end,
		SetPoint = function() end,
		Show = function() end,
	}
	if inherits == "AlertContainerTemplate" then
		_G.Mixin(anchor, _G.AlertContainerMixin)
		anchor:OnLoad()
	end
	check(inherits == nil, "the toast anchor uses a plain frame")
	return anchor
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

check(type(anchor.alertFrameSubSystems) == "table", "the anchor has its own alert subsystems")
check(type(anchor.reasonsToBlockLeftClickingAlerts) == "table", "the anchor has its own click blockers")
check(anchor.fullscreenFrame == _G.UIParent, "fullscreen alerts use UIParent")
check(anchor.fullscreenStrata == _G.DEFAULT_FULLSCREEN_STRATA, "fullscreen alerts use the default strata")
check(anchor.baseAnchorFrame == anchor, "alerts stack from the addon anchor")

-- The addon's wait skips loading events that have already fired.
local flags = anchor.shouldQueueAlertsFlags
check(#waits == 1, "the container waits through ns.AfterEvents")
check(
	table.concat(waits[1].events, " ") == "VARIABLES_LOADED PLAYER_ENTERING_WORLD",
	"for the loading events a loader records"
)
check(
	flags.playerEnteredWorld == false and flags.variablesLoaded == false and flags.firstFrameRendered == false,
	"alerts stay held until the wait ends"
)
waits[1].callback()
check(flags.playerEnteredWorld and flags.variablesLoaded and flags.firstFrameRendered == false, "the world flags first")
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
