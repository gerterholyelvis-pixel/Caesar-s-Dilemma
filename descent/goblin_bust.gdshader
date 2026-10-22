shader_type canvas_item;

// Per-frame lighting of the baked goblin sculpt: black volcanic glass with GGX highlights, a stylised wet environment,
// conchoidal facets, ash on the up-facing planes, layered ember / cold-rim lighting and ember light seeping out of the cracks.
// tex_a: normal.xy, height, coverage   tex_b: ao, convexity, material, cavity   tex_c: crack distance + arrival time
// tex_d: facet tilt.xy, facet seam, facet F1   tex_n: tileable noise (r fine, g mid, b low)

uniform sampler2D tex_a : filter_linear, repeat_disable;
uniform sampler2D tex_b : filter_linear, repeat_disable;
uniform sampler2D tex_c : filter_linear, repeat_disable;
uniform sampler2D tex_d : filter_linear, repeat_disable;
uniform sampler2D tex_n : filter_linear, repeat_enable;
uniform vec2 org = vec2(-640.0, -360.0);
uniform vec2 span = vec2(1280.0, 1160.0);
uniform float T = 0.0;
uniform float lit = 1.0;
uniform vec2 lpos = vec2(-300.0, 420.0);
uniform float hot = 0.0;
uniform float crack_heat = 0.0;
uniform float eye = 0.0;
uniform float smirk = 0.0;
uniform float mouth_glow = 0.0;
uniform float dust = 0.85;
uniform float px = 1.0;
uniform float cracks_on = 1.0;

const vec3 EMBER = vec3(1.0, 0.36, 0.09);
const vec3 COLDC = vec3(0.16, 0.46, 0.70);

// colour contribution of one point light: soft diffuse, sharp + broad specular (a2s = roughness^4 of the two lobes)
vec3 plight(vec2 wp, float hz, vec3 N, vec3 lp, vec3 col, float rad2, vec2 a2s, vec3 alb, float f0, float sharpw) {
	vec3 Lv = lp - vec3(wp, hz);
	float d2 = dot(Lv, Lv);
	vec3 L = Lv * inversesqrt(d2);
	float att = 1.0 / (1.0 + d2 / rad2);
	float nl = max(dot(N, L), 0.0);
	vec3 H = normalize(L + vec3(0.0, 0.0, 1.0));
	float nh = max(dot(N, H), 0.0);
	float vh = max(H.z, 0.0);
	float v5 = 1.0 - vh;
	v5 = v5 * v5 * v5 * v5 * v5;
	float F = f0 + (1.0 - f0) * v5;
	float k = 0.25 / max(vh * vh, 0.2) * F * nl;
	float nh2 = nh * nh;
	float dd1 = nh2 * (a2s.x - 1.0) + 1.0;
	float dd2 = nh2 * (a2s.y - 1.0) + 1.0;
	float s1 = a2s.x / (3.14159 * dd1 * dd1) * k;
	float s2 = a2s.y / (3.14159 * dd2 * dd2) * k;
	float w = clamp(nl * 0.5 + 0.5, 0.0, 1.0);
	float wrap = w * w * sqrt(w);
	return col * att * (alb * (nl * 0.9 + wrap * 0.35) + vec3(s1 * sharpw + s2 * 0.20));
}

vec3 envmap(vec3 R, float li) {
	vec3 c = vec3(0.004, 0.006, 0.011) + vec3(0.10, 0.20, 0.30) * 0.10 * smoothstep(0.55, 1.0, R.z);
	// cold softbox, upper right, and a thin strip, upper left
	vec3 up = normalize(vec3(0.55, -0.72, 0.42));
	float du = dot(R, up);
	c += COLDC * (smoothstep(0.90, 0.975, du) * 3.2 + smoothstep(0.45, 0.95, du) * 0.30);
	vec3 d2 = normalize(vec3(-0.72, -0.46, 0.52));
	c += vec3(0.30, 0.52, 0.72) * smoothstep(0.955, 0.985, dot(R, d2)) * 1.6;
	// the lava floor and the ember: warm glow below and left
	vec3 de = normalize(vec3(-0.5, 0.78, 0.38));
	float dde = dot(R, de);
	c += EMBER * (smoothstep(0.86, 0.97, dde) * 3.0 + smoothstep(0.3, 0.9, dde) * 0.5) * li;
	float ry = clamp(R.y * 0.5 + 0.5, 0.0, 1.0);
	float ry2 = ry * ry;
	c += vec3(1.0, 0.22, 0.05) * ry2 * ry2 * ry * 0.45 * li;
	return c;
}

void fragment() {
	vec4 A = texture(tex_a, UV);
	if (A.a < 0.003) {
		COLOR = vec4(0.0);
	} else {
		vec2 wp = org + UV * span;
		vec4 B = texture(tex_b, UV);
		vec4 D = texture(tex_d, UV);
		float hgt = A.b * 256.0;
		vec2 nxy = A.rg * 2.0 - 1.0;
		vec3 N = vec3(nxy, sqrt(max(1.0 - dot(nxy, nxy), 0.0)));
		float mat = B.b;
		float ao = B.r;
		float cav = B.a;
		float df = smoothstep(1.7, 0.7, px);       // micro detail fades when zoomed out

		float isEar = step(0.2, mat) * step(mat, 0.3);
		float isHorn = step(0.4, mat) * step(mat, 0.6);
		float isCloth = step(0.7, mat) * step(mat, 0.8);
		float isMetal = step(0.9, mat);
		float isHead = 1.0 - clamp(isEar + isHorn + isCloth + isMetal, 0.0, 1.0);

		// ---- noise lookups (one texture, several scales) ----
		vec2 nq = wp * (1.0 / 140.0);
		vec3 n0 = texture(tex_n, nq).rgb;
		float nx1 = texture(tex_n, nq + vec2(0.005, 0.0)).r;
		float ny1 = texture(tex_n, nq + vec2(0.0, 0.005)).r;
		vec3 nm = texture(tex_n, wp * (1.0 / 520.0) + 0.3).rgb;       // mid scale: ash, wet patches
		float streak = texture(tex_n, vec2(wp.x * 0.0022, wp.y * 0.00007) + 0.5).b;
		// ---- micro normal and conchoidal facets ----
		vec2 micro = vec2(nx1 - n0.r, ny1 - n0.r) * 9.0;
		float fa = mix(0.30, 0.07, isHead * smoothstep(0.1, 0.5, ao)) + 0.18 * isCloth;
		fa *= (1.0 - 0.6 * isMetal);
		vec2 tilt = (D.rg - 0.5) * fa;
		float rip = sin(D.a * 0.9 * 38.0 + (D.r - 0.5) * 20.0);
		tilt += normalize(D.rg - 0.5 + 1e-3) * rip * 0.035 * (1.0 - 0.5 * isHead);
		vec3 Nf = normalize(vec3(N.xy + (tilt + micro * (0.10 + 0.30 * (1.0 - isHead)) * df) * (0.4 + 0.6 * N.z), N.z));
		float seam = smoothstep(0.2, 0.0, D.b) * (1.0 - 0.6 * isHead);

		// ---- cracks: distance + arrival time ----
		vec4 tc = texture(tex_c, UV);
		float dcr = tc.r * 48.0;
		ivec2 ti = ivec2(UV * vec2(textureSize(tex_c, 0)));
		vec4 ct = texelFetch(tex_c, ti, 0);
		float arr = (ct.g + ct.b / 255.0) * 64.0;
		float age = T - arr;
		float open = smoothstep(0.0, 0.22, age) * cracks_on;
		float calm = (1.0 - smirk * 0.8 * smoothstep(1.0, 0.45, length((wp - vec2(0.0, 176.0)) / vec2(200.0, 86.0)))) * (1.0 - eye * 0.7 * smoothstep(1.0, 0.5, length((vec2(abs(wp.x), wp.y) - vec2(92.0, -46.0)) / vec2(78.0, 44.0))));
		float cw = mix(0.6, 1.15, ct.a) * (0.55 + 0.45 * smoothstep(0.0, 3.0, age));
		float core = smoothstep(cw + 0.6, cw - 0.2, dcr) * open;
		float pulse = 0.85 + 0.15 * sin(T * 2.1 + arr * 7.0);
		float bright = (0.30 + 0.70 * smoothstep(0.0, 2.5, age)) * (0.30 + 0.70 * crack_heat) * pulse + exp(-max(age, 0.0) * 2.2) * 1.6;
		float inner = exp(-dcr / 4.5) * open;
		float wide = exp(-dcr / 15.0) * open;
		// crack walls: bevel toward the fissure, darkness inside
		vec2 go = 1.5 / vec2(textureSize(tex_c, 0));
		vec2 gd = vec2(texture(tex_c, UV + vec2(go.x, 0.0)).r - texture(tex_c, UV - vec2(go.x, 0.0)).r,
			texture(tex_c, UV + vec2(0.0, go.y)).r - texture(tex_c, UV - vec2(0.0, go.y)).r);
		float gl = length(gd);
		vec2 gdir = gd / max(gl, 1e-4);
		float wall = smoothstep(cw * 4.0 + 2.0, cw * 0.8, dcr) * open;
		Nf = normalize(vec3(Nf.xy - gdir * wall * 0.65 * step(0.0005, gl), Nf.z));
		float chasm = smoothstep(cw * 1.4, cw * 0.4, dcr) * open;

		// ---- material ----
		vec3 alb = vec3(0.024, 0.025, 0.034);
		float rough1 = 0.12 + 0.08 * streak + 0.04 * D.a;
		float f0 = 0.045;
		vec3 f0c = vec3(f0);
		float wet = smoothstep(0.35, 0.7, nm.g);
		rough1 += 0.07 * (1.0 - wet);
		if (isHorn > 0.5) {
			alb = vec3(0.06, 0.052, 0.044);
			rough1 = 0.34 + 0.1 * streak;
			f0 = 0.05;
		}
		if (isCloth > 0.5) {
			alb = vec3(0.020, 0.018, 0.024);
			rough1 = 0.55 + 0.2 * streak;
		}
		if (isMetal > 0.5) {
			alb = vec3(0.0);
			f0c = vec3(0.55, 0.38, 0.12);
			f0 = 0.55;
			rough1 = 0.28 + 0.1 * streak;
		}
		float rough2 = 0.60;

		// ash on the up-facing planes (and ledges where the sculpt is flat)
		float top = smoothstep(0.25, 0.80, -Nf.y) * smoothstep(0.35, 0.9, Nf.z + 0.25);
		float ash = clamp(top * (0.30 + 1.1 * nm.r) * dust * (1.0 - 0.7 * chasm) * (0.35 + 0.65 * ao) * (1.0 - 0.8 * isCloth), 0.0, 1.0);
		alb = mix(alb, vec3(0.115, 0.112, 0.125), ash);
		rough1 = mix(rough1, 0.85, ash);
		f0 = mix(f0, 0.02, ash);

		vec3 Nl = Nf;
		float li = clamp(lit, 0.0, 1.5);
		vec3 col = vec3(0.0);
		// ambient: cold, dim, occluded
		float cold_up = 0.5 + 0.5 * (-Nl.y);
		col += alb * COLDC * (0.10 + 0.20 * cold_up) * ao * 0.6 + COLDC * 0.010 * ao * (0.4 + 0.6 * cold_up) * (1.0 - 0.6 * isCloth);

		float r12 = rough1 * rough1;
		float r22 = rough2 * rough2;
		vec2 a2s = vec2(r12 * r12, r22 * r22);
		float sharpw = (1.0 + 0.9 * isHead) * (1.0 - 0.6 * isCloth);
		float aof = 0.45 + 0.55 * ao;
		// ember key: low left
		col += plight(wp, hgt, Nl, vec3(lpos, 230.0), EMBER * (1.9 * li), 490000.0, a2s, alb, f0, sharpw) * aof;
		// second weaker ember, low right
		vec2 lp2 = vec2(-lpos.x * 1.1 + 40.0, lpos.y * 0.9);
		col += plight(wp, hgt, Nl, vec3(lp2, 200.0), vec3(1.0, 0.30, 0.07) * (1.1 * li), 410000.0, a2s, alb, f0, sharpw) * aof;
		// cold moon key from upper right behind (grazing: carves the brow, nose bridge and cheekbones)
		col += plight(wp, hgt, Nl, vec3(520.0, -520.0, 260.0), vec3(0.30, 0.55, 0.85) * 1.5, 810000.0, a2s, alb, f0, sharpw) * (0.35 + 0.65 * ao);
		// the eyes light the face once open
		if (eye > 0.02) {
			col += plight(wp, hgt, Nl, vec3(-92.0, -46.0, 70.0), vec3(1.0, 0.45, 0.10) * (0.6 * eye), 28900.0, a2s, alb, f0, 0.8);
			col += plight(wp, hgt, Nl, vec3(92.0, -46.0, 70.0), vec3(1.0, 0.45, 0.10) * (0.6 * eye), 28900.0, a2s, alb, f0, 0.8);
		}
		if (mouth_glow > 0.02) {
			col += plight(wp, hgt, Nl, vec3(0.0, 168.0, 40.0), vec3(1.0, 0.30, 0.06) * (0.6 * mouth_glow), 25600.0, a2s, alb, f0, 0.8);
		}

		// wet reflection of the stylised environment (fresnel weighted)
		float nv = max(Nl.z, 0.0);
		vec3 R = vec3(2.0 * nv * Nl.xy, 2.0 * nv * nv - 1.0);
		float f1 = 1.0 - nv;
		float f5 = f1 * f1 * f1 * f1 * f1;
		vec3 frc = f0c + (vec3(1.0) - f0c) * f5;
		vec3 refl = envmap(R, li) * (1.0 - 0.8 * smoothstep(0.3, 0.75, rough1));
		col += refl * frc * (0.25 + 0.75 * ao) * (1.0 - ash);

		// rim light: cold on the upper right, warm toward the ember
		float rim = f1 * f1 * sqrt(f1);
		vec2 nd = normalize(Nl.xy + vec2(1e-4));
		float cold_side = smoothstep(-0.15, 0.85, dot(nd, vec2(0.5, -0.8660)));
		float cold_side2 = smoothstep(0.1, 0.9, dot(nd, vec2(-0.8836, -0.4678)));
		col += COLDC * rim * (cold_side * 2.6 + cold_side2 * 0.7) * (0.45 + 0.55 * ao) * (1.0 - 0.5 * isCloth);
		float warm_side = smoothstep(0.0, 0.9, dot(nd, normalize(lpos - wp)));
		col += EMBER * rim * warm_side * li * 0.9 * (0.5 + 0.5 * ao);

		// seams of the fracture planes catch the light
		col += (COLDC * 0.5 * cold_side + EMBER * 0.7 * warm_side * li) * seam * 0.16 * (0.4 + 0.6 * rim * 2.0) * (1.0 - isHead * 0.5);

		// ---- inner light: hot glass, ember glow seeping from the cracks ----
		float tk = clamp(1.0 - hgt / 190.0, 0.0, 1.0);
		float hfl = 0.65 + 0.35 * nm.b;
		col += vec3(0.9, 0.22, 0.04) * hot * hfl * (0.004 + 0.028 * tk * tk + 0.03 * seam) * (0.6 + 0.4 * isHead + isEar * 0.8);
		float sss = (wide * 0.13 + inner * 0.40) * bright * calm;
		col += vec3(1.0, 0.26, 0.04) * sss * (1.0 - chasm * 0.3) * (0.5 + 0.5 * pulse);
		col *= 1.0 - chasm * 0.65;
		col += vec3(2.6, 1.15, 0.30) * core * min(bright, 1.4) * 0.62 * calm;

		// cavities swallow the light
		col *= mix(1.0, 0.45, smoothstep(0.1, 0.7, cav));

		COLOR = vec4(col, A.a);
	}
}
