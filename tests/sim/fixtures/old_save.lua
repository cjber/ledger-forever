-- A save from before the database carried a version: one character with marks and a stamp, as the first release
-- would have written it. The addon lifts it in place and keeps both.
LedgerForeverDB = {
	chars = {
		["Player-1-0000"] = {
			marks = 42,
			stamps = { [1411] = { at = 1, source = "story" } },
		},
	},
}
