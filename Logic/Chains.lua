---@type string, LedgerForeverNamespace
local _, ns = ...

if ns.broken then
	return
end

-- Quest chains from QuestieDB records, by Adventure Guide's rule: a chain starts at a head no quest leads to,
-- follows `next` while exactly one quest leads into each step, and has at least two quests. A fork or a loop is not
-- a chain. Its total is shown only when proven: every member has at most one prerequisite and the chain ends on a
-- quest with no `next`.
--
-- A record is { zone?, races?, classes?, pre?, preAny?, next?, exclusive?, repeatable? }; `pre` lists the quests all
-- needed, `preAny` any one of them.
---@class LedgerChains
local Chains = {}
ns.Chains = Chains

---@param records table<integer, table>
---@return table<integer, integer|false> prev the one quest leading to each id, false when several do
local function Previous(records)
	local prev = {}
	for id, record in pairs(records) do
		local following = record.next
		if following and records[following] then
			prev[following] = prev[following] == nil and id or false
		end
	end
	return prev
end

---@param prev table
---@param id integer
---@return integer? head nil on a fork or a loop
local function Head(prev, id)
	local seen = {}
	while true do
		if seen[id] then
			return nil
		end
		seen[id] = true
		local before = prev[id]
		if before == false then
			return nil
		end
		if before == nil then
			return id
		end
		id = before
	end
end

---@param record table
---@return integer
local function PreCount(record)
	return #(record.pre or {})
end

---@param records table<integer, table>
---@return table[] chains { head = id, members = id[], total = integer? }, ordered by head
function Chains.Build(records)
	local prev = Previous(records)
	local chains, claimed = {}, {}
	local ids = {}
	for id in pairs(records) do
		ids[#ids + 1] = id
	end
	table.sort(ids)
	for _, id in ipairs(ids) do
		local head = Head(prev, id)
		if head and not claimed[head] then
			local members, seen, proven = {}, {}, true
			local step = head
			local ends = false
			-- A step that several quests lead into is a merge: the chain stops before it.
			while step and records[step] and not seen[step] and prev[step] ~= false do
				seen[step] = true
				members[#members + 1] = step
				local record = records[step]
				if PreCount(record) > 1 or (record.preAny and #record.preAny > 0) then
					proven = false
				end
				if not record.next then
					ends = true
				end
				step = record.next
			end
			claimed[head] = true
			if #members >= 2 then
				for _, member in ipairs(members) do
					claimed[member] = true
				end
				chains[#chains + 1] = { head = head, members = members, total = proven and ends and #members or nil }
			end
		end
	end
	return chains
end
