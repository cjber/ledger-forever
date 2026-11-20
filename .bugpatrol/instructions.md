# About the app

Ledger Forever is a World of Warcraft: Forever addon written in Lua 5.1. It cannot run outside the
game client, and this patrol never starts it (see the rules below). What runs here is its headless test harness: each
`tests/<name>_spec.lua` stubs the client API, loads the addon files the TOC lists, and checks one
feature. Run a spec with `luajit tests/<name>_spec.lua`; a failing spec exits non-zero and prints
the failed assertion. `luacheck <file>` lints a file.

One invariant has its own spec and is the first place to look: `tests/core_dependency_spec.lua` checks that
`Core/Require.lua` stops the addon with one on-screen line when the loaded ForeverCore lacks a member the addon calls.
The tracker section must attach through `ForeverCore.TrackerHost`, rendered only after `PLAYER_ENTERING_WORLD` and
`VARIABLES_LOADED`, deferred one frame.

Use the specs and `luajit -e` one-liners that load the harness to check what a change claims.
Report a spec that fails, an error that a spec prints, or a behaviour a spec shows that the change
does not intend.

## Sign in

No sign-in.

## Important flows

- Registration with ForeverCore and the `/ledger` opener (the book itself is not built yet).
- The missing or outdated ForeverCore path: one on-screen line, and the slash words still answer.

## Never do these things

- Never start the game, Battle.net, Lutris or Wine. The headless client (forever-core's `wow-forever-addon/in-game.md`) tests the build linked into the game, not this checkout, so in-game checks belong to the agent that ships a change.
- Never edit, move or delete files.
- Never use the network.
