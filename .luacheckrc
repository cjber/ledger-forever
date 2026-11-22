std = "lua51"
max_line_length = 120
exclude_files = { "forever-core/**", "tools/.cache/**", "tests/.corpus/**", ".release/**", ".types/**", "types/**", ".claude/**", ".bugpatrol/runs/**", ".speedpatrol/runs/**", ".sloppatrol/runs/**" }
ignore = { "212/_.*", "212/self" } -- unused args prefixed with _, and self on mixin handlers

globals = {
	"LedgerForeverDB",
	"LedgerForever_OnAddonCompartmentClick",
	"SLASH_LEDGERFOREVER1",
	"SLASH_LEDGERFOREVER2",
	"SlashCmdList",
}

read_globals = {
	"AlertContainerMixin", "DEFAULT_FULLSCREEN_STRATA",
	"C_AddOns", "C_Timer", "CreateFrame", "ForeverCore", "GetLocale", "InCombatLockdown", "Mixin", "UIErrorsFrame",
	"UIParent", "UnitName", "C_Texture", "CreateAtlasMarkup", "geterrorhandler", "strtrim", "hooksecurefunc", "issecretvalue", "canaccessvalue",
	"AlertFrame", "BottomManagedFrameContainer", "C_DateAndTime", "C_Map", "C_MapExplorationInfo", "C_QuestLog", "GRAY_FONT_COLOR", "GetMaxPlayerLevel",
	"GetServerTime", "LibQuestieDB", "OBJECTIVE_TRACKER_COLOR", "Questie", "UISpecialFrames", "UnitClass", "UnitFactionGroup",
	"UnitGUID", "UnitLevel", "UnitRace", "bit", "debugprofilestop", "loadstring", "setfenv",
}

-- A translation line is one string: no room to wrap.
files["Locales/"] = { max_line_length = false }
files["tests/"] = { std = "+luajit" }
