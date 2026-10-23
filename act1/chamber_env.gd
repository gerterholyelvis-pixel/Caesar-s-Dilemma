extends RefCounted
## Act 1 chamber: procedural PBR textures, materials, particles, environment and audio baking.
## Texture/audio bakes are pure-data (Images / AudioStreamWAV) and safe to run on a worker Thread.

static var _glow: Texture2D = null

# ---------------------------------------------------------------- noise helpers
static func _noise_bytes(seed_v: int, freq: float, octaves: int, size: int, cellular: bool = false) -> PackedByteArray:
	var n := FastNoiseLite.new()
	n.seed = seed_v
	n.frequency = freq
	if cellular:
		n.noise_type = FastNoiseLite.TYPE_CELLULAR
		n.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
		n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
		n.fractal_type = FastNoiseLite.FRACTAL_NONE
		n.domain_warp_enabled = true
		n.domain_warp_amplitude = 40.0
		n.domain_warp_frequency = 0.02
	else:
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.fractal_type = FastNoiseLite.FRACTAL_FBM
		n.fractal_octaves = octaves
	var img: Image = n.get_seamless_image(size, size)
	if img.get_format() != Image.FORMAT_L8:
		img.convert(Image.FORMAT_L8)
	return img.get_data()

static func _finish(alb: PackedByteArray, hgt: PackedByteArray, rgh: PackedByteArray, emi: PackedByteArray, w: int, h: int, bump: float) -> Dictionary:
	var out := {}
	var ia := Image.create_from_data(w, h, false, Image.FORMAT_RGB8, alb)
	var ih := Image.create_from_data(w, h, false, Image.FORMAT_L8, hgt)
	var ir := Image.create_from_data(w, h, false, Image.FORMAT_L8, rgh)
	ih.bump_map_to_normal_map(bump)
	ia.generate_mipmaps()
	ih.generate_mipmaps(true)
	ir.generate_mipmaps()
	out["albedo"] = ia
	out["normal"] = ih
	out["rough"] = ir
	if emi.size() > 0:
		var ie := Image.create_from_data(w, h, false, Image.FORMAT_RGB8, emi)
		ie.generate_mipmaps()
		out["emit"] = ie
	return out

# ---------------------------------------------------------------- stone (masonry / flagstone)
static func bake_stone(S: int, rows: int, nb: int, seed_v: int, floor_mode: bool) -> Dictionary:
	var n_big := _noise_bytes(seed_v + 1, 0.006, 4, S)
	var n_mid := _noise_bytes(seed_v + 2, 0.02, 4, S)
	var n_fine := _noise_bytes(seed_v + 3, 0.09, 3, S)
	var n_edge := _noise_bytes(seed_v + 4, 0.05, 3, S)
	var n_moss := _noise_bytes(seed_v + 5, 0.012, 4, S)
	var n_crack := _noise_bytes(seed_v + 6, 0.012, 1, S, true)
	var n_gate := _noise_bytes(seed_v + 7, 0.008, 3, S)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var row_h: int = S / rows
	var bounds: Array = []
	var offs := PackedInt32Array()
	var tints := PackedFloat32Array()
	for r in rows:
		var b := PackedFloat32Array()
		for i in nb:
			var j: float = 0.0 if i == 0 else rng.randf_range(-0.3, 0.3)
			b.append((float(i) + j) * float(S) / float(nb))
			tints.append(rng.randf_range(0.7, 1.25))
		bounds.append(b)
		offs.append(rng.randi_range(0, S - 1))
	var mort_w: float = 4.0 if floor_mode else 6.0
	var bev_w: float = 14.0 if floor_mode else 22.0
	var base_r: float = 0.15 if floor_mode else 0.18
	var base_g: float = 0.14 if floor_mode else 0.165
	var base_b: float = 0.14 if floor_mode else 0.16
	var alb := PackedByteArray(); alb.resize(S * S * 3)
	var emi := PackedByteArray(); emi.resize(S * S * 3)
	var hgt := PackedByteArray(); hgt.resize(S * S)
	var rgh := PackedByteArray(); rgh.resize(S * S)
	for y in S:
		var r: int = y / row_h
		var ly: int = y - r * row_h
		var dy: float = float(mini(ly, row_h - 1 - ly))
		var b: PackedFloat32Array = bounds[r]
		var off: int = offs[r]
		for x in S:
			var i: int = y * S + x
			var g: float = float(n_big[i]) / 255.0
			var md: float = float(n_mid[i]) / 255.0
			var fn: float = float(n_fine[i]) / 255.0
			var ne: float = float(n_edge[i]) / 255.0
			var mo: float = float(n_moss[i]) / 255.0
			var xr: int = posmod(x - off, S)
			var dx: float = minf(float(xr), float(S - xr))
			var bid: int = 0
			for k in nb:
				var dk: float = absf(float(xr) - b[k])
				if dk < dx:
					dx = dk
				if b[k] <= float(xr):
					bid = k
			var e: float = minf(dx, dy) + (ne - 0.5) * 20.0 + (fn - 0.5) * 6.0
			var bev: float = smoothstep(mort_w, mort_w + bev_w, e)
			var mort: float = 1.0 - smoothstep(mort_w - 2.0, mort_w + 3.0, e)
			var tint: float = tints[r * nb + bid]
			var v: float = (0.5 + 0.9 * g) * tint * (0.85 + 0.3 * fn)
			var cr: float = base_r * v + (md - 0.5) * 0.03
			var cg: float = base_g * v
			var cb: float = base_b * v * 1.04
			# moss + ash
			var ms: float = smoothstep(0.66, 0.8, mo) * bev
			var mc: float = 0.6 + fn
			cr = lerpf(cr, 0.07 * mc, ms * 0.7)
			cg = lerpf(cg, 0.12 * mc, ms * 0.7)
			cb = lerpf(cb, 0.06 * mc, ms * 0.7)
			var ash: float = smoothstep(0.72, 0.92, md) * 0.28
			cr = lerpf(cr, 0.34, ash); cg = lerpf(cg, 0.33, ash); cb = lerpf(cb, 0.32, ash)
			# cavity grime + mortar
			var cav: float = lerpf(0.5, 1.0, smoothstep(mort_w, mort_w + 34.0, e))
			cr *= cav; cg *= cav; cb *= cav
			var mm: float = 0.7 + fn * 0.6
			cr = lerpf(cr, 0.07 * mm, mort); cg = lerpf(cg, 0.062 * mm, mort); cb = lerpf(cb, 0.06 * mm, mort)
			# cracks with ember glow
			var cc: float = float(n_crack[i]) / 255.0
			var gate: float = smoothstep(0.68, 0.82, float(n_gate[i]) / 255.0)
			var ck: float = (1.0 - smoothstep(0.0, 0.045, cc)) * gate
			var cd: float = 1.0 - 0.75 * ck
			cr *= cd; cg *= cd; cb *= cd
			var em: float = ck * (0.45 + 0.55 * fn)
			# roughness / height
			var rr: float = 0.84 + 0.12 * (fn - 0.5)
			if floor_mode:
				rr = 0.72 + 0.14 * (fn - 0.5)
			rr = lerpf(rr, 0.96, mort)
			rr = lerpf(rr, 0.42, smoothstep(0.74, 0.9, md) * 0.55 * bev)
			var hs: float = 0.5 + (md - 0.5) * 0.35 + (fn - 0.5) * 0.3
			var h: float = bev * hs - ck * 0.35
			if floor_mode:
				var pd: float = 1.0 - smoothstep(0.27, 0.35, g)
				rr = lerpf(rr, 0.035, pd)
				h = lerpf(h, 0.3, pd)
				var pk: float = lerpf(1.0, 0.5, pd)
				cr *= pk; cg *= pk; cb *= pk
			alb[i * 3] = int(clampf(cr, 0.0, 1.0) * 255.0)
			alb[i * 3 + 1] = int(clampf(cg, 0.0, 1.0) * 255.0)
			alb[i * 3 + 2] = int(clampf(cb, 0.0, 1.0) * 255.0)
			emi[i * 3] = int(clampf(em, 0.0, 1.0) * 255.0)
			emi[i * 3 + 1] = int(clampf(em * 0.38, 0.0, 1.0) * 255.0)
			emi[i * 3 + 2] = int(clampf(em * 0.06, 0.0, 1.0) * 255.0)
			hgt[i] = int(clampf(h, 0.0, 1.0) * 255.0)
			rgh[i] = int(clampf(rr, 0.0, 1.0) * 255.0)
	return _finish(alb, hgt, rgh, emi, S, S, 7.0)

# ---------------------------------------------------------------- wood planks
static func bake_wood(S: int) -> Dictionary:
	var n1 := _noise_bytes(31, 0.03, 4, S)
	var n2 := _noise_bytes(32, 0.12, 3, S)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var planks: int = 4
	var pw: int = S / planks
	var ptint := PackedFloat32Array()
	for p in planks:
		ptint.append(rng.randf_range(0.7, 1.2))
	var alb := PackedByteArray(); alb.resize(S * S * 3)
	var hgt := PackedByteArray(); hgt.resize(S * S)
	var rgh := PackedByteArray(); rgh.resize(S * S)
	for y in S:
		var pos: float = float(y) * 19.0 / float(S)
		var ya: int = int(pos)
		var fr: float = pos - float(ya)
		for x in S:
			var i: int = y * S + x
			var p: int = x / pw
			var px: int = x - p * pw
			var ra: int = ((ya + p * 5) % 19) * 13 % S
			var rb: int = (((ya + 1) + p * 5) % 19) * 13 % S
			var ga: float = lerpf(float(n1[ra * S + x]), float(n1[rb * S + x]), fr) / 255.0
			var fn: float = float(n2[i]) / 255.0
			var seam: float = 1.0 - smoothstep(1.0, 5.0, float(mini(px, pw - 1 - px)))
			var wv: float = (0.45 + 1.1 * ga) * ptint[p] * (0.9 + 0.2 * fn)
			var cr: float = 0.17 * wv
			var cg: float = 0.105 * wv
			var cb: float = 0.06 * wv
			var k: float = 1.0 - 0.8 * seam
			alb[i * 3] = int(clampf(cr * k, 0.0, 1.0) * 255.0)
			alb[i * 3 + 1] = int(clampf(cg * k, 0.0, 1.0) * 255.0)
			alb[i * 3 + 2] = int(clampf(cb * k, 0.0, 1.0) * 255.0)
			hgt[i] = int(clampf((0.35 + 0.45 * ga + 0.2 * fn) * (1.0 - seam), 0.0, 1.0) * 255.0)
			rgh[i] = int(clampf(0.72 + 0.2 * fn, 0.0, 1.0) * 255.0)
	return _finish(alb, hgt, rgh, PackedByteArray(), S, S, 4.0)

# ---------------------------------------------------------------- rune frieze
static func _stroke(mask: PackedByteArray, w: int, h: int, a: Vector2, b: Vector2, r: float) -> void:
	var steps: int = int(a.distance_to(b) * 1.5) + 1
	for s in steps + 1:
		var p: Vector2 = a.lerp(b, float(s) / float(steps))
		var x0: int = maxi(0, int(p.x - r - 1.0))
		var x1: int = mini(w - 1, int(p.x + r + 1.0))
		var y0: int = maxi(0, int(p.y - r - 1.0))
		var y1: int = mini(h - 1, int(p.y + r + 1.0))
		for yy in range(y0, y1 + 1):
			for xx in range(x0, x1 + 1):
				var d: float = Vector2(float(xx), float(yy)).distance_to(p)
				if d <= r + 0.7:
					var v: int = 255 if d <= r - 0.3 else 150
					if v > mask[yy * w + xx]:
						mask[yy * w + xx] = v

static func bake_frieze() -> Dictionary:
	var W: int = 1024
	var H: int = 64
	var mask := PackedByteArray(); mask.resize(W * H)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	_stroke(mask, W, H, Vector2(0, 6), Vector2(W, 6), 1.6)
	_stroke(mask, W, H, Vector2(0, 57), Vector2(W, 57), 1.6)
	for c in 16:
		var cx: float = c * 64.0 + 32.0
		var top: float = 16.0 + rng.randf_range(0, 4)
		var bot: float = 48.0 - rng.randf_range(0, 4)
		_stroke(mask, W, H, Vector2(cx, top), Vector2(cx, bot), 1.9)
		var nbr: int = rng.randi_range(2, 4)
		for k in nbr:
			var py: float = rng.randf_range(top, bot)
			var sx: float = -1.0 if rng.randf() < 0.5 else 1.0
			var ex: float = cx + sx * rng.randf_range(8, 17)
			var ey: float = py + rng.randf_range(-12, 12)
			_stroke(mask, W, H, Vector2(cx, py), Vector2(ex, clampf(ey, 12.0, 52.0)), 1.7)
		if rng.randf() < 0.45:
			var cy: float = rng.randf_range(top + 4, bot - 4)
			for a in 14:
				var a0: float = TAU * a / 14.0
				var a1: float = TAU * (a + 1) / 14.0
				_stroke(mask, W, H, Vector2(cx, cy) + Vector2(cos(a0), sin(a0)) * 6.0, Vector2(cx, cy) + Vector2(cos(a1), sin(a1)) * 6.0, 1.4)
	var n := _noise_bytes(91, 0.05, 3, 512)
	var alb := PackedByteArray(); alb.resize(W * H * 3)
	var emi := PackedByteArray(); emi.resize(W * H * 3)
	var hgt := PackedByteArray(); hgt.resize(W * H)
	var rgh := PackedByteArray(); rgh.resize(W * H)
	for y in H:
		for x in W:
			var i: int = y * W + x
			var m: float = float(mask[i]) / 255.0
			var nv: float = float(n[(y * 7 % 512) * 512 + (x % 512)]) / 255.0
			var v: float = (0.7 + 0.6 * nv) * lerpf(1.0, 0.35, m)
			alb[i * 3] = int(clampf(0.12 * v, 0, 1) * 255.0)
			alb[i * 3 + 1] = int(clampf(0.108 * v, 0, 1) * 255.0)
			alb[i * 3 + 2] = int(clampf(0.105 * v, 0, 1) * 255.0)
			emi[i * 3] = int(m * 255.0)
			emi[i * 3 + 1] = int(m * 0.36 * 255.0)
			emi[i * 3 + 2] = int(m * 0.05 * 255.0)
			hgt[i] = int(clampf(0.75 - m * 0.55 + (nv - 0.5) * 0.15, 0, 1) * 255.0)
			rgh[i] = int(clampf(0.85 - m * 0.1, 0, 1) * 255.0)
	return _finish(alb, hgt, rgh, emi, W, H, 6.0)

## Circular sigil, white strokes on transparent (use additive/unshaded, tint via albedo_color).
static func bake_sigil() -> Image:
	var S: int = 256
	var data := PackedByteArray(); data.resize(S * S * 4)
	var c := Vector2(S * 0.5, S * 0.5)
	for y in S:
		for x in S:
			var p := Vector2(float(x), float(y)) - c
			var r: float = p.length()
			var ang: float = atan2(p.y, p.x)
			var v: float = 0.0
			for rr in [118.0, 110.0, 70.0, 40.0]:
				var d: float = (r - rr) / 1.8
				v = maxf(v, exp(-d * d))
			# spokes between r=70 and r=110
			var sp: float = fposmod(ang, TAU / 12.0)
			var sd: float = minf(sp, TAU / 12.0 - sp) * r / 1.8
			if r > 70.0 and r < 110.0:
				v = maxf(v, exp(-sd * sd))
			# eye: lens outline + pupil
			var arc_y: float = 16.0 * (1.0 - (p.x / 38.0) * (p.x / 38.0))
			if absf(p.x) < 38.0:
				var d2: float = (absf(p.y) - arc_y) / 1.8
				v = maxf(v, exp(-d2 * d2))
			v = maxf(v, exp(-pow(r / 7.0, 4.0)))
			var a: int = int(clampf(v, 0.0, 1.0) * 255.0)
			var i: int = (y * S + x) * 4
			data[i] = 255; data[i + 1] = 255; data[i + 2] = 255; data[i + 3] = a
	var img := Image.create_from_data(S, S, false, Image.FORMAT_RGBA8, data)
	img.generate_mipmaps()
	return img

static func bake_textures() -> Dictionary:
	var d := {}
	d["wall"] = bake_stone(512, 4, 2, 100, false)
	d["floor"] = bake_stone(512, 4, 3, 200, true)
	d["wood"] = bake_wood(256)
	d["frieze"] = bake_frieze()
	d["sigil"] = bake_sigil()
	return d

# ---------------------------------------------------------------- materials (main thread)
static func _tex(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(img)

static func stone_mat(d: Dictionary, uv_scale: float, tint: Color = Color(1, 1, 1), emit_energy: float = 0.9, normal_scale: float = 1.3) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = _tex(d["albedo"])
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = _tex(d["normal"])
	m.normal_scale = normal_scale
	m.roughness = 1.0
	m.roughness_texture = _tex(d["rough"])
	m.metallic_specular = 0.5
	if d.has("emit") and emit_energy > 0.0:
		var g := StandardMaterial3D.new()
		g.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		g.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		g.albedo_texture = _tex(d["emit"])
		g.albedo_color = Color(emit_energy, emit_energy, emit_energy, 1.0)
		g.uv1_triplanar = true
		g.uv1_world_triplanar = true
		g.uv1_triplanar_sharpness = 6.0
		g.uv1_scale = Vector3(uv_scale, uv_scale, uv_scale)
		g.disable_receive_shadows = true
		g.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		m.next_pass = g
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_triplanar_sharpness = 6.0
	m.uv1_scale = Vector3(uv_scale, uv_scale, uv_scale)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

static func metal_mat(col: Color, rough: float, metallic: float = 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = metallic
	m.roughness = rough
	return m

static func glow_tex() -> Texture2D:
	if _glow != null:
		return _glow
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	_glow = t
	return t

static func additive_mat(tex: Texture2D, col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = tex
	m.albedo_color = col
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	return m

# ---------------------------------------------------------------- particles
static func _particle_mat(billboard: bool, shaded: bool, col_mult: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	if not shaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = glow_tex()
	m.albedo_color = col_mult
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.billboard_keep_scale = true
	m.disable_receive_shadows = true
	return m

static func _ramp(cols: PackedColorArray, offs: PackedFloat32Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.colors = cols
	g.offsets = offs
	var t := GradientTexture1D.new()
	t.gradient = g
	return t

static func fire(s: float = 1.0) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 26
	p.lifetime = 0.95
	p.preprocess = 1.0
	p.visibility_aabb = AABB(Vector3(-1.5, -0.5, -1.5), Vector3(3, 4, 3))
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.09 * s
	m.direction = Vector3(0, 1, 0)
	m.spread = 10.0
	m.initial_velocity_min = 0.35 * s
	m.initial_velocity_max = 0.75 * s
	m.gravity = Vector3(0, 0.5, 0)
	m.scale_min = 0.6
	m.scale_max = 1.1
	var c := Curve.new()
	c.add_point(Vector2(0, 0.55)); c.add_point(Vector2(0.25, 1.0)); c.add_point(Vector2(1, 0.08))
	var ct := CurveTexture.new(); ct.curve = c
	m.scale_curve = ct
	m.color_ramp = _ramp(PackedColorArray([Color(3.2, 2.4, 1.2, 0.0), Color(2.8, 1.3, 0.4, 0.85), Color(1.3, 0.34, 0.06, 0.55), Color(0.25, 0.04, 0.0, 0.0)]), PackedFloat32Array([0.0, 0.12, 0.6, 1.0]))
	p.process_material = m
	var q := QuadMesh.new()
	q.size = Vector2(0.3, 0.3) * s
	q.material = _particle_mat(true, false, Color(1, 1, 1, 1))
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p

static func embers(s: float = 1.0) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 16
	p.lifetime = 3.2
	p.preprocess = 3.0
	p.visibility_aabb = AABB(Vector3(-3, -0.5, -3), Vector3(6, 6, 6))
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.12 * s
	m.direction = Vector3(0, 1, 0)
	m.spread = 28.0
	m.initial_velocity_min = 0.4
	m.initial_velocity_max = 1.1
	m.gravity = Vector3(0, 0.15, 0)
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 0.6
	m.turbulence_noise_scale = 1.5
	m.scale_min = 0.5
	m.scale_max = 1.0
	m.color_ramp = _ramp(PackedColorArray([Color(3, 1.6, 0.5, 1), Color(2.2, 0.6, 0.12, 0.9), Color(0.6, 0.1, 0.0, 0.0)]), PackedFloat32Array([0.0, 0.5, 1.0]))
	p.process_material = m
	var q := QuadMesh.new()
	q.size = Vector2(0.03, 0.03)
	q.material = _particle_mat(true, false, Color(1, 1, 1, 1))
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p

static func dust(extent: Vector3, amount: int) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = 16.0
	p.preprocess = 16.0
	p.visibility_aabb = AABB(-extent, extent * 2.0)
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = extent
	m.direction = Vector3(0, -1, 0)
	m.spread = 180.0
	m.initial_velocity_min = 0.01
	m.initial_velocity_max = 0.06
	m.gravity = Vector3(0, -0.012, 0)
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 0.12
	m.turbulence_noise_scale = 2.5
	m.scale_min = 0.5
	m.scale_max = 1.3
	m.color_ramp = _ramp(PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)]), PackedFloat32Array([0.0, 0.15, 0.85, 1.0]))
	p.process_material = m
	var q := QuadMesh.new()
	q.size = Vector2(0.014, 0.014)
	var mat := _particle_mat(true, true, Color(0.9, 0.95, 1.0, 1))
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.75, 0.9)
	mat.emission_energy_multiplier = 0.5
	q.material = mat
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p

static func dust_burst(r: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 48
	p.lifetime = 2.6
	p.one_shot = true
	p.explosiveness = 0.9
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-3, -4, -3), Vector3(6, 6, 6))
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(r, 0.05, 0.1)
	m.direction = Vector3(0, -1, 0)
	m.spread = 35.0
	m.initial_velocity_min = 0.1
	m.initial_velocity_max = 0.7
	m.gravity = Vector3(0, -0.3, 0)
	m.damping_min = 0.3
	m.damping_max = 0.8
	m.scale_min = 1.0
	m.scale_max = 4.0
	m.color_ramp = _ramp(PackedColorArray([Color(0.7, 0.62, 0.55, 0.0), Color(0.7, 0.62, 0.55, 0.35), Color(0.5, 0.45, 0.4, 0.0)]), PackedFloat32Array([0.0, 0.2, 1.0]))
	p.process_material = m
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.09)
	var mat := _particle_mat(true, true, Color(1, 1, 1, 1))
	q.material = mat
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p

static func ash_fall(extent: Vector3) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 40
	p.lifetime = 5.0
	p.preprocess = 5.0
	p.visibility_aabb = AABB(Vector3(-2, -5, -2) , Vector3(4, 6, 4))
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = extent
	m.direction = Vector3(0, -1, 0)
	m.spread = 8.0
	m.initial_velocity_min = 0.2
	m.initial_velocity_max = 0.5
	m.gravity = Vector3(0, -0.12, 0)
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 0.2
	m.scale_min = 0.6
	m.scale_max = 1.4
	m.color_ramp = _ramp(PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)]), PackedFloat32Array([0.0, 0.1, 0.8, 1.0]))
	p.process_material = m
	var q := QuadMesh.new()
	q.size = Vector2(0.022, 0.022)
	q.material = _particle_mat(true, false, Color(0.55, 0.75, 1.0, 1))
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p

# ---------------------------------------------------------------- environment + overlay
static func make_environment() -> Environment:
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0, 0, 0)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.14, 0.19, 0.27)
	e.ambient_light_energy = 0.9
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 1.0
	e.tonemap_white = 6.0
	e.ssao_enabled = true
	e.ssao_radius = 1.4
	e.ssao_intensity = 2.6
	e.ssao_power = 1.6
	e.ssao_detail = 0.6
	e.ssao_light_affect = 0.25
	e.ssr_enabled = true
	e.ssr_max_steps = 48
	e.ssr_fade_in = 0.12
	e.ssr_fade_out = 2.0
	e.ssr_depth_tolerance = 0.25
	e.glow_enabled = true
	e.glow_intensity = 0.85
	e.glow_strength = 1.0
	e.glow_bloom = 0.04
	e.glow_hdr_threshold = 0.9
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	e.fog_enabled = true
	e.fog_light_color = Color(0.035, 0.05, 0.065)
	e.fog_density = 0.012
	e.fog_aerial_perspective = 0.0
	e.volumetric_fog_enabled = true
	e.volumetric_fog_density = 0.008
	e.volumetric_fog_albedo = Color(0.62, 0.7, 0.8)
	e.volumetric_fog_emission = Color(0.012, 0.018, 0.026)
	e.volumetric_fog_emission_energy = 1.0
	e.volumetric_fog_length = 16.0
	e.volumetric_fog_anisotropy = 0.55
	e.volumetric_fog_gi_inject = 1.0
	e.volumetric_fog_ambient_inject = 0.0
	e.adjustment_enabled = true
	e.adjustment_contrast = 1.1
	e.adjustment_saturation = 0.9
	return e

static func overlay_shader() -> Shader:
	var s := Shader.new()
	s.code = """
shader_type canvas_item;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float grain = 0.05;
uniform float vig = 0.62;
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 c = UV - 0.5;
	float v = smoothstep(0.28, 0.82, length(c * vec2(1.0, 0.85)));
	float a1 = v * vig;
	float g = hash(floor(FRAGCOORD.xy) + vec2(floor(TIME * 24.0) * 17.0, 3.0)) - 0.5;
	float ga = abs(g) * 2.0 * grain;
	vec3 gc = vec3(g > 0.0 ? 1.0 : 0.0);
	float a2 = ga + a1 * (1.0 - ga);
	vec3 c2 = (gc * ga) / max(a2, 0.0001);
	float a3 = fade + a2 * (1.0 - fade);
	vec3 c3 = (c2 * a2 * (1.0 - fade)) / max(a3, 0.0001);
	COLOR = vec4(c3, a3);
}
"""
	return s

# ---------------------------------------------------------------- audio (worker thread safe)
const RATE := 22050

static func _norm(a: PackedFloat32Array, peak: float) -> void:
	var mx: float = 0.0001
	for v in a:
		mx = maxf(mx, absf(v))
	var k: float = peak / mx
	for i in a.size():
		a[i] *= k

static func _wav(a: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(a.size() * 2)
	for i in a.size():
		bytes.encode_s16(i * 2, int(clampf(a[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = a.size()
	return w

static func _lowpass_noise(rng: RandomNumberGenerator, n: int, alpha: float, passes: int) -> PackedFloat32Array:
	var a := PackedFloat32Array(); a.resize(n)
	for i in n:
		a[i] = rng.randf() * 2.0 - 1.0
	for p in passes:
		var y: float = 0.0
		for i in n:
			y += alpha * (a[i] - y)
			a[i] = y
	return a

static func bake_ambient() -> AudioStreamWAV:
	var dur: float = 24.0
	var N: int = int(dur * RATE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var out := PackedFloat32Array(); out.resize(N)
	# drone: integer cycle counts over the loop => seamless
	for i in N:
		var t: float = float(i) / float(RATE)
		var lfo1: float = 0.6 + 0.4 * sin(TAU * 2.0 * t / dur)
		var lfo2: float = 0.6 + 0.4 * sin(TAU * 3.0 * t / dur + 1.0)
		var s: float = 0.5 * sin(TAU * 55.0 * t + 0.8 * sin(TAU * 1.0 * t / dur))
		s += 0.35 * sin(TAU * 55.5 * t) * lfo1
		s += 0.22 * sin(TAU * 82.5 * t) * lfo2
		s += 0.12 * sin(TAU * 110.0 * t) * lfo1
		s += 0.06 * sin(TAU * 165.5 * t) * lfo2
		out[i] = s * 0.35
	# wind (crossfaded loop)
	var xf: int = RATE
	var wn := _lowpass_noise(rng, N + xf, 0.03, 2)
	var wh := _lowpass_noise(rng, N + xf, 0.12, 2)
	for i in N:
		var t2: float = float(i) / float(RATE)
		var env: float = 0.5 + 0.5 * sin(TAU * 3.0 * t2 / dur + 2.0)
		var env2: float = 0.5 + 0.5 * sin(TAU * 5.0 * t2 / dur)
		var w1: float = wn[i]
		var w2: float = wh[i]
		if i < xf:
			var f: float = float(i) / float(xf)
			w1 = wn[i] * f + wn[N + i] * (1.0 - f)
			w2 = wh[i] * f + wh[N + i] * (1.0 - f)
		out[i] += (w1 * 6.0 * env + w2 * 2.2 * env2 * env) * 0.5
	# drips with inharmonic bell partials
	var ratios := [1.0, 2.76, 5.4, 8.93]
	var amps := [1.0, 0.5, 0.25, 0.12]
	var decs := [0.32, 0.2, 0.12, 0.07]
	var drip_times := [1.7, 5.2, 9.6, 13.1, 14.0, 19.4, 22.3]
	for dt in drip_times:
		var f0: float = rng.randf_range(650.0, 1500.0)
		var dl: int = int(0.9 * RATE)
		var drip := PackedFloat32Array(); drip.resize(dl)
		for j in dl:
			var t3: float = float(j) / float(RATE)
			var s2: float = 0.0
			for k in 4:
				s2 += float(amps[k]) * sin(TAU * f0 * float(ratios[k]) * t3) * exp(-t3 / float(decs[k]))
			drip[j] = s2 * (1.0 - exp(-t3 * 900.0))
		var gain: float = rng.randf_range(0.05, 0.1)
		var st: int = int(float(dt) * RATE)
		var echoes := [[0, 1.0], [int(0.23 * RATE), 0.33], [int(0.41 * RATE), 0.14]]
		for ech in echoes:
			var o: int = st + int(ech[0])
			var g2: float = gain * float(ech[1])
			for j in dl:
				out[(o + j) % N] += drip[j] * g2
	_norm(out, 0.28)
	return _wav(out, true)

static func bake_step(seed_v: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var n: int = int(0.24 * RATE)
	var nz := _lowpass_noise(rng, n, 0.14 + 0.03 * float(seed_v % 3), 1)
	var out := PackedFloat32Array(); out.resize(n)
	var f: float = 55.0 + float(seed_v % 5) * 4.0
	for i in n:
		var t: float = float(i) / float(RATE)
		out[i] = nz[i] * 5.0 * exp(-t * 26.0) + sin(TAU * f * t) * exp(-t * 24.0) * 0.6
		out[i] *= (1.0 - exp(-t * 400.0))
	_norm(out, 0.24)
	return _wav(out, false)

static func bake_thud() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var n: int = int(1.1 * RATE)
	var nz := _lowpass_noise(rng, n, 0.06, 2)
	var out := PackedFloat32Array(); out.resize(n)
	var ph: float = 0.0
	for i in n:
		var t: float = float(i) / float(RATE)
		ph += TAU * (44.0 + 30.0 * exp(-t * 12.0)) / float(RATE)
		out[i] = sin(ph) * exp(-t * 5.0) + nz[i] * 14.0 * exp(-t * 16.0)
		out[i] *= (1.0 - exp(-t * 500.0))
	_norm(out, 0.3)
	return _wav(out, false)

static func _creak(n: int, base: float, wob: float, seed_v: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var out := PackedFloat32Array(); out.resize(n)
	var ph: float = 0.0
	var rough := _lowpass_noise(rng, n, 0.2, 1)
	for i in n:
		var t: float = float(i) / float(RATE)
		var f: float = base * (1.0 + 0.25 * sin(TAU * 2.3 * t) + wob * rough[i] * 6.0)
		ph += TAU * f / float(RATE)
		var s: float = sin(ph) + 0.55 * sin(2.0 * ph + 0.7) + 0.35 * sin(3.0 * ph + 1.9) + 0.2 * sin(5.0 * ph)
		out[i] = s * 0.3
	return out

static func bake_rattle() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var n: int = int(1.5 * RATE)
	var out := _creak(n, 150.0, 0.5, 3)
	var nz := _lowpass_noise(rng, n, 0.45, 1)
	var gate: float = 0.0
	for i in n:
		var t: float = float(i) / float(RATE)
		if rng.randf() < 0.0012:
			gate = 1.0
		gate *= 0.9985
		var swell: float = sin(PI * clampf(t / 1.5, 0.0, 1.0))
		out[i] = out[i] * swell * 0.6 + nz[i] * gate * 6.0 * (1.0 - t / 1.8)
	_norm(out, 0.26)
	return _wav(out, false)

static func bake_door_open() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var n: int = int(3.6 * RATE)
	var cr := _creak(n, 95.0, 0.7, 8)
	var rum := _lowpass_noise(rng, n, 0.035, 2)
	var rasp := _lowpass_noise(rng, n, 0.3, 1)
	var out := PackedFloat32Array(); out.resize(n)
	for i in n:
		var t: float = float(i) / float(RATE)
		var env: float = sin(PI * clampf(t / 3.6, 0.0, 1.0))
		var am: float = 0.5 + 0.5 * sin(TAU * 7.0 * t + 3.0 * rum[i] * 20.0)
		out[i] = (rum[i] * 18.0 + cr[i] * 0.8 * am + rasp[i] * 1.6 * am) * env
	_norm(out, 0.3)
	return _wav(out, false)

static func bake_audio() -> Dictionary:
	var d := {}
	d["ambient"] = bake_ambient()
	d["steps"] = [bake_step(11), bake_step(12), bake_step(13), bake_step(14)]
	d["thud"] = bake_thud()
	d["rattle"] = bake_rattle()
	d["open"] = bake_door_open()
	return d
