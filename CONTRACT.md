# Layer contract (read before editing)

Design space 960x640. Godot 4.7, Forward+, `use_hdr_2d = true`, WorldEnvironment glow (start_screen.gd).
Scene is composed by `start_screen.gd` (OWNED BY THE LEAD - do not edit it; ask via your report).

Draw order, back to front:
1. layers/sky_back.gdshader     opaque gradient sky
2. layers/celestial.gdshader    additive: stars, moon
3. layers/clouds_high.gdshader  alpha: cirrus in the sky
4. layers/clouds.gdshader       alpha: raymarched cloud deck below horizon
5. sigil.gd (Node2D)            glowing rune sigil, radius 190 at scale 1, modulate is >1 for bloom
6. layers/sigil_fx.gd (Node2D)  effects around the sigil, same transform as the sigil
7. layers/ambient_fx.gd (Node2D) screen-space particles/ambience
8. layers/post.gdshader         full-screen post (reads hint_screen_texture)
9. layers/start_button.gd       the Start Button (the ONLY text in the game: "Start")
   layers/audio.gd              Node, synthesized sound

Shared camera model used by every sky/cloud shader (keep identical so layers line up):
    uniforms: float aspect; vec2 look;   (set by start_screen.gd each frame)
    vec2 p = (UV - 0.5) * vec2(aspect, 1.0) - look;
    vec3 rd = normalize(vec3(p.x, -p.y - 0.10, 0.95));
    const vec3 MOON_DIR = vec3(-0.38, 0.42, 0.82);  const float TOP=-1.0, BOT=-3.2;
Horizon is at rd.y = 0, i.e. UV.y = 0.40. Camera sits at y=0, cloud deck is a slab y in [BOT, TOP].
Sigil center is at about UV (0.5, 0.40) so it straddles the horizon.

Rules:
- Edit ONLY your own file(s). You may create new files under layers/ prefixed with your layer name.
- Never use smoothstep(edge0, edge1) with edge0 >= edge1 (undefined in GLSL -> NaN/black/red artifacts).
- Everything in HDR must stay sane: bloom threshold is 1.0, so only intentional glints exceed 1.
- Performance budget: whole scene must stay under ~8 ms GPU/frame on an RTX 4060 laptop at 960x640.
  Your share: sky/celestial/clouds_high ~1ms each, clouds ~3ms, everything else ~0.5ms.
- No downloaded assets. Procedural only.
- No text anywhere except the button's "Start".

Testing your layer (this is how to SEE it; screenshots are the only ground truth):
  G="C:/Users/gerte/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64.exe"
  mkdir -p ../shots_<yourname>
  "$G" --path . --quit-after 150 --write-movie ../shots_<yourname>/f.png --fixed-fps 30
  then Read ../shots_<yourname>/f00000119.png  (PNG frame; look at it!). Output line "GPU render time"
  gives avg ms/frame. Check for shader/script errors in the output. Do NOT use Remove-Item on shots dirs.
Iterate at least 3 times: look, critique honestly vs. real photographs, improve.
