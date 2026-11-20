---@type string, LedgerForeverNamespace
local _, ns = ...

if ns.broken then
	return
end

-- The only reader of C_* and unit APIs. Everything else asks here, so a spec swaps one table for a fake client and
-- a missing API answers nil instead of raising.
---@class LedgerClient
local Client = {}
ns.Client = Client

local MAX_LEVEL_FALLBACK = 60

---@return integer
function Client.Now()
	return GetServerTime()
end

---@return integer? seconds nil when the client gives none
function Client.SecondsUntilReset()
	local seconds = C_DateAndTime
		and C_DateAndTime.GetSecondsUntilDailyReset
		and C_DateAndTime.GetSecondsUntilDailyReset()
	if type(seconds) ~= "number" or seconds <= 0 then
		return nil
	end
	return seconds
end

---@return integer
function Client.Level()
	return UnitLevel("player") or 1
end

---@return integer
function Client.MaxLevel()
	return GetMaxPlayerLevel and GetMaxPlayerLevel() or MAX_LEVEL_FALLBACK
end

---@return string? guid
function Client.Guid()
	return ns.Readable(UnitGUID("player"))
end

---@return string? name
function Client.Name()
	return ns.Readable(UnitName("player"))
end

---@return integer factionBit 2 Alliance, 4 Horde
function Client.FactionBit()
	return UnitFactionGroup("player") == "Horde" and 4 or 2
end

---@return integer? raceID
---@return integer? classID
function Client.RaceClass()
	local _, _, raceID = UnitRace("player")
	local _, _, classID = UnitClass("player")
	return raceID, classID
end

---@return table<integer, boolean> completed quest ids
function Client.CompletedQuests()
	local set = {}
	local list = C_QuestLog and C_QuestLog.GetAllCompletedQuestIDs and C_QuestLog.GetAllCompletedQuestIDs()
	for _, id in ipairs(list or {}) do
		set[id] = true
	end
	return set
end

---@param uiMapID integer
---@return integer? lo
---@return integer? hi
function Client.MapLevels(uiMapID)
	if not (C_Map and C_Map.GetMapLevels) then
		return nil, nil
	end
	local lo, hi = C_Map.GetMapLevels(uiMapID)
	if type(lo) == "number" and type(hi) == "number" and lo > 0 then
		return lo, hi
	end
	return nil, nil
end

---@param uiMapID integer
---@return string?
function Client.MapName(uiMapID)
	local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(uiMapID)
	return info and info.name
end

---@return integer? uiMapID the zone the player is in
function Client.CurrentMap()
	return C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
end

-- The overlay key the exploration data uses for a texture: offsetX:offsetY:width:height.
---@param uiMapID integer
---@return table<string, boolean>
function Client.ExploredKeys(uiMapID)
	local keys = {}
	local textures = C_MapExplorationInfo
		and C_MapExplorationInfo.GetExploredMapTextures
		and C_MapExplorationInfo.GetExploredMapTextures(uiMapID)
	for _, texture in ipairs(textures or {}) do
		keys[("%d:%d:%d:%d"):format(texture.offsetX, texture.offsetY, texture.textureWidth, texture.textureHeight)] =
			true
	end
	return keys
end

-- The player's bit in a quest's race mask, in QuestieDB's encoding: Forever's Skyborne are bits 32 and 33, not a
-- shift of the race's number. A race QuestieDB does not know has none.
---@return number? nil for a race with no bit
function Client.RaceBit()
	local raceID = Client.RaceClass()
	local masks = LibQuestieDB and LibQuestieDB.Enum and LibQuestieDB.Enum.raceMaskById
	if masks then
		return raceID and masks[raceID] or nil
	end
	return raceID and raceID <= 8 and 2 ^ (raceID - 1) or nil
end

---@return number? nil when the client gives no class
function Client.ClassBit()
	local _, classID = Client.RaceClass()
	return classID and 2 ^ (classID - 1) or nil
end
