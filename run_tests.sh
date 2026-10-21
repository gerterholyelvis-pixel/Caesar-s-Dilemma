#!/bin/bash
# Runs ONLY the headless SceneTree tests. Scripts such as test_creatures.gd, test_icons.gd, *_view.gd are scene scripts
# (they run inside a .tscn) and pop up an ALERT dialog on the user's screen if run with `-s`: never run those this way.
G="C:/Users/gerte/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64.exe"
fail=0
for f in $(grep -l "^extends SceneTree" game/test_*.gd); do
  [ "$f" = "game/test_e2e.gd" ] && continue   # slow (~2 min): run separately
  "$G" --headless --path . -s "$f" >/tmp/t.out 2>&1; rc=$?
  echo "$f rc=$rc"; [ $rc -ne 0 ] && fail=1
done
exit $fail
