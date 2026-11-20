---@type string, LedgerForeverNamespace
local _, ns = ...

if ns.broken then
	return
end

-- QuestieDB, read in game through its public API (contract 2) for the Forever flavour. Nothing of it is copied into
-- this addon (WFA-28): the quest records live in memory for the session only. The catalogue is read a slice of a
-- frame at a time, only while work remains, once Questie reports ready.
local ADDON, CONTRACT = "QuestieDB", 2
local SLICE_MS = 2
-- Questie can load and never report ready, when its startup stops on an error. The read then goes ahead without it.
local READY_WAIT = 60
local REPEATABLE_FLAGS = 4096 + 32768
local FIELDS = {
	"requiredRaces",
	"requiredClasses",
	"zoneOrSort",
	"preQuestGroup",
	"preQuestSingle",
	"exclusiveTo",
	"nextQuestInChain",
	"questFlags",
	"specialFlags",
}

---@class LedgerQuestieSource
---@field onReady? fun() called when the catalogue is read or found absent
local Source = {}
ns.QuestieSource = Source

-- Pending until the read starts: waiting on Questie is not knowing, and "absent" would tell the book QuestieDB is
-- missing and let the sweep stamp story zones from explored areas before their stories are read.
---@type "absent"|"pending"|"ready"
local state = "pending"
---@type table<integer, table>
local records = {}
local ids, cursor, lib, MapOf
local open = false

-- One of ZoneDB's tables, which QuestieDB keeps as Lua source returning a table literal: run with no globals.
---@param source any
---@return table?
local function Table(source)
	local chunk = type(source) == "string" and loadstring(source)
	if chunk then
		local ok, value = pcall(setfenv(chunk, {}))
		if ok and type(value) == "table" then
			return value
		end
	end
end

---@return table? lib the loaded QuestieDB when it is the Forever build of this contract
local function Library()
	local db = LibQuestieDB
	if type(db) ~= "table" or C_AddOns.GetAddOnMetadata(ADDON, "X-Flavor") ~= "Forever" then
		return nil
	end
	local ok, fits = pcall(db.RequireContract, CONTRACT)
	if not (ok and fits and db.Quest and db.Quest.GetAllIds and db.Quest.GetAll and db.Support) then
		return nil
	end
	return db
end

-- Each area's map, or its parent zone's; an override of 0 means the area has no map. Nil when the tables can't be
-- read, so nothing is ever placed from partial data.
---@param db table
---@return (fun(area: integer): integer?)?
local function Zones(db)
	local source = db.Support.Get("ZoneDB")
	local private = type(source) == "table" and source.private
	if type(private) ~= "table" then
		return nil
	end
	local map, override, parent =
		Table(private.areaIdToUiMapId), Table(private.areaIdToUiMapIdOverride), Table(private.subZoneToParentZone)
	if not (map and override and parent) then
		return nil
	end
	return function(area)
		local found = override[area] or map[area]
		if found == nil and parent[area] then
			found = override[parent[area]] or map[parent[area]]
		end
		return type(found) == "number" and found ~= 0 and found or nil
	end
end

---@param value any
---@return integer[]?
local function List(value)
	return type(value) == "table" and #value > 0 and value or nil
end

---@param values table
---@return table
local function Record(values)
	local v = {}
	for index, field in ipairs(FIELDS) do
		v[field] = values[index]
	end
	local flags, special = tonumber(v.questFlags) or 0, tonumber(v.specialFlags) or 0
	local following = tonumber(v.nextQuestInChain) or 0
	local area = tonumber(v.zoneOrSort) or 0
	local record = {
		races = tonumber(v.requiredRaces),
		classes = tonumber(v.requiredClasses),
		zone = area > 0 and MapOf(area) or nil,
		next = following > 0 and following or nil,
		pre = List(v.preQuestGroup),
		preAny = List(v.preQuestSingle),
		exclusive = List(v.exclusiveTo),
		repeatable = bit.band(special, 1) ~= 0 or bit.band(flags, REPEATABLE_FLAGS) ~= 0,
	}
	-- A lone prerequisite in preQuestSingle is the one quest required: the same as a one-element group.
	if not record.pre and record.preAny and #record.preAny == 1 then
		record.pre, record.preAny = record.preAny, nil
	end
	return record
end

local function Step()
	local started = debugprofilestop()
	while cursor <= #ids do
		local id = ids[cursor]
		cursor = cursor + 1
		local values = lib.Quest.GetAll(id, FIELDS)
		if values then
			records[id] = Record(values)
		end
		if debugprofilestop() - started >= SLICE_MS then
			break
		end
	end
	if cursor > #ids then
		state = "ready"
		if Source.onReady then
			Source.onReady()
		end
		return
	end
	C_Timer.After(0, Step)
end

-- The one entry: Questie's ready callback and the fallback timer both call it, and only the first takes effect, so a
-- late ready never restarts a read that is running, finished or found absent.
local function Begin()
	if open then
		return
	end
	open = true
	lib = Library()
	MapOf = lib and Zones(lib)
	if not (lib and MapOf) then
		state = "absent"
		if Source.onReady then
			Source.onReady()
		end
		return
	end
	ids, cursor, state = lib.Quest.GetAllIds(), 1, "pending"
	C_Timer.After(0, Step)
end

-- "absent" without a QuestieDB this addon can read, "pending" until the catalogue is read, "ready" once it is.
---@return "absent"|"pending"|"ready"
function Source.State()
	return state
end

---@return table<integer, table>
function Source.Records()
	return records
end

-- Starts waiting for Questie; `Source.onReady` is called when the catalogue is read or found absent.
function Source.Start()
	if open then
		return
	end
	local api = Questie and Questie.API
	if api and api.RegisterOnReady then
		api.RegisterOnReady(Begin)
		C_Timer.After(READY_WAIT, Begin)
	else
		Begin()
	end
end
