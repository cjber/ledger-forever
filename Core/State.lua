---@type string, LedgerForeverNamespace
local _, ns = ...

if ns.broken then
	return
end

-- LedgerForeverDB: one record per character plus an account part. Marks and stamps are only ever added, so a
-- migration never deletes them; a newer database than this build knows is read-only, and a corrupt one is replaced.

---@class LedgerState
local State = {}
ns.State = State

State.VERSION = 1

local function NewDB()
	return { version = State.VERSION, chars = {}, account = { designs = {}, settings = {} } }
end

-- Each step lifts a database from version n - 1 to n and keeps what it finds; a missing part is added.
local migrations = {
	[1] = function(db)
		db.chars = db.chars or {}
		db.account = db.account or {}
		db.account.designs = db.account.designs or {}
		db.account.settings = db.account.settings or {}
	end,
}

-- Whether every part this version reads has the type it expects; a missing part is not wrong, a step adds it.
---@param db table
---@return boolean
local function Shaped(db)
	local account = db.account
	return (db.chars == nil or type(db.chars) == "table")
		and (
			account == nil
			or (
				type(account) == "table"
				and (account.designs == nil or type(account.designs) == "table")
				and (account.settings == nil or type(account.settings) == "table")
			)
		)
end

---@param db any the saved variable as the client loaded it
---@return table db the database to use
---@return boolean readOnly true when it was written by a newer build
function State.Migrate(db)
	if type(db) ~= "table" then
		return NewDB(), false
	end
	local version = db.version
	if version == nil then
		version = 0
	end
	-- A version is a whole number from 0; anything else (text, negative, fractional, NaN) is a corrupt save.
	if type(version) ~= "number" or version < 0 or version % 1 ~= 0 then
		return NewDB(), false
	end
	if version > State.VERSION then
		return db, true
	end
	if not Shaped(db) then
		return NewDB(), false
	end
	-- A current save runs the last step again, which only adds what is missing.
	for step = math.min(version + 1, State.VERSION), State.VERSION do
		migrations[step](db)
		db.version = step
	end
	return db, false
end

---@return table
local function NewChar()
	return { marks = 0, stamps = {}, txns = {}, orders = {}, areaBaseline = {} }
end

-- The character's record with every field present. In a read-only database the record is a copy that fills what a
-- newer build left out and a missing one is not stored, so a newer build's data is left as written. A rank missing
-- from an old record is the one its marks reach.
---@param db table
---@param guid string
---@param readOnly boolean?
---@return table
function State.Char(db, guid, readOnly)
	local chars = type(db.chars) == "table" and db.chars or {}
	local stored = chars[guid]
	local char = type(stored) == "table" and stored or nil
	if readOnly then
		local view = NewChar()
		for key, value in pairs(char or {}) do
			if type(value) == type(view[key]) or view[key] == nil then
				view[key] = value
			end
		end
		view.rank = type(view.rank) == "number" and view.rank or ns.Ranks.Index(view.marks)
		return view
	end
	if not char then
		char = NewChar()
		chars[guid] = char
	end
	for key, value in pairs(NewChar()) do
		if char[key] == nil then
			char[key] = value
		end
	end
	char.rank = char.rank or ns.Ranks.Index(char.marks)
	return char
end

local SETTINGS = { toasts = true, tracker = true }

---@param db table? nil before the saved variable loads: the default answers
---@param key string
---@return boolean
function State.Setting(db, key)
	local account = db and db.account
	local settings = type(account) == "table" and account.settings or nil
	local value
	if type(settings) == "table" then
		value = settings[key]
	end
	if value == nil then
		return SETTINGS[key]
	end
	return value
end

-- Stored only when the database has a settings table, as every one this build wrote does.
---@param db table?
---@param key string
---@param value boolean
function State.SetSetting(db, key, value)
	local account = db and db.account
	local settings = type(account) == "table" and account.settings
	if type(settings) == "table" then
		settings[key] = value
	end
end
