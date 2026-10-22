shader_type canvas_item;

// GARDEN FOREGROUND (par 1.5), realistic pass. Sparse, dark, out-of-focus pinnate fronds with
// irregular tapered leaflets, backlit translucency and sun rim light; hanging tendrils with
// refracting dew drops; large defocused spore bokeh. Centre / lower-centre stay clear.
// Time-varying: frond sway, spore drift (cheap).
uniform float aspect = 1.5;
uniform vec2 look = vec2(0.0);
uniform float cam = 0.0;
uniform float span = 3.0;
uniform float par = 1.5;

const vec2 SUN2 = vec2(-0.87, -0.49); // screen-space direction towards the low sun (up-left)

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

// tapered lanceolate leaflet from a along b; returns signed distance, k along, outward normal
float leaflet(vec2 p, vec2 a, vec2 b, float wmax, out float k, out vec2 nrm) {
	vec2 pa = p - a;
	k = clamp(dot(pa, b) / dot(b, b), 0.0, 1.0);
	vec2 dv = pa - b * k;
	float l = length(dv);
	float w = wmax * pow(sin(3.14159 * pow(k, 0.65)), 0.9);
	nrm = dv / max(l, 1e-5);
	return l - w;
}

// x,y root; z direction angle (0 = hanging down, pi = up); w length
const vec4 INST[12] = vec4[](
	vec4(-0.80, -0.04, 0.12, 0.42),
	vec4(0.74, -0.04, -0.14, 0.36),
	vec4(-1.00, 0.33, 1.50, 0.40),
	vec4(1.64, -0.04, 0.16, 0.40),
	vec4(2.06, -0.04, -0.10, 0.34),
	vec4(3.02, 0.30, -1.50, 0.38),
	vec4(3.86, -0.04, 0.12, 0.42),
	vec4(5.24, -0.04, -0.12, 0.38),
	vec4(3.64, 0.30, 1.50, 0.36),
	vec4(5.40, 0.28, -1.50, 0.34),
	vec4(-0.95, 1.05, 2.45, 0.46),
	vec4(5.45, 1.05, -2.45, 0.46)
);
// x curvature, y blur radius (defocus), z seed
const vec3 INS2[12] = vec3[](
	vec3(0.55, 0.014, 1.0), vec3(-0.50, 0.020, 2.0), vec3(0.45, 0.026, 3.0), vec3(0.50, 0.016, 4.0),
	vec3(-0.55, 0.022, 5.0), vec3(-0.45, 0.028, 6.0), vec3(0.50, 0.015, 7.0), vec3(-0.55, 0.021, 8.0),
	vec3(0.45, 0.028, 9.0), vec3(-0.40, 0.03, 10.0), vec3(0.35, 0.026, 11.0), vec3(-0.35, 0.026, 12.0)
);

vec4 frond(vec2 P, int idx) {
	vec4 s = INST[idx];
	vec3 s2 = INS2[idx];
	vec2 q = P - s.xy;
	float Lf = s.w;
	if (length(q) > Lf * 1.45) return vec4(0.0);
	float sw = 0.06 * sin(TIME * 0.45 + s2.z * 2.3);
	float a = s.z + sw * 0.5;
	vec2 dir = vec2(sin(a), cos(a));
	vec2 perp = vec2(cos(a), -sin(a));
	float sc = dot(q, dir);
	float u = dot(q, perp);
	float bend = s2.x * (1.0 + sw);
	float uu = u - bend * sc * sc / Lf * 0.9;
	float bl = s2.y;

	float dmin = 1e3, kk = 0.0, hh = 0.0;
	vec2 nw = vec2(0.0);
	// rachis
	float t = sc / Lf;
	if (t > -0.02 && t < 1.02) {
		float dr = abs(uu) - (0.0045 * (1.0 - clamp(t, 0.0, 1.0)) + 0.0009);
		dmin = dr;
		kk = clamp(t, 0.0, 1.0);
		nw = vec2(sign(uu), 0.0).yx;
		nw = perp * sign(uu);
		hh = 0.5;
	}
	// leaflets
	float pr = Lf / 17.0;
	float ci = floor(sc / pr);
	for (int j = 0; j < 5; j++) {
		float i = ci - float(j) + 1.0;
		for (int sd = 0; sd < 2; sd++) {
			float sg = sd == 0 ? -1.0 : 1.0;
			float rid = i * 2.0 + float(sd) + s2.z * 17.0;
			float r1 = h21(vec2(rid, 1.7));
			float r2 = h21(vec2(rid, 4.1));
			float si = i * pr + (sd == 0 ? 0.0 : 0.5 * pr);
			float ti = si / Lf;
			if (ti < 0.03 || ti > 0.98) continue;
			float ll = Lf * 0.30 * pow(sin(3.14159 * (0.10 + 0.90 * ti)), 0.55) * (0.68 + 0.55 * r1) * (1.0 - 0.25 * ti);
			float th = 0.95 + 0.50 * (r2 - 0.5) + 0.25 * ti;
			vec2 b = vec2(cos(th), sg * sin(th)) * ll;
			// leaflets droop slightly under their own weight
			b.y *= 1.0;
			float k;
			vec2 nl;
			float d = leaflet(vec2(sc, uu), vec2(si, 0.0), b, ll * (0.26 + 0.05 * r2), k, nl);
			if (d < dmin) {
				dmin = d;
				kk = k;
				hh = r1;
				nw = dir * nl.x + perp * nl.y;
			}
		}
	}
	float alpha = (1.0 - smoothstep(-bl, bl, dmin)) * (0.95 - 1.6 * bl);
	if (alpha <= 0.001) return vec4(0.0);
	// shading: dark body, backlit translucency, sun rim
	float vein = 1.0 - smoothstep(0.0, 0.5, abs(fract(hh * 7.0 + kk * 3.0) - 0.5) * 2.0);
	float facing = max(dot(nw, SUN2), 0.0);
	float depth = clamp(-dmin / max(bl * 2.5, 0.004), 0.0, 1.0);
	vec3 body = vec3(0.005, 0.014, 0.016);
	vec3 trans = mix(vec3(0.035, 0.15, 0.075), vec3(0.09, 0.22, 0.09), hh) * (0.2 + 0.8 * kk) * (0.55 + 0.45 * vein);
	vec3 col = mix(body, trans, 0.30 * (1.0 - depth * 0.6) * (0.35 + 0.65 * (1.0 - float(P.y > 0.6) * 0.5)));
	float edge = exp(-pow((dmin + bl * 0.4) / (bl * 1.3 + 0.003), 2.0));
	vec3 rc = mix(vec3(1.0, 0.72, 0.38), vec3(0.45, 0.95, 0.85), fract(s2.z * 0.37));
	col += rc * edge * facing * 0.26 + vec3(0.10, 0.40, 0.45) * edge * 0.05;
	return vec4(col, alpha);
}

vec4 tendril(vec2 P, float x0, float len, float ph, float blur) {
	float y = P.y;
	if (y < -0.02 || y > len + 0.04) return vec4(0.0);
	float cx = x0 + 0.018 * sin(y * 9.0 + ph) * y * 3.0 + 0.03 * sin(TIME * 0.3 + ph) * y * y;
	float dx = abs(P.x - cx);
	float t = clamp(y / len, 0.0, 1.0);
	float w = 0.0034 * (1.0 - 0.7 * t) + 0.0006;
	float d = dx - w;
	float al = 1.0 - smoothstep(-blur, blur, d);
	al *= 1.0 - smoothstep(len, len + 0.01, y);
	vec3 col = vec3(0.012, 0.035, 0.030) + vec3(0.9, 0.7, 0.4) * 0.12 * exp(-pow((d + blur * 0.3) / (blur + 0.002), 2.0)) * step(P.x, cx);
	vec4 res = vec4(col, al * 0.9);
	// dew drops: refract the (bright) environment upside-down, dark edge, sun glint, caustic
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float yd = len * (0.38 + 0.31 * fi) + 0.005 * sin(ph + fi);
		float r = 0.0072 + 0.0042 * fract(ph * (1.7 + fi));
		if (i == 2) r *= 1.4;
		float ycd = i == 2 ? len + r * 0.9 : yd;
		float xd = x0 + 0.018 * sin(ycd * 9.0 + ph) * ycd * 3.0 + 0.03 * sin(TIME * 0.3 + ph) * ycd * ycd;
		vec2 p = (P - vec2(xd, ycd)) / vec2(r, r * 1.12);
		float rr = length(p);
		if (rr > 1.15) continue;
		float inside = 1.0 - smoothstep(0.93, 1.0, rr);
		vec3 env = mix(vec3(0.04, 0.10, 0.16), vec3(0.28, 0.72, 0.70), smoothstep(-0.7, 0.9, p.y));
		float ring = smoothstep(0.55, 0.98, rr);
		vec3 dc = env * (1.0 - 0.75 * ring) * 0.85;
		dc += vec3(1.0, 0.78, 0.5) * 1.1 * exp(-dot(p - vec2(-0.40, -0.42), p - vec2(-0.40, -0.42)) * 28.0);
		dc += vec3(0.4, 0.95, 0.85) * 0.5 * exp(-pow(length(p - vec2(0.28, 0.45)) / 0.32, 2.0));
		dc += vec3(0.5, 0.6, 0.6) * 0.18 * exp(-pow((rr - 0.96) / 0.05, 2.0)) * max(dot(normalize(p + 1e-4), SUN2), 0.0);
		res.rgb = mix(res.rgb, dc, inside);
		res.a = max(res.a, inside * 0.95);
	}
	return res;
}

void fragment() {
	float sx = (UV.x - 0.5) * aspect;
	float X = sx + cam * span * par - look.x * (0.4 + par);
	float Y = UV.y - look.y * (0.3 + 0.5 * par);
	vec2 P = vec2(X, Y);

	vec4 acc = vec4(0.0); // premultiplied accumulation, back to front
	for (int i = 0; i < 12; i++) {
		vec4 f = frond(P, i);
		acc.rgb = f.rgb * f.a + acc.rgb * (1.0 - f.a);
		acc.a = f.a + acc.a * (1.0 - f.a);
	}
	// hanging tendrils
	const vec4 TD[6] = vec4[](vec4(-0.50, 0.30, 1.3, 0.0), vec4(0.45, 0.22, 4.1, 0.0), vec4(1.95, 0.27, 2.2, 0.0), vec4(3.35, 0.24, 5.0, 0.0), vec4(4.25, 0.29, 0.7, 0.0), vec4(5.00, 0.25, 3.3, 0.0));
	for (int i = 0; i < 6; i++) {
		vec4 s = TD[i];
		if (abs(P.x - s.x) > 0.15) continue;
		vec4 t = tendril(P, s.x, s.y, s.z, 0.004);
		acc.rgb = t.rgb * t.a + acc.rgb * (1.0 - t.a);
		acc.a = t.a + acc.a * (1.0 - t.a);
	}

	// keep the centre and lower centre clear
	float clear = 1.0 - (1.0 - smoothstep(0.40, 0.75, abs(sx))) * smoothstep(0.05, 0.5, Y);
	clear *= 1.0 - (1.0 - smoothstep(0.55, 0.85, abs(sx))) * smoothstep(0.50, 0.62, Y);
	acc *= clear;

	vec3 col = acc.a > 0.0 ? acc.rgb / acc.a : vec3(0.0);
	float al = acc.a;

	// spore bokeh: large defocused discs drifting up; ring-brightened like real lens bokeh
	for (int L = 0; L < 2; L++) {
		float cs = L == 0 ? 0.33 : 0.52;
		vec2 q = P / cs + vec2(0.0, -TIME * (L == 0 ? 0.006 : 0.004) / cs);
		q.x += float(L) * 7.3;
		vec2 id = floor(q);
		vec2 h = h22(id + float(L) * 31.0);
		if (h.x > 0.42) continue;
		vec2 c = id + 0.2 + 0.6 * h22(id + 5.5);
		float rad = (L == 0 ? 0.016 : 0.028) * (0.6 + 0.8 * h.y) / cs;
		float dd = length(q - c) / rad;
		float disc = 1.0 - smoothstep(0.80, 1.0, dd);
		float ring = exp(-pow((dd - 0.92) / 0.10, 2.0));
		vec3 bc = mix(vec3(1.0, 0.72, 0.36), vec3(0.45, 0.95, 0.85), step(0.5, h.y));
		float ba = (disc * 0.07 + ring * 0.10) * clear * (0.4 + 0.6 * smoothstep(0.0, 0.5, abs(sx)));
		col = (col * al + bc * ba * (1.0 - al)) / max(al + ba * (1.0 - al), 0.0001);
		al = al + ba * (1.0 - al);
	}

	col += (h21(FRAGCOORD.xy) - 0.5) * (1.5 / 255.0);
	COLOR = vec4(col, al);
}
