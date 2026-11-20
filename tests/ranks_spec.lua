-- Run from the repository root: luajit tests/ranks_spec.lua
-- The rank ladder: six ranks of three steps by cumulative marks, and marks as idempotent transactions.
local Env = dofile("tests/ledger_env.lua")
local ns = Env.load(Env.namespace(), { "Logic/Ranks.lua", "Logic/Marks.lua" })
local checks = 0
local function check(condition, label)
	checks = checks + 1
	assert(condition, label)
end

local Ranks = ns.Ranks
check(#Ranks.Names == 6, "six ranks")
check(#Ranks.Thresholds == 18, "three steps each")
for index = 2, #Ranks.Thresholds do
	check(Ranks.Thresholds[index] > Ranks.Thresholds[index - 1], "thresholds rise at step " .. index)
end
check(Ranks.Index(0) == 1, "no marks is the first step")
check(Ranks.Index(7) == 1 and Ranks.Index(8) == 2, "a step starts exactly at its threshold")
check(Ranks.Index(10 ^ 6) == 18, "the top step has no ceiling")
check(Ranks.Name(1) == "Wanderer I", "first name")
check(Ranks.Name(18) == "Cartographer III", "last name")
local tier, step = Ranks.Split(8)
check(tier == 3 and step == 2, "step 8 is Pathfinder II")
check(Ranks.NextThreshold(18) == nil, "nothing above the top")
check(Ranks.Fraction(0) == 0 and Ranks.Fraction(4) == 0.5, "half way through the first step")
check(Ranks.Fraction(10 ^ 6) == 1, "the top step is full")

local Marks = ns.Marks
local char = { marks = 0, rank = 1, txns = {} }
local paid, rank = Marks.Pay(char, "order:1:1", "order")
check(paid and rank == nil and char.marks == Marks.Value.order, "an order pays its value")
paid = Marks.Pay(char, "order:1:1", "order")
check(not paid and char.marks == Marks.Value.order, "the same id pays once")
paid, rank = Marks.Pay(char, "stamp:100", "stamp")
check(paid and rank == 2 and char.rank == 2, "a payment that crosses a threshold reports the new rank")
local before = char.marks
Marks.Pay(char, "level:11", "level")
check(char.marks == before + Marks.Value.level, "level marks add")
for _, value in pairs(Marks.Value) do
	check(value > 0, "no mark value takes marks away")
end
print(("ranks_spec: %d checks"):format(checks))
