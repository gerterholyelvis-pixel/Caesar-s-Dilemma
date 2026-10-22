shader_type canvas_item;
// THE OBSIDIAN DEEP: one-pass painterly low-key cavern. Layers: backdrop, far ruins, ridge, floor, 3 shard layers with reflections, foreground silhouettes.
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform vec2 par = vec2(0.0);
uniform float flick = 1.0;
uniform float t_now = 0.0;

float h11(float n){ return fract(sin(n * 127.1) * 43758.5453); }
float h21(vec2 p){ p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
vec2 h22(vec2 p){ float n = h21(p); return vec2(n, h21(p + n + 7.7)); }
float vn(vec2 p){ vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1,0)), f.x), mix(h21(i + vec2(0,1)), h21(i + vec2(1,1)), f.x), f.y); }
float fbm(vec2 p){ float a = 0.5, s = 0.0; for (int i = 0; i < 4; i++){ s += a * vn(p); p = p * 2.03 + 11.7; a *= 0.5; } return s; }
float vn1(float x){ float i = floor(x), f = fract(x); f = f*f*(3.0-2.0*f); return mix(h11(i), h11(i+1.0), f); }

const vec3 EMBER = vec3(1.0, 0.30, 0.07);
const vec3 COLD = vec3(0.36, 0.48, 0.70);

float fissure_band(float x){
	float n = fbm(vec2(x * 2.2, 3.1));
	return smoothstep(0.30, 0.75, n);
}
float ridge_y(float x){
	float k = vn1(x * 5.0) * 0.6 + vn1(x * 13.0) * 0.3 + vn1(x * 31.0) * 0.1;
	float spike = pow(abs(sin(x * 9.0 + vn1(x * 2.0) * 6.0)), 3.0);
	return 0.605 - 0.07 * k - 0.06 * spike * vn1(x * 3.0 + 4.0);
}

float ruins(vec2 p, float asp){
	float m = 0.0;
	float xc = 0.70 * asp, a = 0.075, ys = 0.46, tk = 0.011;
	vec2 q = vec2(p.x - xc, p.y);
	float rl = abs(length(q - vec2(a, ys)) - 2.0 * a);
	float rr = abs(length(q + vec2(a, -ys)) - 2.0 * a);
	float arch = ((q.x < 0.0 ? rl : rr) < tk && p.y < ys) ? 1.0 : 0.0;
	arch += (abs(abs(q.x) - a) < tk * 1.3 && p.y > ys - 0.02 && p.y < 0.64) ? 1.0 : 0.0;
	arch += (abs(q.x) < a + 0.02 && abs(p.y - 0.43) < 0.004) ? 1.0 : 0.0;
	m = max(m, arch);
	vec2 c = vec2(-0.20 * asp, 0.78);
	float d = length(p - c);
	float ang = atan(p.y - c.y, p.x - c.x);
	float ribs = ((abs(d - 0.58) < 0.014 * (1.0 + 0.5 * sin(ang * 3.0))) && (fract(ang * 5.1) < 0.40) && p.x < 0.46 * asp && p.y < 0.62) ? 1.0 : 0.0;
	m = max(m, ribs);
	float sx = (p.x - 0.86 * asp) * 18.0;
	float step_y = 0.64 - floor(clamp(sx, 0.0, 6.0)) * 0.012 - 0.002;
	float stair = (sx > 0.0 && sx < 6.0 && p.y > step_y - 0.012 && p.y < 0.64) ? 1.0 : 0.0;
	m = max(m, stair);
	return clamp(m, 0.0, 1.0);
}

vec3 fogcol(float y, float x){
	float glow = exp(-pow((y - 0.61) / 0.12, 2.0));
	return vec3(0.030, 0.026, 0.040) + EMBER * 0.11 * glow * (0.6 + 0.8 * fissure_band(x)) * flick;
}


vec3 env(vec3 R, float gx){
	float back = smoothstep(0.55, -0.55, R.z);
	float hor = exp(-pow((R.y + 0.02) / 0.30, 2.0));
	vec3 e = EMBER * 0.17 * hor * back * (0.45 + 0.9 * fissure_band(gx)) * flick;
	e += COLD * 0.12 * smoothstep(0.25, 0.95, R.y) * (0.4 + 0.6 * back);
	e += vec3(0.65, 0.78, 1.0) * pow(max(dot(R, normalize(vec3(-0.55, 0.62, -0.5))), 0.0), 90.0) * 0.8;
	return e;
}
float dustmask(vec2 q){ return smoothstep(0.38, 0.85, fbm(q * 1.7 + 4.0)) * (0.6 + 0.4 * fbm(q * 9.0)); }

vec4 shard(vec2 p, float asp, float base, float scale, float lpar, float hmax, float wmax, float fog, float seed, float rim, float centre_clear, bool refl, float dxb){
	float y = p.y;
	float yy = y;
	float rippl = dxb;
	float att = 1.0;
	if (refl){
		float dd = y - base;
		rippl += (vn(vec2(p.x * 40.0, dd * 90.0 + seed)) - 0.5) * 0.008 * (0.4 + dd * 8.0) + (vn(vec2(p.x * 3.0, dd * 20.0)) - 0.5) * 0.004;
		yy = base - dd * 1.05;
		att = 0.55 * exp(-dd * 4.5) * (1.0 - 0.75 * dustmask(vec2(p.x * 2.0, dd * 6.0 + seed)));
	}
	float px = p.x + rippl + par.x * lpar * asp;
	float xs = px * scale;
	float cell = floor(xs);
	float lx = fract(xs);
	vec2 hh = h22(vec2(cell, seed));
	vec2 h2 = h22(vec2(cell + 31.0, seed * 1.7));
	float ucx = ((cell + 0.5) / scale - par.x * lpar * asp) / asp;
	float clear = 1.0 - centre_clear * (1.0 - smoothstep(0.08, 0.26, abs(ucx - 0.5)));
	float present = step(0.04 + (1.0 - clear) * 0.85, hh.x);
	float ht = hmax * (0.22 + 0.78 * hh.y * hh.y + 0.1 * h2.x);
	float w = wmax * (0.5 + 0.5 * h2.y);
	float h = base - yy;
	float hn = h / max(ht, 0.05);
	float lean = (h2.x - 0.5) * 0.35;
	float lxs = lx - lean * h * scale * 0.6;
	lxs += (fbm(vec2(hn * 4.0 + cell * 3.7, seed * 2.0)) - 0.5) * 0.035;
	float c = 0.5;
	float hl = h / ht;
	float we = w * (1.0 - 0.28 * clamp(hl, 0.0, 1.0));
	float pk = c + (hh.y - 0.5) * 0.36;
	float kl = ht * (0.9 + hh.x * 1.6), kr = ht * (0.9 + h2.y * 1.6);
	float top = ht - (lxs < pk ? (pk - lxs) * kl : (lxs - pk) * kr);
	top += (vn(vec2(lxs * 16.0 + cell * 5.0, seed)) - 0.5) * ht * 0.012 - 0.02 * ht * smoothstep(0.7, 0.9, vn(vec2(lxs * 33.0, cell + seed)));
	float inside = step(abs(lxs - c), we) * step(0.0, h) * step(h, top) * present;
	if (inside < 0.5) return vec4(0.0);
	float split = c + (h2.x - 0.5) * 0.3 + (hl - 0.3) * (hh.y - 0.5) * 0.5;
	float side = lxs < split ? 0.0 : 1.0;
	float capH = ht * 0.16 + 0.01;
	float isCap = step(top - capH * (0.6 + hh.x), h);
	float fid = side + 2.0 * isCap + 4.0 * floor(hl * 2.2 + h2.y);
	float fb = 0.35 + 0.65 * h21(vec2(fid, cell + seed));
	float foot = exp(-hl * 5.5);

	// conchoidal normal: faceted base, rounded toward the edges, curved ripple rings and glassy micro-undulation
	float u = (lxs - c) / max(we, 0.01);
	float bulge = sign(u) * pow(abs(u), 3.0);
	vec2 nxy = vec2((side < 0.5 ? -0.42 : 0.42) + bulge * 1.15, 0.10 + 0.25 * hl);
	if (isCap > 0.5) nxy = vec2(sign(lxs - pk) * 0.55 + bulge * 0.5, 0.85);
	vec2 pt = vec2(0.5 + (h21(vec2(fid, 3.0 + cell)) - 0.5) * 0.4, ht * 0.5 * h21(vec2(cell, fid)));
	vec2 dv = vec2((lxs - pt.x) * 3.0, (h - pt.y) / max(ht, 0.05) * 2.0);
	float r = length(dv) + 0.001;
	float ph = r * 8.0 + h21(vec2(cell, 9.0)) * 6.0;
	nxy += dv / r * cos(ph) * exp(-r * 1.0) * 0.42;
	vec2 qn = vec2(lxs * 7.0 + cell * 3.0, hn * 7.0 + seed);
	nxy += vec2(vn(qn + vec2(0.3, 0.0)) - vn(qn - vec2(0.3, 0.0)), vn(qn + vec2(0.0, 0.3)) - vn(qn - vec2(0.0, 0.3))) * 0.55;
	vec3 n = normalize(vec3(nxy, 1.0));
	vec3 R = vec3(2.0 * n.z * n.x, 2.0 * n.z * n.y, 2.0 * n.z * n.z - 1.0);
	float F = 0.05 + 1.25 * pow(1.0 - n.z, 2.0);
	vec3 reflc = env(R, ucx) * F * (0.55 + 0.9 * fb) * 2.4;
	vec3 Hc = normalize(normalize(vec3(-0.5, 0.65, 0.6)) + vec3(0.0, 0.0, 1.0));
	vec3 Hr = normalize(normalize(vec3(0.65, 0.1, 0.5)) + vec3(0.0, 0.0, 1.0));
	vec3 spec = vec3(0.75, 0.86, 1.0) * pow(max(dot(n, Hc), 0.0), 140.0) * 0.9 * (0.4 + 0.6 * fb);
	spec += EMBER * pow(max(dot(n, Hr), 0.0), 50.0) * 0.14 * foot * flick;

	// body: dark blue-violet glass with smoky inclusions and flow banding seen through the surface
	float smoke = fbm(vec2(lxs * 3.0 + cell * 2.3, hn * 3.2 + seed * 3.0));
	float smoke2 = fbm(vec2(lxs * 7.0 - cell, hn * 8.0 + 5.0 + seed));
	vec3 col = vec3(0.006, 0.007, 0.014);
	col += vec3(0.022, 0.018, 0.046) * smoothstep(0.35, 0.78, smoke) * (0.5 + 0.5 * smoke2);
	float band = pow(0.5 + 0.5 * sin(hn * 26.0 + smoke * 14.0 + lxs * 11.0), 5.0);
	col += vec3(0.008, 0.010, 0.020) * band * smoke;
	col += EMBER * (0.040 * foot * (0.45 + smoke2) * flick * fb);
	float vv = abs(fbm(vec2(lxs * 2.2 + cell * 3.1 + smoke * 0.3, hn * 3.0 + seed)) - 0.5);
	float hasv = step(0.55, h21(vec2(cell, 5.0 + seed)));
	float vein = (1.0 - smoothstep(0.0, 0.018, vv)) * hasv;
	col += EMBER * (vein * 0.28 + (1.0 - smoothstep(0.0, 0.05, vv)) * 0.05 * hasv) * flick * (0.4 + 0.6 * foot) * clamp(rim, 0.0, 1.0);
	col += reflc + spec;

	// soft, broken cold rim where the glass thins at its edges
	float ex = (we - abs(lxs - c)) / scale;
	float ey = (top - h) * 0.45 / max(1.0, kl / 0.8 + 0.2);
	float ed = min(ex, ey);
	float brk = pow(vn(vec2(h * 38.0 + cell * 7.0, lxs * 9.0 + seed)), 1.4) * 1.7;
	float rimv = exp(-ed / (0.0032 + 0.0016 * rim)) * brk;
	vec3 rimc = mix(COLD, EMBER, side * 0.55 * foot + 0.1);
	col += rimc * rimv * 0.62 * rim * (0.55 + 0.45 * flick);
	col += COLD * 0.05 * exp(-abs(lxs - split) / scale / 0.004) * rim * brk;
	col = mix(col, fogcol(y, ucx), fog);
	return vec4(col, att);
}

vec3 embers(vec2 p, float tt){
	vec3 acc = vec3(0.0);
	for (int k = 0; k < 4; k++){
		float fk = float(k);
		float sc = 7.0 + fk * 6.0;
		vec2 q = vec2(p.x * sc, p.y * sc);
		q.y += tt * (0.30 + 0.16 * fk);
		q.x += sin(tt * 0.3 + fk * 2.0 + q.y * 0.5) * 0.4 + tt * 0.05 * fk;
		vec2 id = floor(q), fq = fract(q);
		vec2 hr = h22(id + fk * 17.0);
		float hs = h21(id * 1.31 + fk * 5.0);
		vec2 d = fq - (0.34 + 0.32 * hr);
		float streak = fk > 2.5 ? 1.0 : 1.0 + 1.8 * hs * hs * (1.0 + 0.3 * fk);
		d.y /= streak;
		d.x -= d.y * 0.25;
		float sz = fk > 2.5 ? 0.10 + 0.09 * hs : 0.02 + 0.05 * hs;
		float dist = length(d);
		float tw = 0.5 + 0.5 * sin(tt * (1.0 + hr.x * 3.0) + hr.y * 30.0);
		float live = step(0.80 - 0.05 * fk, hr.y);
		float core = smoothstep(sz, 0.0, dist);
		float lum = (0.35 + 1.4 * hs * hs) / sqrt(streak);
		if (fk > 2.5){
			core = smoothstep(sz, sz * 0.8, dist) * (0.45 + 0.8 * smoothstep(sz * 0.55, sz, dist)) * 0.5;
			lum = 0.35 * (0.5 + hs);
		}
		vec3 ec = mix(vec3(1.0, 0.62, 0.22), vec3(0.85, 0.16, 0.04), hr.x);
		float nearglow = 0.35 + 0.8 * exp(-pow((p.y - 0.62) / 0.3, 2.0));
		acc += ec * core * live * tw * lum * 0.55 * nearglow;
	}
	for (int k = 0; k < 2; k++){
		float fk = float(k);
		vec2 q = vec2(p.x * (22.0 + 14.0 * fk) + tt * (0.25 + 0.2 * fk), p.y * (22.0 + 14.0 * fk) - tt * (0.12 + 0.07 * fk));
		q.x += sin(tt * 0.5 + q.y * 0.8) * 0.5;
		vec2 id = floor(q), fq = fract(q); vec2 hr = h22(id + 90.0 + fk * 9.0);
		vec2 d = fq - (0.25 + 0.5 * hr);
		d.x *= 1.0 + 1.5 * hr.x;
		float dist = length(d);
		acc += vec3(0.55, 0.52, 0.55) * smoothstep(0.08, 0.0, dist) * step(0.88, hr.y) * 0.11 * (0.4 + 0.6 * sin(tt * 0.7 + hr.x * 20.0)) * (0.5 + exp(-pow((p.y - 0.62) / 0.25, 2.0)));
	}
	return acc;
}

void fragment(){
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	float asp = res.x / res.y;
	vec2 uv = UV;
	vec2 p = vec2(uv.x * asp, uv.y);
	float H = 0.64;
	float tt = t_now;
	vec3 col;

	float sm = fbm(vec2(p.x * 1.6 + tt * 0.01, p.y * 2.5 - tt * 0.005));
	float sm2 = fbm(vec2(p.x * 4.0 - tt * 0.015, p.y * 5.0 + 3.0));
	col = mix(vec3(0.006, 0.007, 0.012), vec3(0.030, 0.026, 0.040), smoothstep(0.0, 0.6, p.y));
	col += vec3(0.022, 0.025, 0.040) * sm * smoothstep(0.7, 0.2, p.y) * 0.9;
	col += EMBER * 0.17 * exp(-pow((p.y - 0.56) / 0.17, 2.0)) * (0.5 + 0.9 * sm) * (0.45 + 0.8 * fissure_band(uv.x)) * flick;
	col += EMBER * 0.030 * exp(-pow((p.y - 0.58) / 0.30, 2.0)) * sm2 * flick;
	col += COLD * 0.012 * pow(vn(vec2(p.x * 3.0 + p.y * 1.2, 1.0)), 3.0) * smoothstep(0.65, 0.1, p.y);

	float rm = ruins(p, asp);
	vec3 ruinC = mix(vec3(0.016, 0.017, 0.026), fogcol(p.y, uv.x), 0.55);
	col = mix(col, ruinC + COLD * 0.012 * (0.5 + sm), rm * 0.92);

	float ry = ridge_y(uv.x * 2.0 + par.x * 3.0);
	float below = smoothstep(ry - 0.0015, ry + 0.0015, p.y);
	vec3 ridgeC = mix(vec3(0.008, 0.009, 0.014), fogcol(p.y, uv.x) * 0.7, 0.35) + COLD * 0.010 * fbm(p * 14.0);
	float edge = exp(-abs(p.y - ry) * 260.0) * fissure_band(uv.x);
	float edgeline = exp(-abs(p.y - (ry + 0.012 + 0.02 * vn1(uv.x * 12.0))) * 500.0) * step(0.62, vn1(uv.x * 25.0 + 8.0));
	col = mix(col, ridgeC, below);
	col += EMBER * (edge * 0.55 + edgeline * 0.9) * flick;
	float fy = H - 0.05 - 0.05 * vn1(uv.x * 6.0);
	float fis = exp(-pow((p.y - fy) / 0.0025, 2.0)) * step(0.55, vn1(uv.x * 9.0 + 2.0)) * below;
	col += EMBER * fis * 0.8 * flick;

	if (p.y > H){
		float d = p.y - H;
		float fz = d + 0.035;
		vec2 fp = vec2((p.x - 0.5 * asp) / fz, 1.0 / fz) * 0.55;
		vec3 fl = vec3(0.020, 0.022, 0.032);
		float sheen = fbm(vec2(fp.x * 0.5, fp.y * 0.35) + par.x * 5.0);
		fl += COLD * 0.07 * smoothstep(0.3, 0.8, sheen) * exp(-d * 2.0);
		fl += vec3(0.012, 0.014, 0.022) * (1.0 - d);
		float rp = (vn(vec2(p.x * 60.0, d * 12.0)) - 0.5) * 0.02 * (0.3 + d * 3.0);
		float bg = fissure_band((p.x + rp) / asp);
		float streak = bg * exp(-d * 4.5) * (0.35 + 0.65 * vn(vec2(p.x * 25.0, d * 4.0 + tt * 0.2)));
		fl += EMBER * 0.26 * streak * flick;
		// polished-floor reflection of the glowing ridge fissures, wavering with depth
		float yr = H - d * 0.9 + rp * 0.5;
		float rfis = exp(-pow((yr - fy) / (0.004 + d * 0.03), 2.0)) * step(0.55, vn1(uv.x * 9.0 + 2.0));
		float redge = exp(-abs(yr - ry) * (120.0 / (1.0 + d * 8.0))) * fissure_band(uv.x);
		fl += EMBER * (rfis * 0.32 + redge * 0.22) * flick * exp(-d * 3.5);
		// fine ash film: matt grey patches that kill the reflection, soft dust streaks
		float dust = dustmask(fp * 0.6);
		fl = mix(fl, vec3(0.040, 0.037, 0.045) * (0.6 + 0.8 * fbm(fp * 5.0)), dust * 0.55);
		// cracks: coarse Voronoi plates plus a finer hairline net, ember glimmer deep inside
		vec2 g = floor(fp * 1.3), f = fract(fp * 1.3);
		float d1 = 9.0, d2 = 9.0; vec2 cid = vec2(0.0);
		for (int j = -1; j <= 1; j++){ for (int i = -1; i <= 1; i++){
			vec2 o = vec2(float(i), float(j));
			vec2 pp = o + h22(g + o) - f;
			float dd2 = dot(pp, pp);
			if (dd2 < d1){ d2 = d1; d1 = dd2; cid = g + o; } else if (dd2 < d2){ d2 = dd2; }
		} }
		float ce = sqrt(d2) - sqrt(d1);
		float wob = (vn(fp * 9.0) - 0.5) * 0.02;
		float crack = 1.0 - smoothstep(0.0, 0.014 + 0.006 * h21(cid), ce + wob);
		float lit = step(0.80, h21(cid));
		vec2 g2 = floor(fp * 4.7), f2 = fract(fp * 4.7);
		float e1 = 9.0, e2 = 9.0; vec2 cid2 = vec2(0.0);
		for (int j = -1; j <= 1; j++){ for (int i = -1; i <= 1; i++){
			vec2 o = vec2(float(i), float(j));
			vec2 pp = o + h22(g2 + o + 13.0) - f2;
			float dd2 = dot(pp, pp);
			if (dd2 < e1){ e2 = e1; e1 = dd2; cid2 = g2 + o; } else if (dd2 < e2){ e2 = dd2; }
		} }
		float ce2 = sqrt(e2) - sqrt(e1);
		float hair = (1.0 - smoothstep(0.0, 0.030, ce2 + wob * 2.0)) * step(0.35, h21(cid2 + 3.0));
		fl = mix(fl, vec3(0.003, 0.003, 0.006), crack * 0.85 + hair * 0.45);
		fl += (EMBER * 0.42 * lit * flick + COLD * 0.05) * crack * (1.0 - smoothstep(0.0, 0.006, ce)) * exp(-d * 1.2);
		fl += EMBER * 0.10 * flick * hair * step(0.82, h21(cid2)) * exp(-d * 1.5) * (1.0 - smoothstep(0.0, 0.012, ce2));
		fl += COLD * 0.04 * pow(1.0 - smoothstep(0.0, 0.05, ce + 0.04), 2.0) * (1.0 - dust) * exp(-d * 3.0);
		fl = mix(fl, fogcol(p.y, uv.x), exp(-d * 9.0) * 0.8);
		col = fl;
	}

	for (int L = 0; L < 3; L++){
		float base = 0.0, scale = 0.0, lp = 0.0, hmax = 0.0, wmax = 0.0, fog = 0.0, seed = 0.0, rim = 0.0, cc = 0.0;
		if (L == 0){ base = 0.645; scale = 3.0; lp = 0.3; hmax = 0.40; wmax = 0.36; fog = 0.55; seed = 1.0; rim = 0.6; cc = 0.0; }
		if (L == 1){ base = 0.705; scale = 2.6; lp = 0.7; hmax = 0.55; wmax = 0.34; fog = 0.35; seed = 2.0; rim = 0.55; cc = 0.6; }
		if (L == 2){ base = 0.775; scale = 1.35; lp = 1.2; hmax = 0.62; wmax = 0.32; fog = 0.12; seed = 3.0; rim = 0.85; cc = 0.95; }
		if (p.y > base){
			// reflection: three taps whose spread grows with distance below the shard foot (blurry polished glass)
			float bl = 0.002 + (p.y - base) * 0.05;
			vec4 acc = vec4(0.0);
			for (int tp = -1; tp <= 1; tp++){
				vec4 s = shard(p, asp, base, scale, lp, hmax, wmax, fog, seed, rim, cc, true, float(tp) * bl);
				acc += vec4(s.rgb * s.a, s.a);
			}
			col = col * (1.0 - acc.a / 3.0) + acc.rgb / 3.0;
		} else {
			vec4 s = shard(p, asp, base, scale, lp, hmax, wmax, fog, seed, rim, cc, false, 0.0);
			if (s.a > 0.0) col = s.rgb;
		}
	}

	// volumetric smoke and light shafts from the distant fissures
	{
		float below_h = max(0.64 - p.y, 0.0);
		float xr = p.x / asp - 0.5;
		float v = fbm(vec2(p.x * 5.0 + below_h * xr * 9.0 + tt * 0.02, below_h * 1.2 - tt * 0.01));
		float shaft = smoothstep(0.42, 0.85, v) * fissure_band(uv.x) * exp(-below_h * 2.6) * smoothstep(0.0, 0.05, 0.66 - p.y);
		col += EMBER * 0.07 * shaft * flick;
		col += COLD * 0.010 * shaft * 0.5;
		float mist = fbm(vec2(p.x * 2.2 - tt * 0.012, p.y * 3.5 + 7.0 + tt * 0.004));
		col = mix(col, fogcol(p.y, uv.x) * 1.2, smoothstep(0.35, 0.85, mist) * 0.22 * exp(-pow((p.y - 0.66) / 0.22, 2.0)));
	}

	col += embers(p, tt);

	{
		float ax = p.x + par.x * 2.2 * asp;
		float xs = ax * 1.15, cell = floor(xs), lx = fract(xs);
		vec2 hh = h22(vec2(cell, 7.0)), h2 = h22(vec2(cell, 17.0));
		float ucx = ((cell + 0.5) / 1.15) / asp;
		float em = smoothstep(0.27, 0.42, abs(ucx - 0.5));
		float ht = 0.22 + 0.34 * hh.y;
		float h = 1.04 - p.y;
		float w = 0.22 + 0.22 * h2.y;
		float pk = 0.5 + (hh.x - 0.5) * 0.5;
		float top = ht - (lx < pk ? (pk - lx) * ht * 1.8 : (lx - pk) * ht * 2.6);
		top += (vn(vec2(lx * 14.0 + cell * 5.0, 4.0)) - 0.5) * ht * 0.08;
		float inside = step(abs(lx - 0.5), w) * step(h, top) * step(0.0, h) * step(0.2, hh.x) * em;
		if (inside > 0.5){
			float ed = min((w - abs(lx - 0.5)) / 1.15, (top - h) * 0.25);
			float brk = pow(vn(vec2(h * 20.0 + cell * 3.0, lx * 6.0)), 1.3) * 1.6;
			vec3 fgc = vec3(0.003, 0.004, 0.007) + COLD * 0.012 * fbm(vec2(lx * 6.0 + cell, h * 6.0));
			fgc += COLD * 0.16 * exp(-ed / 0.006) * brk * flick;
			fgc += EMBER * 0.05 * (1.0 - smoothstep(0.0, 0.03, ed)) * exp(-h * 2.0);
			col = fgc;
		}
	}

	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(lum), 0.12);
	col = col * vec3(1.04, 0.98, 1.02) * 1.5;
	col = pow(col, vec3(0.86));
	vec2 vq = uv - 0.5;
	float vl = length(vq * vec2(1.0, 1.1));
	float vig = 1.0 - smoothstep(0.30, 0.95, vl);
	col *= mix(0.30, 1.0, vig);
	col += vec3(0.006, 0.006, 0.010);
	col += max(col - 0.35, 0.0) * 0.4;
	// gentle lens fringe: warm outward, cool inward, strongest at the corners
	col += vec3(vq.x, 0.0, -vq.x) * 0.05 * vl * vl * (0.3 + lum * 4.0);
	float gr = h21(uv * res + fract(tt) * 91.0) - 0.5;
	col += gr * 0.020 * (1.0 - 0.5 * clamp(lum * 4.0, 0.0, 1.0));
	col = mix(vec3(0.0), col, fade);
	COLOR = vec4(col, 1.0);
}
