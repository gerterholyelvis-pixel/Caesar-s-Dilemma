shader_type canvas_item;
// First Sprout cinematic: one full-screen "macro photograph" shader.
// Screen space s: x right, y up, unit = screen height. World: the subject plane sits at depth 1,
// the ground plane y=0 is a true perspective plane, trees/dust live on depth layers with analytic depth of field.

uniform vec2 res = vec2(1920.0, 1080.0);
uniform float t = 0.0;
uniform float fl = 2.5;                 // focal length / zoom
uniform vec2 cam = vec2(0.0, 0.17);     // camera x, height
uniform float hy = 0.04;                // horizon screen y
uniform float focus = 1.0;              // focus depth
uniform float aperture = 1.0;
uniform float leaf_vis = 1.0;
uniform vec2 tip = vec2(0.0, 0.27);
uniform vec2 drop_c = vec2(0.0, 0.2);
uniform float drop_r = 0.04;
uniform float drop_st = 0.0;            // vertical stretch
uniform float drop_sq = 0.0;            // impact squash
uniform float drop_vis = 1.0;
uniform float neck = 1.0;
uniform float imp = -1.0;               // seconds since impact
uniform float grow = 0.0;               // sprout growth 0..1
uniform float lit = 0.0;                // garden reveal / illumination 0..1
uniform float sun_k = 1.0;

const vec3 GOLD = vec3(1.0, 0.74, 0.34);
const vec3 TEAL = vec3(0.10, 0.80, 0.62);
const vec3 VIOLET = vec3(0.52, 0.28, 0.92);
const vec3 CYAN = vec3(0.45, 0.95, 1.0);
const float SOIL_FREQ = 150.0;

float h11(float p) { p = fract(p * 0.1031); p *= p + 33.33; p *= p + p; return fract(p); }
float h21(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
vec2 h22(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973)); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.xx + p3.yz) * p3.zy); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p, float fade, int oct) {
	float a = 0.5; float sum = 0.0; float fq = 1.0;
	for (int i = 0; i < 5; i++) {
		if (i >= oct) { break; }
		float w = clamp(1.0 - fade * fq * 0.8, 0.0, 1.0);
		sum += a * w * vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.2); a *= 0.5; fq *= 2.0;
	}
	return sum;
}
vec2 rot2(vec2 p, float a) { float c = cos(a); float s = sin(a); return vec2(p.x * c - p.y * s, p.x * s + p.y * c); }
float smin(float a, float b, float k) { float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0); return mix(b, a, h) - k * h * (1.0 - h); }

float world_blur(float z) { return aperture * abs(1.0 - z / focus) * 0.04; }

// Self-similar fractal tree by domain folding with a parabolic bend. Returns (distance for L=1, level of nearest, leaf distance).
vec3 fold_tree(vec2 p, float g, float ang, float curl, float sway, float thick0, float bend, float leafk) {
	float d = 1e5; float lv = 0.0; float bud = 1e5; float s = 1.0;
	for (int i = 0; i < 6; i++) {
		float fi = float(i);
		float lg = clamp(g * 6.6 - fi * 0.8, 0.0, 1.0);
		float nl = clamp(g * 6.6 - (fi + 1.0) * 0.8, 0.0, 1.0);
		p = rot2(p, (1.0 - lg) * curl * (fi < 0.5 ? 0.15 : 1.0) + sway * (0.4 + 0.25 * fi));
		float bd = bend * (1.0 - 0.07 * fi);
		float h = clamp(p.y, 0.0, lg);
		float qx = p.x - bd * p.y * p.y;
		float rad = thick0 * (1.0 - 0.09 * fi) * (1.0 - 0.38 * h / max(lg, 0.05));
		float di = (length(vec2(qx, p.y - h)) - rad) * s * 0.92;
		if (di < d) { d = di; lv = fi; }
		p -= vec2(bd * lg * lg, lg);
		p = rot2(p, atan(2.0 * bd * lg));
		float rb = 0.15 * (1.0 - nl) * smoothstep(0.2, 1.0, lg) * leafk;
		vec2 lp = vec2(p.x / 0.62, (p.y - rb * 1.1) / 1.55);
		bud = min(bud, (length(lp) - rb) * s * 0.7);
		p.x = abs(p.x);
		p = rot2(p, ang + 0.07 * sin(fi * 2.3 + 1.0));
		p *= 1.55; s /= 1.55;
	}
	return vec3(d, lv, bud);
}

vec3 haze_col() {
	return mix(vec3(0.03, 0.11, 0.12), vec3(0.42, 0.26, 0.12), 0.2 + 0.3 * sun_k) * (0.6 + 0.6 * lit);
}

vec3 skycol(vec2 s) {
	vec2 sp = vec2(-0.62 - cam.x * 0.2, 0.34);
	float up = s.y - hy;
	vec3 c = mix(vec3(0.90, 0.42, 0.14) * 0.46, vec3(0.04, 0.30, 0.34) * 0.42, smoothstep(0.0, 0.45, up));
	c = mix(c, vec3(0.07, 0.04, 0.22) * 0.5, smoothstep(0.3, 1.1, up));
	float d = length(s - sp);
	c += GOLD * (0.30 * exp(-d * 2.4) + 1.6 * exp(-d * 11.0) + 9.0 * exp(-d * 55.0)) * sun_k;
	c *= 0.8 + 0.4 * fbm(vec2(s.x * 1.6 + t * 0.01, s.y * 6.0), 0.0, 4);
	return c * (0.8 + 0.4 * lit);
}

// bokeh grid: discs whose radius follows the blur, energy conserving
float bokeh(vec2 g, float sp, float r0, float bw, float dens, float seed, float tw) {
	vec2 c = floor(g / sp);
	vec2 f = g / sp - c - 0.5;
	vec2 o = (h22(c + seed) - 0.5) * 0.55;
	float hs = h21(c + seed * 3.7);
	float r = min(sqrt(r0 * r0 + bw * bw * 0.3), sp * 0.42);
	float d = length(f - o) * sp;
	float e = r0 / (r + 1e-6);
	float disc = smoothstep(r, r * 0.82, d) * (1.0 + 0.6 * smoothstep(r * 0.55, r * 0.95, d));
	float tws = 0.7 + 0.3 * sin(t * (0.6 + hs * 1.8) + hs * 40.0) * tw;
	return step(1.0 - dens, hs) * disc * min(e, 1.0) * tws;
}

vec3 soil(vec2 g, float z, float bw, bool lowq) {
	float fw = bw * 0.55 + z / (fl * res.y);
	vec2 q = g * SOIL_FREQ * vec2(1.0, 0.5);
	float fade = fw * SOIL_FREQ * 0.45;
	int oct = lowq ? 3 : 5;
	float h = fbm(q * 0.6, fade * 0.6, oct) + 0.45 * fbm(q * 3.1, fade * 3.1, 3);
	float h2 = fbm((q + vec2(0.0, 0.5)) * 0.6, fade * 0.6, oct) + 0.45 * fbm((q + vec2(0.0, 0.5)) * 3.1, fade * 3.1, 3);
	float slope = (h - h2);
	float rimlit = clamp(slope * 4.2, 0.0, 1.0);
	vec3 alb = mix(vec3(0.050, 0.030, 0.024), vec3(0.14, 0.085, 0.060), smoothstep(0.3, 1.0, h));
	vec3 c = alb * (0.5 + 1.0 * h);
	c += GOLD * vec3(1.0, 0.62, 0.30) * rimlit * rimlit * 0.32 * (0.5 + 0.7 * sun_k);
	c += vec3(0.012, 0.055, 0.05) * (0.4 + h);
	float sheen = pow(clamp(1.0 - 1.0 / (z * 0.9 + 0.4), 0.0, 1.0), 2.0);
	c += skycol(vec2(-0.3, hy + 0.02)) * sheen * 0.12 * (0.4 + h);
	// wet glints: sharp near focus, creamy bokeh when blurred
	float w1 = 1.0 - smoothstep(0.003, 0.02, bw);
	float w2 = smoothstep(0.004, 0.03, bw);
	float gl = 0.0;
	if (!lowq) { gl += w1 * bokeh(g, 0.011, 0.0007, bw, 0.05, 3.0, 0.5) * (1.0 - smoothstep(1.2, 3.0, z)); }
	gl += w2 * bokeh(g, 0.09, 0.003, bw, 0.05, 11.0, 0.4) * 0.3;
	c += mix(GOLD, CYAN, 0.25) * gl * 1.6;
	return c;
}

vec3 mossfar(vec2 g, float z, float bw) {
	float n = fbm(g * vec2(3.0, 3.0), bw * 3.0, 4);
	vec3 c = vec3(0.02, 0.09, 0.08) + vec3(0.03, 0.30, 0.24) * smoothstep(0.35, 0.8, n) * (0.25 + 0.7 * lit);
	c += VIOLET * 0.07 * smoothstep(0.55, 0.9, fbm(g * 2.0 + 5.0, bw * 2.0, 3)) * (0.3 + lit);
	float b1 = bokeh(g, 0.55, 0.012, bw * 2.2, 0.35, 21.0, 1.0);
	float b2 = bokeh(g + 0.3, 0.32, 0.009, bw * 2.2, 0.3, 33.0, 1.0);
	c += mix(TEAL, GOLD, 0.5) * (b1 + b2) * (0.8 + 1.3 * lit);
	return c;
}

// one depth layer of alien fractal trees. returns (premultiplied rgb, alpha)
vec4 tree_layer(vec2 s, float z, float seed, bool lowq, float blurk) {
	float X = cam.x + s.x * z / fl;
	float Yh = cam.y + (s.y - hy) * z / fl;
	float bw = min(world_blur(z), 0.10) * blurk;
	float pix = z / (fl * res.y);
	float sp = 1.05;
	float cell = floor(X / sp + seed * 0.37);
	float hs = h21(vec2(cell, seed));
	if (hs > 0.78) { return vec4(0.0); }
	float H = 0.55 + 0.5 * h21(vec2(cell, seed + 7.0));
	float xc = (cell - seed * 0.37 + 0.5) * sp + (h21(vec2(cell, seed + 3.0)) - 0.5) * 0.3;
	float L = H / 2.3;
	float sway = sin(t * 0.7 + xc * 3.0 + z) * 0.03 * (1.0 + 0.5 * seed);
	vec3 tr = fold_tree(vec2(X - xc, Yh) / L, 1.0, 0.52 + 0.12 * h21(vec2(cell, seed + 5.0)), 0.0, sway, 0.085, 0.16, 1.0);
	float d = tr.x * L;
	float soft = bw + pix;
	float a = smoothstep(soft, -soft, d) * smoothstep(-bw - pix, bw + pix, Yh);
	a *= (1.0 / (1.0 + bw * 14.0)) * (1.0 - smoothstep(0.62, 0.95, abs(fract(X / sp + seed * 0.37) - 0.5) * 2.0));
	float db = tr.z * L;
	float r0 = 0.02 * L * 3.0;
	float rb = sqrt(r0 * r0 + bw * bw * 0.4);
	float bud = smoothstep(rb, rb * 0.6, db + r0) * (r0 * r0) / (rb * rb);
	float thick = 0.085 * L * (1.0 - 0.09 * tr.y) / pow(1.55, tr.y);
	float e = clamp(-d / thick, 0.0, 1.0);
	vec3 body = mix(vec3(0.012, 0.075, 0.08), vec3(0.09, 0.045, 0.20), step(0.6, h21(vec2(cell, seed + 1.0))));
	body *= (0.6 + 0.8 * lit);
	vec3 rim = GOLD * pow(1.0 - e, 3.0) * (0.25 + 0.7 * sun_k) * (0.5 + 0.5 * lit) * (X < xc ? 1.0 : 0.3);
	vec3 tipc = mix(TEAL, CYAN, 0.4) * (0.35 + 1.6 * lit) * smoothstep(1.0, 5.0, tr.y);
	vec3 col = body + rim + tipc * 0.5 * e;
	vec3 glow = mix(TEAL, VIOLET, h21(vec2(cell, seed + 2.0))) * exp(-max(d, 0.0) / (0.03 + bw * 0.6)) * 0.08 * (0.4 + 1.5 * lit);
	col += glow;
	float fogk = 1.0 - exp(-0.15 * z);
	col = mix(col, haze_col(), fogk);
	float win = 1.0 - smoothstep(0.62, 0.95, abs(fract(X / sp + seed * 0.37) - 0.5) * 2.0);
	vec3 budc = mix(CYAN, TEAL, 0.5) * bud * (0.5 + 1.2 * lit) * win;
	return vec4(col * a + budc, clamp(a + bud * 0.5 * win, 0.0, 1.0));
}

vec3 garden(vec2 s, float blurk, bool lowq) {
	vec3 col = skycol(s);
	// ground plane below the horizon
	if (s.y < hy - 0.0005) {
		float z = fl * cam.y / (hy - s.y);
		float gx = cam.x + s.x * z / fl;
		float bw = world_blur(z) * blurk;
		float zs = smoothstep(2.0, 6.5, z);
		vec3 g = soil(vec2(gx, z), z, bw, lowq);
		if (zs > 0.0) { g = mix(g, mossfar(vec2(gx, z), z, bw), zs); }
		vec3 fogc = skycol(vec2(s.x, hy));
		g = mix(g, fogc, max(1.0 - exp(-0.13 * z), smoothstep(3.0, 16.0, z)));
		col = g;
	}
	vec4 L0 = tree_layer(s, 15.0, 1.0, lowq, blurk);
	col = col * (1.0 - L0.a) + L0.rgb;
	vec4 L1 = tree_layer(s, 8.0, 2.0, lowq, blurk);
	col = col * (1.0 - L1.a) + L1.rgb;
	vec4 L2 = tree_layer(s, 4.2, 3.0, lowq, blurk);
	col = col * (1.0 - L2.a) + L2.rgb;
	vec4 L3 = tree_layer(s, 2.3, 4.0, lowq, blurk);
	col = col * (1.0 - L3.a) + L3.rgb;
	return col;
}

// ---- subject ----------------------------------------------------------------------------------------------
vec3 leaf_shade(vec2 W, float pix, out float alpha) {
	float u = tip.x - W.x;
	alpha = 0.0;
	if (u < 0.0) { return vec3(0.0); }
	float uu = max(u, 0.0);
	float mid = tip.y + 0.30 * uu + 0.55 * uu * uu;
	float slope = 0.30 + 1.1 * uu;
	float dp = (W.y - mid) / sqrt(1.0 + slope * slope);
	float w = 0.115 * pow(clamp(uu / 0.34, 0.0, 1.0), 0.62) + 0.0004;
	w *= 1.0 + 0.05 * sin(uu * 70.0);
	float d = abs(dp) - w;
	float bl = world_blur(1.0) * 0.8;
	alpha = smoothstep(max(pix, bl) * 1.2, -max(pix, bl) * 1.2, d);
	float c = clamp(dp / max(w, 1e-4), -1.0, 1.0);
	float ac = abs(c);
	float lv = fract(uu * 30.0 - ac * 4.6);
	float vein1 = smoothstep(0.13, 0.0, abs(lv - 0.5) - 0.34) * smoothstep(0.02, 0.2, ac);
	float lv2 = fract(uu * 96.0 - ac * 12.0 + 0.3);
	float vein2 = smoothstep(0.10, 0.0, abs(lv2 - 0.5) - 0.38) * 0.45;
	float rib = smoothstep(0.075, 0.0, ac) * smoothstep(0.0, 0.12, uu);
	float tex = fbm(vec2(uu * 60.0, c * 6.0), 0.0, 3);
	float trans = pow(1.0 - ac, 0.7) * (0.65 + 0.5 * tex);
	vec3 deep = vec3(0.020, 0.15, 0.10);
	vec3 thin = vec3(0.60, 0.92, 0.28);
	vec3 col = mix(deep, thin, trans * 0.85);
	col *= 1.0 - 0.45 * (vein1 + vein2);
	col = mix(col, vec3(0.9, 0.85, 0.35), rib * 0.55);
	col += GOLD * pow(ac, 5.0) * 1.1;
	col += vec3(0.55, 0.9, 0.5) * smoothstep(0.1, 0.0, uu - 0.02) * 0.4;
	return col * (0.7 + 0.6 * sun_k);
}

float drop_sdf(vec2 W) {
	vec2 pp = W - drop_c;
	pp.y /= (1.0 + drop_st) * (1.0 - drop_sq * 0.5);
	pp.x /= (1.0 + drop_sq * 0.45);
	float de = (length(pp) - drop_r) / (1.0 + 0.5 * drop_st + 0.5 * drop_sq);
	float d = de;
	if (neck > 0.002) {
		vec2 a = tip;
		vec2 b = vec2(drop_c.x, drop_c.y + drop_r * (1.0 + drop_st) * 0.85);
		float hh = clamp(dot(W - a, b - a) / dot(b - a, b - a), 0.0, 1.0);
		float rn = mix(0.0055, 0.019, hh * hh) * neck;
		float nd = length(W - mix(a, b, hh)) - rn;
		d = smin(de, nd, 0.012 + 0.012 * neck);
	}
	return d;
}

vec3 drop_color(vec2 W, float pix, out float alpha) {
	float d = drop_sdf(W);
	float m = smoothstep(pix, -pix, d);
	alpha = m * drop_vis;
	if (alpha < 0.002) { return vec3(0.0); }
	float r = drop_r;
	float e = pix * 2.0;
	vec2 nrm = normalize(vec2(drop_sdf(W + vec2(e, 0.0)) - drop_sdf(W - vec2(e, 0.0)), drop_sdf(W + vec2(0.0, e)) - drop_sdf(W - vec2(0.0, e))) + vec2(1e-7));
	float k = clamp(-d / r, 0.0, 1.0);
	vec2 n2 = nrm * (1.0 - k);
	float dd = 1.0 - k;
	float nz = sqrt(max(1.0 - dot(n2, n2), 0.0));
	vec3 n = vec3(n2, nz);
	float wob = 0.012 * sin(t * 3.1 + n2.y * 4.0);
	// inverted miniature garden seen through the drop (wide-angle, slightly chromatic)
	vec2 q = -n2 * (0.62 + 0.40 * dd * dd) + vec2(0.0, 0.06 + wob);
	vec3 env;
	env.r = garden(q * 1.0, 0.0, true).r;
	env.g = garden(q * 0.985, 0.0, true).g;
	env.b = garden(q * 0.97, 0.0, true).b;
	// absorption / tint: gold core, deep teal toward the rim
	vec3 tint = mix(vec3(1.0, 0.72, 0.30), vec3(0.08, 0.70, 0.52), smoothstep(0.05, 0.9, dd));
	vec3 col = env * tint * 0.62;
	// living, viscous glow inside: slow gold filaments in a teal body
	float fil = fbm(n2 * 3.2 + vec2(t * 0.12, -t * 0.09), 0.0, 4);
	float core = pow(1.0 - clamp(dd, 0.0, 1.0), 1.4);
	col += mix(vec3(0.05, 0.60, 0.50), GOLD, smoothstep(0.35, 0.8, fil) * 0.8 + 0.15 * sin(t * 1.7)) * (core * 0.7 + 0.12);
	// caustic crescent on the side away from the light, and a hot focus below the centre
	float cs = smoothstep(0.50, 0.80, dd) * smoothstep(1.0, 0.86, dd) * smoothstep(0.15, -0.75, n.y);
	col += vec3(1.0, 0.85, 0.5) * cs * 1.5;
	col += GOLD * smoothstep(0.5, 0.0, length(n2 - vec2(0.14, -0.30))) * 0.5;
	// fresnel + rim darkening (TIR)
	float fr = pow(1.0 - nz, 3.0);
	col += mix(CYAN, GOLD, 0.6) * fr * 0.9;
	col *= 1.0 - 0.7 * smoothstep(0.84, 1.0, dd) * (1.0 - fr * 0.6);
	// speculars: softbox window + pin highlight + secondary
	vec2 wq = rot2(n2 - vec2(-0.40, 0.42), 0.55);
	float win = smoothstep(0.15, 0.10, abs(wq.x)) * smoothstep(0.075, 0.04, abs(wq.y));
	col += vec3(1.0, 0.97, 0.88) * win * 2.6;
	col += vec3(1.0) * smoothstep(0.05, 0.0, length(n2 - vec2(-0.55, 0.28))) * 2.0;
	col += vec3(0.7, 1.0, 0.95) * smoothstep(0.10, 0.0, length(n2 - vec2(0.55, -0.50))) * 0.9;
	return col;
}

vec3 sprout_color(vec2 W, float pix, out float alpha, out vec3 glow) {
	alpha = 0.0; glow = vec3(0.0);
	if (grow <= 0.001) { return vec3(0.0); }
	float bw = world_blur(1.0);
	float L = 0.135;
	float sway = sin(t * 1.1) * 0.025 * smoothstep(0.3, 1.0, grow);
	vec3 tr = fold_tree(vec2(W.x, W.y + 0.004) / L, grow, 0.46, 1.5, sway, 0.11, 0.24, 1.0);
	float d = tr.x * L;
	float soft = bw * 0.6 + pix * 1.3;
	alpha = smoothstep(soft, -soft, d) * smoothstep(0.0, 0.014, W.y + 0.004) / (1.0 + bw * 10.0);
	float lvl = tr.y;
	float thick = 0.11 * L * (1.0 - 0.09 * lvl) / pow(1.55, lvl);
	float e = clamp(-d / max(thick, 1e-4), 0.0, 1.0);
	float lvk = lvl / 5.0;
	vec3 base = mix(vec3(0.015, 0.30, 0.18), vec3(0.06, 0.62, 0.45), lvk);
	vec3 core = mix(vec3(1.0, 0.84, 0.40), vec3(0.50, 1.0, 0.82), lvk);
	vec3 col = base * (0.45 + 0.6 * (1.0 - e * 0.5));
	col += core * pow(e, 1.8) * 0.40;               // luminous core of the translucent stem
	col += GOLD * pow(1.0 - e, 3.5) * 0.5;         // backlit rim
	float cells = fbm(vec2(W.x, W.y) * 260.0, bw * 260.0, 3);
	col *= 0.85 + 0.35 * cells;
	// translucent leaves at the tips: veined, glowing from within, with a dew bead
	float db = tr.z * L;
	float bm = smoothstep(pix * 1.3, -pix * 1.3, db) * smoothstep(0.0, 0.4, grow);
	float lk = clamp(-db / 0.012, 0.0, 1.0);
	vec3 leafc = mix(vec3(1.0, 0.86, 0.45), vec3(0.20, 0.90, 0.62), smoothstep(0.0, 0.8, lk)) * (0.8 + 0.2 * sin(t * 2.0 + lvl));
	col = mix(col, leafc, bm * 0.92);
	col += vec3(1.0) * smoothstep(0.004, 0.0, db + 0.002) * 0.5 * smoothstep(0.5, 1.0, grow);
	alpha = max(alpha, bm * 0.92);
	glow = mix(TEAL, GOLD, 0.30) * exp(-max(d, 0.0) / (0.02 + bw * 0.8)) * 0.10 * smoothstep(0.0, 0.3, grow);
	return col * (0.85 + 0.35 * sun_k);
}

vec3 impact_ground(vec2 s) {
	vec3 add = vec3(0.0);
	if (s.y >= hy - 0.0005) { return add; }
	float z = fl * cam.y / (hy - s.y);
	float gx = cam.x + s.x * z / fl;
	vec2 gp = vec2(gx, z - 1.0);
	float rr = length(gp);
	float tau = max(imp, 0.0);
	float bw = world_blur(z);
	float arm = step(0.0, imp);
	float R = 0.012 + 0.085 * (1.0 - exp(-tau * 2.0));
	float ring = exp(-pow((rr - R) / (0.007 + bw * 0.5), 2.0)) * exp(-tau * 1.4) * arm;
	float ring2 = exp(-pow((rr - R * 0.62) / (0.006 + bw * 0.5), 2.0)) * exp(-tau * 1.9) * arm;
	float pool = exp(-rr / (0.02 + 0.03 * tau + bw * 0.5)) * arm * (0.2 + 0.7 * exp(-tau * 0.7));
	add += mix(vec3(1.0, 0.78, 0.35), TEAL, smoothstep(0.0, 0.08, rr)) * pool * 0.9;
	add += GOLD * (ring + ring2 * 0.6) * 0.55;
	float sp = exp(-length(vec2(gp.x * 0.9, gp.y * 1.6)) / 0.06) * smoothstep(0.0, 0.5, grow) * 0.45;
	add += mix(TEAL, GOLD, 0.35) * sp;
	float dh = drop_c.y;
	float cx = exp(-length(vec2(gp.x - 0.02, gp.y * 1.5)) / (0.03 + dh * 0.1)) * (1.0 - arm) * drop_vis * smoothstep(0.0, 0.12, dh) * 0.35;
	add += GOLD * cx;
	return add;
}

float wetmask(vec2 s) {
	if (s.y >= hy - 0.0005 || imp < 0.0) { return 0.0; }
	float z = fl * cam.y / (hy - s.y);
	float gx = cam.x + s.x * z / fl;
	float rr = length(vec2(gx, z - 1.0));
	float Rw = 0.02 + 0.06 * (1.0 - exp(-imp * 1.2));
	return smoothstep(Rw, Rw * 0.2, rr);
}

vec3 spray(vec2 s) {
	vec3 acc = vec3(0.0);
	if (imp < 0.0 || imp > 2.4) { return acc; }
	for (int i = 0; i < 28; i++) {
		float fi = float(i);
		float h1 = h11(fi * 1.37 + 3.0);
		float h2 = h11(fi * 2.91 + 7.0);
		float h3 = h11(fi * 5.13 + 1.0);
		float ang = 0.35 + h1 * (3.1416 - 0.7);
		float sp = 0.035 + 0.11 * h2 * h2;
		vec2 v = vec2(cos(ang), sin(ang) * 1.5) * sp;
		float life = 0.8 + 1.4 * h3;
		float tt = imp - h2 * 0.06;
		if (tt < 0.0 || tt > life) { continue; }
		vec2 P = vec2(v.x * tt, v.y * tt - 0.5 * 0.16 * tt * tt);
		if (P.y < -0.002) { continue; }
		vec2 sp2 = vec2(fl * (P.x - cam.x), hy + fl * (P.y - cam.y));
		float rad = (0.0012 + 0.0022 * h3) * fl;
		rad = sqrt(rad * rad + pow(world_blur(1.0) * fl * 0.4, 2.0));
		float d = length(s - sp2);
		float k = (rad * rad) / (d * d + rad * rad);
		float fade = smoothstep(life, life * 0.4, tt) * smoothstep(0.0, 0.05, tt);
		vec3 c = h1 > 0.5 ? mix(GOLD, vec3(1.0, 0.95, 0.7), 0.5) : mix(TEAL, CYAN, 0.5);
		if (h2 < 0.3) { c = vec3(0.65, 0.42, 0.22); }
		acc += c * k * k * fade * 2.2;
	}
	return acc;
}

vec3 rays(vec2 s) {
	vec2 sp = vec2(-0.62 - cam.x * 0.2, 0.34);
	vec2 v = s - sp;
	float r = length(v);
	float a = atan(v.y, v.x);
	float n = vnoise(vec2(a * 6.0 + t * 0.04, 1.0)) * 0.55 + vnoise(vec2(a * 17.0 - t * 0.06, 3.0)) * 0.3 + vnoise(vec2(a * 41.0, 5.0 + t * 0.05)) * 0.15;
	float shaft = pow(smoothstep(0.35, 0.95, n), 1.6);
	float fall = exp(-r * 0.95);
	return (GOLD * 0.9 + TEAL * 0.15) * shaft * fall * 0.26 * sun_k;
}

vec3 dust(vec2 s) {
	vec3 acc = vec3(0.0);
	for (int l = 0; l < 3; l++) {
		float fl_ = float(l);
		float z = 0.65 + fl_ * 1.1;
		float k = world_blur(z) * 1.5 + 0.0006;
		vec2 g = vec2(cam.x + s.x * z / fl, cam.y + (s.y - hy) * z / fl);
		g += vec2(t * 0.012 * (1.0 + fl_), sin(t * 0.3 + fl_) * 0.01 - t * 0.006);
		g.y += sin(g.x * 9.0 + t * 0.5 + fl_ * 3.0) * 0.006;
		float sp = 0.16 * z;
		float b = bokeh(g, sp, 0.004 * z, k, 0.16, 41.0 + fl_ * 9.0, 1.0);
		vec2 sunv = s - vec2(-0.62, 0.34);
		float inray = 0.45 + 0.9 * exp(-length(sunv) * 0.8);
		acc += mix(GOLD, vec3(1.0, 0.95, 0.8), 0.4) * b * inray * (1.4 - 0.25 * fl_);
	}
	return acc;
}

// out-of-focus foreground grass blades, creamy and backlit
vec3 fgblades(vec3 col, vec2 s) {
	float soft = 0.030 * aperture * abs(1.0 - 0.45 / focus) + 0.004;
	for (int i = 0; i < 4; i++) {
		float fi = float(i);
		float bx = -0.80 + fi * 0.5 + 0.03 * h11(fi * 3.0);
		if (i == 1) { bx = -0.52; }
		if (i == 2) { bx = 0.74; }
		if (i == 3) { bx = 0.97; }
		bx -= cam.x * fl * 0.4;
		float H = (i == 0 ? 0.95 : (i == 1 ? 0.55 : (i == 2 ? 0.8 : 0.5)));
		float lean = (i == 0 ? 0.30 : (i == 1 ? 0.15 : (i == 2 ? -0.35 : -0.2)));
		float y01 = clamp((s.y + 0.6) / H, 0.0, 1.0);
		float xc = bx + lean * y01 * y01 + 0.015 * sin(t * 0.5 + fi * 2.0) * y01;
		float w = 0.07 * pow(1.0 - y01, 0.9) + 0.0005;
		float d = abs(s.x - xc) - w;
		float inside = step(y01, 0.999);
		float a = smoothstep(soft, -soft, d) * inside * (1.0 / (1.0 + soft * 4.0)) * 0.92;
		float e = clamp(-d / max(w, 1e-3), 0.0, 1.0);
		vec3 c = mix(vec3(0.015, 0.09, 0.07), vec3(0.04, 0.17, 0.10), e);
		c += GOLD * smoothstep(0.55, 0.0, abs(e - 0.12)) * 0.45 * sun_k * (s.x < xc ? 1.0 : 0.25);
		col = mix(col, c, a);
	}
	return col;
}

void fragment() {
	vec2 s = vec2((FRAGCOORD.x - 0.5 * res.x) / res.y, -(FRAGCOORD.y - 0.5 * res.y) / res.y);
	vec2 W = vec2(cam.x + s.x / fl, cam.y + (s.y - hy) / fl);
	float pix = 1.0 / (fl * res.y);
	vec3 col = garden(s, 1.0, false);
	float wet = wetmask(s);
	col *= 1.0 - 0.45 * wet;
	col += impact_ground(s);
	float la = 0.0;
	vec3 lc = leaf_shade(W, pix, la);
	la *= leaf_vis;
	col = mix(col, lc, la);
	float sa; vec3 sg;
	vec3 sc = sprout_color(W, pix, sa, sg);
	col += sg;
	col = mix(col, sc, sa);
	float da;
	vec3 dc = drop_color(W, pix, da);
	float dd0 = length(vec2(W.x - drop_c.x, (W.y - drop_c.y) / (1.0 + drop_st))) / drop_r;
	col += mix(TEAL, GOLD, 0.4) * exp(-max(dd0 - 1.0, 0.0) * 3.5) * 0.14 * drop_vis;
	col = mix(col, dc, da);
	col += spray(s);
	col = fgblades(col, s);
	col += rays(s);
	col += dust(s);
	if (imp >= 0.0) {
		vec2 ip = vec2(fl * (0.0 - cam.x), hy + fl * (0.0 - cam.y));
		float tau = imp;
		float h = exp(-length((s - ip) * vec2(1.0, 1.7)) * 3.2) * exp(-tau * 1.1) * 0.22
			+ exp(-length((s - ip) * vec2(1.0, 1.7)) * 11.0) * exp(-tau * 2.5) * 0.45;
		col += mix(GOLD, vec3(1.0, 0.97, 0.85), 0.5) * h;
		float colm = exp(-abs(s.x - ip.x) * 28.0) * smoothstep(0.0, 0.5, s.y - ip.y) * exp(-(s.y - ip.y) * 2.5) * exp(-tau * 1.6) * 0.3;
		col += GOLD * colm;
	}
	COLOR = vec4(col, 1.0);
}
