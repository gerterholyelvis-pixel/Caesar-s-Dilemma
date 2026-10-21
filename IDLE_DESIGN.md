# Caesar's Dilemma, the IDLE GAME (pivot from the roguelike; the old game is saved as git tag `roguelike-v1`)

Kept as-is: start screen, Limbo + the angel, the garden fly-through, the title "Caesar's Dilemma". Everything after the title is the idle game.
User's wishes: START SIMPLE and unlock complexity gradually ("a little bit of everything"); POLISH everything; CLEAR and MODERN-looking UI;
better graphics; unique visuals. Carried over: the GLYPH LANGUAGE + CODEX, HEROES SESHAT and THOTH, the ANGEL and LIMBO.
Wanted aspects: PRESTIGE/REBIRTH layers, RESEARCH + CRAFTING + AUTOMATION, EXPLORATION + EVENTS (Caesar's Dilemmas), COLLECTIONS + ACHIEVEMENTS + SECRETS.
Not carried over: backpack grid, turn-based combat, route map, runs.

## Fantasy
You wake in a ruined, silent fractal garden (the world beyond Limbo) holding one seed. You regrow it: tap, plant, automate, decode the secret glyph language,
send expeditions, craft relics, and when growth stalls the angel in Limbo offers to take you back so the garden can start again stronger. Mysterious tone kept
(unread glyphs, secrets, cryptic events); the UI itself is CLEAR (numbers, costs, rates always plain).

## Progressive disclosure ladder (each rung unlocks a new tab/aspect with a small cinematic moment + a glyph word learned)
0. First minute: ONE number (Sap) and ONE button: tap the Seed. Buy the first Sprout (auto Sap/s). Nothing else visible.
1. Generators (garden growth): Sprout, Fern, Fractal Tree, Crystal Bloom, Spore Engine, Waterfall Mill, ... cost x1.15 each, x2 milestones at 25/50/100/200 owned.
   The GARDEN WORLD VIEW visibly grows with what you own (fractal trees appear in the mid layer, the waterfall comes alive, light grows).
2. Upgrades: clear one-time multipliers and click upgrades, grouped and always showing effect + cost; Buy x1/x10/x100/Max.
3. Research (Insight, 2nd currency, produced by Thoth observing + glyph decoding): a tech tree whose nodes are named in glyphs until decoded in the CODEX; research
   unlocks automation (auto-buy managers), new generators, new tabs.
4. Heroes: SESHAT (the Measurer: lattice bonuses, boosts generators, builder) and THOTH (the Scribe: Insight, research speed, glyph learning). Levels, perks,
   active abilities with cooldowns (the engaged-play layer), unlocked at milestones.
5. Expeditions + Events: send timed idle expeditions to zones (Glade, Waterfall, Crystal Hollow, Mirror Lake, Eclipse Shore, ...) for Essences and Relic fragments;
   random garden events; occasional CAESAR'S DILEMMA (2-3 choices with trade-offs, cryptic text, reusing the existing dilemma writing).
6. Crafting: combine Essences into Relics (permanent multipliers) via recipes the player discovers (some secret); relic slots.
7. Prestige 1, "Return to Limbo": the angel offers rebirth for Memories (permanent multiplier + a Memory tree). Prestige 2, "Eclipse" (later): new currency + new
   generators. Layer 3 sketched, not built yet.
8. Collections + Achievements + Secrets: Codex (glyphs), Flora catalogue, Relics, Achievements (many hidden), Secrets (hidden interactions in the garden world).

## Systems and rules
- BIG NUMBERS: custom mantissa+exponent type (class BigNum) from day one; formatting K/M/B... then scientific, plus an optional alien-glyph notation.
- Engine: fixed-step simulation decoupled from rendering; deterministic; offline progress (efficiency-capped, 'welcome back' summary); autosave + versioned
  save + export/import string; everything data-driven (JSON/GDScript dictionaries) so content is easy to add; balance simulator.
- UI (modern, clear, beautiful): top resource bar with rates; tab rail; big readable numbers; one-click Buy x1/x10/x100/Max; progress toward next milestone;
  tooltips with exact maths; unlock toasts; never hide the numbers (mystery lives in glyph names, secrets and events, not in the maths).
- VISUALS: the fractal alien garden is the main stage and EVOLVES with progress; glassy ink-and-gold panels; HDR bloom, particles, post-processing, smooth easing,
  satisfying number/purchase juice; unique, not a stock idle-game look. Palette: teal/emerald, violet/magenta, gold, cyan glow.
- AUDIO: the generated music/sfx system (just intonation, Euclidean rhythm...) driven by progress (more stems as the garden grows); sfx for every purchase/unlock.
- Mystery pillar stays: glyph words everywhere, secrets, cryptic lore; clarity of numbers is non-negotiable.

## Build stages
I0 strip the roguelike (agent), keep Limbo/garden/title and the reusable libs (glyph_gen, lexicon, meta, codex_ui, cutscene, cinematics shell, sfx, music, ui_kit, creature_art hero forms).
I1 core engine (BigNum, economy, save, offline, tests).  I2 UI framework + HUD.  I3 garden world view that grows with progress.
I4 systems in parallel: generators+upgrades | research+glyph decoding | heroes | expeditions+events | crafting | prestige | collections+achievements.
I5 audio + cinematic moments.  I6 balance by simulation.  I7 polish for beauty/clarity/60 fps.  Commit + push after each stage.
