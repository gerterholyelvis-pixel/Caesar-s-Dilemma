# Caesar's Dilemma: new game

Flow: start screen -> Limbo (the little black angel in the red hat rises, "Hello traveler", "Where do you come from?",
three hieroglyph answers, his "...") -> the floor of Limbo cracks and gives way -> FALL cinematic (descent/fall_cinematic.gd)
down through ever deeper hells -> the obsidian bottom (descent/obsidian_scene.tscn), very low light, where the new game starts.

Test hooks for limbo: `-- --pick` answers automatically, `-- --fast` shortens the collapse waits.

The old games are preserved as git tags: `idle-v1` (garden/idle game) and `roguelike-v1` (roguelike).
Kept libraries: game/ (glyph_gen, lexicon, meta, cutscene, sfx, music, hub, ui_kit, dilemmas + tests).
