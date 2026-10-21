shader_type canvas_item;

// GARDEN GROUND (par 1.0). Calm dark-teal glass-moss with self-similar (multi-scale) vein networks,
// a soft glowing path, and a shallow luminous pool with stepping crystal slabs near the falls.
uniform float aspect = 1.5;
uniform vec2 look = vec2(0.0);
uniform float cam = 0.0;
uniform float span = 3.0;
uniform float par = 1.0;

const float LIP = 0.76;

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
	f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float a = 0.5, s = 0.0;
	for (int i = 0; i < 4; i++) {
		s += a * vnoise(p);
		p = p * 2.03 + 17.1;
		a *= 0.5;
	}
	return s;
}
// x = F1, y = F2, z = hash of nearest cell
vec3 vor(vec2 p) {
	vec2 ip = floor(p);
	vec2 fp = fract(p);
	float d1 = 8.0, d2 = 8.0, id = 0.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 r = g + h22(ip + g) - fp;
			float d = dot(r, r);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				id = h21(ip + g + 7.7);
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return vec3(sqrt(d1), sqrt(d2), id);
}
// three octaves of cell-edge veins: each octave is a finer copy of the same network
// returns x = vein intensity, y = node glow, z = node hash
vec3 veins(vec2 p, float soft) {
	float e = 0.0, a = 1.0, s = 1.0, node = 0.0, nid = 0.0;
	for (int i = 0; i < 3; i++) {
		vec3 v = vor(p * s + float(i) * 5.3);
		float d = v.y - v.x;
		e += a * (1.0 - smoothstep(0.0, (0.07 + soft) * (1.0 - 0.18 * float(i)), d));
		if (i == 0) {
			node = exp(-v.x * v.x * 90.0) * step(0.62, v.z);
			nid = v.z;
		}
		s *= 2.17;
		a *= 0.5;
	}
	return vec3(e, node, nid);
}

float pathc(float X) {
	return 0.34 + 0.07 * sin(X * 1.25 + 0.8) + 0.03 * sin(X * 2.9 + 2.0);
}

void fragment() {
	float X = (UV.x - 0.5) * aspect + cam * span * par - look.x * (0.4 + par);
	float Y = UV.y - look.y * (0.3 + 0.5 * par);

	float lip = LIP + 0.009 * (vnoise(vec2(X * 2.2, 3.1)) - 0.5) * 2.0 + 0.003 * sin(X * 9.0);
	float v = (Y - lip) / (1.0 - LIP);
	float vc = max(v, 0.0);

	// perspective plane
	float z = 1.0 / (vc + 0.45);
	vec2 gp = vec2(X * z * 1.1, z * 1.6);

	float haze = exp(-vc * 4.5);
	float moss = fbm(gp * 2.6);
	vec3 col = mix(vec3(0.020, 0.072, 0.082), vec3(0.011, 0.040, 0.056), smoothstep(0.0, 1.0, vc));
	col *= 0.78 + 0.55 * moss;
	col = mix(col, vec3(0.05, 0.14, 0.17), haze * 0.40);

	// fractal veins, gently domain warped
	vec2 w = vec2(fbm(gp * 1.5 + 3.0), fbm(gp * 1.5 + 11.0)) - 0.5;
	vec3 vn = veins(gp * 1.9 + w * 0.8, 0.0);
	float fade = 0.35 + 0.65 * fbm(gp * 1.1 + 40.0);
	col += vec3(0.07, 0.30, 0.31) * vn.x * 0.27 * fade * (1.0 - 0.5 * haze);

	// soft glowing path
	float vcen = pathc(X);
	float pm = exp(-pow((vc - vcen) / 0.15, 2.0));
	col += vec3(0.035, 0.13, 0.12) * pm;
	col += vec3(0.18, 0.46, 0.38) * vn.x * pm * 0.20;
	vec3 nodecol = mix(vec3(0.75, 0.55, 0.20), vec3(0.45, 0.75, 0.95), step(0.82, vn.z));
	col += nodecol * vn.y * 0.30 * (0.35 + 0.65 * pm);

	// ---- pool near the falls ----
	float Xs = 2.55 + 0.30 * sin(vc * 4.0 + 1.0) + 0.12 * (vnoise(vec2(vc * 6.0, 4.0)) - 0.5);
	float vw = vc + 0.03 * (vnoise(vec2(X * 3.0, 8.0)) - 0.5);
	float wd = min(vw - 0.235, (X - Xs) * 0.30);
	float wmask = smoothstep(0.0, 0.014, wd);

	float glowx = exp(-pow((X - 3.30) / 0.75, 2.0));
	vec3 wc = mix(vec3(0.018, 0.085, 0.115), vec3(0.05, 0.26, 0.29), 0.25 + 0.75 * glowx);
	wc *= 1.0 - 0.45 * exp(-max(wd, 0.0) / 0.03) * 0.8;
	vec2 wp = vec2(X * 1.7, vc * 1.1 + 4.0);
	vec3 cv = veins(wp * 2.2 + vec2(TIME * 0.03, fbm(wp + TIME * 0.02)), 0.02);
	wc += vec3(0.10, 0.50, 0.55) * cv.x * 0.10 * (0.4 + glowx);
	float streak = vnoise(vec2(X * 26.0, vc * 2.5 - TIME * 0.08));
	wc += vec3(0.10, 0.38, 0.40) * glowx * streak * 0.10 * smoothstep(0.1, 0.5, vc);

	// stepping crystal slabs
	const vec4 SL[5] = vec4[](vec4(2.74, 0.40, 0.10, 0.075), vec4(2.97, 0.52, 0.09, 0.07), vec4(3.22, 0.44, 0.11, 0.08), vec4(3.46, 0.58, 0.10, 0.075), vec4(3.72, 0.48, 0.10, 0.07));
	for (int i = 0; i < 5; i++) {
		vec4 s = SL[i];
		vec2 l = vec2((X - s.x) / s.z, (vc - s.y) / s.w);
		if (abs(l.x) > 1.7 || abs(l.y) > 2.2) continue;
		// glow on water
		float gd = pow(pow(abs(l.x), 3.0) + pow(abs(l.y), 3.0), 0.3333) - 1.0;
		wc += vec3(0.08, 0.40, 0.42) * exp(-max(gd, 0.0) * 4.0) * 0.12 * (gd > 0.0 ? 1.0 : 0.0);
		// body (front face) is the same shape shifted down
		vec2 lb = vec2(l.x, l.y - 0.42);
		float sb = pow(pow(abs(lb.x), 3.0) + pow(abs(lb.y), 3.0), 0.3333) - 1.0;
		float mb = 1.0 - smoothstep(-0.05, 0.03, sb);
		wc = mix(wc, vec3(0.012, 0.07, 0.085), mb * 0.95);
		float st = gd;
		float mt = 1.0 - smoothstep(-0.05, 0.03, st);
		vec3 sv = veins(l * 1.6 + s.x * 13.0, 0.02);
		vec3 top = vec3(0.045, 0.20, 0.22) * (0.8 + 0.4 * (1.0 - l.y * 0.5));
		top += vec3(0.15, 0.55, 0.52) * sv.x * 0.16;
		top += nodecol * sv.y * 0.15;
		float rimm = exp(-pow(st / 0.07, 2.0)) * (1.0 - smoothstep(-0.2, 0.3, l.y));
		top += vec3(0.30, 0.80, 0.75) * rimm * 0.40;
		wc = mix(wc, top, mt);
	}

	col = mix(col, wc, wmask);

	// bank rim light where ledge meets water, and slight dark undercut
	float bank = exp(-pow((wd + 0.004) / 0.007, 2.0));
	col += vec3(0.10, 0.45, 0.45) * bank * 0.25 * (1.0 - wmask);
	col *= 1.0 - 0.25 * exp(-pow((wd - 0.014) / 0.012, 2.0));

	// lip rim light along the far edge
	float rim = exp(-pow((Y - lip - 0.005) / 0.0045, 2.0));
	col += vec3(0.16, 0.58, 0.55) * rim * (0.30 + 0.35 * vnoise(vec2(X * 5.0, 2.0)));

	col *= 1.0 - 0.18 * smoothstep(0.45, 1.0, vc);
	col = col / (1.0 + col * 0.5);

	float a = smoothstep(lip - 0.003, lip + 0.003, Y);
	// faint haze just above the lip
	float up = exp(-max(lip - Y, 0.0) / 0.012) * (1.0 - a);
	vec3 outc = col;
	float oa = a;
	if (a < 0.999) {
		float ha = up * 0.10;
		outc = (col * a + vec3(0.12, 0.38, 0.40) * ha * (1.0 - a)) / max(a + ha * (1.0 - a), 0.0001);
		oa = a + ha * (1.0 - a);
	}
	outc += (h21(FRAGCOORD.xy) - 0.5) * (1.5 / 255.0);
	COLOR = vec4(outc, oa);
}
