-- luacheck: read globals scenario
scenario("Ledger toasts stack, queue and open the book", function(sim)
	dofile("tests/sim/forever_core.lua").install(sim)
	sim:login()

	local G = sim.G
	local anchor = assert(G.LedgerForeverToastAnchor, "the toast anchor loaded")
	local flags = anchor.shouldQueueAlertsFlags
	assert(flags.playerEnteredWorld and flags.variablesLoaded and flags.firstFrameRendered, "the alert queue is ready")

	-- Use the loader's private namespace in this client. The runner exercises other surfaces in a fresh client.
	local ns
	for _, entry in ipairs(sim.loader.addons) do
		if entry.name == "LedgerForever" then
			ns = entry.ns
			break
		end
	end
	assert(ns, "Ledger Forever's namespace loaded")
	sim:runAs(
		"LedgerForever",
		[[
		local ns = ...
		assert(ns.State.Setting(ns.Ledger.DB(), "toasts"), "toasts are enabled")
		ns.Toast.Show("Order complete", "First order")
		ns.Toast.Show("Order complete", "Second order")
		ns.Toast.Show("New rank", "Third toast")
	]],
		ns
	)

	local queue = assert(anchor.alertFrameSubSystems[1], "the real Blizzard alert subsystem was created")
	assert(queue.alertFramePool:GetTemplate() == "CriteriaAlertFrameTemplate", "the pool uses the stock criteria toast")
	assert(queue:GetNumVisibleAlerts() == 2, "two toasts show")
	assert(queue:GetNumQueuedAlerts() == 1, "the third toast queues")
	local function shownToast(heading, name)
		for frame in queue.alertFramePool:EnumerateActive() do
			if frame.Name:GetText() == name then
				assert(frame.Unlocked:GetText() == heading, "the toast heading is set")
				assert(frame:IsVisible(), "the toast is visible")
				assert(frame:GetParent() == G.UIParent, "Blizzard parents the toast to the fullscreen frame")
				local relative = frame
				for _ = 1, 2 do
					local _, parent = relative:GetPoint()
					if parent == anchor then
						return frame
					end
					assert(parent and parent:GetAlertContainer() == anchor, "the toast stacks under the addon anchor")
					relative = parent
				end
				error("the toast stack does not reach the addon anchor")
			end
		end
		error("no visible toast named " .. name)
	end

	local first = shownToast("Order complete", "First order")
	shownToast("Order complete", "Second order")
	assert(not ns.Book.IsShown(), "the book starts closed")
	sim:click(first)
	assert(ns.Book.IsShown(), "clicking the toast opens Ledger Forever's book")

	sim.run(function()
		first:Hide()
	end)
	assert(queue:GetNumVisibleAlerts() == 1, "hiding a toast releases its slot")
	-- The loaded Blizzard pool runs the reset callback before reclaiming the slot, so the callback still sees
	-- two active frames. Run the real queue check again once the slot is free.
	sim.run(function()
		queue:CheckQueuedAlerts()
	end)
	assert(queue:GetNumQueuedAlerts() == 0, "the queue drains once a slot is free")
	assert(queue:GetNumVisibleAlerts() == 2, "the queued toast takes the freed slot")
	shownToast("New rank", "Third toast")
	sim:expectNoErrors()
	sim:expectNoStrandedWaits("LedgerForever")
end)
