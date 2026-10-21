# Balance (greedy-bot simulation)

Run: `godot --headless --path . -s game/sim_balance.gd -- 400` (runs per hero/origin combo; ~40 s).
Bot: real ItemDB/Backpack/Combat/EnemyDB/RouteMap/DilemmaDB; Run's economy mirrored locally (first-fit placement via
`find_spot`, ratio-greedy item use, naive pathing and dilemma scoring). It does NOT plan adjacency, so a human should beat it.

## Result (2400 runs)
| | win | avg depth |
|---|---|---|
| overall | 23% | 9.6 |
| seshat / thoth | 19% / 28% | 9.7 / 9.6 |
| eclipse / mirror / cathedral | 22% / 25% / 23% | 9.6 / 9.6 / 9.7 |

Fights (avg damage taken, avg turns, loss rate): fight 7.4 / 3.6 / 6%, elite 26 / 4.9 / 37%, boss 37 / 4.3 / 67%.
Item pick-win lift (acquired by depth 5, vs hero/origin baseline): median 0.96, max x1.9 median (hungry_maw),
min x0.4 (cursed_crown: cost 3 is rarely the bot's best ratio; humans use it with `sole_ruler`).

## Changes
- enemies.gd: regular enemy hp x2.0; elites attack x0.9; boss hp 60 -> 90, attack x0.75 (tests updated).
- items.gd: bone_blade 6->5 (+secret `twin` +3 beside a copy), crystal_bow 5->7 (+secret `second_string`), quiver +2,
  fractal_seed 3->4, lapis_shield 7->8, spore_flask heal 6, healing_bloom heal 2, sun_shard +1, mirror_shard 1,
  hollow_idol 1, moss_charm `hush` now wakes beside blooms, hungry_maw 2 (gnaw +1), tide_flute 2, shard_axe 14,
  oath_stone +2, void_lantern +2, grafted_heart 12 / cost 1, cursed_crown 20, spiral_shell 6.
- Tests updated for the new numbers: test_items_backpack, test_integration, test_combat_enemies.
- Mirror origin gets its edge from the twin secrets (copy placed beside the original); the bot rarely arranges that.
