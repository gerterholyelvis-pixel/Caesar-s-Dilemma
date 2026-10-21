# Garden contract (read before editing)

Godot 4.7, Forward+, 960x640 design space, no HDR bloom (fake glow in-shader). The scene is
`garden.tscn -> garden.gd` (OWNED BY THE LEAD, do not edit it). It stacks layers back to front:

| # | file | kind | parallax `par` | what |
|---|------|------|----------------|------|
| 1 | garden_sky.gdshader    | OPAQUE  | 0.06 | sky, far atmosphere, very distant shapes |
| 2 | garden_mid.gdshader    | ALPHA   | 0.30 | mid-distance fractal flora / formations |
| 3 | garden_falls.gdshader  | ALPHA   | 0.50 | the HERO WATERFALL, its cliffs, pool and mist |
| 4 | garden_ground.gdshader | ALPHA   | 1.00 | the walkable ground band, path, near water edge |
| 5 | garden_fx.gd           | Node2D  | -    | calm spores/motes (lead owns) |
| 6 | garden_fg.gdshader     | ALPHA   | 1.50 | sparse near foreground silhouettes framing the edges |
| 7 | title.gd               | Control | -    | the title "Caesar's Dilemma" (own file) |

Every shader layer has these uniforms (set by garden.gd; copy them verbatim):
    uniform float aspect = 1.5;   // width / height
    uniform vec2  look = vec2(0); // tiny mouse parallax, about +-0.03; ZERO once the camera is locked
    uniform float cam = 0.0;      // camera progress 0..1 over the ~5 s fly-through (ease in/out)
    uniform float span = 3.0;     // SPAN
    uniform float par = 1.0;      // this layer's parallax factor (table above)
and TIME. Alpha layers output normal (non-premultiplied) alpha; COLOR.a = 0 where empty.

## Shared coordinates (all layers must agree)
Everything is measured in SCREEN HEIGHTS: y = UV.y (0 top, 1 bottom), x = (UV.x - 0.5) * aspect
(so x = 0 is screen centre; at 16:9, the screen spans x in about [-0.89, 0.89]).
A layer's world x is:
    float X = (UV.x - 0.5) * aspect + cam * span * par - look.x * (0.4 + par);
    float Y = UV.y - look.y * (0.3 + 0.5 * par);
The camera travels RIGHT through the world: content moves LEFT on screen as cam goes 0 -> 1.
At cam = 1 the camera is parked at the end of the journey and stays there for the whole game.

## The place
An ALIEN, FRACTAL botanical world, NOT Babylon or anything biblical (no ziggurats, no arches/gates,
no palms, no Middle-Eastern motifs). Think: giant recursive-branching crystalline trees, fractal ferns
and spiral fronds, Julia/Mandelbrot-style filigree in sky and flora, glowing spore blooms, terraced
glassy pools, bioluminescent rim light. Palette: deep teal and emerald, cool violet and magenta,
gold/amber highlights, cyan glow, with pale mist; harmonious and restrained, with plenty of calm
negative space (the previous version was rejected as "too much going on"). Higher quality: smooth
gradients, dithering, atmospheric perspective (far = hazier, bluer, lower contrast), soft rim lights.
No text, no characters in the scene layers.

## The journey (cam 0 -> 1) and the destination
cam = 0: we begin in a quiet fractal glade. The camera glides right past tall fractal flora; the
valley opens and the sound-of-water feel builds; at cam = 1 a huge, beautiful WATERFALL fills the
centre-right of the screen (cascading from a high cliff/lip at the top into a luminous pool), with
mist, and the garden's glow around it. The falls layer (par 0.5) must be positioned so its centre
sits at screen x about +0.15 .. +0.25 when cam = 1, i.e. its WORLD X (in that layer's coordinates)
is about  0.20 + 1.0 * span * 0.5 = 1.70. At cam = 0 it must be off-screen to the right (world X 1.70
vs screen edge ~0.9: fine automatically).

## Ground / gameplay band (IMPORTANT, mechanics come next)
Characters will stand on a line at y = 0.80. The ground layer draws the walkable surface from about
y = 0.76 (its far lip) to the bottom: calm, readable, low-contrast detail so small dark characters
read clearly. Keep the band x in [-0.5, 0.5], y in [0.55, 0.80] (where the player stands and the
dialogue sits) free of busy detail and bright hot spots in ALL layers; put hero details elsewhere.

## Rules
- Edit ONLY your own file(s) (listed in your brief). Copy the project to your own lab to test:
  cp -r PROJECT PROJECT/../lab_NAME, edit lab_NAME files, and at the end copy your own final file(s)
  into PROJECT/. Other agents are working on the other layers simultaneously, so the lab copy has
  only stubs for them; judge your own layer in isolation but match the shared look/coordinates.
- Performance: at 1920x1080, <= ~1.5 ms per shader layer (sky/mid/falls/ground/fg combined must stay
  under ~7 ms). Small loops (<= ~20 heavy iterations). NEVER use smoothstep(edge0, edge1, x) with
  edge0 >= edge1 (undefined in GLSL -> NaN/black artifacts). Use Hoskins-style hashes
  (fract(vec3(p.xyx) * 0.1031) form) rather than sin-based hashes for large coordinates.
- No downloaded assets; procedural only. Tone-mapped, dithered, no banding, no black borders.
- How to see your layer (screenshots are the only ground truth; actually Read the PNGs):
    G="C:/Users/gerte/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64.exe"
    mkdir -p ../shots_NAME_a
    "$G" --path . res://garden.tscn --position -32000,-32000 --quit-after 40 --write-movie ../shots_NAME_a/f.png --fixed-fps 10 -- --cam=0.0
  `-- --cam=X` freezes the camera at progress X (use 0.0, 0.5 and 1.0 to check the whole journey and the
  parallax; `-- --title` freezes at 1.0 and shows the title). The scene fades in from warm white for
  the first 1.8 s (frames 0-17), so Read frames >= 25. Use a fresh shots dir name per run (Remove-Item
  on shot dirs is blocked). Windows flash briefly; that's expected. GPU timings printed at the end are
  noisy because other agents render too. Iterate at least 4 look -> critique -> improve cycles.

## Title timing
The title is on screen for ABOUT 3 SECONDS TOTAL: title.play() pops it in within ~0.5 s (fully readable by 0.5 s), garden.gd calls title.fade_out() 2.6 s after play(), and the fade must take ~0.45 s (so it is gone ~3.0 s after play()). Do not extend these times.

## NEVER show a window on the user's screen
The user's screen is in use. EVERY Godot command you run that opens a window MUST include  --position -32000,-32000  so the window is placed far off-screen (frames are still rendered and saved to the PNGs). Verified: this still writes the movie frames. Do not run the game any other way, and do not launch it normally. (--headless is fine for pure script-error checks since it opens no window, but it renders nothing.)
