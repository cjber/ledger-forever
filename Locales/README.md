# Translations

Every phrase Ledger Forever writes goes through `L`, so it can be translated. German, Spanish (esES and esMX), Korean,
Brazilian Portuguese, Russian and Chinese (zhCN and zhTW) are machine translated, and so is French: such a file starts
with a `-- Machine translated` comment, and a machine line in a human file ends `-- mt`. A human correction replaces
the machine line and drops its mark. There is no Italian file, because the WoW: Forever client has no Italian.
`python3 tools/check_locales.py` checks every file and prints its coverage.

To correct a line, edit `Locales/<locale>.lua` and open a pull request. To add a language the client offers, copy
`phrases.txt` to `Locales/<locale>.lua`, change the locale in its `GetLocale` line and translate the right-hand side of
each line. Anything you leave out stays in English. Then add `Locales\<locale>.lua` to `LedgerForever.toc`, right after
`Locales\enUS.lua`, and open a pull request. If that's a hassle, paste your lines into a
[translation issue](https://github.com/cjber/ledger-forever/issues/new?template=translation.yml) and I'll add them.

Zone, quest and item names come from the game, so they are already in your language.
