shader_type canvas_item;

// GARDEN FOREGROUND: out-of-focus framing: hanging vines, palm fronds, blossoming branches, big leaves.
uniform float aspect = 1.5;
uniform vec2 look = vec2(0.0);

float h12(vec2 p){ vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
vec2 h22(vec2 p){ vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973)); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.xx + p3.yz) * p3.zy); }

vec2 rot(vec2 d, float a){ float c = cos(a), s = sin(a); return vec2(c * d.x + s * d.y, -s * d.x + c * d.y); }

void over(inout vec3 col, inout float a, vec3 c, float m){
	col = mix(col, c, m);
	a = a + m * (1.0 - a);
}

vec3 leafcol(float h, float lit, float depth){
	vec3 deep = vec3(0.025, 0.12, 0.07);
	vec3 mid = vec3(0.10, 0.34, 0.10);
	vec3 yel = vec3(0.45, 0.58, 0.12);
	vec3 c = mix(deep, mid, 0.35 + 0.65 * h);
	c = mix(c, yel, lit * (0.35 + 0.4 * h));
	return mix(c, c * vec3(0.8, 0.95, 1.15) + vec3(0.04, 0.09, 0.10), depth);
}

void vines(vec2 q, float W, float cw, float sc, float soft, float seed, float depth, inout vec3 col, inout float a){
	float ci = floor(q.x / cw);
	for(int k = -1; k <= 1; k++){
		float c = ci + float(k);
		vec2 r = h22(vec2(c, seed));
		float x0 = (c + 0.15 + 0.7 * r.x) * cw;
		float ex = abs(x0 / W - 0.5) * 2.0;
		float len = (0.10 + 0.55 * pow(ex, 1.6)) * (0.55 + 0.9 * r.y) * sc;
		if(h12(vec2(c, seed + 7.0)) < 0.18 + 0.5 * (1.0 - ex)) len *= 0.35;
		if(q.y > len + 0.1 * sc) continue;
		float sw = sin(TIME * 0.7 + r.x * 6.28 + q.y * 3.0) * 0.010 * sc * clamp(q.y / max(len, 0.01), 0.0, 1.0);
		float xs = x0 + sw;
		float stem = 1.0 - smoothstep(0.0007 * sc, 0.0007 * sc + soft * 0.7, abs(q.x - xs));
		stem *= 1.0 - smoothstep(len, len + soft, q.y);
		over(col, a, vec3(0.06, 0.16, 0.06) * (1.0 + depth), stem * 0.85);
		float sp = 0.026 * sc;
		float j0 = floor(q.y / sp + 0.5);
		for(int jj = -1; jj <= 1; jj++){
			float j = j0 + float(jj);
			if(j < 0.0) continue;
			float yj = j * sp;
			if(yj > len) continue;
			vec2 hr = h22(vec2(c * 13.0 + j, seed + 3.0));
			float sd = (hr.x < 0.5) ? -1.0 : 1.0;
			float tt = yj / max(len, 0.01);
			float swj = sin(TIME * 0.7 + r.x * 6.28 + yj * 3.0) * 0.010 * sc * tt;
			vec2 cen = vec2(x0 + swj + sd * 0.011 * sc, yj + 0.006 * sc);
			float lg = sc * (0.040 + 0.020 * hr.y) * (1.0 - 0.3 * tt);
			float ang = sd * (0.7 + 0.5 * hr.y) + sin(TIME * 0.9 + j) * 0.06;
			vec2 d = rot(q - cen, ang);
			float u = clamp(d.y / lg, 0.0, 1.0);
			float hw = lg * 0.24 * pow(sin(3.14159 * u) + 0.001, 0.75) + 0.0005;
			float m = (1.0 - smoothstep(hw - soft, hw + soft, abs(d.x))) * smoothstep(-soft, soft, d.y) * (1.0 - smoothstep(lg - soft, lg + soft, d.y));
			float lit = clamp(0.5 - d.x * sd / max(hw, 0.002) * 0.5, 0.0, 1.0);
			vec3 lc = leafcol(hr.y, lit, depth);
			lc += vec3(0.12, 0.12, 0.03) * (1.0 - smoothstep(0.0, 0.004 + soft, abs(d.x))) * 0.7;
			if(hr.y > 0.93){
				float fe = length(vec2(d.x, d.y - lg * 0.35)) / (lg * 0.16);
				m = 1.0 - smoothstep(0.8, 1.0, fe);
				lc = mix(vec3(0.62, 0.38, 0.88), vec3(0.98, 0.62, 0.30), step(0.965, hr.y)) * (0.8 + 0.3 * lit);
			}
			over(col, a, lc, m);
		}
		vec2 hr2 = h22(vec2(c, seed + 11.0));
		vec2 d2 = q - vec2(xs, len + 0.012 * sc);
		float lg2 = 0.05 * sc;
		float e2 = length(d2 / vec2(lg2 * 0.3, lg2 * 0.6));
		over(col, a, leafcol(hr2.x, 0.4, depth), 1.0 - smoothstep(1.0 - soft / (lg2 * 0.4), 1.0, e2));
	}
}

vec2 frond(vec2 q, vec2 org, float ang, float len, float curl, float wid, float soft){
	vec2 d = rot(q - org, ang);
	float s = d.x;
	float t = s / len;
	if(t < -0.02 || t > 1.02) return vec2(0.0);
	float n = d.y - curl * s * s / len;
	float an = abs(n);
	float L = wid * sin(3.14159 * clamp(pow(clamp(t, 0.0, 1.0), 0.6), 0.0, 1.0)) * (1.0 - 0.3 * t) + 0.004;
	float P = len / 26.0;
	float v = fract((s - an * 0.9) / P);
	float thr = 0.55 * (1.0 - 0.7 * clamp(an / L, 0.0, 1.0));
	float strip = smoothstep(0.0, 0.25, v) * (1.0 - smoothstep(thr, thr + 0.3, v));
	float env = 1.0 - smoothstep(L * 0.8, L, an);
	float win = smoothstep(0.0, 0.03, t) * (1.0 - smoothstep(0.93, 1.0, t));
	float rach = (1.0 - smoothstep(0.0035 * (1.0 - 0.7 * t), 0.0035 + soft, an)) * win;
	float m = max(rach, strip * env * win);
	return vec2(clamp(m, 0.0, 1.0), t);
}

void bigleaf(vec2 q, vec2 base, float ang, float len, float wid, float soft, float h, inout vec3 col, inout float a){
	vec2 d = rot(q - base, ang);
	float t = d.x / len;
	if(t < -0.05 || t > 1.05) return;
	float hw = wid * sin(3.14159 * clamp(t, 0.0, 1.0)) * (1.0 - 0.25 * t) + 0.002;
	float m = 1.0 - smoothstep(hw - soft, hw + soft, abs(d.y));
	m *= smoothstep(-0.02, 0.0, t);
	float side = clamp(0.5 + d.y / max(hw, 0.001) * 0.5, 0.0, 1.0);
	float rib = 1.0 - smoothstep(0.0, 0.02 + soft, abs(d.y));
	vec3 c = leafcol(h, side * 0.9, 0.0);
	c += vec3(0.10, 0.10, 0.02) * rib * 0.6;
	over(col, a, c, m * 0.97);
}

void branch(vec2 q, vec2 org, float ang, float len, float curl, float seed, float soft, inout vec3 col, inout float a){
	vec2 d = rot(q - org, ang);
	float s = d.x;
	float n = d.y - curl * s * s / len;
	float t = s / len;
	if(t < -0.05 || t > 1.1) return;
	float stem = 1.0 - smoothstep(0.008 * (1.0 - 0.5 * t), 0.008 + soft, abs(n));
	stem *= 1.0 - smoothstep(len, len + soft, s);
	over(col, a, vec3(0.10, 0.055, 0.04), stem);
	float cs = 0.045;
	vec2 cell = floor(vec2(s, n) / cs);
	for(int i = -1; i <= 1; i++){
		for(int j = -1; j <= 1; j++){
			vec2 cc = cell + vec2(float(i), float(j));
			vec2 hh = h22(cc + seed);
			vec2 pc = (cc + 0.5 + (hh - 0.5) * 0.7) * cs;
			float tc = pc.x / len;
			if(tc < 0.0 || tc > 1.0) continue;
			float wdc = 0.05 + 0.09 * sin(3.14159 * tc);
			if(abs(pc.y) > wdc) continue;
			float hk = h12(cc + seed + 5.0);
			if(hk < 0.12) continue;
			if(hk > 0.78){
				vec2 dl = rot(vec2(s, n) - pc, hh.x * 6.28);
				float el = length(dl / vec2(0.022, 0.009));
				over(col, a, leafcol(hh.y, 0.7, 0.1), 1.0 - smoothstep(0.7, 1.0, el));
			} else {
				vec2 dp = vec2(s, n) - pc;
				float ang2 = atan(dp.y, dp.x);
				float R = (0.022 + 0.014 * hh.y) * (0.72 + 0.28 * cos(5.0 * (ang2 + hh.x * 6.28)));
				float m = 1.0 - smoothstep(R - soft, R + soft, length(dp));
				vec3 pink = vec3(0.98, 0.52, 0.66);
				vec3 white = vec3(1.0, 0.93, 0.92);
				vec3 pc3 = mix(pink, white, step(0.5, hh.x));
				pc3 = mix(pc3, vec3(1.0, 0.8, 0.3), (1.0 - smoothstep(0.0, R * 0.3, length(dp))) * 0.8);
				over(col, a, pc3, m);
			}
		}
	}
}

void fragment() {
	vec2 uv = UV - look;
	float W = aspect;
	vec2 q = vec2(uv.x * W, uv.y);
	vec2 qm = vec2(W - q.x, q.y);

	vec3 col = vec3(0.0);
	float a = 0.0;

	vines(q, W, 0.045, 0.8, 0.004, 1.0, 0.45, col, a);
	{
		float sway = sin(TIME * 0.45) * 0.02;
		vec2 f1 = frond(q, vec2(-0.06, 0.30), 0.18 + sway, 0.62, 0.22, 0.085, 0.006);
		vec2 f2 = frond(qm, vec2(-0.06, 0.12), 0.45 - sway, 0.70, 0.30, 0.095, 0.006);
		vec2 f3 = frond(q, vec2(-0.05, 0.06), 0.55 + sway * 0.6, 0.55, 0.18, 0.07, 0.006);
		vec2 f[3] = vec2[3](f1, f2, f3);
		for(int i = 0; i < 3; i++){
			vec3 c = mix(vec3(0.03, 0.14, 0.07), vec3(0.28, 0.46, 0.10), clamp(f[i].y * 1.2, 0.0, 1.0) * 0.8);
			over(col, a, c, f[i].x * 0.95);
		}
	}
	branch(q, vec2(-0.05, 0.48), -0.32, 0.52, 0.12, 3.0, 0.006, col, a);
	branch(qm, vec2(-0.05, 0.40), -0.22, 0.52, 0.08, 9.0, 0.006, col, a);
	vines(q, W, 0.09, 1.1, 0.008, 3.0, 0.15, col, a);
	vines(q, W, 0.16, 1.7, 0.018, 5.0, 0.0, col, a);

	for(int i = 0; i < 7; i++){
		float fi = float(i);
		vec2 hr = h22(vec2(fi, 21.0));
		float yy = mix(0.55, 1.1, fi / 6.0);
		float ang = -0.4 - 0.9 * (fi / 6.0) + hr.x * 0.5;
		float len = 0.20 + 0.14 * hr.y;
		bigleaf(q, vec2(-0.05, yy), ang - 0.3, len, 0.06, 0.012, hr.x, col, a);
		vec2 hr2 = h22(vec2(fi, 77.0));
		bigleaf(qm, vec2(-0.05, mix(0.45, 1.1, fi / 6.0)), -0.5 - 0.8 * (fi / 6.0) + hr2.x * 0.5 - 0.3, 0.22 + 0.14 * hr2.y, 0.065, 0.012, hr2.x, col, a);
	}
	bigleaf(q, vec2(-0.1, 1.05), -0.9, 0.5, 0.11, 0.03, 0.2, col, a);
	bigleaf(qm, vec2(-0.1, 1.05), -1.0, 0.55, 0.12, 0.03, 0.5, col, a);
	bigleaf(q, vec2(-0.08, 0.35), 0.3, 0.30, 0.09, 0.04, 0.3, col, a);
	bigleaf(qm, vec2(-0.08, 0.30), 0.35, 0.34, 0.1, 0.04, 0.6, col, a);

	float cm = smoothstep(0.30, 0.50, length(vec2((uv.x - 0.5) * 1.5, (uv.y - 0.78) * 1.0)));
	a *= mix(cm, 1.0, smoothstep(0.35, 0.0, uv.y) * 0.8);

	vec2 g = vec2(dFdx(a), dFdy(a)) * 160.0;
	float rim = clamp(dot(-g, vec2(-0.7, -0.6)), 0.0, 1.0);
	float lit = clamp(0.2 + 0.8 * (1.0 - uv.x) * (1.0 - uv.y * 0.6), 0.0, 1.0);
	float sunk = exp(-length((uv - vec2(0.30, 0.25)) * vec2(1.0, 1.2)) * 2.4);
	col = col * (0.82 + 0.5 * lit);
	col = mix(col, col * vec3(1.5, 1.3, 0.7) + vec3(0.08, 0.05, 0.0), sunk * 0.4);
	col += vec3(1.0, 0.55, 0.22) * rim * 0.4 * a;
	col = col / (1.0 + col * 0.25);
	col = pow(clamp(col, 0.0, 1.0), vec3(0.95));
	float dn = h12(FRAGCOORD.xy + fract(TIME) * 61.0) - 0.5;
	col += dn / 255.0;
	COLOR = vec4(clamp(col, 0.0, 1.0), clamp(a, 0.0, 1.0));
}
