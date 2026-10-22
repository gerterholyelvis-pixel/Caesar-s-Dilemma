shader_type canvas_item;
render_mode blend_disabled;

// THE FALL: analytic pseudo-3D shaft. A vertical cylinder of noise-displaced rock around the camera axis,
// carved with gothic piers, rib rings, pointed-arch windows and screaming faces; smoke banks (planes),
// a smoke ceiling, and a lake of fire / obsidian plates far below. One ray, one wall solve, no loops over geometry.

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform float T = 0.0;
uniform float camY = 0.0;
uniform float phi = -1.3;       // pitch: -pi/2 looks up, +pi/2 looks straight down
uniform float yaw = 0.0;
uniform float roll = 0.0;
uniform float fl = 0.8;
uniform vec2 res = vec2(960.0, 640.0);
uniform vec2 cam_off = vec2(0.0);
uniform vec2 shake = vec2(0.0);
uniform float heat = 0.0;
uniform float fogd = 0.03;
uniform float fog_extra = 0.0;
uniform float struct_y0 = 150.0;
uniform float ceilY = 690.0;
uniform float floorY = 920.0;
uniform float lake = 1.0;
uniform float expo = 1.0;
uniform float limbo_light = 1.0;
uniform float smoke_amt = 0.6;
uniform float flash = 0.0;

const float R0 = 15.0;

float h21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
vec2 h22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

// wall radius at (angle a, depth Y). feat = emissive mask (window glow, eyes, mouths); tx = rock texture 0..1
float wall_r(float a, float Y, float lod, out float feat, out float tx, out float halo) {
	float u = a * 0.15915494;
	float n1 = textureLod(noise_tex, vec2(u * 3.0, Y * 0.016), lod).r;
	float n2 = textureLod(noise_tex, vec2(u * 9.0 + 0.37, Y * 0.045 + 0.2), lod).r;
	float n3 = textureLod(noise_tex, vec2(u * 27.0 + 0.11, Y * 0.11), lod).r;
	tx = n2 * 0.55 + n3 * 0.45;
	float cav = smoothstep(ceilY - 25.0, ceilY + 55.0, Y);
	float r = R0 * (1.0 + 0.30 * (n1 - 0.5)) + 2.2 * (n2 - 0.5) + 1.0 * (n3 - 0.5);
	r += cav * 100.0;
	feat = 0.0;
	halo = 0.0;
	float sa = smoothstep(struct_y0, struct_y0 + 70.0, Y) * (1.0 - cav);
	if (sa > 0.002) {
		vec2 cell = vec2(u * 8.0 + 0.5, Y / 21.0);
		vec2 id = floor(cell);
		id.x = mod(id.x, 8.0);
		vec2 lc = fract(cell);
		float hh = h21(id + 7.0);
		float pier = 1.0 - smoothstep(0.0, 0.13, min(lc.x, 1.0 - lc.x));
		float ring = smoothstep(0.0, 0.04, lc.y) * (1.0 - smoothstep(0.05, 0.13, lc.y));
		float notch = smoothstep(0.30, 0.48, n2);
		r -= (2.8 * pier + 2.2 * ring * notch) * sa;
		vec2 q = vec2(lc.x - 0.5, lc.y);
		if (hh < 0.46) {
			float aw = 0.27 * sqrt(clamp(1.0 - pow(max(q.y - 0.5, 0.0) / 0.38, 2.0), 0.0, 1.0));
			float win = smoothstep(aw, aw - 0.04, abs(q.x)) * smoothstep(0.10, 0.15, q.y) * step(q.y, 0.88);
			win *= 1.0 - 0.85 * smoothstep(0.035, 0.0, abs(q.x)) * step(0.3, q.y);   // central mullion
			r += 3.4 * win * sa;
			feat = max(feat, win * sa * (0.20 + 0.9 * (1.0 - q.y)) * (0.55 + 0.9 * n3));
			halo = exp(-(q.x * q.x * 7.0 + pow(q.y - 0.45, 2.0) * 5.0)) * sa;
		} else if (hh < 0.70) {
			vec2 e1 = (q - vec2(-0.17, 0.62)) / vec2(0.105, 0.07);
			vec2 e2 = (q - vec2(0.17, 0.62)) / vec2(0.105, 0.07);
			float eyes = max(1.0 - dot(e1, e1), 1.0 - dot(e2, e2));
			vec2 m = (q - vec2(0.0, 0.27)) / vec2(0.125, 0.18);
			float mouth = 1.0 - dot(m, m);
			vec2 ns = (q - vec2(0.0, 0.46)) / vec2(0.045, 0.10);
			float nose = 1.0 - dot(ns, ns);
			float pit = clamp(max(max(eyes, mouth), nose * 0.6) * 3.0, 0.0, 1.0) * (0.55 + 0.9 * n3);
			vec2 f = (q - vec2(0.0, 0.5)) / vec2(0.44, 0.47);
			float plate = clamp((1.0 - dot(f, f)) * 4.0, 0.0, 1.0);
			r += (-1.1 * plate + 3.2 * pit) * sa;
			feat = max(feat, pit * sa * 0.9 * (0.5 + 0.8 * n3));
			halo = exp(-(q.x * q.x * 6.0 + pow(q.y - 0.45, 2.0) * 4.0)) * sa * 0.7;
		}
	}
	return r;
}

vec3 floor_col(vec2 xz, float t) {
	vec2 g = xz * 0.05;
	vec2 ip = floor(g);
	vec2 fp = fract(g);
	float F1 = 8.0;
	float F2 = 8.0;
	vec2 cid = ip;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 nb = vec2(float(i), float(j));
			vec2 df = nb + h22(ip + nb) - fp;
			float dd = dot(df, df);
			if (dd < F1) { F2 = F1; F1 = dd; cid = ip + nb; }
			else if (dd < F2) { F2 = dd; }
		}
	}
	float edge = sqrt(F2) - sqrt(F1);
	float flow = texture(noise_tex, xz * 0.012 + vec2(T * 0.01, 0.0)).r;
	float lc = clamp(lake, 0.12, 1.0);
	float soft = 0.02 + t * 0.0008;
	float lav = smoothstep(0.20 * lc + soft, 0.0, edge) * (0.55 + 0.9 * flow);
	float hc = h21(cid);
	vec3 plate = vec3(0.010, 0.009, 0.013) + vec3(0.03, 0.028, 0.04) * hc * hc;
	plate += vec3(1.0, 0.30, 0.05) * smoothstep(0.7, 0.0, edge) * 0.10 * lake;
	plate += vec3(0.5, 0.55, 0.65) * step(0.90, hc) * 0.05;   // glassy facets catching light
	vec3 lava = vec3(1.0, 0.22, 0.03) * (0.9 + 1.5 * lav) + vec3(0.3, 0.12, 0.0) * flow;
	return mix(plate, lava * lake * 0.5, clamp(lav * 1.1, 0.0, 1.0));
}

vec3 fog_color(float yy, float dy) {
	vec3 ash = vec3(0.15, 0.145, 0.14);
	vec3 soot = vec3(0.045, 0.040, 0.040);
	vec3 deep = vec3(0.62, 0.12, 0.035);
	vec3 c = mix(ash, soot, smoothstep(0.0, 0.40, heat));
	c = mix(c, deep * 0.22, smoothstep(0.35, 1.0, heat));
	float below = pow(max(dy, 0.0), 5.0) * smoothstep(0.35, 1.0, heat);
	c += vec3(1.0, 0.33, 0.06) * below * (0.35 + 0.9 * smoothstep(100.0, floorY, yy)) * lake;
	return c;
}

vec3 sky_col(vec3 d, vec2 o) {
	float tt = (-45.0 - camY) / d.y;
	vec2 hit = o + d.xz * tt;
	float r = length(hit);
	float tt2 = (-20.0 - camY) / d.y;
	vec2 hc = (o + d.xz * tt2) * 0.012 + vec2(T * 0.01, 0.0);
	float n = texture(noise_tex, hc).r;
	vec3 base = vec3(0.16, 0.158, 0.155) * (0.5 + 1.1 * n);
	base += vec3(0.20, 0.20, 0.21) * exp(-r * 0.02) * 0.6;
	float er = 17.0;
	float ring = exp(-max(r - er, 0.0) * 0.30) * smoothstep(er - 1.2, er + 0.6, r);
	float core = exp(-max(r - er, 0.0) * 0.08);
	vec3 c = base + vec3(0.85, 0.86, 0.90) * ring * 1.5 + vec3(0.30, 0.31, 0.34) * core * 0.35;
	c *= smoothstep(er - 0.6, er + 0.4, r) * 0.97 + 0.03;   // black eclipse disc
	return c * limbo_light;
}

void fragment() {
	vec2 uv = UV + shake;
	vec2 p = (uv - 0.5) * vec2(res.x / res.y, 1.0);
	float cr = cos(roll);
	float sr = sin(roll);
	vec2 q = vec2(p.x * cr - p.y * sr, p.x * sr + p.y * cr);
	q.y = -q.y;
	vec3 F = vec3(0.0, sin(phi), cos(phi));
	vec3 Uv = vec3(0.0, -cos(phi), sin(phi));
	vec3 d = normalize(F * fl + vec3(1.0, 0.0, 0.0) * q.x + Uv * q.y);
	float cy = cos(yaw);
	float sy = sin(yaw);
	d.xz = vec2(d.x * cy - d.z * sy, d.x * sy + d.z * cy);
	vec2 o = cam_off;
	vec2 h = d.xz;
	float A = dot(h, h) + 1e-6;
	float B = dot(o, h);

	float rho = R0;
	float t = 1.0;
	float a = 0.0;
	float Y = camY;
	float ff = 0.0;
	float tx = 0.5;
	float hl = 0.0;
	for (int i = 0; i < 3; i++) {
		float C = dot(o, o) - rho * rho;
		t = (-B + sqrt(max(B * B - A * C, 0.0))) / A;
		t = min(t, 900.0);
		Y = camY + t * d.y;
		vec2 hp = o + h * t;
		a = atan(hp.y, hp.x);
		float lod = clamp(log2(1.0 + t * 0.03), 0.0, 6.0);
		rho = wall_r(a, Y, lod, ff, tx, hl);
	}
	{
		float C = dot(o, o) - rho * rho;
		t = min((-B + sqrt(max(B * B - A * C, 0.0))) / A, 900.0);
	}

	vec3 col;
	float tf = (floorY - camY) / max(d.y, 1e-4);
	bool sky = d.y < 0.0 && Y < 0.0;
	bool is_floor = d.y > 0.0 && tf < t;
	float tend = t;
	float deep = clamp(Y / floorY, 0.0, 1.0);
	vec3 fcol = fog_color(Y, d.y);
	float fd = fogd + fog_extra;

	if (sky) {
		col = sky_col(d, o);
		tend = 120.0;
		// jagged lip of the cracked floor: pale cold rim just inside the hole
		float lip = smoothstep(-6.0, 0.0, Y) * limbo_light;
		col += vec3(0.30, 0.30, 0.32) * lip * 0.0;
	} else if (is_floor) {
		tend = tf;
		col = floor_col(o + h * tf, tf);
		float trf = exp(-tf * fd * 0.5);
		col = col * trf + fcol * (1.0 - trf);
	} else {
		float lodw = clamp(log2(1.0 + t * 0.03), 0.0, 6.0);
		float e = 0.5;
		float f2;
		float t2;
		float t3;
		float rA = wall_r(a + e / rho, Y, lodw, f2, t2, t3);
		float rY = wall_r(a, Y + e, lodw, f2, t2, t3);
		float s_a = (rA - rho) / e;
		float s_y = (rY - rho) / e;
		vec3 N = normalize(vec3(-1.0, s_a, s_y));
		float warm = max(N.z, 0.0);
		float cool = max(-N.z, 0.0);
		float u = a * 0.15915494;
		float n3 = textureLod(noise_tex, vec2(u * 27.0 + 0.11, Y * 0.11), lodw).r;
		float strata = 0.5 + 0.5 * sin(Y * 0.17 + tx * 2.5);
		vec3 rock = mix(vec3(0.06, 0.055, 0.058), vec3(0.24, 0.20, 0.18), smoothstep(0.25, 0.75, tx));
		rock *= 0.8 + 0.3 * strata;
		rock *= 0.7 + 0.6 * smoothstep(0.1, 0.6, tx);
		float lake_l = 0.2 + 0.8 * lake;
		vec3 warmL = vec3(1.0, 0.34, 0.07) * (0.02 + 1.1 * pow(deep, 2.2)) * smoothstep(0.1, 0.9, heat + 0.1) * lake_l;
		vec3 coolL = vec3(0.62, 0.64, 0.70) * (limbo_light * 0.9 * exp(-max(Y, 0.0) / 60.0) + 0.30);
		vec3 amb = vec3(0.06, 0.052, 0.056) + vec3(0.04, 0.012, 0.004) * heat;
		col = rock * (warmL * (0.30 + warm * 1.5 + hl * 3.0) + coolL * (0.12 + cool * 2.6) + amb);
		// bone-grey rim light on projecting edges
		float edge = length(vec2(s_a, s_y));
		col += vec3(0.55, 0.52, 0.47) * smoothstep(1.5, 3.8, edge) * (0.10 + 0.28 * (1.0 - heat * 0.4)) * (0.4 + cool) * (0.3 + lake_l * 0.7);
		// lava falls (long vertical streaks) and glowing cracks
		float vn = textureLod(noise_tex, vec2(u * 5.0 + 0.77, Y * 0.003 - T * 0.009 + tx * 0.05), lodw).r;
		float vein = smoothstep(0.016, 0.0, abs(vn - 0.5)) * smoothstep(140.0, 260.0, Y);
		float crack = smoothstep(0.03, 0.0, abs(n3 - 0.5)) * smoothstep(100.0, 400.0, Y) * 0.5;
		vec3 emb = vec3(1.0, 0.30, 0.05);
		col += emb * (vein * 1.5 + crack * 0.2) * heat * lake_l * (0.7 + 0.5 * sin(T * 2.0 + Y * 0.1));
		// carved openings glow like furnaces
		col += mix(vec3(0.9, 0.25, 0.04), vec3(1.0, 0.55, 0.15), n3) * ff * ff * (0.15 + 0.9 * heat) * (0.15 + 0.85 * lake_l) * smoothstep(0.0, 0.25, heat + 0.25);
		float tr = exp(-t * fd);
		col = col * tr + fcol * (1.0 - tr);
	}

	// smoke banks: horizontal planes of cinder cloud punched through at speed
	float S = 36.0;
	float dir = d.y >= 0.0 ? 1.0 : -1.0;
	float k0 = dir > 0.0 ? floor(camY / S) + 1.0 : floor(camY / S);
	for (int i = 1; i >= 0; i--) {
		float k = k0 + dir * float(i);
		float Yp = k * S;
		float tp = (Yp - camY) / d.y;
		if (tp > 0.5 && tp < tend && Yp > 4.0) {
			vec2 hp = o + d.xz * tp;
			vec2 cu = hp * 0.035 + vec2(k * 7.31, k * 3.17) + vec2(T * 0.02, 0.0);
			float dn = textureLod(noise_tex, cu, clamp(log2(1.0 + tp * 0.03), 0.0, 5.0)).r;
			dn = dn * 0.7 + 0.3 * textureLod(noise_tex, cu * 2.7 + 0.5, 2.0).r;
			float edgeR = length(hp);
			float al = smoothstep(0.30, 0.62, dn) * smoothstep(0.0, 6.0, tp) * smoothstep(4.0, 16.0, Yp);
			al *= smoke_amt * exp(-tp * fd * 0.2) * (1.0 - smoothstep(0.0, 1.0, (Yp - ceilY + 30.0) / 60.0) * 0.0);
			vec3 sc = fog_color(Yp, 0.0) * (0.8 + 0.5 * dn);
			sc += vec3(1.0, 0.3, 0.06) * smoothstep(0.7, 0.95, dn) * heat * 0.25 * smoothstep(120.0, floorY, Yp);   // glowing cinders in the cloud
			col = mix(col, sc, clamp(al, 0.0, 0.95));
		}
	}

	// lightning-like flashes in the ash storm
	col += vec3(0.55, 0.50, 0.46) * flash * (0.25 + 0.75 * exp(-t * 0.03)) * 0.55;
	col *= expo;
	COLOR = vec4(col, 1.0);
}
