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

vec3 over_(vec3 c, float a, vec3 lc, float la) {   // premultiplied: returns new rgb; alpha handled by caller
	return lc * la + c * (1.0 - la);
}

vec4 render(vec2 UV_, vec2 FC_, float T_) {
	float X = (UV_.x - 0.5) * aspect + cam * span * par - look.x * (0.4 + par);
	float Y = UV_.y - look.y * (0.3 + 0.5 * par);
	vec2 p = vec2(X - CX, Y);
	float edgeFade = smoothstep(-0.86, -0.58, p.x) * (1.0 - smoothstep(0.60, 0.90, p.x));
	if (edgeFade <= 0.002) { return vec4(0.0); }
	float T = T_;

	vec3 haze = vec3(0.16, 0.30, 0.46);
	vec3 teal0 = vec3(0.012, 0.16, 0.22);
	vec3 teal1 = vec3(0.04, 0.50, 0.58);
	vec3 cyan = vec3(0.45, 0.95, 1.00);
	vec3 foam = vec3(0.82, 0.97, 1.00);
	vec3 amber = vec3(1.00, 0.68, 0.24);

	vec3 col = vec3(0.0);
	float a = 0.0;

	// ---------- geometry ----------
	float cxF;
	float hwF;
	vec3 g = fall_geo(p, cxF, hwF);
	float dE = g.x;
	float rockBottom = 0.672 - 0.03 * smoothstep(0.28, 0.58, abs(p.x)) + jag(p.x * 1.3 + 2.0) * 0.5;
	bool inPool = p.y > rockBottom;

	// ledge basins (ellipses) between the tiers
	float ledgeY1 = 0.350;
	float ledgeY2 = 0.572;
	vec2 q1 = vec2(p.x / (0.31 + jag(p.x * 0.8) * 1.5), (p.y - ledgeY1 - jag(p.x * 2.0 + 1.0) * 0.25) / 0.011);
	vec2 q2 = vec2(p.x / (0.35 + jag(p.x * 0.8 + 4.0) * 1.5), (p.y - ledgeY2 - jag(p.x * 2.0 + 5.0) * 0.25) / 0.010);
	float l1 = length(q1);
	float l2 = length(q2);
	float ledgeSdf = min((l1 - 1.0) * 0.011, (l2 - 1.0) * 0.010);

	// outer cliff silhouette (zig-zag, tapering to the base)
	float xl = -(0.40 + 0.38 * (1.0 - p.y)) + jag(p.y * 1.1) * 0.9;
	float xr = 0.36 + 0.50 * (1.0 - p.y) - jag(p.y * 1.1 + 3.1) * 0.9;
	float outer = min(p.x - xl, xr - p.x);
	float rockM = (1.0 - smoothstep(-0.004, 0.004, -outer)) * (1.0 - smoothstep(-0.004, 0.004, p.y - rockBottom));
	rockM = clamp(rockM, 0.0, 1.0);

	bool inColumn = p.y < 0.678;
	float waterM = inColumn ? (1.0 - smoothstep(-0.0025, 0.0025, dE)) : 0.0;
	float ledgeM = 1.0 - smoothstep(-0.0025, 0.0025, ledgeSdf);
	if (p.y < 0.10 - 0.0) {
		// river above the lip: same channel, closed off at the very top by dark rock
		waterM = 1.0 - smoothstep(-0.0025, 0.0025, abs(p.x) - 0.19 * 1.04 * 0.84 - (jag(p.y * 1.7) * 0.19 * 3.0) * 0.5);
	}

	// ---------- ROCK ----------
	if (rockM > 0.0) {
		vec2 q = p * vec2(10.0, 6.0);
		vec3 v0 = vor(q);
		vec3 v1 = vor(q * 2.1 + 3.3);
		vec3 v2 = vor(q * 4.6 + 9.1);
		float facet = (0.40 + 0.60 * v0.z) * (0.78 + 0.22 * v1.z) * (0.90 + 0.10 * v2.z);
		float c0 = 1.0 - smoothstep(0.0, 0.07, v0.y);
		float c1 = (1.0 - smoothstep(0.0, 0.09, v1.y)) * 0.55;
		float c2 = (1.0 - smoothstep(0.0, 0.12, v2.y)) * 0.30;
		float cracks = max(c0, max(c1, c2));
		float dEr = (p.y < 0.678) ? max(dE, 0.0) : 1.0;
		float dLed = max(ledgeSdf, 0.0);
		float near = exp(-min(dEr, dLed * 1.4 + smoothstep(0.30, 0.50, abs(p.x)) * 0.3) * 22.0);
		float depthDark = mix(0.55, 1.0, smoothstep(0.62, 0.0, abs(p.x)) * 0.6 + 0.4 * smoothstep(0.0, 0.5, p.y));
		vec3 rockLo = vec3(0.030, 0.042, 0.105);
		vec3 rockHi = vec3(0.14, 0.23, 0.40);
		vec3 rc = mix(rockLo, rockHi, facet * (0.35 + 0.65 * near) * depthDark);
		// teal bounce light from the water, violet higher up
		rc += vec3(0.03, 0.26, 0.30) * near * (0.35 + 0.65 * facet);
		rc = mix(rc, vec3(0.20, 0.10, 0.34), 0.22 * (1.0 - p.y) * (1.0 - near));
		// fractured cracks: gold on some crystals, violet on others, brighter near the water
		vec3 crk = mix(vec3(0.55, 0.22, 0.85), amber, step(0.72, v0.z));
		rc += crk * cracks * (0.10 + 0.55 * near) * (0.6 + 0.4 * v1.z);
		// rim light right at the water's edge
		rc += cyan * exp(-dEr * 120.0) * 0.55 + amber * exp(-dEr * 40.0) * 0.12 * step(0.6, v0.z);
		rc += cyan * exp(-dLed * 110.0) * 0.45 * (1.0 - smoothstep(0.30, 0.52, abs(p.x)));
		// atmosphere
		float hz = 0.22 + 0.25 * (1.0 - p.y);
		rc = mix(rc, haze, hz * 0.5);
		float edgeHaze = smoothstep(0.0, 0.12, outer);
		rc = mix(haze * 0.8, rc, edgeHaze);
		float ra = rockM;
		col = rc * ra;
		a = ra;
	}

	// ---------- WATER: falls ----------
	if (inColumn && waterM > 0.0 && p.y >= 0.10) {
		float u = g.y;
		float tier = g.z;
		float sxn = clamp((p.x - cxF) / max(hwF, 0.001), -1.0, 1.0);
		float freq = 40.0 + 16.0 * tier;
		vec2 sp = vec2(p.x * freq + sin(p.y * 6.0 + tier) * 0.6, p.y * 5.0 - T * (2.2 + tier * 0.45 + u * 0.8));
		float s = vn(sp) * 0.55 + vn(sp * vec2(2.1, 1.6) + vec2(5.0, -T * 1.1)) * 0.30 + vn(sp * vec2(4.4, 0.8) + vec2(2.0, -T * 1.7)) * 0.15;
		float streak = smoothstep(0.30, 0.80, s);
		vec3 body = mix(teal0 * 1.6, teal1, streak);
		body = mix(body, cyan, streak * streak * (0.35 + 0.5 * u));
		// aeration: more white as it falls, and at the edges
		float aer = pow(u, 2.2) * 0.55 + pow(abs(sxn), 5.0) * 0.5;
		float fz = vn(sp * vec2(0.8, 0.7) + vec2(11.0, -T * 2.0));
		body = mix(body, foam, clamp(aer * (0.4 + 0.9 * fz) * (0.5 + streak), 0.0, 0.92));
		// gold glints running through the water
		float gl = smoothstep(0.80, 0.96, vn(sp * vec2(0.55, 0.45) + 3.0));
		body += amber * gl * (1.0 - u * 0.6) * 0.55;
		body *= 0.85 + 0.25 * (1.0 - sxn * sxn);
		// the head of the fall is smooth and clear; a bright lip curls over the edge
		float ylip = 0.085 + 0.032 * sxn * sxn * step(tier, 0.5);
		float head = (tier < 0.5) ? smoothstep(0.0, 0.07, p.y - ylip) : smoothstep(0.0, 0.03, u);
		body = mix(mix(teal1, foam, 0.55), body, head);
		float wa = waterM * (0.60 + 0.38 * streak) * mix(0.55, 1.0, head);
		wa = clamp(wa + aer * 0.2, 0.0, 0.98) * waterM;
		col = body * wa + col * (1.0 - wa);
		a = wa + a * (1.0 - wa);
	}

	// ---------- WATER: river above the lip ----------
	if (p.y < 0.10 && waterM > 0.0) {
		float fl = fbm(vec2(p.x * 7.0, p.y * 22.0 + T * 1.3));
		vec3 rv = mix(teal0 * 2.0, teal1, fl);
		rv += foam * pow(fl, 4.0) * 0.5;
		float lipGlow = exp(-abs(p.y - 0.093) * 60.0);
		rv = mix(rv, foam, lipGlow * 0.7);
		float wa = waterM * 0.9;
		col = rv * wa + col * (1.0 - wa);
		a = wa + a * (1.0 - wa);
	}

	// ---------- WATER: ledge basins ----------
	if (ledgeM > 0.0) {
		float lq = min(l1, l2);
		float gl = vn(vec2(p.x * 9.0 - T * 0.12, p.y * 90.0 + T * 0.2));
		vec3 bc = mix(teal0 * 2.0, teal1, 0.45 + 0.5 * gl * (1.0 - lq));
		bc += cyan * (1.0 - lq) * 0.28;
		// luminous front edge
		bc += amber * exp(-(1.0 - lq) * 5.0) * 0.30 + foam * exp(-(1.0 - lq) * 14.0) * 0.45;
		// foam where the fall above lands
		float land = exp(-pow((p.y - ((l1 < l2) ? ledgeY1 : ledgeY2)) / 0.012, 2.0)) * fbm(vec2(p.x * 24.0, T * 0.8));
		bc = mix(bc, foam, land * 0.8);
		float ba = ledgeM * 0.85 * (1.0 - smoothstep(0.5, 1.0, abs(p.x) / ((l1 < l2) ? 0.31 : 0.35)));
		col = bc * ba + col * (1.0 - ba);
		a = ba + a * (1.0 - ba);
	}

	// ---------- POOL ----------
	if (p.y > rockBottom - 0.01) {
		float pm = smoothstep(-0.004, 0.006, p.y - rockBottom);
		float dy = p.y - 0.672;
		float yy = clamp(dy / 0.33, 0.0, 1.0);
		vec3 pc = mix(vec3(0.03, 0.34, 0.42), vec3(0.01, 0.13, 0.20), pow(yy, 0.7));
		// calm ripples spreading from the four landing points
		float rip = 0.0;
		for (int i = 0; i < 4; i++) {
			float cc = ((float(i) + 0.5) / 4.0 - 0.5) * W;
			vec2 d = vec2(p.x - cc, dy * 3.2);
			float r = length(d);
			rip += sin(r * 70.0 - T * 2.2 + float(i)) * exp(-r * 6.5) * (1.0 - exp(-r * 40.0));
		}
		pc += cyan * rip * 0.05;
		// soft streaky reflection of the falls and a few drifting lights
		float refl = fbm(vec2(p.x * 20.0, p.y * 3.0 - T * 0.2)) * exp(-dy * 5.0) * smoothstep(-0.2, 0.2, 0.4 - abs(p.x));
		pc += teal1 * refl * 0.35;
		float sp2 = pow(vn(vec2(p.x * 9.0, p.y * 14.0 + T * 0.15)), 9.0) * (1.0 - yy) * 0.6;
		pc += mix(cyan, amber, step(0.5, h21(floor(vec2(p.x * 9.0, p.y * 14.0))))) * sp2 * 0.5;
		// shoreline glow, restrained (the foam line)
		float shore = exp(-max(dy, 0.0) * 55.0) * (0.5 + 0.5 * fbm(vec2(p.x * 16.0, T * 0.4)));
		pc = mix(pc, foam * 0.85, shore * 0.35);
		pm *= 0.97;
		col = pc * pm + col * (1.0 - pm);
		a = pm + a * (1.0 - pm);
	}

	// ---------- MIST (soft, low alpha) ----------
	{
		float lat = exp(-pow(p.x / 0.42, 2.0));
		float m = 0.0;
		float by[3] = float[3](0.345, 0.565, 0.668);
		float am[3] = float[3](0.30, 0.28, 0.18);
		for (int i = 0; i < 3; i++) {
			float gy = exp(-pow((p.y - (by[i] - 0.035)) / 0.065, 2.0));
			float nz = fbm(vec2(p.x * 5.5 + float(i) * 3.1, p.y * 4.5 + T * 0.10));
			m += gy * smoothstep(0.30, 0.85, nz) * am[i];
		}
		m *= lat;
		m *= 1.0 - smoothstep(0.70, 0.78, p.y);   // gone before the ground band
		vec3 mc = vec3(0.62, 0.88, 0.96);
		col = mc * m + col * (1.0 - m);
		a = m + a * (1.0 - m);
	}

	// ---------- halo of the fall: gentle cyan glow behind everything near it ----------
	{
		float hd = length(vec2(p.x * 0.9, (p.y - 0.38) * 0.55));
		float hl = exp(-hd * 3.2) * 0.16 * (1.0 - smoothstep(0.70, 0.78, p.y));
		vec3 hc = vec3(0.25, 0.85, 0.95);
		col = hc * hl * (1.0 - a) + col;
		a = hl * (1.0 - a) + a;
	}

	a *= edgeFade;
	col *= edgeFade;
	vec3 rgb = col / max(a, 0.0001);
	// filmic-ish shoulder, then dither
	rgb = 1.0 - exp(-rgb * 1.55);
	rgb += (h21(FC_ + fract(T) * 13.0) - 0.5) / 200.0;
	return vec4(clamp(rgb, 0.0, 1.0), clamp(a, 0.0, 1.0));
}

void fragment() {
	COLOR = render(UV, FRAGCOORD.xy, TIME);
}
