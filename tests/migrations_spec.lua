-- Run from the repository root: luajit tests/migrations_spec.lua
-- The saved variable: empty, current, old, newer and corrupt databases. Marks and stamps are never deleted.
local Env = dofile("tests/ledger_env.lua")
local ns = Env.load(Env.namespace(), { "Logic/Ranks.lua", "Core/State.lua" })
local checks = 0
local function check(condition, label)
	checks = checks + 1
	assert(condition, label)
end

local State = ns.State
local db, readOnly = State.Migrate(nil)
check(
	db.version == State.VERSION and not readOnly and next(db.chars) == nil,
	"an empty variable gives a fresh database"
)
check(type(db.account.settings) == "table" and type(db.account.designs) == "table", "account part exists")

local current = { version = State.VERSION, chars = { a = { marks = 5 } }, account = { designs = {}, settings = {} } }
local same = State.Migrate(current)
check(same == current and same.chars.a.marks == 5, "a current database is kept as is")

-- An old save: no version, characters already present.
local old = { chars = { a = { marks = 40, stamps = { [100] = { at = 1, source = "story" } } } } }
local migrated = State.Migrate(old)
check(migrated == old and migrated.version == State.VERSION, "an unversioned save is lifted in place")
check(migrated.chars.a.marks == 40 and migrated.chars.a.stamps[100], "marks and stamps survive a migration")
check(type(migrated.account.settings) == "table", "the missing account part is added")

local future = { version = State.VERSION + 1, chars = { a = { marks = 9 } } }
local kept, locked = State.Migrate(future)
check(kept == future and locked and future.version == State.VERSION + 1, "a newer database is read-only and untouched")
local char = State.Char(future, "b", locked)
check(char.marks == 0 and future.chars.b == nil, "a read-only database gets no new record")

for _, bad in ipairs({ "text", 5, { version = "x" }, { version = 1, chars = "no" }, { chars = 7 } }) do
	local replaced, flag = State.Migrate(bad)
	check(replaced ~= bad and replaced.version == State.VERSION and not flag, "a corrupt variable is replaced")
end

-- A current save with parts missing is completed, never trusted as is.
for _, partial in ipairs({ { version = 1 }, { version = 1, chars = {} }, { version = 1, account = {} } }) do
	local lifted = State.Migrate(partial)
	check(
		lifted == partial and type(lifted.chars) == "table" and type(lifted.account.settings) == "table",
		"missing parts added"
	)
	check(State.Setting(lifted, "toasts") == true and State.Char(lifted, "g").orders ~= nil, "and read without error")
end
for _, version in ipairs({ -1, 0.5, 0 / 0 }) do
	local replaced = State.Migrate({ version = version, chars = { a = {} } })
	check(replaced.version == State.VERSION and next(replaced.chars) == nil, "an invalid version is a corrupt save")
end
local badAccount = State.Migrate({ version = 1, chars = {}, account = "x" })
check(type(badAccount.account) == "table", "a non-table account is replaced")

-- A newer save missing parts reads with defaults and is never written to.
local sparse = { version = State.VERSION + 1, chars = { g = { marks = 9 } } }
local view = State.Char(sparse, "g", true)
check(
	view.marks == 9 and type(view.orders) == "table" and type(view.stamps) == "table",
	"a read-only record has every field"
)
check(
	view.rank == ns.Ranks.Index(9) and sparse.chars.g.orders == nil,
	"its rank follows its marks and the save is untouched"
)
local bare = { version = State.VERSION + 1 }
check(State.Char(bare, "g", true).marks == 0, "a read-only save without characters reads")
check(State.Setting(bare, "toasts") == true, "a read-only save without an account answers the default")
State.SetSetting(bare, "toasts", false)
check(bare.account == nil, "and is not written")

-- An old record's rank comes from its marks, so the next payment is not a false rank-up.
local legacy = State.Migrate({ chars = { g = { marks = 42 } } })
check(State.Char(legacy, "g").rank == ns.Ranks.Index(42), "an old record without a rank derives it")

local fresh = State.Migrate(nil)
local made = State.Char(fresh, "g")
check(
	made.marks == 0 and made.rank == 1 and made.stamps and made.txns and made.orders,
	"a new character has every field"
)
check(State.Char(fresh, "g") == made, "the record is stored")
fresh.chars.h = { marks = 3 }
local filled = State.Char(fresh, "h")
check(filled.marks == 3 and filled.stamps and filled.txns, "an old record gains the fields it lacks")

check(State.Setting(nil, "toasts") == true, "defaults answer before the variable loads")
State.SetSetting(fresh, "toasts", false)
check(State.Setting(fresh, "toasts") == false and State.Setting(fresh, "tracker") == true, "a setting is stored")
State.SetSetting(nil, "toasts", false)
print(("migrations_spec: %d checks"):format(checks))
