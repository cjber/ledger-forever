-- Shared by the specs: loads addon files the way the client does (the addon name and one namespace per chunk) with
-- English-as-key locale text and a SafeCall that just calls. Not a spec itself.
local Env = {}

function Env.namespace()
	local ns = {}
	ns.L = setmetatable({}, {
		__index = function(_, key)
			return key
		end,
	})
	ns.core = {
		SafeCall = function(_, fn, ...)
			return fn(...)
		end,
	}
	ns.Readable = function(value)
		return value
	end
	return ns
end

---@param ns table
---@param files string[]
function Env.load(ns, files)
	for _, path in ipairs(files) do
		local chunk = assert(loadfile(path))
		chunk("LedgerForever", ns)
	end
	return ns
end

-- A fake client: every field a spec changes is a plain value.
function Env.client(overrides)
	local state = {
		now = 1000,
		reset = 3600,
		level = 10,
		maxLevel = 60,
		guid = "Player-1",
		name = "Barry",
		faction = 2,
		race = 2 ^ 0,
		class = 2 ^ 2,
		completed = {},
		map = nil,
		explored = {},
		levels = {},
	}
	for key, value in pairs(overrides or {}) do
		state[key] = value
	end
	local Client = {}
	function Client.Now()
		return state.now
	end
	function Client.SecondsUntilReset()
		return state.reset
	end
	function Client.Level()
		return state.level
	end
	function Client.MaxLevel()
		return state.maxLevel
	end
	function Client.Guid()
		return state.guid
	end
	function Client.Name()
		return state.name
	end
	function Client.FactionBit()
		return state.faction
	end
	function Client.RaceBit()
		return state.race
	end
	function Client.ClassBit()
		return state.class
	end
	function Client.CompletedQuests()
		local copy = {}
		for id in pairs(state.completed) do
			copy[id] = true
		end
		return copy
	end
	function Client.MapLevels(id)
		local range = state.levels[id]
		if range then
			return range[1], range[2]
		end
		return nil, nil
	end
	function Client.MapName(id)
		return "Zone " .. id
	end
	function Client.CurrentMap()
		return state.map
	end
	function Client.ExploredKeys(id)
		return state.explored[id] or {}
	end
	return Client, state
end

Env.widgets = {}

-- A widget stand-in: any method answers with another stand-in, except the few whose results a spec reads back.
function Env.widget(kind)
	local widget = { kind = kind, shown = true, text = nil, scripts = {} }
	Env.widgets[#Env.widgets + 1] = widget
	local methods = {
		SetText = function(self, text)
			self.text = text
		end,
		GetText = function(self)
			return self.text
		end,
		Show = function(self)
			self.shown = true
		end,
		Hide = function(self)
			self.shown = false
		end,
		SetShown = function(self, shown)
			self.shown = shown and true or false
		end,
		IsShown = function(self)
			return self.shown
		end,
		SetScript = function(self, name, fn)
			self.scripts[name] = fn
		end,
		SetValue = function(self, value)
			self.value = value
		end,
		CreateTexture = function()
			return Env.widget("Texture")
		end,
		CreateFontString = function()
			return Env.widget("FontString")
		end,
	}
	return setmetatable(widget, {
		__index = function(_, key)
			return methods[key] or function(self)
				return self
			end
		end,
	})
end

return Env
