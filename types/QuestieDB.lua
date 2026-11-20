---@meta

-- The part of QuestieDB's public API (the LibQuestieDB global, contract 2) that Client.lua and QuestieSource.lua read,
-- written from its documented surface. QuestieDB is optional and has no licence, so nothing of its own types is copied.

-- An entity reader: LibQuestieDB.Quest.
---@class LedgerQuestieEntity
---@field GetAllIds fun(): integer[]
---@field GetAll fun(id: integer, keys: string[]): table? the fields in `keys` order, with `n`; nil for an unknown ID

---@class LedgerQuestieDB
---@field Enum? {raceMaskById: table<integer, integer>} a race's number -> its bit in a quest's requiredRaces
---@field RequireContract fun(required: integer): boolean, string?
---@field Quest LedgerQuestieEntity
---@field Support {Get: fun(module: string): table?} Get("ZoneDB"): its zone tables, some as Lua source

---@type LedgerQuestieDB?
LibQuestieDB = nil
