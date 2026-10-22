shader_type canvas_item;

// GARDEN GROUND (par 1.0), realistic pass. Damp soil / moss / gravel lit from a height field
// (low golden light from upper-left + cool sky fill + falls glow), wet speculars, contact shadows,
// a shallow pool near the falls (fresnel reflection, ripple normals, caustics, glints, foam,
// visible pebble bed), mossy stepping stones, backlit grass along the far lip.
// Time-varying: water ripples/caustics/glints and grass sway only.
uniform float aspect = 1.5;
uniform vec2 look = vec2(0.0);
uniform float cam = 0.0;
uniform float span = 3.0;
uniform float par = 1.0;

const float LIP = 0.76;
const vec3 SUN = vec3(1.0, 0.70, 0.42);
const vec3 SKYF = vec3(0.10, 0.17, 0.24);
const vec3 LDIR = vec3(-0.80, 0.46, -0.12);

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
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
float fbm3(vec2 p) {
	float a = 0.5, s = 0.0;
	for (int i = 0; i < 3; i++) {
		s += a * vnoise(p);
		p = p * 2.03 + 17.1;
		a *= 0.5;
	}
	return s * 1.14;
}
// x = F1, y = hash of nearest cell
vec2 vor1(vec2 p) {
	vec2 ip = floor(p);
	vec2 fp = fract(p);
	float d1 = 8.0, id = 0.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 r = g + h22(ip + g) - fp;
			float d = dot(r, r);
			if (d < d1) {
				d1 = d;
				id = h21(ip + g + 7.7);
			}
		}
	}
	return vec2(sqrt(d1), id);
}

// ground height field in "gp" ground-plane units. pa = pebble amount. peb/pid output pebble height + id
float terrain(vec2 gp, float pa, out float peb, out float pid) {
	float h = 0.55 * fbm3(gp * 0.45) + 0.10 * vnoise(gp * vec2(3.1, 1.6)) + 0.035 * vnoise(gp * vec2(11.0, 4.0));
	// roots / cracks: ridged, domain warped
	vec2 w = gp * 0.8 + 2.0 * vec2(vnoise(gp * 0.5), vnoise(gp * 0.5 + 9.0));
	float rr = 1.0 - abs(2.0 * vnoise(w * 0.7) - 1.0);
	rr = pow(rr, 7.0);
	h += 0.22 * rr * (0.4 + 0.6 * pa);
	// gravel / pebbles
	vec2 pg = gp * vec2(0.75, 0.75);
	vec2 v = vor1(pg);
	float n = vnoise(pg * vec2(5.0, 2.5));
	float rad = 0.12 + 0.18 * fract(v.y * 37.7);
	float p = (v.x + 0.07 * (n - 0.5)) / rad;
	float on = step(1.0 - pa, v.y);
	peb = on * sqrt(max(1.0 - p * p, 0.0));
	pid = v.y;
	return h + 0.55 * peb;
}

float pathc(float X) {
	return 0.10 + 0.05 * sin(X * 1.25 + 0.8);
}

// 3-pass caustic web
float caustic(vec2 p) {
	float t = TIME * 0.35;
	vec2 q = p;
	float c = 0.0;
	for (int i = 0; i < 3; i++) {
		float f = float(i);
		q += vec2(sin(q.y * 1.7 + t + f * 1.3), cos(q.x * 1.5 - t * 0.8 + f * 2.1)) * 0.55;
		c += 1.0 / (1.0 + 14.0 * pow(abs(sin(q.x * 1.1) * cos(q.y * 1.1)), 1.0));
	}
	return c * 0.333;
}

vec4 grass(float X, float Y, float lip) {
	float dy = lip - Y;
	vec4 res = vec4(0.0);
	if (dy < -0.004 || dy > 0.05) return res;
	const float N = 95.0;
	float ci = floor(X * N);
	for (int k = -3; k <= 2; k++) {
		float c = ci + float(k);
		vec2 hh = h22(vec2(c, 3.0));
		float clump = vnoise(vec2(c * 0.09, 9.0));
		clump = smoothstep(0.30, 0.75, clump);
		if (hh.x > 0.40 + 0.55 * clump) continue;
		float x0 = (c + hh.y) / N;
		float H = (0.005 + 0.026 * fract(hh.x * 53.1)) * (0.5 + 0.7 * clump);
		float t = dy / H;
		if (t < -0.2 || t > 1.0) continue;
		float lean = (hh.y - 0.5) * 0.028 + 0.004 * sin(TIME * 0.9 + c * 0.7);
		float cx = x0 + lean * t * t;
		float hw = 0.0034 * (1.0 - t) + 0.0004;
		float m = 1.0 - smoothstep(hw * 0.55, hw, abs(X - cx));
		if (m <= 0.0) continue;
		float tint = fract(hh.x * 91.7);
		vec3 base = vec3(0.035, 0.075, 0.035);
		vec3 tip = mix(vec3(0.28, 0.46, 0.13), vec3(0.50, 0.50, 0.16), tint);
		// backlit translucency: tips glow, strongest toward the low sun on the left
		vec3 gc = mix(base, tip, smoothstep(0.1, 1.0, t) * 0.8);
		gc *= 0.75 + 0.5 * clamp(0.5 - lean * 20.0, 0.0, 1.0);
		res.rgb = mix(res.rgb, gc, m);
		res.a = max(res.a, m);
	}
	return res;
}

void fragment() {
	float X = (UV.x - 0.5) * aspect + cam * span * par - look.x * (0.4 + par);
	float Y = UV.y - look.y * (0.3 + 0.5 * par);

	float lip = LIP + 0.007 * (vnoise(vec2(X * 2.2, 3.1)) - 0.5) * 2.0 + 0.0025 * (vnoise(vec2(X * 23.0, 1.0)) - 0.5);
	float v = (Y - lip) / (1.0 - LIP);
	float vc = max(v, 0.0);

	// perspective ground plane
	float d = 1.0 / (vc + 0.25);
	float Xc = cam * span * par - look.x * (0.4 + par);
	float sxs = X - Xc;
	vec2 gp = vec2((Xc + sxs * d * 0.22) * 7.0, d * 1.2) * 2.6;
	float haze = exp(-vc * 5.0);

	// pool geometry (unchanged layout)
	float Xs = 2.55 + 0.30 * sin(vc * 4.0 + 1.0) + 0.22 * (vnoise(vec2(vc * 14.0, 4.0)) - 0.5);
	float vw = vc + 0.03 * (vnoise(vec2(X * 3.0, 8.0)) - 0.5);
	float wd = min(vw - 0.235, (X - Xs) * 0.30);
	float wmask = smoothstep(0.0, 0.008, wd);
	float glowx = exp(-pow((X - 3.25) / 0.85, 2.0));

	// ---------------- land ----------------
	float pc = pathc(X);
	float pathm = exp(-pow((vc - pc) / 0.10, 2.0));
	float pa = clamp(0.05 + 0.85 * smoothstep(0.12, 0.70, vc), 0.0, 1.0) * (1.0 - 0.7 * pathm);
	pa = max(pa, 0.5 * smoothstep(0.0, 0.5, wd + 0.15) * step(0.0, wd + 0.15) * (1.0 - wmask)); // shingle at the bank
	float peb, pid;
	float h0 = terrain(gp, pa, peb, pid);
	float e = 0.06;
	float pe1, pi1;
	float hx = terrain(gp + vec2(e, 0.0), pa, pe1, pi1);
	float hz = terrain(gp + vec2(0.0, e), pa, pe1, pi1);
	float calm = 1.0 - 0.45 * smoothstep(0.30, 0.0, abs(vc - 0.17)) * 1.0;
	float K = 4.5 * calm;
	vec3 n = normalize(vec3(-(hx - h0) / e * K * 0.5, 1.0, -(hz - h0) / e * K * 0.5));
	vec3 L = normalize(LDIR);

	// contact / cast shadow: sample height up-light
	float hs = terrain(gp - vec2(L.x, L.z) * 0.20, pa, pe1, pi1);
	float shadow = 1.0 - clamp((hs - h0 - 0.05) * 3.0, 0.0, 1.0) * 0.8;
	float cav = clamp(0.5 + (h0 - (0.55 * fbm3(gp * 0.45) + 0.2)) * 3.0, 0.0, 1.0); // cheap cavity AO
	float ao = mix(0.55, 1.0, cav) * mix(0.7, 1.0, smoothstep(0.0, 0.35, peb + 0.1 * (1.0 - pa)));

	// materials
	float moisture = clamp(0.5 + (0.45 - h0) * 1.2, 0.0, 1.0);
	float mossn = fbm3(gp * 0.9 + 5.0);
	float moss = smoothstep(0.38, 0.62, mossn + 0.25 * (moisture - 0.5) - 0.3 * pathm);
	vec3 soil = mix(vec3(0.070, 0.050, 0.040), vec3(0.050, 0.055, 0.052), vnoise(gp * 1.7));
	soil *= 0.8 + 0.5 * vnoise(gp * vec2(9.0, 3.0));
	vec3 mosscol = mix(vec3(0.034, 0.062, 0.034), vec3(0.058, 0.090, 0.048), vnoise(gp * vec2(4.0, 2.0)));
	vec3 alb = mix(soil, mosscol, moss * (1.0 - 0.7 * peb));
	vec3 stone = mix(vec3(0.15, 0.14, 0.13), vec3(0.11, 0.125, 0.15), fract(pid * 13.7));
	stone *= 0.45 + 0.5 * vnoise(gp * vec2(6.0, 2.5));
	stone = mix(stone, mosscol * 1.1, 0.5 * smoothstep(0.5, 0.2, peb) * moss);
	alb = mix(alb, stone, smoothstep(0.0, 0.25, peb));

	float wet = exp(-max(wd, 0.0) / 0.001) * 0.0 + (1.0 - wmask) * exp(-max(wd + 0.02, 0.0) / 0.05);
	wet = clamp(wet + 0.35 * moisture, 0.0, 1.0);
	alb *= 1.0 - 0.45 * wet;

	// light
	float ndl = dot(n, L);
	float dif = max(ndl, 0.0) * 0.8 + 0.2 * max(ndl * 0.5 + 0.5, 0.0);
	vec3 V = normalize(vec3(0.0, 0.5, 1.0));
	vec3 Hh = normalize(L + V);
	float spec = pow(max(dot(n, Hh), 0.0), mix(20.0, 60.0, wet)) * mix(0.04, 0.22, wet);
	float rimf = pow(1.0 - max(n.y, 0.0), 3.0);
	vec3 fall = vec3(0.10, 0.50, 0.55) * glowx * 0.25 * (0.6 + 0.8 * max(n.x, 0.0));
	vec3 col = alb * 6.5 * (SUN * dif * 1.5 * shadow * ao + SKYF * 1.5 * ao + fall);
	col += SUN * spec * shadow * 0.55 + vec3(0.25, 0.45, 0.55) * rimf * wet * 0.05;
	// bioluminescent lichen specks (sparse accents)
	vec2 lc = gp * 1.3;
	vec2 lcell = floor(lc);
	float lh = h21(lcell + 3.3);
	float lspark = step(0.965, lh) * moss * (1.0 - peb);
	float ld = length(fract(lc) - 0.2 - 0.6 * h22(lcell));
	vec3 lcol = mix(vec3(0.30, 0.85, 0.75), vec3(0.95, 0.65, 0.22), step(0.985, lh));
	col += lcol * lspark * exp(-ld * ld * 90.0) * 0.28;

	// ---------------- water ----------------
	if (wmask > 0.0) {
		float wd2 = 1.0 / (vc + 0.25);
		vec2 rp = vec2((Xc + sxs * wd2 * 0.4) * 11.0, wd2 * 26.0);
		float tt = TIME * 0.12;
		float f0 = fbm3(rp + vec2(tt, -tt * 0.7));
		float f1 = fbm3(rp + vec2(0.07, 0.0) + vec2(tt, -tt * 0.7));
		float f2 = fbm3(rp + vec2(0.0, 0.07) + vec2(tt, -tt * 0.7));
		float rs = 0.11 * (0.4 + 0.6 * glowx) + 0.05;
		vec3 wn = normalize(vec3(-(f1 - f0) / 0.07 * rs, 1.0, -(f2 - f0) / 0.07 * rs * 1.6));
		float cosv = 0.16 + 0.55 * vc;
		float fres = 0.03 + 0.97 * pow(1.0 - clamp(cosv * wn.y, 0.0, 1.0), 5.0);
		// reflected environment: horizon glow, dark cliffs, the falls' luminous column
		float ry = clamp(0.25 + 0.7 * (1.0 - vc * 1.2) + (f0 - 0.5) * 0.5, 0.0, 1.0);
		vec3 env = mix(vec3(0.05, 0.08, 0.15), vec3(0.30, 0.26, 0.38), ry * ry);
		float st = vnoise(vec2(X * 30.0, vc * 5.0 - TIME * 0.05)) * 0.6 + 0.4 * vnoise(vec2(X * 80.0, vc * 9.0));
		env += vec3(0.22, 0.75, 0.80) * glowx * (0.45 + 0.8 * st) * exp(-vc * 1.8) * 1.1;
		// bed seen through the water: pebble ground, tinted + depth faded
		float dep = smoothstep(0.0, 0.45, wd);
		vec3 bed = col * mix(vec3(0.85, 1.0, 0.95), vec3(0.10, 0.45, 0.50), dep);
		float cs = caustic(vec2((Xc + sxs * wd2 * 0.4) * 6.0, wd2 * 12.0));
		bed += vec3(0.25, 0.75, 0.70) * cs * cs * (0.15 + 0.55 * glowx) * (1.0 - 0.6 * dep) * 0.55;
		vec3 body = vec3(0.012, 0.055, 0.070) + vec3(0.02, 0.15, 0.17) * glowx * 0.5;
		vec3 wcol = mix(bed, body, 0.15 + 0.7 * dep) * (1.0 - fres) + env * fres;
		// sun glints
		vec3 Hw = normalize(L + vec3(0.0, 0.35, 1.0));
		float gl = pow(max(dot(wn, Hw), 0.0), 800.0);
		wcol += SUN * gl * 1.0 * (0.4 + vnoise(rp * 3.0 + TIME * 0.1));
		// foam at the shore and at the falls' base
		float fm = fbm3(vec2(X * 22.0, vc * 40.0 + TIME * 0.05));
		float shore = exp(-max(wd, 0.0) / 0.012) * smoothstep(0.38, 0.62, fm);
		float fb = glowx * exp(-pow((vc - 0.245) / 0.05, 2.0)) * smoothstep(0.42, 0.7, fm);
		wcol += vec3(0.55, 0.68, 0.68) * (shore * 0.55 + fb * 0.45);
		col = mix(col, wcol, wmask);

		// stepping stones: rounded mossy rocks, lit, with wet line, reflection and shadow
		const vec4 SL[5] = vec4[](vec4(2.74, 0.40, 0.10, 0.075), vec4(2.97, 0.52, 0.09, 0.07), vec4(3.22, 0.44, 0.11, 0.08), vec4(3.46, 0.58, 0.10, 0.075), vec4(3.72, 0.48, 0.10, 0.07));
		for (int i = 0; i < 5; i++) {
			vec4 s = SL[i];
			vec2 l = vec2((X - s.x) / s.z, (vc - s.y) / s.w);
			if (abs(l.x) > 2.0 || abs(l.y) > 3.0) continue;
			float jit = 0.10 * (vnoise(vec2(atan(l.y, l.x) * 1.4 + float(i) * 5.0, 2.0 + float(i))) - 0.5);
			// soft cast shadow + reflection darkening on water, toward the right (away from the sun)
			vec2 ls = l - vec2(0.45, 0.55);
			float sd = length(ls) - 1.0 - jit;
			col *= 1.0 - 0.5 * (1.0 - smoothstep(-0.1, 0.6, sd)) * step(0.0, l.y + 0.2);
			vec2 lb = vec2(l.x, l.y - 0.45);
			float sb = length(lb) - 1.0 - jit;
			float mb = 1.0 - smoothstep(-0.03, 0.03, sb);
			float rt = length(l) - 1.0 - jit;
			float mt = 1.0 - smoothstep(-0.03, 0.03, rt);
			// ring ripples where rock meets water
			col += vec3(0.5, 0.65, 0.65) * exp(-pow((min(sb, rt + 0.0) - 0.07) / 0.03, 2.0)) * 0.12 * (1.0 - mb) * (1.0 - mt) * (0.4 + fm);
			// side wall: dark, vertically graded, wet line at base, fresnel sheen
			float wallv = clamp((l.y - 0.0) / 0.9, 0.0, 1.0);
			float rn = vnoise(vec2(l.x * 6.0 + float(i) * 9.0, l.y * 5.0)) * 0.6 + 0.4 * vnoise(vec2(l.x * 17.0, l.y * 13.0 + float(i)));
			vec3 wall = mix(vec3(0.085, 0.080, 0.080), vec3(0.025, 0.03, 0.035), wallv) * (0.6 + 0.8 * rn);
			wall *= 1.0 + 1.1 * clamp(-l.x * 0.7, 0.0, 1.0) * (1.0 - wallv);
			wall = mix(wall, vec3(0.02, 0.07, 0.04), smoothstep(0.5, 0.0, wallv) * 0.4 * rn);
			col = mix(col, wall, mb);
			// dome top: analytic normal from ellipse, rock + moss texture
			float r2 = clamp(dot(l, l), 0.0, 1.0);
			vec3 sn = normalize(vec3(l.x * 0.9, 0.65 + 0.35 * sqrt(1.0 - r2), l.y * 0.7 - 0.2));
			float tn = fbm3(l * 4.0 + float(i) * 7.0);
			sn = normalize(sn + 0.25 * vec3(vnoise(l * 11.0) - 0.5, 0.0, vnoise(l * 11.0 + 5.0) - 0.5));
			float sd2 = max(dot(sn, L), 0.0);
			vec3 ma = mix(vec3(0.13, 0.12, 0.12), vec3(0.04, 0.095, 0.04), smoothstep(0.35, 0.65, tn));
			ma = mix(ma, vec3(0.08, 0.14, 0.05), smoothstep(0.5, 0.9, l.y * 0.5 + 0.5) * 0.3);
			vec3 top = ma * 1.8 * (SUN * sd2 * 1.4 + SKYF * 1.4);
			top += SUN * pow(max(dot(sn, Hh), 0.0), 40.0) * 0.12 * (1.0 - smoothstep(0.3, 0.7, tn));
			top *= mix(0.55, 1.0, smoothstep(1.0, 0.6, sqrt(r2)));
			col = mix(col, top, mt);
		}
	}

	// shore: dark wet undercut + darker saturated soil edge
	col *= 1.0 - 0.3 * exp(-pow((wd - 0.012) / 0.014, 2.0));

	// aerial perspective toward the far lip
	vec3 hz2 = vec3(0.11, 0.16, 0.21);
	col = mix(col, hz2, haze * 0.38);
	// lip: bright rim where the ground edge catches the low light
	float rim = exp(-pow((Y - lip - 0.003) / 0.004, 2.0)) * (0.25 + 0.4 * vnoise(vec2(X * 6.0, 2.0)));
	col += vec3(0.30, 0.30, 0.20) * rim * 0.35;
	// gentle vignette towards the bottom
	col *= 1.0 - 0.28 * smoothstep(0.5, 1.0, vc);

	col = col / (1.0 + col * 0.35);

	float a = smoothstep(lip - 0.002, lip + 0.002, Y);
	vec4 gr = grass(X, Y, lip);
	vec3 outc = col;
	float oa = a;
	if (gr.a > 0.0) {
		oa = gr.a + a * (1.0 - gr.a);
		outc = (gr.rgb * gr.a + col * a * (1.0 - gr.a)) / max(oa, 0.0001);
	}
	outc += (h21(FRAGCOORD.xy) - 0.5) * (1.5 / 255.0);
	COLOR = vec4(outc, oa);
}
