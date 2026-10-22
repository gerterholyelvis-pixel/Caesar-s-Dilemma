shader_type canvas_item;

// GARDEN LAYER: mid-distance fractal flora (ALPHA, par 0.30) -- realistic pass.
// Gnarled recursive trees: analytic cylinder normals + bark bump + moss, leaf-cluster canopies with
// thin-leaf translucency, canopy AO, warm key (upper-left) + sky fill + cyan waterfall rim,
// aerial haze, sparse bioluminescent bulbs. Fiddlehead fronds share the same lighting model.
uniform float aspect = 1.5;
uniform vec2 look = vec2(0.0);
uniform float cam = 0.0;
uniform float span = 3.0;
uniform float par = 1.0;

const vec3 LDIR = vec3(-0.5025, 0.4018, 0.7637); // normalised (-0.55, 0.44, 0.84), y UP
const vec3 SUN = vec3(1.0, 0.72, 0.42);

float h11(float p) {
	p = fract(p * 0.1031); p *= p + 33.33; p *= p + p; return fract(p);
}
float h21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}

struct TR {
	float d; float lvl; float rw; float s; vec2 nrm; vec2 lq; float lid;
	float cd; vec2 cg; float glow; float gh; float dtw; vec2 tn;
};

float segd(vec2 p, float len) {
	return length(p - vec2(0.0, clamp(p.y, 0.0, len)));
}

TR tree(vec2 P, float tx, float by, float L, float seed, int nl) {
	vec2 q = vec2(P.x - tx, by - P.y) / L;
	float sc = L;
	vec2 ax = vec2(1.0, 0.0), ay = vec2(0.0, 1.0);
	float pid = 1.0;
	TR t;
	t.d = 1e3; t.lvl = 0.0; t.rw = 0.01; t.s = 1.0; t.nrm = vec2(1.0, 0.0); t.lq = vec2(0.0); t.lid = 0.0;
	t.cd = 0.0; t.cg = vec2(0.0); t.glow = 0.0; t.gh = 0.0; t.dtw = 1e3; t.tn = vec2(1.0, 0.0);
	float aR = 0.24 + 0.34 * h11(seed), aL = 0.30 + 0.42 * h11(seed + 3.1);
	float kR = 0.70 + 0.07 * h11(seed + 7.7), kL = 0.60 + 0.10 * h11(seed + 5.3);
	float sl0 = 1.1 + 0.9 * h11(seed + 1.9);
	float sp0 = 0.7 + 0.8 * h11(seed + 13.0);
	for (int i = 0; i < nl; i++) {
		float fi = float(i);
		float sl = i == 0 ? sl0 : 1.0;
		float r = 0.088 * pow(0.88, fi);
		float yy = clamp(q.y / sl, 0.0, 1.0);
		float taper = i < 2 ? 1.0 + (i == 0 ? 1.1 : 0.5) * pow(1.0 - yy, 3.0) : 1.0;
		float knob = 0.88 + 0.24 * vnoise(vec2(q.y * 9.0 + fi * 5.1 + seed, 0.7));
		float wob = (vnoise(vec2(q.y * 2.4 + seed + fi * 11.0, 1.7)) - 0.5) * 0.16 * sin(3.14159 * yy);
		vec2 lv = vec2(q.x + wob, q.y - clamp(q.y, 0.0, sl));
		float dd = length(lv);
		float rr = r * taper * knob;
		float dw = (dd - rr) * sc;
		if (i >= nl - 3 && dd * sc < t.dtw) { t.dtw = dd * sc; vec2 ln0 = dd > 1e-6 ? lv / dd : vec2(1.0, 0.0); t.tn = ax * ln0.x + ay * ln0.y; }
		if (dw < t.d) {
			t.d = dw; t.lvl = fi; t.rw = rr * sc; t.s = clamp(dd / rr, 0.0, 1.0);
			vec2 ln = dd > 1e-6 ? lv / dd : vec2(1.0, 0.0);
			t.nrm = ax * ln.x + ay * ln.y;
			t.lq = vec2(q.x, q.y) * sc; t.lid = seed + fi * 7.3 + pid;
		}
		q.y -= sl;
		if (i == nl - 1) break;
		float aRi = sp0 * aR + 0.2 * (h11(seed * 1.3 + fi * 7.1) - 0.5);
		float aLi = sp0 * aL + 0.2 * (h11(seed * 2.1 + fi * 5.3) - 0.5);
		float sR = sin(aRi), cR = sqrt(1.0 - sR * sR), sLn = sin(aLi), cLn = sqrt(1.0 - sLn * sLn);
		vec2 qr = vec2(q.x * cR - q.y * sR, q.x * sR + q.y * cR) / kR;
		vec2 ql = vec2(q.x * cLn + q.y * sLn, -q.x * sLn + q.y * cLn) / kL;
		vec2 axr = cR * ax - sR * ay, ayr = sR * ax + cR * ay;
		vec2 axl = cLn * ax + sLn * ay, ayl = -sLn * ax + cLn * ay;
		float rn = r * 0.88;
		vec2 lvr = vec2(qr.x, qr.y - clamp(qr.y, 0.0, 1.0));
		vec2 lvl = vec2(ql.x, ql.y - clamp(ql.y, 0.0, 1.0));
		float ddr = length(lvr), ddl = length(lvl);
		float dr = (ddr - rn) * sc * kR;
		float dl = (ddl - rn) * sc * kL;
		if (i + 1 >= nl - 3) {
			if (ddr * sc * kR < t.dtw) { t.dtw = ddr * sc * kR; t.tn = axr * (ddr > 1e-6 ? lvr.x / ddr : 1.0) + ayr * (ddr > 1e-6 ? lvr.y / ddr : 0.0); }
			if (ddl * sc * kL < t.dtw) { t.dtw = ddl * sc * kL; t.tn = axl * (ddl > 1e-6 ? lvl.x / ddl : 1.0) + ayl * (ddl > 1e-6 ? lvl.y / ddl : 0.0); }
		}
		if (dr < t.d) {
			t.d = dr; t.lvl = fi + 1.0; t.rw = rn * sc * kR; t.s = clamp(ddr / rn, 0.0, 1.0);
			t.nrm = ax * 0.0 + axr * (ddr > 1e-6 ? lvr.x / ddr : 1.0) + ayr * (ddr > 1e-6 ? lvr.y / ddr : 0.0);
			t.lq = qr * sc * kR; t.lid = seed + (fi + 1.0) * 7.3 + pid * 2.0;
		}
		if (dl < t.d) {
			t.d = dl; t.lvl = fi + 1.0; t.rw = rn * sc * kL; t.s = clamp(ddl / rn, 0.0, 1.0);
			t.nrm = axl * (ddl > 1e-6 ? lvl.x / ddl : 1.0) + ayl * (ddl > 1e-6 ? lvl.y / ddl : 0.0);
			t.lq = ql * sc * kL; t.lid = seed + (fi + 1.0) * 7.3 + pid * 2.0 + 1.0;
		}
		// foliage blobs on both child ends (last levels only)
		if (i >= nl - 3) {
			vec2 pr = qr - vec2(0.0, 1.0), pl = ql - vec2(0.0, 1.0);
			float g1 = exp(-dot(pr, pr) * 1.25), g2 = exp(-dot(pl, pl) * 1.25);
			if (true) {
				float scr = sc * kR, scl = sc * kL;
				float tr = 0.0042;
				float hr = h11(seed + pid * 2.0 * 3.7), hl = h11(seed + (pid * 2.0 + 1.0) * 3.7);
				float dr2 = length(pr) * scr, dl2 = length(pl) * scl;
				float gr = (hr < 0.22 ? 1.0 : 0.0) * tr * tr / (dr2 * dr2 + tr * tr);
				float gl = (hl < 0.22 ? 1.0 : 0.0) * tr * tr / (dl2 * dl2 + tr * tr);
				t.glow += gr + gl;
				t.gh = gr > gl ? hr : hl;
			}
		}
		pid = pid * 2.0;
		if (segd(qr, 1.0 + kR * 2.2) * kR < segd(ql, 1.0 + kL * 2.2) * kL) { q = qr; sc *= kR; ax = axr; ay = ayr; pid += 0.0; }
		else { q = ql; sc *= kL; ax = axl; ay = ayl; pid += 1.0; }
	}
	float fr0 = clamp(t.dtw / (L * 0.36), 0.0, 1.0);
	vec2 Ec = vec2((P.x - tx) / (L * 1.9), (P.y - (by - L * 2.6)) / (L * 0.9));
	float env = clamp(1.0 - dot(Ec, Ec), 0.0, 1.0);
	t.cd = 1.3 * (1.0 - fr0) + 1.0 * env; t.cg = -t.tn * fr0;
	return t;
}

// Fiddlehead frond: stalk + inward spiral with pinnae.
struct FR { float d; float glow; float u; float rw; };

FR frond(vec2 P, vec2 base, float H, float R0, float flip, float sway) {
	P.x = base.x + flip * (P.x - base.x);
	vec2 Ep = vec2(base.x, base.y - H);
	vec2 cc = Ep - vec2(R0, 0.0);
	FR f; f.d = 1e3; f.glow = 0.0; f.u = -1.0; f.rw = 0.006;
	float b = 0.20;
	float sy = clamp((P.y - Ep.y) / (base.y - Ep.y), 0.0, 1.0);
	float xs = Ep.x + b * (P.y - Ep.y) * 0.8 + sway * sy * sy * H;
	float slope = b * 0.8 + 2.0 * sway * sy * H / (base.y - Ep.y);
	float ws = mix(0.006, 0.014, sy);
	float ds = abs(P.x - xs) / sqrt(1.0 + slope * slope) - ws;
	if (P.y < Ep.y) ds = length(P - Ep) - ws;
	f.d = ds; f.u = -1.0; f.rw = ws;
	vec2 v = vec2(P.x - cc.x, cc.y - P.y);
	float rho = max(length(v), 1e-4);
	float phi = atan(v.y, v.x);
	float thmax = 10.2;
	float thr = log(R0 / rho) / b;
	float n = floor((thr - phi) / 6.2831853 + 0.5);
	float th = clamp(phi + 6.2831853 * n, 0.0, thmax);
	float rs = R0 * exp(-b * th);
	vec2 sp = rs * vec2(cos(th), sin(th));
	float wsp = 0.0065 * (0.35 + 0.65 * rs / R0);
	float dsp = length(v - sp) - wsp;
	if (dsp < f.d) { f.d = dsp; f.u = th / thmax; f.rw = wsp; }
	float dl = 0.5;
	float m = clamp(floor(th / dl + 0.5), 1.0, floor(thmax / dl));
	float tm = m * dl;
	float rm = R0 * exp(-b * tm);
	vec2 dir = vec2(cos(tm), sin(tm));
	vec2 S = rm * dir;
	float len = 0.50 * rm + 0.006;
	vec2 pa = v - S;
	float hp = clamp(dot(pa, dir) / len, 0.0, 1.0);
	vec2 perp = vec2(-dir.y, dir.x);
	float dpin = length(pa - dir * len * hp - perp * 0.25 * len * hp * hp) - 0.0026 * (1.0 - 0.6 * hp);
	if (dpin < f.d) { f.d = dpin; f.u = tm / thmax; f.rw = 0.0026; }
	vec2 tip = S + dir * len + perp * 0.25 * len;
	float tr = 0.0035 * (0.4 + 0.6 * rm / R0) + 0.001;
	float td = length(v - tip);
	f.glow = tr * tr / (td * td + tr * tr) * (fract(tm * 7.13) < 0.3 ? 1.0 : 0.0);
	return f;
}

vec3 hueTip(float s) {
	vec3 mag = vec3(1.0, 0.38, 0.72), gold = vec3(1.0, 0.74, 0.34), cy = vec3(0.40, 1.0, 0.92);
	s = fract(s * 3.0) * 1.0;
	return s < 0.5 ? mix(mag, gold, s * 2.0) : mix(gold, cy, (s - 0.5) * 2.0);
}

// shared lighting: key sun (upper-left) + sky fill + cyan waterfall rim + wet specular
vec3 lightIt(vec3 alb, vec3 n, float ao, float wf, float gloss, float spec) {
	float nl = dot(n, LDIR);
	float diff = max(nl, 0.0);
	vec3 amb = mix(vec3(0.10, 0.09, 0.20), vec3(0.22, 0.30, 0.52), n.y * 0.5 + 0.5) * 0.9;
	vec3 col = alb * (SUN * diff * 1.25 + amb) * ao;
	float fr = pow(1.0 - clamp(n.z, 0.0, 1.0), 2.2);
	col += vec3(0.16, 0.85, 0.80) * (max(n.x, 0.0) * 0.35 + fr * max(n.x + 0.35, 0.0)) * wf * (0.25 + 0.75 * ao) * 0.55;
	vec3 H = normalize(LDIR + vec3(0.0, 0.0, 1.0));
	col += SUN * pow(max(dot(n, H), 0.0), gloss) * spec * ao;
	return col;
}

vec3 hazeCol(float Y) {
	return mix(vec3(0.30, 0.28, 0.52), vec3(0.62, 0.44, 0.60), smoothstep(0.15, 0.80, Y));
}

void fragment() {
	float X = (UV.x - 0.5) * aspect + cam * span * par - look.x * (0.4 + par);
	float Y = UV.y - look.y * (0.3 + 0.5 * par);
	float px = SCREEN_PIXEL_SIZE.y;
	float wfX = smoothstep(-0.6, 1.8, X);
	float wf = 0.25 + 0.75 * wfX;
	vec3 acc = vec3(0.0); float aa = 0.0; // premultiplied accumulation

	// low mist (faint, patchy, drifting slowly)
	{
		float n = vnoise(vec2(X * 2.2, Y * 9.0) + vec2(TIME * 0.02, 0.0)) * 0.6 + vnoise(vec2(X * 5.0 + 4.0, Y * 16.0)) * 0.4;
		float m = exp(-pow((Y - 0.80) / 0.10, 2.0)) * (0.30 + 0.70 * n) * 0.20;
		vec3 mc = mix(vec3(0.42, 0.50, 0.70), vec3(0.65, 0.75, 0.85), wfX);
		acc += mc * m; aa += m;
	}

	for (int dep = 1; dep >= 0; dep--) {
		bool far = dep == 1;
		float XX = far ? X * 0.70 : X;
		for (int k = 0; k < 5; k++) {
			vec4 T; // x, base y, L, seed
			if (far) {
				if (k == 0) T = vec4(-0.50, 0.84, 0.16, 11.0);
				else if (k == 1) T = vec4(0.22, 0.84, 0.14, 23.0);
				else if (k == 2) T = vec4(0.70, 0.84, 0.15, 37.0);
				else if (k == 3) T = vec4(1.12, 0.84, 0.12, 41.0);
				else T = vec4(1.55, 0.84, 0.11, 57.0);
			} else {
				if (k == 0) T = vec4(-0.66, 0.88, 0.21, 3.0);
				else if (k == 1) T = vec4(0.0, 0.88, 0.19, 14.0);
				else if (k == 2) T = vec4(1.30, 0.88, 0.17, 8.0);
				else if (k == 3) T = vec4(1.85, 0.88, 0.14, 19.0);
				else continue;
			}
			float fadeX = 1.0 - 0.7 * smoothstep(1.2, 1.9, X);
			{
				// faint scattered light pooled behind the crown (not a flat halo)
				vec2 ac = vec2(T.x, T.y - T.z * 3.3);
				vec2 ad = (vec2(XX, Y) - ac) / (T.z * vec2(3.2, 2.0));
				float aur = exp(-dot(ad, ad) * 1.6) * (far ? 0.05 : 0.06) * fadeX;
				vec3 ac3 = mix(vec3(0.30, 0.34, 0.70), vec3(0.85, 0.55, 0.60), wfX);
				acc = ac3 * aur + acc * (1.0 - aur);
				aa = aur + aa * (1.0 - aur);
			}
			if (abs(XX - T.x) > T.z * 3.8 || Y < T.y - T.z * 4.9 || Y > T.y) continue;
			{ vec2 e = vec2((XX - T.x) / (T.z * 3.7), (Y - (T.y - T.z * 3.5)) / (T.z * 2.6)); if (dot(e, e) > 1.0 && !(abs(XX - T.x) < T.z * 0.9 && Y > T.y - T.z * 2.4)) continue; }
			TR t = tree(vec2(XX, Y), T.x, T.y, T.z, T.w, far ? 6 : 7);
			float treeH = h11(T.w * 1.7);
			vec3 hz = hazeCol(Y);
			float hzAmt = far ? 0.58 : 0.20;
			// aerial haze thickens toward the ground (trunk bases dissolve in mist)
			hzAmt = clamp(hzAmt + (Y - (T.y - 0.30)) * 0.7 * smoothstep(0.0, 0.3, Y - (T.y - 0.30)), 0.0, 0.72);

			// ---- bark / branches ----
			float bcov = 1.0 - smoothstep(-px * 0.8, px * 0.8, t.d);
			vec3 bcol = vec3(0.0);
			float rwv = max(t.rw, px);
			if (bcov > 0.001) {
				float s = t.s;
				vec3 n = vec3(t.nrm * s, sqrt(max(1.0 - s * s, 0.02)));
				float h1 = vnoise(vec2(t.lq.x / (rwv * 0.42), t.lq.y / (rwv * 3.5) + t.lid * 3.1));
				float h2 = vnoise(vec2(t.lq.x / (rwv * 0.13), t.lq.y / (rwv * 0.9) + t.lid));
				float bump = h1 * 0.65 + h2 * 0.35;
				n = normalize(n + vec3(t.nrm * (bump - 0.5) * 0.9, 0.0));
				vec3 alb = mix(vec3(0.050, 0.042, 0.060), vec3(0.15, 0.125, 0.115), bump * bump * 1.6);
				float moss = smoothstep(0.50, 0.68, vnoise(vec2(t.lq.x / (rwv * 1.6), t.lq.y / (rwv * 2.4) + t.lid * 1.7)) + n.y * 0.28);
				alb = mix(alb, vec3(0.055, 0.17, 0.11) * (0.7 + 0.6 * h2), moss * 0.85);
				float ao = (1.0 - 0.72 * clamp(t.cd * 0.45, 0.0, 1.0)) * (0.55 + 0.45 * bump);
				ao *= 0.55 + 0.45 * smoothstep(0.0, 0.5, t.s < 0.0 ? 0.0 : 1.0 - t.s * 0.4);
				float rootAO = smoothstep(0.0, 0.10, T.y - Y);   // contact darkening near the ground
				ao *= mix(0.55, 1.0, rootAO);
				bcol = lightIt(alb, n, ao, wf, 18.0, 0.10 + 0.18 * (1.0 - moss));
				// sap vein: thin bioluminescent filament in a few branches, slow pulse
				float veinOn = h11(floor(t.lid * 3.0) + 7.0) < 0.35 && t.lvl >= 1.0 ? 1.0 : 0.0;
				float vein = exp(-pow(t.lq.x / (rwv * 0.14), 2.0)) * veinOn * (1.0 - moss);
				float pulse = 0.65 + 0.35 * sin(t.lq.y * 260.0 - TIME * 1.5);
				bcol += vec3(0.25, 0.95, 0.85) * vein * pulse * 0.22 * smoothstep(0.0, 0.3, 1.0 - t.s);
			}

			// ---- foliage ----
			float ccov = 0.0; vec3 ccol = vec3(0.0);
			if (t.cd > 0.12) {
				vec2 pw = vec2(XX, Y) + vec2(T.w * 1.37, T.w * 0.71);
				vec2 pa = vec2(pw.x * 0.8 + pw.y * 0.6, -pw.x * 0.6 + pw.y * 0.8);
				float fs = far ? 190.0 : 150.0;
				float n1 = vnoise(pa * fs);
				float n3 = vnoise(vec2(pw.x * 0.6 - pw.y * 0.8, pw.x * 0.8 + pw.y * 0.6) * fs * 0.52);
				float n2 = vnoise(pw * 13.0);
				float n2x = vnoise(pw * 13.0 + vec2(0.35, 0.0)), n2y = vnoise(pw * 13.0 + vec2(0.0, 0.35));
				float lm = smoothstep(0.25, 0.75, n1 * 0.6 + n3 * 0.4);
				float dens = t.cd + (lm - 0.5) * 0.9 + (n2 - 0.5) * 0.9;
				ccov = smoothstep(0.68, 0.76, dens);
				if (ccov > 0.002) {
					vec2 bigg = vec2(n2x - n2, n2y - n2) * 5.0; // clump-scale lobes (y down in screen)
					vec3 n = normalize(vec3(-t.cg.x * 1.0 - bigg.x + (n3 - 0.5) * 0.9, -t.cg.y * 1.0 + bigg.y + (n1 - 0.5) * 0.9, 1.0));
					float hid = fract(n1 * 7.0 + n3 * 3.0);
					vec3 tint = treeH < 0.30 ? vec3(0.15, 0.12, 0.30) : (treeH < 0.55 ? vec3(0.08, 0.25, 0.22) : vec3(0.11, 0.27, 0.12));
					vec3 alb = tint * (0.65 + 0.7 * lm);
					float ao = (1.0 - 0.75 * smoothstep(0.9, 2.0, t.cd)) * (0.35 + 0.65 * smoothstep(0.2, 0.75, n2 + 0.3 * (lm - 0.5))) * (0.55 + 0.45 * lm);
					vec3 lit = lightIt(alb, n, ao, wf, 30.0, 0.05 + 0.14 * step(0.8, hid));
					// thin-leaf translucency: light leaking through leaves facing away from the sun
					float tr = max(-dot(n, LDIR), 0.0) * 0.8 + 0.22;
					vec3 sss = mix(vec3(0.62, 0.80, 0.22), vec3(0.85, 0.55, 0.80), step(treeH, 0.30)) * alb * 3.0;
					lit += sss * SUN * tr * (0.35 + 0.65 * lm) * ao * 0.8;
					ccol = lit;
				}
			}
			// bioluminescent bulbs
			vec3 gc = hueTip(t.gh * 3.7 + treeH);
			float gcore = t.glow * (0.5 + 0.5 * wf);
			float halo = gcore * 0.0;
			vec3 emis = gc * gcore * 1.0;

			vec3 col = bcol * bcov;
			float al = bcov;
			col = mix(col, ccol, ccov);
			al = al + ccov * (1.0 - al);
			// haze mixing (colour only), alpha eases a bit with distance
			col = mix(col, hz * al, hzAmt * 0.9);
			al *= far ? 0.88 : 0.97;
			float ga = clamp(gcore * 0.9, 0.0, 1.0);
			col += emis * (far ? 0.55 : 0.8);
			al = clamp(al + ga, 0.0, 1.0);
			al *= fadeX; col *= fadeX;
			acc = col + acc * (1.0 - al);
			aa = al + aa * (1.0 - al);
		}
		if (far) {
			// volumetric haze sheet between the two tree depths
			float n = vnoise(vec2(X * 1.6, Y * 5.0) + vec2(TIME * 0.015, 0.0)) * 0.65 + vnoise(vec2(X * 4.0, Y * 11.0 + 3.0)) * 0.35;
			float m = smoothstep(0.30, 0.80, Y) * (0.12 + 0.12 * n);
			vec3 hz = hazeCol(Y + 0.05) * 1.05;
			acc = hz * m + acc * (1.0 - m);
			aa = m + aa * (1.0 - m);
		}
	}

	// fiddlehead fronds (near depth)
	for (int k = 0; k < 2; k++) {
		vec4 F; float flip = 1.0; float sway = 0.1;
		if (k == 0) { F = vec4(0.42, 0.86, 0.36, 0.07); flip = -1.0; sway = 0.12; }
		else { F = vec4(1.62, 0.86, 0.46, 0.085); flip = -1.0; sway = 0.10; }
		if (abs(X - F.x) > 0.5 || Y < F.y - F.z - F.w * 2.4 || Y > F.y) continue;
		FR f = frond(vec2(X, Y), F.xy, F.z, F.w, flip, sway);
		float cov = 1.0 - smoothstep(-px * 0.8, px * 0.8, f.d);
		float fadeX = 1.0 - 0.6 * smoothstep(1.4, 2.0, X);
		float u = clamp(f.u, 0.0, 1.0);
		vec3 col = vec3(0.0); float al = cov;
		if (cov > 0.001) {
			float gx = dFdx(f.d) * flip, gy = -dFdy(f.d);
			vec2 gdir = vec2(gx, gy) / (length(vec2(gx, gy)) + 1e-7);
			float s = clamp(1.0 + f.d / max(f.rw, px), 0.0, 1.0);
			s = 1.0 - s; // 0 centre .. 1 edge
			vec3 n = normalize(vec3(gdir * s, sqrt(max(1.0 - s * s, 0.03))));
			float fn = vnoise(vec2(X * 260.0, Y * 40.0));
			n = normalize(n + vec3(0.0, 0.0, 0.0) + vec3(gdir * (fn - 0.5) * 0.4, 0.0));
			vec3 stalkc = vec3(0.07, 0.20, 0.16), curlc = vec3(0.10, 0.30, 0.25), pinc = vec3(0.16, 0.38, 0.20);
			vec3 alb = f.u < 0.0 ? stalkc * (0.8 + 0.4 * fn) : mix(curlc, pinc, 0.35 + 0.65 * u);
			float ao = 0.75 + 0.25 * (1.0 - smoothstep(0.0, 1.0, 1.0 - u)) * (f.u < 0.0 ? 0.0 : 1.0) + (f.u < 0.0 ? 0.25 * smoothstep(0.0, 0.1, F.y - Y) : 0.0);
			ao *= mix(0.6, 1.0, smoothstep(0.0, 0.12, F.y - Y));
			col = lightIt(alb, n, ao, wf, 22.0, 0.20);
			float tr = max(-dot(n, LDIR), 0.0) * 0.7 + 0.15;
			col += vec3(0.60, 0.80, 0.25) * alb * SUN * tr * 1.6 * ao * (f.u < 0.0 ? 0.3 : 1.0);
			vec3 hz = hazeCol(Y);
			col = mix(col, hz * al, 0.14);
		}
		vec3 gc = hueTip(0.15 + 0.3 * float(k) + u);
		float glow = f.glow * (0.5 + 0.5 * wf);
		col = col * cov + gc * glow * 0.95;
		al = clamp(cov + glow * 0.9, 0.0, 1.0);
		al *= fadeX; col *= fadeX;
		acc = col + acc * (1.0 - al);
		aa = al + aa * (1.0 - al);
	}

	// god rays: warm shafts from the upper-left, kept above the gameplay band
	{
		float u = (X * 0.80 + Y * 0.60);
		float rays = vnoise(vec2(u * 7.0, 3.3 + TIME * 0.01)) * 0.6 + vnoise(vec2(u * 17.0, 1.1)) * 0.4;
		rays = smoothstep(0.35, 0.85, rays);
		float fall = (1.0 - smoothstep(0.10, 0.55, Y)) * (1.0 - smoothstep(0.4, 1.0, UV.x + 0.0)) ;
		float m = rays * fall * 0.075;
		vec3 rc = vec3(1.0, 0.78, 0.52);
		acc += rc * m; aa += m;
	}

	float dith = (h21(FRAGCOORD.xy + fract(TIME) * 17.0) - 0.5) / 255.0;
	vec3 rgb = aa > 0.002 ? acc / aa : vec3(0.0);
	rgb = rgb / (1.0 + 0.18 * rgb);
	COLOR = vec4(clamp(rgb + dith, 0.0, 1.0), clamp(aa, 0.0, 1.0));
}
