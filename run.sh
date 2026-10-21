D="C:/Users/gerte/AppData/Local/Claude-Data/claude_pzs8sxrjxfjjc/scratch-workspaces/1fa06145-7fa2-4d18-99db-1ca2768bc4e7/48491dd8-dedd-4ea8-8051-35f633fc5567/scratch-2026-10-21-ef175b"
mkdir -p "$D/$1"
"C:/Users/gerte/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64.exe" --path "$D/alchemist_v2" res://limbo.tscn --quit-after 60 --write-movie "$D/$1/f.png" --fixed-fps 10 2>&1 | grep -E "ERROR|GPU|SHADER" | head
