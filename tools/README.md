# Tools

`python3 tools/gate.py` is the fast local gate (`--changed` for the files you touched). `tools/typecheck.sh` runs the
LuaLS pass and is left to CI. `tools/forever_tools` and `tools/forever_sim` are vendored from forever-core: refresh them
with `python3 tools/forever_tools/sync.py update --source ../forever-core`, never edit them. `tools/forever-core.txt`
pins the embedded ForeverCore release.
