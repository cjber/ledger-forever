# About the code

Ledger Forever is a World of Warcraft: Forever addon in Lua 5.1. The files `LedgerForever.toc` lists are
what the game loads; `tests/*_spec.lua` load them in that order inside a stubbed client.

- Keep every saved variable name and every global the TOC exposes unchanged.
- Generated data, `Libs/` and `tools/forever_tools/` are never edited by hand.
- Taint: never replace a Blizzard global or hook a secure function a spec does not already hook.
- Never use the network, and never start the game, Battle.net, Lutris or Wine. The headless client (forever-core's `wow-forever-addon/in-game.md`) tests the build linked into the game, not this checkout, so in-game checks belong to the agent that ships a change.

`python3 tools/repo_rules.py` holds the rules no linter covers; run it with the other checks.

## Live roots

Things reached indirectly: none of them is dead code, even when no file calls it by name.

- `LedgerForever.toc` file list: load order `Locales/enUS.lua` (then any `Locales/<locale>.lua`),
  `Core/ForeverRequire.lua`, `Core/Require.lua`, `Data/Credits.lua`, `Core/Secret.lua`, `Core/Core.lua`; never reorder
  as formatting.
- `## SavedVariables: LedgerForeverDB`; `## AddonCompartmentFunc: LedgerForever_OnAddonCompartmentClick`: global
  called by the client.
- `SLASH_LEDGERFOREVER1/2` + `SlashCmdList.LEDGERFOREVER` (Core/Core.lua): `/ledger`, `/ledgerforever`.
- `Core/ForeverRequire.lua` is the shared file, the same in every addon.
- `tools/check_diagnostics.py`, `tools/lint_multivalue.py`: run by `tools/typecheck.sh`; `tools/changelog.py`: run by
  `release.yml` and (`--check`) `ci.yml`; `tools/repo_rules.py`: run by `ci.yml`.
