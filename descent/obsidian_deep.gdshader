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

vec4 shard(vec2 p, float asp, float base, float scale, float lpar, float hmax, float wmax, float fog, float seed, float rim, float centre_clear, bool refl){
	float y = p.y;
	float yy = y;
	float rippl = 0.0;
	float att = 1.0;
	if (refl){
		float dd = y - base;
		rippl = (vn(vec2(p.x * 40.0, dd * 90.0 + seed)) - 0.5) * 0.010 * (0.4 + dd * 8.0) + (vn(vec2(p.x * 3.0, dd * 20.0)) - 0.5) * 0.004;
		yy = base - dd * 1.05;
		att = 0.30 * exp(-dd * 5.5);
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
	float lean = (h2.x - 0.5) * 0.35;
	float lxs = lx - lean * h * scale * 0.6;
	float c = 0.5;
	float hl = h / ht;
	float we = w * (1.0 - 0.28 * clamp(hl, 0.0, 1.0));
	float pk = c + (hh.y - 0.5) * 0.36;
	float kl = ht * (0.9 + hh.x * 1.6), kr = ht * (0.9 + h2.y * 1.6);
	float top = ht - (lxs < pk ? (pk - lxs) * kl : (lxs - pk) * kr);
	float inside = step(abs(lxs - c), we) * step(0.0, h) * step(h, top) * present;
	if (inside < 0.5) return vec4(0.0);
	float split = c + (h2.x - 0.5) * 0.3 + (hl - 0.3) * (hh.y - 0.5) * 0.5;
	float side = lxs < split ? 0.0 : 1.0;
	float capH = ht * 0.16 + 0.01;
	float isCap = step(top - capH * (0.6 + hh.x), h);
	float fid = side + 2.0 * isCap + 4.0 * floor(hl * 2.2 + h2.y);
	float fb = 0.35 + 0.65 * h21(vec2(fid, cell + seed));
	vec3 col = vec3(0.012, 0.014, 0.022);
	float foot = exp(-hl * 3.2);
	col += EMBER * 0.075 * foot * flick * fb;
	col += COLD * 0.040 * fb * (0.3 + 0.7 * hl) * (side < 0.5 ? 1.0 : 0.45);
	col += vec3(0.018, 0.022, 0.034) * isCap * (0.5 + fb);
	vec2 pt = vec2(0.5 + (h21(vec2(fid, 3.0 + cell)) - 0.5) * 0.4, ht * 0.5 * h21(vec2(cell, fid)));
	float r = length(vec2((lxs - pt.x) * 3.0, (h - pt.y) / max(ht, 0.05) * 2.0));
	float ring = smoothstep(0.55, 1.0, sin(r * 14.0 + h21(vec2(cell, 9.0)) * 6.0)) * exp(-r * 1.6);
	col += COLD * 0.020 * ring;
	float ex = (we - abs(lxs - c)) / scale;
	float ey = (top - h) * 0.45 / max(1.0, kl / 0.8 + 0.2);
	float ed = min(ex, ey);
	float rimv = 1.0 - smoothstep(0.0, 0.0035 + 0.0015 * rim, ed);
	float sp = abs(lxs - split) / scale;
	float ridge = 1.0 - smoothstep(0.0, 0.0022, sp);
	float capEdge = 1.0 - smoothstep(0.0, 0.0022, abs(h - (top - capH * (0.6 + hh.x))) * 0.7);
	vec3 rimc = mix(COLD, EMBER, side * 0.55 * foot + 0.1);
	col += rimc * (rimv * 0.50 + ridge * 0.28 + capEdge * 0.20) * rim * 1.05 * (0.55 + 0.45 * flick);
	float vv = abs(fbm(vec2(lxs * 2.2 + cell * 3.1, h * 5.0 / max(ht, 0.1) * 0.6 + seed)) - 0.5);
	float vein = (1.0 - smoothstep(0.0, 0.010, vv)) * step(0.55, h21(vec2(cell, 5.0 + seed)));
	col += EMBER * vein * 0.50 * flick * (0.4 + 0.6 * foot) * clamp(rim, 0.0, 1.0);
	vec2 gp = floor(vec2(lxs * 30.0, h * 30.0 * scale));
	float gl = h21(gp + cell * 3.0);
	float tw = 0.5 + 0.5 * sin(t_now * (0.7 + gl * 2.5) + gl * 40.0);
	col += vec3(0.8, 0.85, 1.0) * smoothstep(0.985, 1.0, gl) * tw * 0.7 * rim * (0.3 + 0.7 * fb);
	col = mix(col, fogcol(y, ucx), fog);
	return vec4(col, att);
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
		vec3 fl = vec3(0.022, 0.024, 0.034);
		float sheen = fbm(vec2(fp.x * 0.5, fp.y * 0.35) + par.x * 5.0);
		fl += COLD * 0.09 * smoothstep(0.3, 0.8, sheen) * exp(-d * 2.0);
		fl += vec3(0.012, 0.014, 0.022) * (1.0 - d);
		float rp = (vn(vec2(p.x * 60.0, d * 12.0)) - 0.5) * 0.02 * (0.3 + d * 3.0);
		float bg = fissure_band((p.x + rp) / asp);
		float streak = bg * exp(-d * 4.5) * (0.35 + 0.65 * vn(vec2(p.x * 25.0, d * 4.0 + tt * 0.2)));
		fl += EMBER * 0.30 * streak * flick;
		vec2 g = floor(fp * 1.3), f = fract(fp * 1.3);
		float d1 = 9.0, d2 = 9.0; vec2 cid = vec2(0.0);
		for (int j = -1; j <= 1; j++){ for (int i = -1; i <= 1; i++){
			vec2 o = vec2(float(i), float(j));
			vec2 pp = o + h22(g + o) - f;
			float dd2 = dot(pp, pp);
			if (dd2 < d1){ d2 = d1; d1 = dd2; cid = g + o; } else if (dd2 < d2){ d2 = dd2; }
		} }
		float ce = sqrt(d2) - sqrt(d1);
		float crack = 1.0 - smoothstep(0.0, 0.035, ce);
		float lit = step(0.80, h21(cid));
		fl = mix(fl, vec3(0.004, 0.004, 0.007), crack * 0.7);
		fl += (EMBER * 0.35 * lit * flick + COLD * 0.06) * crack * (1.0 - smoothstep(0.0, 0.012, ce)) * exp(-d * 1.2);
		fl = mix(fl, fogcol(p.y, uv.x), exp(-d * 9.0) * 0.8);
		col = fl;
	}

	vec4 s;
	for (int L = 0; L < 3; L++){
		float base = 0.0, scale = 0.0, lp = 0.0, hmax = 0.0, wmax = 0.0, fog = 0.0, seed = 0.0, rim = 0.0, cc = 0.0;
		if (L == 0){ base = 0.645; scale = 3.0; lp = 0.3; hmax = 0.40; wmax = 0.36; fog = 0.55; seed = 1.0; rim = 0.6; cc = 0.0; }
		if (L == 1){ base = 0.705; scale = 2.6; lp = 0.7; hmax = 0.55; wmax = 0.34; fog = 0.35; seed = 2.0; rim = 0.55; cc = 0.6; }
		if (L == 2){ base = 0.775; scale = 1.35; lp = 1.2; hmax = 0.62; wmax = 0.32; fog = 0.12; seed = 3.0; rim = 0.85; cc = 0.95; }
		bool refl = p.y > base;
		s = shard(p, asp, base, scale, lp, hmax, wmax, fog, seed, rim, cc, refl);
		if (s.a > 0.0){
			col = mix(col, s.rgb, refl ? s.a : 1.0);
		}
	}

	for (int k = 0; k < 3; k++){
		float sc = 9.0 + float(k) * 7.0;
		vec2 q = vec2(p.x * sc, p.y * sc);
		q.y += tt * (0.35 + 0.2 * float(k));
		q.x += sin(tt * 0.3 + float(k) * 2.0 + q.y * 0.5) * 0.4;
		vec2 id = floor(q), fq = fract(q);
		vec2 hr = h22(id + float(k) * 17.0);
		float dist = length(fq - (0.2 + 0.6 * hr));
		float tw = 0.5 + 0.5 * sin(tt * (1.0 + hr.x * 3.0) + hr.y * 30.0);
		float live = step(0.78 - 0.06 * float(k), hr.y);
		float dot_ = smoothstep(0.10 + 0.02 * float(k), 0.0, dist) * live * tw;
		float nearglow = 0.35 + 0.8 * exp(-pow((p.y - 0.62) / 0.3, 2.0));
		col += EMBER * dot_ * (0.45 - 0.1 * float(k)) * nearglow;
	}
	{
		vec2 q = vec2(p.x * 26.0 + tt * 0.4, p.y * 26.0 - tt * 0.15);
		vec2 id = floor(q), fq = fract(q); vec2 hr = h22(id + 90.0);
		float dist = length(fq - (0.25 + 0.5 * hr));
		col += vec3(0.5, 0.55, 0.7) * smoothstep(0.07, 0.0, dist) * step(0.9, hr.y) * 0.10 * (0.4 + 0.6 * sin(tt + hr.x * 20.0));
	}

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
		float inside = step(abs(lx - 0.5), w) * step(h, top) * step(0.0, h) * step(0.2, hh.x) * em;
		if (inside > 0.5){
			float ed = min((w - abs(lx - 0.5)) / 1.15, (top - h) * 0.25);
			vec3 fgc = vec3(0.003, 0.004, 0.007) + COLD * 0.012 * h21(vec2(floor(lx * 4.0), cell));
			fgc += COLD * 0.28 * (1.0 - smoothstep(0.0, 0.004, ed)) * flick;
			fgc += EMBER * 0.05 * (1.0 - smoothstep(0.0, 0.03, ed)) * exp(-h * 2.0);
			col = fgc;
		}
	}

	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(lum), 0.12);
	col = col * vec3(1.04, 0.98, 1.02) * 1.5;
	col = pow(col, vec3(0.86));
	vec2 vq = uv - 0.5;
	float vig = 1.0 - smoothstep(0.30, 0.95, length(vq * vec2(1.0, 1.1)));
	col *= mix(0.30, 1.0, vig);
	col += vec3(0.006, 0.006, 0.010);
	col += max(col - 0.35, 0.0) * 0.4;
	float gr = h21(uv * res + fract(tt) * 91.0) - 0.5;
	col += gr * 0.018;
	col = mix(vec3(0.0), col, fade);
	COLOR = vec4(col, 1.0);
}
