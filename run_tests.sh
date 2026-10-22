#!/bin/bash
# Runs ONLY the headless SceneTree tests (scene scripts must never be run with -s: they pop an ALERT on the user's screen).
G="C:/Users/gerte/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64.exe"
fail=0
for f in $(grep -l "^extends SceneTree" game/test_*.gd); do
  "$G" --headless --path . -s "$f" >/tmp/t.out 2>&1; rc=$?
  echo "$f rc=$rc"; [ $rc -ne 0 ] && { fail=1; grep -n "ERROR\|FAIL" /tmp/t.out | head -5; }
done
exit $fail
