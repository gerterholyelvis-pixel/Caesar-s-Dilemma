shader_type canvas_item;

// GARDEN LAYER 3: the hero waterfall. Alpha layer (par 0.50), world centre X = 1.70.
// A fractal waterfall: one great fall splits into two, then four (each half the width of its
// parent), spilling over glowing ledges into a calm bioluminescent pool. The rock is crystal
// that fractures at three nested scales (Voronoi inside Voronoi inside Voronoi).
uniform float aspect = 1.5;
uniform vec2  look = vec2(0.0);
uniform float cam = 0.0;
uniform float span = 3.0;
uniform float par = 1.0;

const float CX = 1.70;
const float W = 0.72;          // total span between outer fall centres (tier 2 spans +-0.27)

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
float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x),
	           mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 4; i++) {
		s += a * vn(p);
		p = p * 2.03 + vec2(17.1, 9.7);
		a *= 0.5;
	}
	return s;
}
float tri(float x) { return abs(fract(x) - 0.5) * 2.0; }
// self-similar zig-zag: three octaves of the same sawtooth
float jag(float y) { return tri(y * 4.0) * 0.030 + tri(y * 11.0 + 0.3) * 0.012 + tri(y * 29.0 + 0.7) * 0.005 - 0.024; }

vec3 vor(vec2 q) {
	vec2 i = floor(q);
	vec2 f = fract(q);
	float d1 = 8.0;
	float d2 = 8.0;
	float id = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = h22(i + g);
			vec2 r = g + o - f;
			float d = dot(r, r);
			if (d < d1) { d2 = d1; d1 = d; id = h21(i + g + 7.0); }
			else if (d < d2) { d2 = d; }
		}
	}
	float s1 = sqrt(d1);
	return vec3(s1, sqrt(d2) - s1, id);
}

// Geometry of the three fall tiers. Returns (signed edge distance, tier-local u, tier index) and
// the nearest fall centre / half width through the out parameters.
vec3 fall_geo(vec2 p, out float cx, out float hw) {
	float n;
	float ya;
	float yb;
	float t;
	if (p.y < 0.345) { n = 1.0; ya = 0.10; yb = 0.345; t = 0.0; }
	else if (p.y < 0.565) { n = 2.0; ya = 0.365; yb = 0.565; t = 1.0; }
	else { n = 4.0; ya = 0.585; yb = 0.675; t = 2.0; }
	float u = clamp((p.y - ya) / (yb - ya), 0.0, 1.0);
	float idx = clamp(floor((p.x / W + 0.5) * n), 0.0, n - 1.0);
	cx = ((idx + 0.5) / n - 0.5) * W;
	float h0 = 0.19 / n * 1.04;
	hw = h0 * (0.84 + 0.30 * u) + (jag(p.y * 1.7 + idx * 0.37) * h0 * 3.0) * 0.5;
	float dE = abs(p.x - cx) - hw;
	return vec3(dE, u, t);
}

float fbm3(vec2 p) {
	float s = vn(p) * 0.5;
	p = p * 2.03 + vec2(17.1, 9.7);
	s += vn(p) * 0.28;
	p = p * 2.03 + vec2(17.1, 9.7);
	return s + vn(p) * 0.22;
}

const vec3 LDIR = vec3(-0.58, -0.52, 0.63);     // low golden light from upper left (y down)
const vec3 SUNC = vec3(1.00, 0.78, 0.52);
const vec3 SKYC = vec3(0.30, 0.40, 0.62);
const vec3 HAZE = vec3(0.34, 0.42, 0.56);

void ov(inout vec3 c, inout float a, vec3 lc, float la) {
	c = lc * la + c * (1.0 - la);
	a = la + a * (1.0 - la);
}

vec4 render(vec2 UV_, vec2 FC_, float T_) {
	float X = (UV_.x - 0.5) * aspect + cam * span * par - look.x * (0.4 + par);
	float Y = UV_.y - look.y * (0.3 + 0.5 * par);
	vec2 p = vec2(X - CX, Y);
	float edgeFade = smoothstep(-0.86, -0.58, p.x) * (1.0 - smoothstep(0.60, 0.90, p.x));
	if (edgeFade <= 0.002) { return vec4(0.0); }
	float T = T_;
	vec3 L = normalize(LDIR);
	vec3 Hh = normalize(L + vec3(0.0, 0.0, 1.0));

	vec3 col = vec3(0.0);
	float a = 0.0;

	// ---------- geometry ----------
	float cxF;
	float hwF;
	vec3 g = fall_geo(p, cxF, hwF);
	float edgeN = fbm3(vec2(p.x * 26.0, p.y * 9.0)) - 0.5;
	float dE = g.x + edgeN * (0.010 + 0.022 * g.y * step(0.5, g.z));
	float rockBottom = 0.672 - 0.03 * smoothstep(0.28, 0.58, abs(p.x)) + jag(p.x * 1.3 + 2.0) * 0.5 + (fbm3(vec2(p.x * 18.0, 3.0)) - 0.5) * 0.016;

	float ledgeY1 = 0.350;
	float ledgeY2 = 0.572;
	vec2 q1 = vec2(p.x / (0.31 + jag(p.x * 0.8) * 1.5), (p.y - ledgeY1 - jag(p.x * 2.0 + 1.0) * 0.25) / 0.011);
	vec2 q2 = vec2(p.x / (0.35 + jag(p.x * 0.8 + 4.0) * 1.5), (p.y - ledgeY2 - jag(p.x * 2.0 + 5.0) * 0.25) / 0.010);
	float l1 = length(q1);
	float l2 = length(q2);
	float ledgeSdf = min((l1 - 1.0) * 0.011, (l2 - 1.0) * 0.010);

	float xl = -(0.40 + 0.38 * (1.0 - p.y)) + jag(p.y * 1.1) * 0.9;
	float xr = 0.36 + 0.50 * (1.0 - p.y) - jag(p.y * 1.1 + 3.1) * 0.9;
	float outer = min(p.x - xl, xr - p.x) + (fbm3(p * vec2(13.0, 11.0) + 5.0) - 0.5) * 0.05;
	float rockM = clamp((1.0 - smoothstep(-0.003, 0.003, -outer)) * (1.0 - smoothstep(-0.004, 0.004, p.y - rockBottom)), 0.0, 1.0);

	bool inColumn = p.y < 0.678;
	float waterM = inColumn ? (1.0 - smoothstep(-0.003, 0.003, dE)) : 0.0;
	float ledgeM = 1.0 - smoothstep(-0.003, 0.003, ledgeSdf);
	if (p.y < 0.10) {
		waterM = 1.0 - smoothstep(-0.003, 0.003, abs(p.x) - 0.19 * 1.04 * 0.84 - (jag(p.y * 1.7) * 0.19 * 3.0) * 0.5 + edgeN * 0.012);
	}
	float dEr = inColumn ? max(dE, 0.0) : 1.0;
	float dLed = max(ledgeSdf, 0.0);
	float nearW = exp(-min(dEr, dLed * 1.4) * 14.0);

	// ---------- ROCK ----------
	if (rockM > 0.0) {
		vec2 q = p * vec2(9.0, 6.0);
		vec3 v0 = vor(q + vec2(0.0, fbm3(p * 5.0) * 0.8));
		vec3 v1 = vor(q * 2.3 + 3.3);
		float warp = fbm3(vec2(p.x * 2.2, p.y * 3.0)) * 1.6 + vn(vec2(p.x * 9.0, p.y * 2.0)) * 0.25;
		float sy = p.y * 17.0 + warp * 3.0;
		float band = floor(sy);
		float bf = fract(sy);
		float bh = h21(vec2(band, 3.7));
		vec2 tilt = (h22(vec2(v0.z * 91.7, v0.z * 13.1)) - 0.5) * 0.45;
		vec2 bq = p * vec2(20.0, 17.0);
		float b0 = fbm3(bq);
		float bx = fbm3(bq + vec2(0.35, 0.0));
		float by = fbm3(bq + vec2(0.0, 0.35));
		vec2 bump = vec2(b0 - bx, b0 - by) * 1.3;
		float lip = smoothstep(0.0, 0.18, bf) * (1.0 - smoothstep(0.82, 1.0, bf));
		float strataTilt = (bf - 0.5) * 0.9 * (0.5 + bh);
		vec3 n = normalize(vec3(tilt.x + bump.x, tilt.y + bump.y - strataTilt * 0.7, 1.0));
		float crack = 1.0 - smoothstep(0.0, 0.05, v0.y);
		float crack2 = (1.0 - smoothstep(0.0, 0.06, v1.y)) * 0.6;
		float cr = max(crack, crack2);
		float diff = clamp(dot(n, L) * 0.8 + 0.22, 0.0, 1.0) * (0.6 + 0.4 * smoothstep(0.55, -0.4, p.x));
		float ao = 1.0 - cr * 0.65;
		ao *= 0.72 + 0.28 * smoothstep(0.0, 0.35, bf);
		ao *= 0.55 + 0.45 * smoothstep(0.30, 0.62, b0 + 0.25 * (1.0 - cr));
		float under = exp(-pow((p.y - ledgeY1 - 0.03) / 0.03, 2.0)) + exp(-pow((p.y - ledgeY2 - 0.03) / 0.03, 2.0));
		ao *= 1.0 - 0.45 * clamp(under, 0.0, 1.0);
		vec3 aLo = vec3(0.115, 0.125, 0.165);
		vec3 aMid = vec3(0.185, 0.170, 0.190);
		vec3 aWarm = vec3(0.250, 0.205, 0.185);
		vec3 alb = mix(aLo, aMid, smoothstep(0.2, 0.6, bh));
		alb = mix(alb, aWarm, smoothstep(0.65, 0.95, bh) * 0.8);
		alb *= 0.8 + 0.25 * v0.z + 0.2 * vn(p * 90.0);
		alb *= 0.85 + 0.3 * b0;
		float mossN = fbm3(p * vec2(7.0, 6.0) + 40.0);
		float moss = smoothstep(0.50, 0.70, mossN + (-n.y) * 0.25 + nearW * 0.30) * (0.4 + 0.6 * lip);
		vec3 mossC = vec3(0.075, 0.130, 0.085) * (0.7 + 0.6 * vn(p * 160.0));
		alb = mix(alb, mossC, moss * 0.85);
		float wet = clamp(nearW * 1.2 + smoothstep(0.55, 0.7, p.y) * 0.7, 0.0, 1.0);
		alb *= 1.0 - 0.38 * wet;
		vec3 glowC = vec3(0.10, 0.42, 0.46);
		vec3 lit = alb * (SUNC * diff * 1.7 * ao * ao + SKYC * (0.55 + 0.35 * (-n.y)) * ao + glowC * nearW * 1.1 * ao);
		float sh = max(dot(n, Hh), 0.0);
		float specW = pow(sh, 30.0) * (0.03 + 0.55 * wet) + pow(sh, 8.0) * 0.04 * wet;
		lit += SUNC * specW * ao * (0.4 + 0.6 * (1.0 - moss));
		lit += SUNC * crack * 0.05 * smoothstep(0.0, 0.5, dot(n, L) + 0.3);
		float hz = 0.20 + 0.22 * (1.0 - p.y);
		lit = mix(lit, HAZE * 0.55, hz);
		float edgeHaze = smoothstep(0.0, 0.10, outer);
		lit = mix(HAZE * 0.50, lit, edgeHaze);
		col = lit * rockM;
		a = rockM;
	}

	// ---------- WATER: falls ----------
	if (inColumn && waterM > 0.0 && p.y >= 0.10) {
		float u = g.y;
		float tier = g.z;
		float sxn = clamp((p.x - cxF) / max(hwF, 0.001), -1.0, 1.0);
		float spd = 2.8 + tier * 0.6 + u * 1.6;
		float fx = p.x * (150.0 + 40.0 * tier);
		vec2 s1 = vec2(fx + sin(p.y * 7.0 + tier * 2.0) * 0.8, p.y * (3.5 - u) - T * spd);
		vec2 s2 = vec2(fx * 0.43 + 7.0, p.y * 6.5 - T * spd * 1.35);
		vec2 s3 = vec2(fx * 1.9 + 3.0, p.y * 11.0 - T * spd * 1.9);
		float s = vn(s1) * 0.5 + vn(s2) * 0.32 + vn(s3) * 0.18;
		float streak = smoothstep(0.35, 0.78, s);
		float thick = 1.0 - pow(abs(sxn), 3.0);
		float turb = fbm3(vec2(p.x * 22.0 + tier * 5.0, p.y * 7.0 - T * spd * 0.5));
		float aer = clamp(pow(u, 1.4) * 0.8 + 0.28 + pow(abs(sxn), 4.0) * 0.4 + (turb - 0.5) * 0.6, 0.0, 1.0);
		vec3 deep = vec3(0.05, 0.21, 0.25);
		vec3 clearW = vec3(0.24, 0.46, 0.48);
		vec3 body = mix(deep, clearW, streak * thick);
		body += vec3(0.10, 0.50, 0.52) * (1.0 - aer) * (0.3 + 0.7 * thick) * 0.55;
		float foamAmt = clamp(aer * (0.35 + 0.95 * streak) + (turb - 0.62) * 0.5, 0.0, 1.0);
		vec3 foamC = vec3(0.80, 0.90, 0.93) * (0.75 + 0.25 * smoothstep(1.0, -1.0, sxn));
		foamC += SUNC * 0.18 * smoothstep(0.2, -1.0, sxn);
		body = mix(body, foamC, foamAmt);
		float curv = vn(s1 + 20.0) - vn(s1 + vec2(0.6, 0.0) + 20.0);
		body *= 0.86 + curv * 0.55 + 0.12 * thick;
		float ylip = 0.085 + 0.030 * sxn * sxn * step(tier, 0.5);
		float head = (tier < 0.5) ? smoothstep(0.0, 0.09, p.y - ylip) : smoothstep(0.0, 0.05, u);
		vec3 glass = mix(vec3(0.07, 0.36, 0.40), vec3(0.62, 0.82, 0.84), exp(-max(p.y - ylip, 0.0) * 40.0) * 0.8);
		body = mix(glass, body, head);
		float wa = waterM * mix(0.50, 0.90, clamp(0.35 + 0.6 * foamAmt + 0.2 * thick, 0.0, 1.0));
		wa *= mix(0.6, 1.0, head);
		ov(col, a, body, wa);
	}

	// ---------- WATER: river above the lip ----------
	if (p.y < 0.10 && waterM > 0.0) {
		float fl = fbm3(vec2(p.x * 9.0, p.y * 24.0 + T * 1.4));
		vec3 rv = mix(vec3(0.03, 0.22, 0.27), vec3(0.10, 0.40, 0.44), fl);
		rv += vec3(0.7, 0.85, 0.88) * pow(fl, 4.0) * 0.6;
		float lipGlow = exp(-abs(p.y - 0.093) * 70.0);
		rv = mix(rv, vec3(0.78, 0.90, 0.92), lipGlow * 0.55);
		ov(col, a, rv, waterM * 0.9);
	}

	// ---------- WATER: ledge basins ----------
	if (ledgeM > 0.0) {
		float lq = min(l1, l2);
		float ly = (l1 < l2) ? ledgeY1 : ledgeY2;
		float ch = fbm3(vec2(p.x * 40.0 - T * 0.5, p.y * 90.0 + T * 0.3));
		vec3 bc = mix(vec3(0.04, 0.26, 0.31), vec3(0.14, 0.46, 0.50), ch);
		float landing = exp(-pow((p.y - ly) / 0.010, 2.0));
		float fz = clamp(landing * (0.4 + 1.2 * fbm3(vec2(p.x * 60.0, T * 0.9 + p.y * 40.0))) + exp(-(1.0 - lq) * 10.0) * 0.5, 0.0, 1.0);
		bc = mix(bc, vec3(0.86, 0.94, 0.95), fz * 0.85);
		float ba = ledgeM * 0.85 * (1.0 - smoothstep(0.5, 1.0, abs(p.x) / ((l1 < l2) ? 0.31 : 0.35)));
		ov(col, a, bc, ba);
	}

	// ---------- POOL ----------
	if (p.y > rockBottom - 0.012) {
		float pm = smoothstep(-0.005, 0.006, p.y - rockBottom);
		float dy = p.y - 0.672;
		float yy = clamp(dy / 0.33, 0.0, 1.0);
		vec2 grad = vec2(0.0);
		float rip = 0.0;
		float ringF = 0.0;
		for (int i = 0; i < 4; i++) {
			float cc = ((float(i) + 0.5) / 4.0 - 0.5) * W;
			vec2 d = vec2(p.x - cc, dy * 3.0);
			float r = length(d) + 0.001;
			float ph = r * 95.0 - T * 2.4 + float(i) * 1.7;
			float env = exp(-r * 5.5) * (1.0 - exp(-r * 30.0));
			rip += sin(ph) * env;
			grad += (d / r) * cos(ph) * env * 95.0;
			float rf = fract(T * 0.4 + float(i) * 0.27);
			ringF += smoothstep(0.012, 0.0, abs(r - (0.045 + 0.05 * rf))) * (1.0 - rf);
		}
		grad += (vec2(vn(vec2(p.x * 60.0 + T * 0.3, dy * 140.0)), vn(vec2(p.x * 60.0 - 7.0, dy * 140.0 + T * 0.4))) - 0.5) * 6.0;
		vec3 pn = normalize(vec3(-grad.x * 0.012, -grad.y * 0.012 * 1.4, 1.0));
		float fres = clamp((0.04 + 0.96 * pow(1.0 - pn.z * (0.55 + 0.45 * (1.0 - yy)), 3.0)) * 3.0 + 0.10, 0.0, 0.75);
		vec3 deepC = mix(vec3(0.030, 0.17, 0.21), vec3(0.012, 0.075, 0.12), pow(yy, 0.7));
		float cA = vn(vec2(p.x * 38.0 + rip, dy * 110.0 + T * 0.3));
		float cB = vn(vec2(p.x * 52.0 - 9.0, dy * 150.0 - T * 0.25) + cA);
		float caus = pow(clamp(1.0 - abs(cA - cB) * 2.0, 0.0, 1.0), 6.0) * exp(-dy * 20.0);
		deepC += vec3(0.25, 0.65, 0.62) * caus * 0.30;
		float rx = p.x + pn.x * 0.05;
		float fallRef = exp(-pow(rx / 0.34, 2.0)) * exp(-dy * 7.0);
		float rstr = vn(vec2(rx * 70.0, dy * 14.0 - T * 0.5));
		vec3 refl = mix(vec3(0.26, 0.30, 0.46), vec3(0.45, 0.58, 0.62), fallRef * (0.5 + 0.8 * rstr));
		refl = mix(refl, vec3(0.08, 0.12, 0.18), smoothstep(0.34, 0.62, abs(rx)) * 0.7);
		vec3 pc = mix(deepC, refl, fres);
		pc += SUNC * pow(max(dot(pn, Hh), 0.0), 200.0) * 0.18;
		float fz = fbm3(vec2(p.x * 36.0, dy * 80.0 - T * 0.6));
		float impact = exp(-max(dy, 0.0) * 70.0) * smoothstep(0.35, 0.8, fz + 0.1);
		impact = clamp(impact + ringF * 0.04 * smoothstep(0.3, 0.7, fz), 0.0, 1.0);
		pc = mix(pc, vec3(0.78, 0.88, 0.90), impact * 0.65);
		ov(col, a, pc, pm * 0.98);
	}

	// ---------- SPRAY & MIST ----------
	{
		float lat = exp(-pow(p.x / 0.44, 2.0));
		float m = 0.0;
		float by3[3] = float[3](0.345, 0.565, 0.668);
		float am[3] = float[3](0.26, 0.26, 0.30);
		for (int i = 0; i < 3; i++) {
			float gy = exp(-pow((p.y - (by3[i] - 0.03)) / 0.06, 2.0));
			float nz = fbm3(vec2(p.x * 6.0 + float(i) * 3.1 + T * 0.05, p.y * 5.0 - T * 0.12));
			float nz2 = vn(vec2(p.x * 17.0 - T * 0.08, p.y * 11.0 - T * 0.2 + float(i)));
			m += gy * smoothstep(0.34, 0.85, nz * 0.7 + nz2 * 0.3) * am[i];
		}
		m *= lat * (1.0 - smoothstep(0.70, 0.78, p.y));
		float lightSide = smoothstep(0.4, -0.4, p.x);
		vec3 mc = mix(vec3(0.52, 0.66, 0.74), vec3(0.95, 0.90, 0.80), lightSide * 0.55);
		ov(col, a, mc, m);
		float ray = vn(vec2((p.x + p.y * 0.85) * 18.0, T * 0.05));
		float rayM = smoothstep(0.55, 0.9, ray) * lat * smoothstep(0.1, 0.45, p.y) * (1.0 - smoothstep(0.62, 0.74, p.y)) * 0.07;
		ov(col, a, vec3(1.0, 0.86, 0.62), rayM);
	}

	// soft halo of the fall (backlit glow)
	{
		float hd = length(vec2(p.x * 0.9, (p.y - 0.38) * 0.55));
		float hl = exp(-hd * 3.4) * 0.10 * (1.0 - smoothstep(0.70, 0.78, p.y));
		col += vec3(0.20, 0.72, 0.80) * hl * (1.0 - a);
		a = hl * (1.0 - a) + a;
	}

	a *= edgeFade;
	col *= edgeFade;
	vec3 rgb = col / max(a, 0.0001);
	rgb = 1.0 - exp(-rgb * 1.5);
	rgb += (h21(FC_ + fract(T) * 13.0) - 0.5) / 200.0;
	return vec4(clamp(rgb, 0.0, 1.0), clamp(a, 0.0, 1.0));
}

void fragment() {
	COLOR = render(UV, FRAGCOORD.xy, TIME);
}
