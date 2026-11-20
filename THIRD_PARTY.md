# Third-party inputs

Everything Ledger Forever is built from that it did not write itself: where each comes from, where its pin lives, its
licence, and whether any of it reaches the zip players install. The addon itself is GPL-3.0-or-later ([LICENSE](LICENSE)).

## Ships in the zip

| Input | Used for | Pin | Licence |
|---|---|---|---|
| [ForeverCore](https://github.com/cjber/forever-core) | The shared Forever tracker, settings page and credits window, embedded in the zip by the release workflow | `tools/forever-core.txt` | GPL-3.0-or-later |

`media/` is this addon's own: the icon is drawn in `media/icon.svg`. Nothing else ships.

## Read in game, never bundled

| Input | Used for | Licence |
|---|---|---|
| Questie and QuestieDB, if installed | A zone's quests, to know when a zone's story is finished | QuestieDB carries no licence; nothing is copied |

## Build and test only

| Input | Used for | Pin | Licence |
|---|---|---|---|
| [Ketho's WoW API annotations](https://github.com/Ketho/vscode-wow-api) | lua-language-server types in `tools/typecheck.sh` | `revision` in `tools/typecheck.sh` | MIT |
| [FrameXML annotations](https://github.com/NumyAddon/FramexmlAnnotations) | FrameXML types, the Ketho checkout's `Annotations/FrameXML` submodule | The gitlink in that Ketho revision | MIT |
| [forever_tools](https://github.com/cjber/forever-core/tree/main/.agents/skills/wow-forever-addon/tooling/forever_tools) | Shared lints and release checks, vendored in `tools/forever_tools/` | `revision` in `tools/forever_tools/MANIFEST.json` | GPL-3.0-or-later |
| [forever_sim](https://github.com/cjber/forever-core/tree/main/.agents/skills/wow-forever-addon/tooling/forever_sim) | Real Blizzard UI scenario tests, vendored in `tools/forever_sim/` | `revision` in `tools/forever_sim/MANIFEST.json` | GPL-3.0-or-later |
| Ko-fi's Support me on Ko-fi button | The support button in the README and its PNG render, `docs/kofi-button.png`, in the store description | None: the README links Ko-fi's live file | Ko-fi's |
| `docs/github-sponsors-button.png` | The GitHub Sponsors button in the README and store description | None | Drawn in forever-core with the heart from GitHub's [Octicons](https://github.com/primer/octicons) (MIT) |
| `docs/discord-button.png` | The Discord button on the store page | None | Drawn in forever-core with Discord's logo from [Simple Icons](https://simpleicons.org) (CC0) |

CI tools (StyLua, ruff, luacheck, lua-language-server, actionlint, zizmor, gitleaks, the BigWigs packager) are pinned in
`.github/workflows/` and `tools/typecheck.sh`.

## Players

Credit for the reports, translations and requests behind the addon.

| Who | What | Notes |
|---|---|---|

## Inspired by

Credit for the addons and projects an idea came from.

| Who | What | Notes |
|---|---|---|
