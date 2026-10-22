shader_type canvas_item;
render_mode blend_disabled;

// One-time bake of the goblin bust sculpt (UPDATE_ONCE SubViewports).
//   pass 0: R,G = normal.xy (0.5 + 0.5 n)   B = height / 256   A = coverage
//   pass 1: R = ambient occlusion   G = convexity (0.5 neutral)   B = material id   A = cavity depth
//   pass 2: R = distance to nearest crack / 48   G,B = crack arrival time (16 bit)   A = crack class
// World units: y down, head centre ~ (0,-30). The sculpt is a height field built from SDF parts and smooth bumps.

uniform int pass_id = 0;
uniform vec2 org = vec2(-640.0, -360.0);
uniform vec2 span = vec2(1280.0, 1160.0);
uniform sampler2D seg_tex : filter_nearest, repeat_disable;
uniform int nseg = 0;

const float HMAX = 256.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 4; i++) {
		s += a * vnoise(p);
		p = p * 2.03 + 17.1;
		a *= 0.5;
	}
	return s;
}

float smin(float a, float b, float k) {
	float h = max(k - abs(a - b), 0.0) / k;
	return min(a, b) - h * h * k * 0.25;
}
float smax(float a, float b, float k) {
	return -smin(-a, -b, k);
}
vec2 rot(vec2 p, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}
float sdEll(vec2 p, vec2 c, vec2 r) {
	vec2 q = (p - c) / r;
	float k0 = length(q);
	float k1 = length(q / r);
	return k0 * (k0 - 1.0) / max(k1, 1e-4);
}
float sdSeg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}
float sdUneven(vec2 p, vec2 a, vec2 b, float ra, float rb) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h) - mix(ra, rb, h);
}

// ---- polygons ----
const vec2 JAW[12] = vec2[12](vec2(-198.0, -20.0), vec2(-188.0, 60.0), vec2(-152.0, 126.0), vec2(-112.0, 192.0), vec2(-58.0, 250.0), vec2(0.0, 294.0),
	vec2(58.0, 250.0), vec2(112.0, 192.0), vec2(152.0, 126.0), vec2(188.0, 60.0), vec2(198.0, -20.0), vec2(0.0, -40.0));
const vec2 TOR[8] = vec2[8](vec2(-130.0, 215.0), vec2(-290.0, 262.0), vec2(-470.0, 375.0), vec2(-620.0, 820.0), vec2(620.0, 820.0), vec2(470.0, 375.0),
	vec2(290.0, 262.0), vec2(130.0, 215.0));
const vec2 EAR[14] = vec2[14](vec2(176.0, -140.0), vec2(255.0, -205.0), vec2(360.0, -232.0), vec2(470.0, -205.0), vec2(555.0, -135.0), vec2(614.0, -42.0),
	vec2(548.0, -64.0), vec2(470.0, -54.0), vec2(385.0, -22.0), vec2(315.0, 26.0), vec2(262.0, 76.0), vec2(214.0, 74.0), vec2(186.0, 20.0), vec2(176.0, -60.0));

float sdJaw(vec2 p) {
	float d = 1e9;
	bool inside = false;
	for (int i = 0; i < 12; i++) {
		vec2 a = JAW[i];
		vec2 b = JAW[(i + 1) % 12];
		d = min(d, sdSeg(p, a, b));
		if (((a.y > p.y) != (b.y > p.y)) && (p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x)) inside = !inside;
	}
	return inside ? -d : d;
}
float sdTor(vec2 p) {
	float d = 1e9;
	bool inside = false;
	for (int i = 0; i < 8; i++) {
		vec2 a = TOR[i];
		vec2 b = TOR[(i + 1) % 8];
		d = min(d, sdSeg(p, a, b));
		if (((a.y > p.y) != (b.y > p.y)) && (p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x)) inside = !inside;
	}
	return inside ? -d : d;
}
float sdEarRaw(vec2 p) {
	float d = 1e9;
	bool inside = false;
	for (int i = 0; i < 14; i++) {
		vec2 a = EAR[i];
		vec2 b = EAR[(i + 1) % 14];
		d = min(d, sdSeg(p, a, b));
		if (((a.y > p.y) != (b.y > p.y)) && (p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x)) inside = !inside;
	}
	return inside ? -d : d;
}

// ---- parts ----
float sdHeadBase(vec2 p) {
	float sk = sdEll(p, vec2(0.0, -48.0), vec2(206.0, 222.0));
	float d = smin(sk, sdJaw(p), 34.0);
	d += (vnoise(p * 0.045) - 0.5) * 5.0;
	// a chipped bite out of the crown, upper right
	d = max(d, -(length(p - vec2(150.0, -196.0)) - 22.0 + (vnoise(p * 0.2) - 0.5) * 9.0));
	return d;
}

float sdEarS(vec2 p) {
	vec2 pm = vec2(abs(p.x), p.y);
	float d = sdEarRaw(pm);
	// notches and tears: left ear and right ear differ
	if (p.x > 0.0) {
		d = max(d, -(length(pm - vec2(556.0, -130.0)) - 15.0));
		d = max(d, -(length(pm - vec2(430.0, -214.0)) - 11.0));
		d = max(d, -(length(pm - vec2(515.0, -58.0)) - 13.0));
		d = max(d, -(length(pm - vec2(296.0, 38.0)) - 10.0));
	} else {
		d = max(d, -(length(pm - vec2(596.0, -60.0)) - 20.0));
		d = max(d, -(length(pm - vec2(338.0, -226.0)) - 12.0));
		d = max(d, -(length(pm - vec2(478.0, -203.0)) - 9.0));
		d = max(d, -(length(pm - vec2(420.0, -34.0)) - 12.0));
	}
	d += (vnoise(pm * 0.09) - 0.5) * 5.0;
	return d;
}

float sdHorns(vec2 p, out float side) {
	// left: short, snapped off.  right: long, chipped tip
	float dl = min(sdUneven(p, vec2(-122.0, -214.0), vec2(-152.0, -262.0), 36.0, 24.0), sdUneven(p, vec2(-152.0, -262.0), vec2(-168.0, -298.0), 24.0, 17.0));
	float cut = dot(p - vec2(-166.0, -292.0), normalize(vec2(0.4, -1.0))) + (vnoise(p * 0.3) - 0.5) * 10.0;
	dl = max(dl, cut);
	float dr = min(sdUneven(p, vec2(122.0, -214.0), vec2(160.0, -274.0), 38.0, 26.0), sdUneven(p, vec2(160.0, -274.0), vec2(176.0, -348.0), 26.0, 4.0));
	dr = max(dr, -(length(p - vec2(170.0, -318.0)) - 9.0 + (vnoise(p * 0.5) - 0.5) * 4.0));
	side = dl < dr ? -1.0 : 1.0;
	return min(dl, dr);
}

float sdRing(vec2 p) {
	return abs(length(p - vec2(-240.0, 98.0)) - 21.0) - 4.5;
}
float sdCoin(vec2 p) {
	float c = length(p - vec2(0.0, 396.0)) - 50.0;
	float cords = min(min(sdSeg(p, vec2(-72.0, 232.0), vec2(-40.0, 330.0)), sdSeg(p, vec2(-40.0, 330.0), vec2(0.0, 352.0))),
		min(sdSeg(p, vec2(72.0, 232.0), vec2(40.0, 330.0)), sdSeg(p, vec2(40.0, 330.0), vec2(0.0, 352.0)))) - 3.5;
	return min(c, cords);
}
float sdTorso(vec2 p) {
	float t = sdTor(p);
	float a1 = sdEll(rot(p - vec2(-300.0, 420.0), -0.35), vec2(0.0), vec2(160.0, 230.0));
	float a2 = sdEll(rot(p - vec2(300.0, 420.0), 0.35), vec2(0.0), vec2(160.0, 230.0));
	return smin(t, min(a1, a2), 24.0);
}
float sdNeck(vec2 p) {
	return sdEll(p, vec2(0.0, 250.0), vec2(120.0, 125.0));
}

float sdAll(vec2 p) {
	float sd = sdHeadBase(p);
	sd = min(sd, sdEarS(p));
	float sde;
	sd = min(sd, sdHorns(p, sde));
	sd = min(sd, sdNeck(p));
	sd = min(sd, sdTorso(p));
	sd = min(sd, sdRing(p));
	return min(sd, sdCoin(p));
}

float infl(float sd, float r, float H) {
	float d = clamp(-sd, 0.0, r);
	float t = 1.0 - d / r;
	return H * sqrt(max(1.0 - t * t, 0.0));
}
float bump(vec2 p, vec2 c, vec2 r, float a, float h) {
	vec2 q = rot(p - c, -a) / r;
	float w = max(1.0 - dot(q, q), 0.0);
	return h * w * w;
}
float ridge(float d, float R, float H) {
	float t = clamp(1.0 - d / R, 0.0, 1.0);
	return H * t * t * (3.0 - 2.0 * t);
}
float gro(float d, float w, float depth) {
	return -depth * exp(-(d * d) / (w * w));
}
// scar: groove with raised lips
float scar(vec2 p, vec2 a, vec2 b, float w, float depth) {
	float d = sdSeg(p, a, b);
	float n = 0.65 + 0.7 * vnoise(p * 0.12);
	w *= n;
	float lip = exp(-pow((d - 2.3 * w) / (1.3 * w), 2.0));
	return -depth * exp(-(d * d) / (w * w)) + depth * 0.55 * lip;
}

// the whole relief; mat: 0 head glass, .25 ear, .5 horn, .75 cloth, 1 metal
float Hall(vec2 p, out float mat) {
	vec2 pm = vec2(abs(p.x), p.y);
	float sh = sdHeadBase(p);
	float h = infl(sh, 176.0, 168.0);
	mat = 0.0;
	float fw = smoothstep(0.0, 46.0, -sh);

	// ---- face sculpt ----
	float f = 0.0;
	// heavy brow: V ridge sweeping to the temples
	float bd = min(sdSeg(pm, vec2(6.0, -82.0), vec2(112.0, -128.0)), sdSeg(pm, vec2(112.0, -128.0), vec2(206.0, -98.0)));
	f += ridge(bd, mix(40.0, 24.0, smoothstep(100.0, 210.0, pm.x)), 58.0);
	f += bump(pm, vec2(0.0, -96.0), vec2(16.0, 26.0), 0.0, -12.0);
	f += bump(pm, vec2(12.0, -112.0), vec2(5.0, 24.0), -0.2, -9.0);
	// forehead mass, horn bases, temples
	f += bump(pm, vec2(84.0, -168.0), vec2(72.0, 46.0), 0.2, 16.0);
	f += bump(pm, vec2(0.0, -176.0), vec2(52.0, 46.0), 0.0, 8.0);
	f += bump(pm, vec2(128.0, -214.0), vec2(48.0, 34.0), 0.4, 18.0);
	f += bump(pm, vec2(174.0, -78.0), vec2(30.0, 56.0), 0.0, -12.0);
	// eye sockets: deep bowls under the brow
	{
		vec2 q = rot(pm - vec2(92.0, -46.0), -0.18) / vec2(74.0, 40.0);
		f += -56.0 * smoothstep(1.0, 0.45, length(q));
		f += bump(pm, vec2(92.0, -3.0), vec2(62.0, 16.0), 0.12, 11.0);
	}
	// cheekbones, hollow cheeks, jaw muscle
	f += bump(pm, vec2(130.0, 30.0), vec2(86.0, 46.0), 0.45, 34.0);
	f += bump(pm, vec2(94.0, 116.0), vec2(62.0, 66.0), 0.0, -30.0);
	f += bump(pm, vec2(146.0, 124.0), vec2(26.0, 66.0), -0.2, 12.0);
	// hooked nose: narrow bridge swelling to a heavy tip
	float bridgeR = mix(13.0, 32.0, smoothstep(-84.0, 40.0, p.y));
	f += ridge(sdSeg(pm, vec2(0.0, -84.0), vec2(0.0, 48.0)), bridgeR, 52.0);
	f += bump(p, vec2(5.0, -26.0), vec2(18.0, 36.0), 0.0, 11.0);
	f += bump(p, vec2(0.0, 60.0), vec2(40.0, 34.0), 0.0, 46.0);
	f += bump(p, vec2(0.0, 84.0), vec2(24.0, 18.0), 0.0, 20.0);
	f += bump(pm, vec2(40.0, 74.0), vec2(26.0, 25.0), 0.5, 30.0);
	f += bump(pm, vec2(19.0, 92.0), vec2(12.0, 9.0), 0.35, -62.0);
	f += gro(sdSeg(pm, vec2(0.0, 104.0), vec2(0.0, 148.0)), 9.0, 9.0);
	// nasolabial folds
	float nd = min(sdSeg(pm, vec2(60.0, 62.0), vec2(90.0, 106.0)), min(sdSeg(pm, vec2(90.0, 106.0), vec2(114.0, 144.0)), sdSeg(pm, vec2(114.0, 144.0), vec2(128.0, 172.0))));
	f += gro(nd, 7.5, 13.0);
	// muzzle and chin
	f += bump(p, vec2(0.0, 172.0), vec2(140.0, 68.0), 0.0, 16.0);
	f += bump(p, vec2(0.0, 248.0), vec2(56.0, 46.0), 0.0, 26.0);
	f += bump(p, vec2(0.0, 274.0), vec2(26.0, 30.0), 0.0, 14.0);
	f += bump(p, vec2(0.0, 238.0), vec2(6.0, 18.0), 0.0, -6.0);
	f += gro(sdSeg(pm, vec2(0.0, 216.0), vec2(62.0, 210.0)), 5.0, 7.0);
	// warts
	f += bump(p, vec2(-18.0, 40.0), vec2(9.0, 8.0), 0.0, 14.0);
	f += bump(p, vec2(30.0, 62.0), vec2(8.0, 8.0), 0.0, 12.0);
	f += bump(p, vec2(-142.0, 94.0), vec2(9.0, 8.0), 0.0, 13.0);
	f += bump(p, vec2(60.0, -152.0), vec2(8.0, 7.0), 0.0, 12.0);
	f += bump(p, vec2(152.0, 112.0), vec2(9.0, 9.0), 0.0, 14.0);
	f += bump(p, vec2(-70.0, 150.0), vec2(6.0, 6.0), 0.0, 9.0);
	// forehead wrinkles (broken lines) and crow's feet
	for (int k = 0; k < 3; k++) {
		float yl = -140.0 - float(k) * 18.0 - 12.0 * (1.0 - pow(p.x / 138.0, 2.0));
		float d = abs(p.y - yl);
		float brk = 0.45 + 0.55 * smoothstep(0.2, 0.55, vnoise(vec2(p.x * 0.07 + float(k) * 7.3, 2.0)));
		f += gro(d, 2.6, 6.0 * brk) * smoothstep(140.0, 100.0, abs(p.x));
		f += 2.0 * brk * exp(-pow((d - 5.0) / 2.5, 2.0)) * smoothstep(140.0, 100.0, abs(p.x));
	}
	f += gro(sdSeg(pm, vec2(152.0, -40.0), vec2(180.0, -29.0)), 2.4, 4.5);
	f += gro(sdSeg(pm, vec2(152.0, -54.0), vec2(182.0, -64.0)), 2.4, 4.5);
	f += gro(sdSeg(pm, vec2(48.0, -10.0), vec2(70.0, 6.0)), 2.2, 4.0);
	// scars: three claw cuts over the right cheek, one slash through the left brow
	f += scar(p, vec2(86.0, -2.0), vec2(158.0, 116.0), 2.2, 7.0);
	f += scar(p, vec2(102.0, -8.0), vec2(172.0, 108.0), 2.0, 6.0);
	f += scar(p, vec2(118.0, -14.0), vec2(186.0, 100.0), 1.9, 5.5);
	f += scar(p, vec2(-163.0, -162.0), vec2(-133.0, -80.0), 2.6, 8.0);
	// pores / pits on the skin
	f += (fbm(p * 0.35) - 0.5) * 2.4;
	h += f * fw;
	// a crack-scar across the skull plate
	h += scar(p, vec2(-20.0, -250.0), vec2(36.0, -186.0), 2.4, 6.0) * fw;

	float m2 = 0.0;
	// ---- ears ----
	float se = sdEarS(p);
	float he = infl(se, 14.0, 46.0);
	{
		vec2 c = vec2(385.0, -95.0);
		vec2 pi = (pm - c) / 0.64 + c;
		float sdi = sdEarRaw(pi) * 0.64;
		he -= 26.0 * smoothstep(2.0, -14.0, sdi);
		he += 11.0 * exp(-pow((se + 8.0) / 5.0, 2.0));
		float ang = atan(pm.y + 66.0, pm.x - 196.0);
		float vl = abs(sin(ang * 11.0 + 5.0 * fbm(pm * 0.03)));
		float vein = smoothstep(0.17, 0.0, vl) * smoothstep(12.0, -24.0, se) * smoothstep(46.0, 130.0, length(pm - vec2(196.0, -66.0)));
		he += 3.6 * vein;
		he += (fbm(pm * 0.5) - 0.5) * 1.6 + (fbm(pm * 0.11 + 4.0) - 0.5) * 7.0;
		he += 9.0 * exp(-pow(sdi / 6.0, 2.0)) * step(se, -4.0);
		he += 4.0 * (0.5 + 0.5 * sin(ang * 6.0 + 3.0 * fbm(pm * 0.02))) * smoothstep(2.0, -14.0, sdi) * smoothstep(30.0, 120.0, length(pm - vec2(196.0, -66.0)));
	}
	he = max(he, 0.0) * step(se, 0.0);
	// ---- horns ----
	float hs;
	float sdh = sdHorns(p, hs);
	float hh = (infl(sdh, 30.0, 52.0) + 62.0 * smoothstep(1.0, -1.0, sdh)) * step(sdh, 0.0);
	{
		vec2 hb = hs < 0.0 ? vec2(-122.0, -214.0) : vec2(122.0, -214.0);
		float along = dot(p - hb, normalize(vec2(hs * 0.45, -1.0)));
		hh -= 2.4 * (0.5 + 0.5 * sin(along * 0.62 + 5.0 * vnoise(p * 0.05))) * step(sdh, 0.0);
	}
	// ---- body ----
	float nk = infl(sdNeck(p), 70.0, 112.0);
	float st = sdTorso(p);
	float to = infl(st, 130.0, 108.0);
	{
		// tattered collar band
		float u = clamp(p.x / 250.0, -1.0, 1.0);
		float yc = 296.0 + 38.0 * cos(u * 1.5708) - 12.0 * abs(fract(p.x / 30.0) - 0.5) * 2.0;
		float cb = ridge(abs(p.y - yc), 20.0, 24.0) * smoothstep(262.0, 232.0, abs(p.x));
		to += cb;
		// slack cloth folds
		to += 5.0 * sin(p.x * 0.05 + 3.0 * fbm(p * 0.01)) * smoothstep(300.0, 330.0, p.y);
		to += (fbm(p * 0.06) - 0.5) * 3.0;
	}
	float rg = sdRing(p);
	float rh = (30.0 + infl(rg, 4.5, 14.0)) * step(rg, 0.0);
	float cn = sdCoin(p);
	float ch = 0.0;
	{
		float cd = length(p - vec2(0.0, 396.0));
		ch = (infl(cn, 14.0, 24.0) + 4.0 * exp(-pow((cd - 38.0) / 3.5, 2.0))) * step(cn, 0.0);
		// stamped crown glyph
		ch += gro(min(sdSeg(p, vec2(-16.0, 410.0), vec2(-16.0, 384.0)), min(sdSeg(p, vec2(-16.0, 384.0), vec2(0.0, 396.0)),
			min(sdSeg(p, vec2(0.0, 396.0), vec2(16.0, 384.0)), sdSeg(p, vec2(16.0, 384.0), vec2(16.0, 410.0))))), 2.0, 3.0) * step(cn, 0.0);
		ch += 20.0 * step(cn, 0.0) * step(cd, 52.0);
	}
	// ---- composite: tallest part wins, with a soft crease where they meet ----
	float H = h;
	mat = 0.0;
	if (he > H) { mat = 0.25; }
	H = smax(H, he, 7.0);
	if (hh > H) { mat = 0.5; }
	H = smax(H, hh, 5.0);
	float hb = max(nk, to);
	if (hb > H) { mat = 0.75; }
	H = smax(H, hb, 8.0);
	float hm = max(rh, ch);
	if (hm > H) { mat = 1.0; }
	H = max(H, hm);
	return max(H, 0.0);
}

// voronoi: x = F1, y = F2 - F1, zw = per-cell random
vec4 vor(vec2 p) {
	vec2 n = floor(p);
	vec2 f = fract(p);
	float f1 = 8.0;
	float f2 = 8.0;
	vec2 bid = vec2(0.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = vec2(hash12(n + g), hash12(n + g + 37.7));
			vec2 r = g + o - f;
			float d = dot(r, r);
			if (d < f1) {
				f2 = f1;
				f1 = d;
				bid = n + g;
			} else if (d < f2) {
				f2 = d;
			}
		}
	}
	f1 = sqrt(f1);
	f2 = sqrt(f2);
	return vec4(f1, f2 - f1, hash12(bid + 3.1) - 0.5, hash12(bid + 9.7) - 0.5);
}

float Hs(vec2 p) {
	float m;
	return Hall(p, m);
}

void fragment() {
	vec2 p = org + UV * span;
	if (pass_id == 0) {
		float sd = sdAll(p);
		float a = smoothstep(0.8, -0.8, sd);
		if (a < 0.002) {
			COLOR = vec4(0.5, 0.5, 0.0, 0.0);
		} else {
			float e = 1.0;
			float hx = Hs(p + vec2(e, 0.0)) - Hs(p - vec2(e, 0.0));
			float hy = Hs(p + vec2(0.0, e)) - Hs(p - vec2(0.0, e));
			vec3 n = normalize(vec3(-hx / (2.0 * e), -hy / (2.0 * e), 1.0));
			float hc = Hs(p);
			COLOR = vec4(n.xy * 0.5 + 0.5, hc / HMAX, a);
		}
	} else if (pass_id == 1) {
		float sd = sdAll(p);
		if (sd > 2.0) {
			COLOR = vec4(1.0, 0.5, 0.0, 0.0);
		} else {
			float mat;
			float h0 = Hall(p, mat);
			float cav = 0.0;
			float cvx = 0.0;
			for (int k = 0; k < 4; k++) {
				float an = float(k) * 0.7853982 + 0.3;
				vec2 d = vec2(cos(an), sin(an));
				float c1 = 0.5 * (Hs(p + d * 9.0) + Hs(p - d * 9.0)) - h0;
				float c2 = 0.5 * (Hs(p + d * 28.0) + Hs(p - d * 28.0)) - h0;
				cav += max(c1, 0.0) / 9.0 * 0.5 + max(c2, 0.0) / 28.0 * 0.5;
				cvx += (c1 / 9.0 + c2 / 28.0);
			}
			cav *= 0.25;
			cvx *= 0.25;
			float ao = clamp(1.0 - cav * 1.5, 0.0, 1.0);
			COLOR = vec4(ao, clamp(0.5 - cvx * 0.9, 0.0, 1.0), mat, clamp(cav * 1.2, 0.0, 1.0));
		}
	} else if (pass_id == 3) {
		vec4 v = vor(p / 46.0);
		COLOR = vec4(v.z + 0.5, v.w + 0.5, clamp(v.y * 4.0, 0.0, 1.0), clamp(v.x / 0.9, 0.0, 1.0));
	} else {
		float best = 1e9;
		float arr = 0.0;
		float cls = 0.0;
		for (int i = 0; i < nseg; i++) {
			vec4 s0 = texelFetch(seg_tex, ivec2(2 * i, 0), 0);
			vec2 a = s0.xy;
			vec2 b = s0.zw;
			vec2 pa = p - a;
			vec2 ba = b - a;
			float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
			float d = length(pa - ba * h);
			if (d < best) {
				vec4 s1 = texelFetch(seg_tex, ivec2(2 * i + 1, 0), 0);
				best = d;
				arr = mix(s1.x, s1.y, h);
				cls = s1.z;
			}
		}
		float v = clamp(arr / 64.0, 0.0, 0.9999);
		float hi = floor(v * 255.0) / 255.0;
		float lo = fract(v * 255.0);
		COLOR = vec4(clamp(best / 48.0, 0.0, 1.0), hi, lo, cls);
	}
}
