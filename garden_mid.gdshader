shader_type canvas_item;

// GARDEN LAYER: mid-distance fractal flora (ALPHA, par 0.30).
// Recursive fold trees (binary, asymmetric, self-similar) with glowing tips, plus spiral fiddlehead fronds.
uniform float aspect = 1.5;
uniform vec2 look = vec2(0.0);
uniform float cam = 0.0;
uniform float span = 3.0;
uniform float par = 1.0;

const int NLV = 9;

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

struct TR { float d; float lvl; float across; float glow; float rw; };

float segd(vec2 p, float len) {
	return length(p - vec2(0.0, clamp(p.y, 0.0, len)));
}

TR tree(vec2 P, float tx, float by, float L, float seed, int nl) {
	vec2 q = vec2(P.x - tx, by - P.y) / L;
	float sc = L;
	TR t; t.d = 1e3; t.lvl = 0.0; t.across = 0.0; t.glow = 0.0; t.rw = 0.01;
	float aR = 0.16 + 0.26 * h11(seed), aL = 0.22 + 0.34 * h11(seed + 3.1);
	float kR = 0.70 + 0.07 * h11(seed + 7.7), kL = 0.60 + 0.10 * h11(seed + 5.3);
	float sl0 = 1.1 + 0.9 * h11(seed + 1.9);
	float sp0 = 0.6 + 0.8 * h11(seed + 13.0);
	for (int i = 0; i < nl; i++) {
		float fi = float(i);
		float sl = i == 0 ? sl0 : 1.0;
		float r = 0.05 * pow(0.86, fi);
		float taper = i < 2 ? 1.0 + 0.55 * (1.0 - clamp(q.y / sl, 0.0, 1.0)) : 1.0;
		float dd = segd(q, sl);
		float dw = (dd - r * taper) * sc;
		if (dw < t.d) { t.d = dw; t.lvl = fi; t.across = dd / (r * taper); t.rw = r * taper * sc; }
		q.y -= sl;
		if (i >= nl - 3) {
			float tipd = length(q) * sc;
			float tr = 0.0055 * (i == nl - 1 ? 1.0 : 0.6);
			t.glow += tr * tr / (tipd * tipd + tr * tr) * (i == nl - 1 ? 1.0 : 0.45);
		}
		if (i == nl - 1) break;
		float spread = sp0;
		float aRi = spread * aR + 0.16 * (h11(seed * 1.3 + fi * 7.1) - 0.5);
		float aLi = spread * aL + 0.16 * (h11(seed * 2.1 + fi * 5.3) - 0.5);
		float sR = sin(aRi), cR = sqrt(1.0 - sR * sR), sLn = sin(aLi), cLn = sqrt(1.0 - sLn * sLn);
		vec2 qr = vec2(q.x * cR - q.y * sR, q.x * sR + q.y * cR) / kR;
		vec2 ql = vec2(q.x * cLn + q.y * sLn, -q.x * sLn + q.y * cLn) / kL;
		float rn = r * 0.86;
		float dr = (segd(qr, 1.0) - rn) * sc * kR;
		float dl = (segd(ql, 1.0) - rn) * sc * kL;
		if (dr < t.d) { t.d = dr; t.lvl = fi + 1.0; t.across = 1.0; t.rw = rn * sc * kR; }
		if (dl < t.d) { t.d = dl; t.lvl = fi + 1.0; t.across = 1.0; t.rw = rn * sc * kL; }
		// choose the child whose whole cone is nearer
		float cr = segd(qr, 1.0 + kR * 2.2) * kR;
		float cl = segd(ql, 1.0 + kL * 2.2) * kL;
		if (cr < cl) { q = qr; sc *= kR; } else { q = ql; sc *= kL; }
	}
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
	float ws = mix(0.005, 0.011, sy);
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
	float wsp = 0.0055 * (0.35 + 0.65 * rs / R0);
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
	float dpin = length(pa - dir * len * hp - perp * 0.25 * len * hp * hp) - 0.0022 * (1.0 - 0.6 * hp);
	if (dpin < f.d) { f.d = dpin; f.u = tm / thmax; f.rw = 0.002; }
	vec2 tip = S + dir * len + perp * 0.25 * len;
	float tr = 0.006 * (0.4 + 0.6 * rm / R0) + 0.0015;
	float td = length(v - tip);
	f.glow = tr * tr / (td * td + tr * tr);
	return f;
}

vec3 hueTip(float s) {
	vec3 mag = vec3(1.0, 0.38, 0.78), gold = vec3(1.0, 0.78, 0.36), cy = vec3(0.45, 1.0, 0.95);
	return s < 0.5 ? mix(mag, gold, s * 2.0) : mix(gold, cy, (s - 0.5) * 2.0);
}

void fragment() {
	float X = (UV.x - 0.5) * aspect + cam * span * par - look.x * (0.4 + par);
	float Y = UV.y - look.y * (0.3 + 0.5 * par);
	float px = SCREEN_PIXEL_SIZE.y;
	vec3 acc = vec3(0.0); float aa = 0.0; // premultiplied accumulation

	// low mist (very faint, patchy)
	{
		float n = vnoise(vec2(X * 2.2, Y * 9.0) + vec2(TIME * 0.02, 0.0)) * 0.6 + vnoise(vec2(X * 5.0 + 4.0, Y * 16.0)) * 0.4;
		float m = exp(-pow((Y - 0.78) / 0.11, 2.0)) * (0.35 + 0.65 * n) * 0.16;
		vec3 mc = vec3(0.45, 0.62, 0.82);
		acc += mc * m; aa += m;
	}

	// two depths of trees
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
			{
				// soft luminous aura behind the crown
				vec2 ac = vec2(T.x, T.y - T.z * 3.3);
				vec2 ad = (vec2(XX, Y) - ac) / (T.z * vec2(3.2, 2.0));
				float aur = exp(-dot(ad, ad) * 1.6) * (far ? 0.07 : 0.10);
				float lx = smoothstep(-0.6, 1.8, X);
				vec3 ac3 = mix(vec3(0.25, 0.35, 0.8), vec3(0.9, 0.45, 0.7), lx) * (0.5 + 0.5 * lx);
				float fx0 = 1.0 - 0.7 * smoothstep(1.2, 1.9, X);
				aur *= fx0;
				acc = ac3 * aur + acc * (1.0 - aur);
				aa = aur + aa * (1.0 - aur);
			}
			if (abs(XX - T.x) > T.z * 3.8 || Y < T.y - T.z * 4.9 || Y > T.y) continue;
			{ vec2 e = vec2((XX - T.x) / (T.z * 3.7), (Y - (T.y - T.z * 3.5)) / (T.z * 2.6)); if (dot(e, e) > 1.0 && !(abs(XX - T.x) < T.z * 0.9 && Y > T.y - T.z * 2.4)) continue; }
			TR t = tree(vec2(XX, Y), T.x, T.y, T.z, T.w, far ? 6 : 7);
			float lv = t.lvl / (far ? 5.0 : 6.0);
			float lightX = smoothstep(-0.6, 1.8, X);
			float lit = 0.35 + 0.65 * lightX;
			float cov = 1.0 - smoothstep(-px * 0.9, px * 0.9, t.d);
			float gx = dFdx(t.d), gy = dFdy(t.d);
			float nx = gx / (length(vec2(gx, gy)) + 1e-7);
			float rimband = 1.0 - smoothstep(0.0, max(t.rw * 0.9, px * 1.5), -t.d);
			float rim = clamp(nx, 0.0, 1.0) * rimband;
			vec3 trunk = vec3(0.045, 0.04, 0.15), midc = vec3(0.04, 0.27, 0.36), tipc = vec3(0.35, 0.9, 0.92);
			vec3 base = mix(trunk, midc, smoothstep(0.0, 0.55, lv));
			base = mix(base, tipc * 0.55, smoothstep(0.45, 1.0, lv) * 0.65);
			float core = exp(-t.across * t.across * 2.5);
			base += tipc * core * (0.10 + 0.5 * lv) * lit;
			base += vec3(1.0, 0.72, 0.38) * rim * (0.25 + 0.9 * lit);
			vec3 gc = hueTip(fract(h11(T.w * 1.7) * 0.6 + lightX * 0.45 + 0.1));
			float halo = exp(-max(t.d, 0.0) / 0.010) * 0.07 * (0.3 + 0.7 * lv) * lit;
			float glow = t.glow * (0.55 + 0.6 * lit);
			vec3 col = base * cov;
			float al = cov;
			col += gc * glow * 1.1 + tipc * halo;
			al = clamp(al + glow * 0.9 + halo, 0.0, 1.0);
			col = min(col, vec3(1.0));
			if (far) {
				vec3 hz = vec3(0.30, 0.34, 0.62);
				col = mix(col, hz * al, 0.55);
				al *= 0.82;
			}
			float fadeX = 1.0 - 0.7 * smoothstep(1.2, 1.9, X);
			al *= fadeX; col *= fadeX;
			acc = col + acc * (1.0 - al);
			aa = al + aa * (1.0 - al);
		}
	}

	// fiddlehead fronds (near depth)
	for (int k = 0; k < 2; k++) {
		vec4 F; float flip = 1.0; float sway = 0.1;
		if (k == 0) { F = vec4(0.42, 0.86, 0.36, 0.07); flip = -1.0; sway = 0.12; }
		else { F = vec4(1.62, 0.86, 0.46, 0.085); flip = -1.0; sway = 0.10; }
		if (abs(X - F.x) > 0.5 || Y < F.y - F.z - F.w * 2.4 || Y > F.y) continue;
		FR f = frond(vec2(X, Y), F.xy, F.z, F.w, flip, sway);
		float cov = 1.0 - smoothstep(-px * 0.9, px * 0.9, f.d);
		float lightX = smoothstep(-0.6, 1.8, X);
		float lit = 0.35 + 0.65 * lightX;
		float u = clamp(f.u, 0.0, 1.0);
		vec3 stalkc = vec3(0.04, 0.2, 0.26), curlc = vec3(0.10, 0.45, 0.50), pinc = vec3(0.30, 0.85, 0.80);
		vec3 base = f.u < 0.0 ? stalkc : mix(curlc, pinc, 0.35 + 0.65 * u);
		float gx = dFdx(f.d), gy = dFdy(f.d);
		float nx = gx / (length(vec2(gx, gy)) + 1e-7);
		float rim = clamp(nx, 0.0, 1.0) * (1.0 - smoothstep(0.0, max(f.rw, px * 1.5), -f.d));
		base += vec3(1.0, 0.72, 0.38) * rim * (0.3 + 0.9 * lit);
		vec3 gc = hueTip(fract(0.15 + lightX * 0.5 + 0.2 * float(k)));
		float halo = exp(-max(f.d, 0.0) / 0.015) * 0.10 * lit;
		float glow = f.glow * (0.5 + 0.7 * lit);
		vec3 col = base * cov + gc * glow * 1.05 + pinc * halo;
		float al = clamp(cov + glow * 0.9 + halo, 0.0, 1.0);
		float fadeX = 1.0 - 0.6 * smoothstep(1.4, 2.0, X);
		al *= fadeX; col *= fadeX;
		acc = col + acc * (1.0 - al);
		aa = al + aa * (1.0 - al);
	}

	float dith = (h21(FRAGCOORD.xy + fract(TIME) * 17.0) - 0.5) / 255.0;
	vec3 rgb = aa > 0.002 ? acc / aa : vec3(0.0);
	rgb = rgb / (1.0 + 0.25 * rgb);
	rgb = pow(rgb, vec3(0.92)) * 1.08;
	COLOR = vec4(clamp(rgb + dith, 0.0, 1.0), clamp(aa, 0.0, 1.0));
}
