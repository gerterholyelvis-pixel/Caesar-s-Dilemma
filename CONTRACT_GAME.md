# Caesar's Dilemma: backpack-builder roguelike (design + code contract)

Godot 4.7 (GDScript), project folder = alchemist_v2. All new code lives in `game/` (create it).
The user's words: "a deckbuilder, except a *backpack builder* where you collect ITEMS instead of cards."
Think Backpack Hero / Backpack Battles mixed with Slay the Spire: turn-based, you pack Tetris-shaped
items into a grid backpack, items touching each other make each other stronger, and every room ends
with a moral "Dilemma". The world is the alien fractal garden (side-on, ground line at UV y = 0.80;
see CONTRACT_GARDEN.md for the look: deep teal/emerald, violet/magenta, gold + cyan glow, fractal
self-similarity) and the hub is Limbo with the little black angel in the red hat.

## Run flow
DECIDED with the user: turn-based combat where you click backpack items; Tetris-shaped items in a grid; meta layer =
BOTH glyph-language learning AND unlockable origins/hats; Dilemmas are RARE EVENTS (about 1-2 per run), not after every fight.

Limbo hub -> (angel asks "where do you come from?" = pick an origin) -> garden run: fight -> loot (pick 1 of 3
items, then drag it into the backpack, rotate with R / right-click) -> fight ... with an occasional Dilemma room
(2-3 trade-off choices) ... final room = boss at the waterfall. Death or victory returns to Limbo.
Meta layer: item names are written in the unreadable pictogram language (glyphs.gd: GlyphsLib.draw);
an item you have never "identified" shows its name as glyphs; using it in combat (or a Glyph Lens)
identifies it permanently (saved in user://meta.cfg), after which its readable name shows.

## Data model (pure logic, NO scene/UI code, no `get_tree()`; everything RefCounted)
File `game/items.gd`  (`class_name ItemDB`)
  const ITEMS: Dictionary  id -> definition Dictionary:
    id: String                    # key
    name: String                  # readable English name
    glyphs: Array[int]            # 3-5 ints 0..13 = unreadable-name pictograms (glyphs.gd COUNT = 14)
    shape: Array[Vector2i]        # occupied cells at rot 0, origin (0,0), all x,y >= 0
    cost: int                     # energy to use (0..3); passive items have cost 0 and kind "passive"
    kind: String                  # "active" (clicked to use, once per turn) | "passive" (always on / triggers)
    tags: Array[String]
    effect: Dictionary            # see "Effects"
    synergies: Array[Dictionary]  # see "Synergies"
    rarity: int                   # 1 common, 2 uncommon, 3 rare
    desc: String                  # one-line rules text with {amount} style placeholders optional
    consumable: bool              # active item can be used only once per battle if true
  static func get_def(id) -> Dictionary;  static func all_ids() -> Array[String]
  static func roll_loot(rng: RandomNumberGenerator, count: int, rarity_bias := 0.0) -> Array[String]  # distinct ids
  static func shape_rotated(id_or_cells, rot: int) -> Array[Vector2i]   # rot 0..3 clockwise 90 deg, normalised to min x,y = 0
The 14 starter item ids (all required): bone_blade, shard_axe, thorn_dagger, crystal_bow, lapis_shield,
reed_buckler, whetstone, quiver, spore_flask, healing_bloom, sun_shard, moss_charm, fractal_seed, glyph_lens.
  Ideas (agent may rebalance): bone_blade 1x3 cost1 dmg6, adjacent whetstone +3; shard_axe L-tromino
  cost2 dmg10; thorn_dagger 1x2 cost1 dmg3 x2 hits; crystal_bow 1x3 cost1 dmg5, adjacent quiver +2;
  lapis_shield 2x2 cost1 block7; reed_buckler 1x2 cost1 block4; whetstone 1x1 passive tag "whetstone"
  (boosts adjacent weapons); quiver 1x1 passive tag "quiver"; spore_flask 1x1 consumable heal5;
  healing_bloom 1x2 cost1 heal4 (+2 adjacent water-tag items); sun_shard 1x1 consumable gain 2 energy;
  moss_charm 1x1 passive: at turn start gain 1 block per adjacent item; fractal_seed T-shape cost2:
  deal 3 damage per adjacent item (the FRACTAL theme: power grows with self-similar packing);
  glyph_lens 1x1 passive: identifies items.
Effects (Dictionary): {"type": "damage"|"block"|"heal"|"energy"|"multi_damage"|"damage_per_adjacent"|
  "turn_start_block_per_adjacent"|"identify", "amount": int, "hits": int (multi_damage)}.
Synergies: [{"with_tag": String, "bonus": {"amount": +int}}]; applies once per adjacent item having the
  tag (edge-adjacent, i.e. sharing an edge, not diagonal), and a passive with "boost_tag":String +
  "boost_amount" boosts every adjacent item having that tag. Agent may extend.

File `game/backpack.gd` (`class_name Backpack`, RefCounted)
  var w := 5; var h := 4                                   # grid size, cells
  var placed: Array[Dictionary]                            # {uid:int, id:String, pos:Vector2i, rot:int}
  func can_place(id: String, pos: Vector2i, rot: int, ignore_uid := -1) -> bool   # in bounds, no overlap
  func place(id: String, pos: Vector2i, rot: int) -> int   # returns uid, or -1 if invalid
  func remove(uid: int) -> Dictionary                      # returns the removed entry ({} if none)
  func find_spot(id: String) -> Dictionary                 # {"pos":Vector2i,"rot":int} first spot where it fits, {} if none
  func cells_of(uid: int) -> Array[Vector2i]               # absolute grid cells
  func uid_at(cell: Vector2i) -> int                       # -1 if empty
  func entry(uid: int) -> Dictionary
  func neighbors(uid: int) -> Array[int]                   # uids sharing an edge
  func effective_effect(uid: int) -> Dictionary            # item effect with all synergy/boost bonuses applied
  func describe(uid: int) -> String                        # readable tooltip text with the real numbers
  func to_array() -> Array / static func from_array(a) -> Backpack     # save/load
  signal changed
File `game/combat.gd` (`class_name Combat`, RefCounted)
  signals: log_line(text: String), changed, item_used(uid: int), damage_dealt(target: String, amount: int, index: int),
           ended(won: bool)
  var backpack: Backpack; var player: Dictionary {hp, max_hp, block, energy, max_energy:=3}
  var enemies: Array[Dictionary]   # {id, name, hp, max_hp, block, intent:{type:"attack"|"block"|"heal"|"split", amount:int, glyphs:Array[int]}, alive:bool, scale:float}
  var turn := 1; var used: Array[int] (uids used this turn); var used_consumables: Array[int]
  func start(bp: Backpack, enemy_ids: Array, player_state: Dictionary, rng: RandomNumberGenerator) -> void
  func can_use(uid: int) -> bool;  func use(uid: int, target := 0) -> void   # active items: spend energy, apply effective_effect
  func end_turn() -> void           # enemies act (use intents), start next turn: energy refill, block resets, passives trigger
  func is_over() -> bool;  var won := false
File `game/enemies.gd` (`class_name EnemyDB`): ENEMIES dict: spore_sprout (hp~18, splits when hurt below half: spawns a
  smaller copy), thorn_crawler, crystal_moth, glass_golem, and boss cascade_warden (hp~60, multi-phase intents).
  Each: id, name, max_hp, intents pattern (cycle), `art` key = same id (creatures are drawn by CreatureArt).
  static func floor_enemies(floor: int, rng) -> Array[String]
File `game/dilemmas.gd` (`class_name DilemmaDB`): ~12 moral Dilemmas, each
  {id, title, text, choices: [{label, effects: [{"type": "max_hp"|"hp"|"gold"|"item"|"curse_item"|"remove_item"|"shrink_pack"|"grow_pack", "amount": int, "id": String}], "flavor": String}]}
  Text in plain English (these are the ONLY readable story text; keep them short, moody, witty, 1-2 sentences).
  static func roll(rng) -> Dictionary
File `game/meta.gd` (`class_name Meta`, static): load()/save() to user://meta.cfg; known_items: Dictionary id->true;
  best_floor:int; unlocked_origins: Array; is_known(id) / mark_known(id).

## Art / UI (Control/CanvasItem code, procedural vector drawing only, no downloaded assets)
`game/item_icons.gd` (`class_name ItemIcons`): static func draw(ci: CanvasItem, id: String, rect: Rect2, t := 0.0, glow := 0.0)
   draws a distinctive, beautiful procedural icon for each of the 14 ids filling `rect` (the item's bounding box in px,
   so a 1x3 blade is a tall thin rect); style = glowing alien-fractal artefacts: dark glassy body, gold/cyan/magenta
   rim glow, subtle self-similar details. `t` = time for shimmer; `glow` 0..1 hover/selected emphasis.
`game/creature_art.gd` (`class_name CreatureArt`): static func draw(ci: CanvasItem, kind: String, center: Vector2, size: float, t: float, hurt := 0.0, scale_f := 1.0)
   kinds: "player" (the traveler: a small cloaked figure, readable silhouette, accent colour cyan-gold, NOT the black angel),
   "spore_sprout", "thorn_crawler", "crystal_moth", "glass_golem", "cascade_warden". Fractal self-similar looks, idle animation from t.
   `hurt` 0..1 white-red flash. Feet at center.y + size*0.5 for ground creatures.
`game/backpack_ui.gd` (Control), `game/battle.gd` (Control), `game/loot_ui.gd`, `game/run.gd`: later phase.

## House rules for every agent
- Edit only the files in your brief. Work in the project folder directly for LOGIC agents (no windows needed:
  use `godot --headless --path . -s game/test_<name>.gd`). ART agents render with a window: ALWAYS add
  `--position -32000,-32000` (window far off-screen; frames are still saved) because the user's screen is in use;
  never run the game normally. See CONTRACT_GARDEN.md for the screenshot recipe (`--write-movie ... --fixed-fps 10`),
  make your own tiny test scene/script under `game/test_*.tscn/.gd` (Read the PNGs! screenshots are ground truth).
- GDScript 4 typing: write `var x: float = ...` where inference from Variant fails (Dictionary/Array reads);
  avoid `:=` on untyped dictionary lookups. Run a headless parse check before finishing: no SCRIPT ERRORs.
- Performance: draw functions must be cheap (UI redraws ~60 fps): keep each item/creature under ~60 draw calls.
- Final report under 90 words: what you built, test results, anything the lead must know.

## More DECISIONS (user, after design discussion)
- THE PLAYER is a FRACTAL BODY THAT MIRRORS THE BUILD: a self-similar, procedurally grown creature whose branches/organs
  are the items in the backpack (blades = spikes, shields = shell plates, heals = blooms, energy = orbiting shards,
  fractal_seed = recursive sprouts). Adjacent (synergising) items visibly resonate (glow links). Moving an item in the
  pack re-grows the body. creature_art kind "player" therefore takes the Backpack contents + the hero's seed form.
- HEROES are SEPARATE CHARACTERS (not hats): each has its own seed form (base fractal shape), passive, and start pack.
  Permanent unlocks. The red hat stays the angel's own symbol.
- ROUTE MAP is a FRACTAL TREE: each fork branches again; branch types (fight, treasure, shop, rest, glyph shrine, dilemma)
  can be shown or hidden as MYSTERY branches; branches CHANGE during the run (sprout a new fork, wither, swap type).
  No fixed run length: the map decides it; the final branch ends at the waterfall boss.
- ORIGINS = starting places (the 3 pictogram answers map to the 3 Limbo variants: eclipse, mirror, cathedral), each with
  different starting items/backpack shape and path-type bias.
- PROGRESSION: items, glyph knowledge (learning the pictogram language), permanent heroes.

## HEROES (user): Hero 1 = SESHAT, Hero 2 = THOTH
- Seshat (goddess of writing, measure, records): seed form = a measuring spiral / star-lattice. Passive idea: adjacency bonuses
  are +1 stronger. Start pack tuned to tight packing.
- Thoth (god of wisdom, magic, writing): seed form = an ibis-curved prism / crescent. Passive idea: learning glyphs pays off
  (identifying an item or translating a glyph grants a small bonus). Start with glyph_lens.
- (Exact passives/start packs are proposals for the lead to finalise with the user.)

## THE GLYPH LEXICON (user): every player gets their own secret translation
- Each save/profile has a random LEXICON SEED (stored in user://meta.cfg). The seed decides which glyph means what, so
  nothing can be looked up online; two players' languages differ.
- A GIGANTIC POOL: glyph shapes are GENERATED procedurally from an integer id (thousands of distinct, good-looking
  pictograms made by combining many "radicals": loops, bars, hooks, spirals, dots, wings, waves, crowned/mirrored variants,
  with consistent stroke style). The 14 hand-drawn glyphs in glyphs.gd are just the first radicals.
- CATEGORIES of meaning, each with its own DETERMINATIVE (a small frame/marker glyph that is the same shape in every
  game and tells the TYPE even before you can read it, like Egyptian determinatives): ITEM, BONUS (stat/effect: damage,
  block, heal, energy, adjacency, ...), LOCATION (route-node types and places: fight, treasure, shop, rest, shrine,
  dilemma, waterfall, ...), ENEMY, HERO, ORIGIN, ACTION/VERB, ELEMENT/QUALITY (fire, still, many, hidden...), plus
  compound words (determinative + root glyph(s), e.g. location + water + high = waterfall).
- Concepts (hundreds) are assigned unique root glyphs by shuffling with the lexicon seed. Names of items, bonuses and map
  nodes are glyph words; numbers stay plain digits so play is never unfair.
- LEARNING: identify an item by using it; shrines/translation events reveal a word; visiting a node reveals its location
  word; a CODEX notebook lets the player pencil in guesses (shown dimmed) and confirms them when proven. Known words
  display in readable English next to (then instead of) the glyphs; learned knowledge persists across runs and gives bonuses.
- API (game/lexicon.gd, class_name Lexicon, static): init(seed), word_for(concept_key: String) -> Array[int] (glyph ids,
  determinative first), draw_word(ci, concept_key, rect, color) via GlyphsLib.draw_gen(ci, glyph_id, c, size, col, w),
  is_known(key), learn(key), guess(key, text) / confirm. GlyphsLib.draw_gen renders any glyph id 0..N-1 procedurally.

## AUDIOVISUAL PILLARS (user emphasis: unique artwork, music, sounds, visuals, cinematics)
- ART: fractal alien identity; every hero, enemy, place and item has its own fractal form and palette; the player's body
  is grown from the pack; no stock look, no downloaded assets.
- MUSIC: FULLY GENERATED IN CODE (decided). Adaptive generative score with distinct themes per place (Limbo hub, garden,
  fights, boss, glyph shrine, route map), layered stems that respond to game state (danger, synergy, learning).
  The player's LEXICON SEED also picks their personal musical mode/motifs, so each profile's game sounds a little different.
  Pre-render stems on a background thread (see layers/audio.gd for the working pattern: bake once into AudioStreamWAV, never
  synthesize per frame on the main thread). Hooks so composed files could replace stems later.
- SOUND: every item has a signature procedural sound; adjacent synergising items ring as a chord; hits, blocks, heals, glyph
  discoveries, map changes, UI all sound-designed (bake into AudioStreamWAV banks).
- CINEMATICS (decided: ALL of these): hero reveal (Seshat / Thoth), boss introductions, first glyph read (revelation
  moment), death and return to Limbo, ending at the waterfall. Build a small reusable CutsceneRunner (timeline of tracks:
  camera moves, layer fades, actor animation, shader uniform tweens, sound cues, letterbox bars, skip with a key).
- VISUALS: shader-driven worlds (as in the garden/limbo), post-processing grade, particles, screen shake/hit-stop, juice.

## MYSTERY PRINCIPLE (user emphasis: the game must feel MYSTERIOUS)
Systems should hide, hint and reward curiosity rather than explain everything:
- SECRET SYNERGIES: some items have hidden synergies/behaviours (def key `secrets`: same shape as `synergies` plus
  `id: String`). They are NOT shown in tooltips or descriptions until they first TRIGGER in play (or are read via a shrine/
  glyph); the first trigger emits `Combat.secret_found(item_id, secret_id)` and is recorded in Meta.discovered_secrets
  (permanent). Tooltips then list discovered secrets; undiscovered items show a faint "…there is more." line when they
  have undiscovered secrets.
- UNKNOWN NAMES: an item's NAME is its glyph word from the Lexicon (the game's secret per-profile language); numbers and
  basic effect text stay always visible (fairness), but the "true name" and extra lore unlock by learning.
- ENEMY SECRETS: each enemy has hidden traits (e.g. splits, reflects, drains block) revealed the first time they happen
  (recorded in Meta.bestiary); intents are always shown as an icon + amount.
- Dilemma texts, enemy names, lore lines: short, cryptic, atmospheric; never explain the world.
- ITEM NAMING: replace the earlier fixed `glyphs: Array[int]` in item definitions by LEXICON lookups:
  `Lexicon.word_for("item:" + id)`. Concept keys look like "item:bone_blade", "bonus:damage", "loc:fight",
  "enemy:spore_sprout", "hero:seshat", "origin:eclipse", "act:use".

## STEP 2 ADDITIONS (art, audio, cinematics)
- Heroes' SEED FORMS: `seshat` = measuring spiral / star-lattice (gold + cyan), `thoth` = ibis-curved prism / crescent (violet + teal).
- creature_art.gd extra API for the player (replaces the simple "player" kind): 
  `CreatureArt.draw_player(ci: CanvasItem, bp, hero_id: String, center: Vector2, size: float, t: float, hurt := 0.0, grow := 1.0)`
  where `bp` is a Backpack (or null for a bare seed). The body = the hero's seed form at the core, plus one self-similar
  branch/organ per placed item (shape/colour by item tags and id: blades=spikes, shields=shell plates, heals=blooms,
  energy=orbiting shards, fractal_seed=recursive sprouts); items that are adjacent (ItemDB/Backpack.neighbors) resonate with glowing
  links. Deterministic from (hero, pack layout); `grow` 0..1 scales growth for tween-in. Also `CreatureArt.pack_signature(bp) -> int`
  so callers know when to re-bake/regrow.
- Audio (all generated in code, baked into AudioStreamWAV on a worker thread, never per-frame synthesis; follow layers/audio.gd):
  `game/sfx.gd` (class_name Sfx, Node): `Sfx.install(parent: Node, lexicon_seed: int)`; `play(name: String)` for names: ui_click, ui_hover,
  place_item, rotate_item, invalid, hit_enemy, hit_player, block, heal, energy, end_turn, win, lose, glyph_learn, secret_found,
  path_change; `play_item(item_id: String)` = every item has its OWN signature sound (derived from the id and its tags so blades ring metallic,
  shields thud with lapis chime, heals bloom, etc.); `play_synergy(count: int)` = chord that grows with adjacent links.
  `game/music.gd` (class_name Music, Node): `Music.install(parent, lexicon_seed)`; `set_theme(name)` for themes limbo, garden, map, battle, boss, shrine
  (crossfade ~2 s); `set_tension(v: float 0..1)` fades stem layers; the lexicon seed picks the player's mode/motif so every profile sounds different;
  loopable bars baked at install on a thread; ambient, mystical, melodic and NOT random-sounding (motif memory, weighted scale-degree walks, slow pads, sparse bell/chime).
- Cinematics: `game/cutscene.gd` (class_name Cutscene, Node): a code-built timeline runner: `Cutscene.new()` then chain
  `at(t, callable)`, `tween(obj, prop, to, dur, delay)`, `shader(material, param, to, dur, delay)`, `sound(name, delay)`, `letterbox(show, dur)`,
  `shake(amount, dur)`, `wait(dur)`; `play()` is awaitable, emits `finished`; `skip()` jumps to the end by fast-forwarding tweens
  (`Tween.custom_step(9999)`, never `kill()` while awaiting); skip with any key if `skippable`.

## AUDIO THEORY DIRECTIVE (user: "use math and music theory for the sounds and rhythms")
Sound and rhythm are built from real math and music theory, which also fits the fractal/mysterious identity:
- TUNING: just intonation / ratio-based scales (e.g. 1:1, 9:8, 5:4, 4:3, 3:2, 5:3, 15:8) or per-profile tunings derived from the lexicon seed;
  synergy chords = small-integer harmonic ratios (stacked 3:2 and 5:4 fifths/thirds); dissonance (tritone 45:32, minor 2nds) reserved for danger/boss.
- HARMONY: modal progressions and proper VOICE LEADING (smooth common-tone motion), chord tones on strong beats, cadences that resolve
  (and deliberately unresolved/suspended endings for mystery); pads are stacked partials; bell timbres use inharmonic partials (e.g. 1, 2.76, 5.4).
- RHYTHM: Euclidean rhythms E(k,n) (e.g. E(3,8), E(5,8), E(7,12)), polyrhythms (3:2, 4:3), swing from golden-ratio offsets,
  Fibonacci/golden-ratio phrase lengths (3,5,8,13 bars/beats), tempo/meter per theme; fractal/self-similar melodies via L-systems
  (a motif that contains scaled copies of itself), with item/synergy count mapped to rhythmic density.
- SOUNDS: envelopes, FM/additive synthesis with ratio-locked carriers/modulators, harmonic series for item voices (id -> partial set).

## STEP 3 UI/FLOW APIs (agents build in parallel against these; step-2 art may land later: guard with `ClassDB`-free fallbacks, i.e. wrap calls in
## `if ItemIcons != null`-style checks via a tiny helper that draws a coloured rounded rect when the class is missing)
All screens are Controls drawn over the LOCKED garden background (garden.tscn after intro; ground line y = 0.80 of the screen), design size 960x640,
ink-black glassy panels with gold rims (see bubble.gd/choice.gd), glyph names via Lexicon + GlyphGen (word_for -> draw determinative + roots), numbers always plain.
- game/backpack_ui.gd `class_name BackpackUI` (Control): `setup(bp: Backpack, mode: String)` modes "arrange" | "combat" | "view"; `refresh()`;
  `hold(item_id: String)` carry a NEW item with a ghost preview (green/red validity, snap, R or right-click rotates, left-click places, Esc cancels);
  drag existing items in arrange mode; signals `item_clicked(uid)`, `item_hovered(uid)`, `placed(uid)`, `hold_finished(placed: bool)`;
  combat mode: clicking an affordable item emits `item_clicked`; props `energy:int`, `used:Array` set by caller to dim items; live synergy links glow between
  adjacent items; built-in tooltip using `Backpack.describe(uid)` + glyph name; item icons via ItemIcons.draw (fallback rect), cached/baked, only hovered redraw live.
- game/battle.gd `class_name Battle` (Control): `start(bp: Backpack, enemy_ids: Array, player_state: Dictionary, hero_id: String, rng: RandomNumberGenerator)`;
  signal `finished(won: bool, player_state: Dictionary)`. Shows player (CreatureArt.draw_player) left on the ground line, enemies right with HP bars + intent icons,
  BackpackUI in combat mode at the bottom, energy pips, End Turn button, floating damage numbers, hit-stop/shake juice, Sfx calls guarded with has_method.
- game/route_map.gd `class_name RouteMap` (Control): `generate(seed: int, origin_id: String, hero_id: String)`; a FRACTAL TREE: nodes
  {id:int, type:String ("fight","elite","treasure","shop","rest","shrine","dilemma","mystery","boss"), depth:int, children:Array, revealed:bool, state:"open"|"withered"|"done"|"current"};
  `reveal_choices()`; `mutate(mode: String)` modes wither|sprout|swap|reveal|hide (only unseen sub-branches change); signal `node_chosen(node: Dictionary)`;
  per-system seeded RNGs; STS-like structure (fixed early fight row, mid treasure, rest before boss, "?" nodes self-balancing, Dilemmas as rare "?" outcomes);
  node types shown as glyph words (Lexicon "loc:<type>") with a readable label once known; beautiful glowing branching-tree drawing with growth animation.
- game/run.gd `class_name Run` (Control) = the flow brain: `begin(hero_id, origin_id)`; map -> node resolution (fight=Battle, treasure/loot=LootUI+BackpackUI.hold,
  shop, rest=heal, shrine=ShrineUI (learn a glyph), dilemma=DilemmaUI, boss=Battle with EnemyDB.BOSS_ID, mystery=random); updates Meta (record_run, secrets via
  Meta.on_secret_discovered, bestiary, known words), signal `run_ended(won: bool, depth: int)`; starting packs per hero/origin.
- game/screens.gd: `LootUI` (show_offers(ids: Array) -> signal chosen(id)), `DilemmaUI` (show(d: Dictionary) -> signal chosen(index: int)), `ShrineUI`
  (offer to learn one glyph word, signal done), `HeroSelectUI` (pick Seshat/Thoth + origin by glyph names, signal picked(hero_id, origin_id)); each a class_name in its
  own file under game/ (loot_ui.gd, dilemma_ui.gd, shrine_ui.gd, hero_select_ui.gd).

## TESTING RULE (a popup alert once appeared on the user's screen)
NEVER run a game/test_*.gd that does not `extends SceneTree` with `-s` (e.g. test_creatures.gd, test_icons.gd, *_view.gd): Godot shows a modal
"Can't load the script ... doesn't inherit from SceneTree" ALERT dialog on the user's screen even with --headless. Use ./run_tests.sh
(runs only the SceneTree tests; test_e2e.gd separately) or run scenes with their .tscn off-screen (--position -32000,-32000).
