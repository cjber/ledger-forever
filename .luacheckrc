std = "lua51"
max_line_length = 120
exclude_files = { "forever-core/**", "tools/.cache/**", ".release/**", ".types/**", "types/**", ".claude/**", ".bugpatrol/runs/**", ".speedpatrol/runs/**", ".sloppatrol/runs/**" }
ignore = { "212/_.*", "212/self" } -- unused args prefixed with _, and self on mixin handlers

globals = {
	"LedgerForeverDB",
	"LedgerForever_OnAddonCompartmentClick",
	"SLASH_LEDGERFOREVER1",
	"SLASH_LEDGERFOREVER2",
	"SlashCmdList",
}

read_globals = {
	"C_AddOns", "C_Timer", "CreateFrame", "ForeverCore", "GetLocale", "InCombatLockdown", "Mixin", "UIErrorsFrame",
	"UIParent", "UnitName", "C_Texture", "CreateAtlasMarkup", "geterrorhandler", "strtrim", "hooksecurefunc", "issecretvalue", "canaccessvalue",
}

-- A translation line is one string: no room to wrap.
files["Locales/"] = { max_line_length = false }
files["tests/"] = { std = "+luajit" }
