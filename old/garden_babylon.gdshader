shader_type canvas_item;

// THE HANGING GARDENS OF BABYLON: full-screen painted background.
// Sky + sun + clouds, far river & haze, terraced ziggurats in depth layers (lapis glaze, gold trim,
// cascading greenery, palms, cypress, waterfalls), the Ishtar-style gate, lawn and a pale stone path.
// Uniforms set by garden.gd: aspect (width/height), look (small mouse parallax offset, about +-0.03).

uniform float aspect = 1.5;
uniform vec2 look = vec2(0.0);

const vec2 SUN = vec2(0.64, 0.255);
const vec3 SUNC = vec3(1.0, 0.72, 0.38);
const float HORIZON = 0.50;

// order-safe smoothstep: never hands smoothstep() edge0 >= edge1
float sst(float a, float b, float x) {
	if (a < b - 1e-6) return smoothstep(a, b, x);
	if (a > b + 1e-6) return 1.0 - smoothstep(b, a, x);
	return step(a, x);
}

// ---------- hashing / noise (Hoskins style) ----------
float h12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x),
			mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm3(vec2 p) {
	float a = 0.5, s = 0.0;
	for (int i = 0; i < 3; i++) {
		s += a * vn(p);
		p = p * 2.03 + vec2(17.1, 9.7);
		a *= 0.5;
	}
	return s * 1.14;
}
float fbm4(vec2 p) {
	float a = 0.5, s = 0.0;
	for (int i = 0; i < 4; i++) {
		s += a * vn(p);
		p = p * 2.03 + vec2(17.1, 9.7);
		a *= 0.5;
	}
	return s * 1.07;
}

// ---------- palette ----------
vec3 flower_col(float r) {
	if (r < 0.32) return vec3(1.0, 0.40, 0.64);
	if (r < 0.46) return vec3(1.0, 0.93, 0.86);
	if (r < 0.74) return vec3(0.62, 0.36, 0.92);
	return vec3(1.0, 0.56, 0.14);
}

// ---------- sky ----------
vec3 sky(vec2 p) {
	float t = clamp((HORIZON - p.y) / HORIZON, 0.0, 1.0);
	vec3 hor = vec3(1.0, 0.80, 0.60);
	vec3 mid = vec3(0.42, 0.78, 0.88);
	vec3 top = vec3(0.13, 0.45, 0.80);
	vec3 c = mix(hor, mid, sst(0.0, 0.42, t));
	c = mix(c, top, sst(0.30, 1.0, t));
	// warm wash toward the sun
	float ds = length((p - SUN) * vec2(0.8, 1.15));
	c = mix(c, vec3(1.0, 0.78, 0.55), 0.32 * exp(-ds * 3.2));
	// clouds: long soft bands, lit from the sun
	vec2 q = vec2(p.x * 1.5 + TIME * 0.006, p.y * 5.2);
	float n = fbm4(q * 1.25 + vec2(3.0, 1.0));
	float n2 = fbm3(q * 1.25 + vec2(3.0, 1.0) + vec2(0.12, 0.25) * 0.6);
	float cov = sst(0.50, 0.78, n) * sst(0.52, 0.12, p.y * 0.9 + 0.0) * sst(0.0, 0.05, p.y);
	cov *= sst(HORIZON + 0.01, HORIZON - 0.12, p.y);
	float lit = clamp(0.55 + (n - n2) * 3.0, 0.0, 1.0);
	vec3 cl_shadow = vec3(0.62, 0.50, 0.78);
	vec3 cl_lit = vec3(1.0, 0.80, 0.68);
	vec3 cl = mix(cl_shadow, cl_lit, lit);
	cl = mix(cl, vec3(1.0, 0.62, 0.62), 0.25 * sst(0.1, 0.4, p.y));
	cl = mix(cl, vec3(1.0, 0.92, 0.7), 0.7 * exp(-ds * 3.5) * lit);
	c = mix(c, cl, cov * 0.85);
	// sun
	float d = length(p - SUN);
	c += SUNC * (0.32 * exp(-d * 10.0) + 0.10 * exp(-d * 2.6));
	c = mix(c, vec3(1.0, 0.97, 0.86), sst(0.05, 0.028, d));
	// low rays
	float ang = atan(p.y - SUN.y, p.x - SUN.x);
	float rays = vn(vec2(ang * 5.0, 0.0)) * vn(vec2(ang * 11.0 + 3.0, 1.0));
	c += vec3(1.0, 0.8, 0.5) * rays * 0.16 * exp(-d * 2.2);
	return c;
}

// ---------- far horizon: hills + river ----------
vec3 far_scene(vec2 p, vec3 skyc, inout float done) {
	// distant blue-lilac hills and a hint of city
	float hy = HORIZON - 0.012 - 0.014 * fbm3(vec2(p.x * 4.0, 2.0)) - 0.006 * step(0.62, h12(vec2(floor(p.x * 90.0), 3.0)));
	vec3 c = skyc;
	if (p.y > hy) {
		vec3 hill = mix(vec3(0.68, 0.66, 0.86), vec3(0.97, 0.80, 0.72), exp(-length(p - SUN) * 2.0));
		c = mix(skyc, hill, 0.9);
		done = 1.0;
	}
	// river
	if (p.y > HORIZON - 0.001) {
		float v = p.y - HORIZON;
		vec3 w = mix(vec3(1.0, 0.82, 0.68), vec3(0.40, 0.70, 0.82), sst(0.0, 0.07, v));
		float rip = vn(vec2(p.x * 90.0 / (0.25 + v * 6.0), v * 600.0 + TIME * 0.6));
		float glint = pow(rip, 4.0);
		float col_ = exp(-pow((p.x - SUN.x) * (3.0 + 25.0 * v), 2.0));
		w += vec3(1.0, 0.80, 0.45) * (0.55 * col_ * (0.4 + 2.0 * glint));
		w += vec3(1.0, 0.85, 0.6) * 0.08 * glint;
		c = w;
		done = 1.0;
	}
	return c;
}

// ---------- greenery ----------
vec3 greenery(vec2 q, float seed, float lightboost, float flowers) {
	float n1 = fbm3(q);
	float n2 = fbm3(q + vec2(0.22, 0.28));
	float lit = clamp(0.5 + (n1 - n2) * 4.5, 0.0, 1.0);
	vec3 deep = vec3(0.03, 0.19, 0.09);
	vec3 mid = vec3(0.10, 0.40, 0.12);
	vec3 hi = vec3(0.62, 0.80, 0.24);
	vec3 c = mix(deep, mid, sst(0.25, 0.7, n1));
	c = mix(c, hi, lit * lit * 0.7 * lightboost);
	c *= 0.78 + 0.42 * lit;
	if (flowers > 0.0) {
		vec2 cq = q * 0.7 + seed * 3.0;
		float cd = vn(cq * 1.5 + 4.0);
		vec3 fc = flower_col(fract(vn(cq * 0.8 + 17.0) * 2.1 + seed));
		// painterly blossom masses
		float mass = sst(0.50, 0.66, cd) * flowers * 2.2;
		float tex = sst(0.30, 0.62, fbm3(q * 4.5 + 7.0));
		float bm = clamp(mass * tex, 0.0, 0.8) * (0.35 + 0.9 * lit);
		vec3 bc = fc * (0.7 + 0.5 * lit);
		c = mix(c, bc, clamp(bm, 0.0, 0.92));
		// scattered petals
		vec2 fq = q * 5.0 + seed * 7.0;
		vec2 id = floor(fq);
		vec2 fp = fract(fq) - 0.5 - (vec2(h12(id + 5.1), h12(id + 9.3)) - 0.5) * 0.7;
		float rad = 0.10 + 0.14 * h12(id + 1.3);
		float fl = sst(rad, rad * 0.45, length(fp)) * step(h12(id + seed), flowers * 1.1 * sst(0.3, 0.6, cd) + 0.03);
		c = mix(c, mix(fc, vec3(1.0), 0.25) * (0.9 + 0.3 * lit), fl);
	}
	return c;
}

float rosette(float fu, float bv) {
	vec2 c = vec2(fu - 0.5, bv - 0.5);
	float r = length(c);
	float a = atan(c.y, c.x);
	float petal = r * (1.0 + 0.4 * cos(a * 8.0));
	return sst(0.34, 0.26, petal) * (1.0 - 0.75 * sst(0.12, 0.08, r));
}

float lapis_gloss(vec2 id, float fu) {
	return sst(0.55, 0.05, abs(fu - 0.3)) * (0.5 + 0.5 * h12(id));
}

vec3 wall_col(float xl, float f, float k, float H, float seed, float detail, vec2 p, out float shade) {
	float g = 0.26;
	bool mud = mod(k + seed, 2.0) < 0.5;
	float cwid = H * 0.62;
	float u = xl / cwid;
	vec2 cid = vec2(floor(u), k + seed);
	float fu = fract(u);
	vec3 gold = vec3(1.0, 0.74, 0.26);
	vec3 lapis = mix(vec3(0.03, 0.14, 0.52), vec3(0.10, 0.36, 0.86), lapis_gloss(cid + floor(f * 4.0), fu) * 0.4 + 0.1 * h12(cid));
	vec3 c;
	if (mud) {
		// mud-brick with a lapis frieze
		float rows = f * 9.0;
		float rr = floor(rows);
		float bu = fract(u * 3.0 + 0.5 * mod(rr, 2.0));
		float joint = sst(0.06, 0.0, min(bu, 1.0 - bu) * 0.5) + sst(0.08, 0.0, min(fract(rows), 1.0 - fract(rows)));
		vec3 brick = mix(vec3(0.80, 0.55, 0.32), vec3(0.93, 0.70, 0.44), h12(vec2(floor(u * 3.0 + 0.5 * mod(rr, 2.0)), rr + k)));
		brick = mix(brick, brick * 0.6, joint * 0.5 * detail);
		c = brick;
		float band = sst(0.40, 0.42, f) * sst(0.80, 0.78, f);
		c = mix(c, lapis, band);
		// ochre relief hint in the frieze
		float bv = (f - 0.42) / 0.36;
		float ff = fu;
		if (mod(cid.x, 2.0) > 0.5) ff = 1.0 - fu;
		float body = length(vec2((ff - 0.46) / 0.34, (bv - 0.42) / 0.20));
		float head = length(vec2((ff - 0.8) / 0.10, (bv - 0.72) / 0.20));
		float legs = step(abs(ff - 0.3), 0.05) + step(abs(ff - 0.6), 0.05);
		float shape = max(sst(1.0, 0.8, body), max(sst(1.0, 0.8, head), legs * step(bv, 0.3) * step(0.0, bv)));
		float odd = mod(cid.x, 2.0);
		c = mix(c, vec3(0.88, 0.62, 0.26), shape * band * detail * 0.7 * odd);
		c = mix(c, vec3(0.98, 0.86, 0.55), rosette(fu, bv) * band * detail * (1.0 - odd));
	} else {
		c = lapis;
		float bv = (f - 0.40) / 0.36;
		float ff = fu;
		if (mod(cid.x, 2.0) > 0.5) ff = 1.0 - fu;
		float body = length(vec2((ff - 0.46) / 0.34, (bv - 0.42) / 0.20));
		float head = length(vec2((ff - 0.8) / 0.10, (bv - 0.72) / 0.20));
		float legs = step(abs(ff - 0.3), 0.05) + step(abs(ff - 0.6), 0.05);
		float shape = max(sst(1.0, 0.8, body), max(sst(1.0, 0.8, head), legs * step(bv, 0.3) * step(0.0, bv)));
		float band = step(0.40, f) * step(f, 0.76);
		float odd = mod(cid.x, 2.0);
		c = mix(c, vec3(0.88, 0.62, 0.26), shape * band * detail * 0.7 * odd);
		c = mix(c, vec3(0.98, 0.86, 0.55), rosette(fu, bv) * band * detail * (1.0 - odd));
		// tile grid
		c *= 1.0 - 0.18 * detail * (sst(0.06, 0.0, fu) + sst(0.08, 0.0, fract(f * 6.0)));
	}
	// gold trim
	float trim = step(g, f) * step(f, g + 0.05) + step(0.37, f) * step(f, 0.40) + step(0.76, f) * step(f, 0.79) + step(0.95, f);
	c = mix(c, gold * (0.9 + 0.2 * h12(cid)), clamp(trim, 0.0, 1.0));
	// ambient occlusion under the garden lip, brighter lower face
	shade = mix(0.45, 1.0, sst(g, g + 0.38, f)) * (0.9 + 0.12 * sst(0.7, 1.0, f));
	return c;
}

// returns rgb + alpha for a stepped terraced mass; p in design space
vec4 zig(vec2 p, float cx, float ytop, float H, float w0, float dw, float n, float seed, float detail, float flow) {
	float s = (p.y - ytop) / H;
	float k = floor(s);
	float f = fract(s);
	float xl = p.x - cx;
	vec3 col = vec3(0.0);
	float a = 0.0;
	float g = 0.26;
	vec2 gq = p / H * 1.5 + seed * 3.0;

	// tier body
	if (k >= 0.0 && k < n) {
		float W = w0 + dw * k;
		float ext = (f < g) ? H * 0.22 * vn(vec2(p.y / H * 7.0 + k * 3.0, seed)) * (1.0 - f / g) : 0.0;
		float edge = W + ext - abs(xl);
		float m = sst(0.0, 0.0025, edge);
		if (m > 0.0) {
			a = m;
			if (f < g) {
				col = greenery(gq, seed, 1.0, flow) * (0.95 + 0.1 * f);
			} else {
				float shade;
				col = wall_col(xl, f, k, H, seed, detail, p, shade);
				// hanging vines
				float vf = 1.0 / (H * 0.075);
				float vid = floor(xl * vf);
				float vr = h12(vec2(vid, k + seed));
				float len = g + 0.05 + vr * 0.55;
				float vx = fract(xl * vf) - 0.5 + 0.18 * sin(f * 14.0 + vr * 20.0);
				float vm = sst(0.30, 0.2, abs(vx)) * step(f, len) * step(0.22, vr + 0.2 * vn(vec2(xl * vf * 0.3, k)));
				vm *= 1.0 - sst(len - 0.12, len, f) * step(0.5, h12(vec2(vid, k)));
				vec3 vine = greenery(gq * 1.8 + vec2(0.0, f * 3.0), seed, 0.9, flow * 1.5);
				col *= shade;
				col = mix(col, vine * (0.8 + 0.2 * shade), vm);
				// waterfall
				float wr = h12(vec2(k, seed + 11.0));
				if (wr > 0.25 && detail > 0.2) {
					float wx = (h12(vec2(k, seed + 3.0)) - 0.5) * 2.0 * (W - 0.12 * H);
					float wwid = H * 0.06;
					float wm = sst(wwid, wwid * 0.5, abs(xl - wx)) * step(g, f);
					float st = vn(vec2(xl * 300.0 / H * 0.2, p.y * 70.0 / H - TIME * 2.4));
					vec3 wc = mix(vec3(0.55, 0.85, 0.95), vec3(1.0, 1.0, 1.0), pow(st, 2.0));
					wc += vec3(1.0, 0.8, 0.5) * 0.2;
					col = mix(col, wc, wm * 0.9);
				}
			}
		}
	}

	// bushes, cypress and palms rising from the terrace line of tiers below
	for (int ci = 1; ci <= 2; ci++) {
		float cand = float(ci);
		float j = k + cand;
		if (j < 0.0 || j >= n) continue;
		float Wj = w0 + dw * j;
		if (abs(xl) > Wj + 0.03) continue;
		float hup = cand - f;               // in H units above the terrace line of tier j
		if (ci == 1) {
			float bh = 0.14 + 0.30 * fbm3(vec2(xl / H * 1.8 + j * 3.7, j + seed)) + 0.05 * vn(vec2(xl / H * 9.0, j));
			float edge = bh - hup;
			if (edge > 0.0 && abs(xl) < Wj + 0.2 * H * vn(vec2(hup * 9.0, j))) {
				vec3 gc = greenery(gq + vec2(j * 1.7, 0.0), seed + j, 1.0, flow * 1.3);
				gc *= 0.85 + 0.3 * clamp(hup / bh, 0.0, 1.0);
				col = gc;
				a = max(a, sst(0.0, 0.01, edge));
			}
		}
		// tall elements
		float csz = H * 2.2;
		float cc = floor(xl / csz);
		float r = h12(vec2(cc, j + seed * 13.0));
		float r2 = h12(vec2(cc + 7.0, j + seed * 5.0));
		float xc = (cc + 0.3 + 0.4 * r2) * csz;
		if (r > 0.58 && r < 0.82 && abs(xc) < Wj - 0.03) {
			// cypress
			float hc = 1.0 + 0.9 * r2 + 0.3 * float(ci - 1);
			float t = hup / hc;
			if (t > 0.0 && t < 1.0) {
				float wc = H * (0.17 + 0.05 * r);
				float hw = wc * pow(1.0 - t, 0.55) * sst(0.0, 0.06, t) * (0.85 + 0.3 * vn(vec2(hup * 18.0, cc)));
				float dxx = (xl - xc) / max(hw, 0.0001);
				if (abs(dxx) < 1.0) {
					vec3 cyc = mix(vec3(0.03, 0.17, 0.09), vec3(0.20, 0.45, 0.14), sst(0.7, -1.0, dxx) * 0.8 * (0.6 + 0.4 * vn(vec2(xl / H * 20.0, hup * 10.0))));
					col = cyc;
					a = max(a, sst(1.0, 0.85, abs(dxx)));
				}
			}
		} else if (r < 0.24 && abs(xc) < Wj - 0.04) {
			// date palm
			float trunkh = 0.85 + 0.45 * r2 + 0.3 * float(ci - 1);
			float R = H * 0.46;
			vec2 cr = vec2(xc + 0.03 * H * (r - 0.12) * 8.0, 0.0);
			float lean = 0.10 * H * (r2 - 0.5) * (hup / trunkh);
			float tm = sst(H * 0.028, H * 0.016, abs(xl - xc - lean * 3.0)) * step(0.0, hup) * step(hup, trunkh);
			if (tm > 0.0) {
				float ring = 0.8 + 0.2 * sin(hup * H * 900.0);
				col = mix(vec3(0.34, 0.22, 0.12), vec3(0.62, 0.42, 0.22), sst(-1.0, 1.0, -(xl - xc) / (H * 0.03))) * ring;
				a = max(a, tm);
			}
			vec2 d = vec2(xl - xc - lean * 3.0, (hup - trunkh) * H);
			d.y += 0.55 * d.x * d.x / R;     // fronds droop
			float rr = length(d);
			float ang = atan(d.y, d.x) + r * 6.0;
			float petals = pow(abs(cos(ang * 4.0)), 0.7);
			float reach = R * (0.35 + 0.65 * petals);
			if (rr < reach) {
				float rib = 0.55 + 0.45 * abs(sin(ang * 32.0 + rr / H * 30.0));
				vec3 fc = mix(vec3(0.07, 0.30, 0.12), vec3(0.45, 0.70, 0.20), clamp(0.5 + d.y / R * 0.6 + 0.3 * rib - 0.3, 0.0, 1.0));
				col = fc;
				a = max(a, sst(reach, reach * 0.9, rr));
			}
		}
	}
	// side lighting: faces toward the sun glow warm, the far side falls into cool shade
	float tow = clamp(xl * sign(SUN.x - cx) / (w0 + dw * n), -1.0, 1.0);
	col *= mix(vec3(0.80, 0.84, 0.95), vec3(1.10, 1.03, 0.92), sst(-0.9, 0.9, tow));
	return vec4(col, a);
}

// ---------- haze ----------
vec3 haze(vec3 c, float amt, vec2 p) {
	float ds = length((p - SUN) * vec2(0.9, 1.2));
	vec3 hc = mix(vec3(0.70, 0.74, 0.92), vec3(1.0, 0.83, 0.66), exp(-ds * 1.6));
	float l = dot(c, vec3(0.3, 0.5, 0.2));
	c = mix(c, vec3(l), amt * 0.25);
	return mix(c, hc, amt);
}

// ---------- Ishtar-style gate ----------
vec4 gate(vec2 p, float cx, float by, float sc) {
	vec2 q = vec2((p.x - cx) / sc, (by - p.y) / sc);   // q.y up from the base
	float ax = abs(q.x);
	float top = 0.0;
	// body: towers at the sides, lower center with the arch
	float tower = step(0.55, ax) * step(ax, 1.0);
	float center = step(ax, 0.55);
	float th = 1.35 + 0.0;
	float chh = 0.95;
	float cren = step(0.5, fract(q.x * 7.0)) * 0.08;
	float h = tower * (th + cren) + center * (chh + cren * 0.7);
	float inside = step(0.0, q.y) * step(q.y, h) * step(ax, 1.0);
	// arch opening
	vec2 ac = vec2(q.x, q.y - 0.42);
	float arch = step(length(vec2(ac.x, max(ac.y, 0.0))), 0.26) * step(0.0, q.y);
	vec3 c = vec3(0.0);
	if (inside > 0.5) {
		float f = fract(q.y * 5.0);
		vec2 id = vec2(floor(q.x * 9.0), floor(q.y * 5.0));
		vec3 lap = mix(vec3(0.05, 0.20, 0.62), vec3(0.14, 0.45, 0.92), 0.35 + 0.4 * h12(id));
		float row = mod(floor(q.y * 5.0), 2.0);
		float motif = step(0.5, row) * sst(0.35, 0.2, abs(fract(q.x * 9.0) - 0.5)) * sst(0.38, 0.2, abs(f - 0.5));
		c = mix(lap, vec3(0.95, 0.68, 0.24), motif);
		float trim = step(0.93, f) + step(f, 0.05) * step(0.5, row) * 0.0;
		c = mix(c, vec3(1.0, 0.78, 0.30), clamp(trim, 0.0, 1.0) * 0.9);
		// top cornice
		c = mix(c, vec3(1.0, 0.78, 0.30), sst(h - 0.14, h - 0.12, q.y) * (1.0 - cren * 0.0));
		c *= 1.0 - 0.15 * step(0.0, q.x);
		if (arch > 0.5) c = mix(vec3(0.05, 0.09, 0.28), vec3(0.75, 0.62, 0.55), 0.2 + 0.5 * sst(0.0, 0.4, q.y));
	}
	return vec4(c, inside);
}

// ---------- ground ----------
vec3 ground(vec2 uv, vec2 p, out float pathm) {
	float y0 = 0.545;
	float v = uv.y - y0;
	float z = 1.0 / max(v + 0.02, 0.02);
	float gx = (uv.x - 0.5) * aspect * z;
	vec2 gp = vec2(gx, z);
	float hw = 0.028 + v * 0.40;
	float wob = 0.012 * (vn(vec2(z * 0.8, 1.0)) - 0.5) * (0.4 + v * 3.0);
	float dx = abs(uv.x - 0.5 - wob);
	float pm = sst(hw + 0.006 + 0.01 * v, hw - 0.006 - 0.014 * v, dx + 0.015 * (vn(gp * vec2(2.0, 0.6)) - 0.5));
	pathm = pm;
	// grass
	float gn = fbm3(gp * vec2(1.2, 0.5) * 0.9);
	float blade = vn(gp * vec2(14.0, 6.0));
	vec3 grass = mix(vec3(0.08, 0.32, 0.12), vec3(0.36, 0.60, 0.17), gn);
	grass = mix(grass, vec3(0.70, 0.78, 0.28), sst(0.55, 0.9, blade) * 0.18);
	// golden sunlit sheen toward the sun side
	grass += vec3(0.20, 0.12, 0.0) * exp(-length(vec2(uv.x * aspect - SUN.x, uv.y - 0.7)) * 1.8) * 0.4;
	// tiny flowers, sparse
	vec2 fq = gp * vec2(2.5, 1.2);
	vec2 id = floor(fq);
	float fr = h12(id);
	vec2 fp = fract(fq) - 0.5;
	float fl = sst(0.12, 0.05, length(fp)) * step(1.0 - 0.07 - 0.2 * sst(0.2, 0.42, abs(uv.x - 0.5)), fr) * sst(0.1, 0.25, v);
	grass = mix(grass, flower_col(h12(id + 3.3)), fl);
	// flowering shrub mounds on the lawn flanks
	{
		vec2 mq = gp * vec2(0.55, 0.30);
		vec2 mid_ = floor(mq);
		vec2 mf = fract(mq) - 0.5;
		float mr = h12(mid_ + 41.0);
		vec2 mc = (vec2(h12(mid_ + 3.0), h12(mid_ + 8.0)) - 0.5) * 0.3;
		float md = length((mf - mc) * vec2(1.0, 1.9));
		float flank = sst(0.17, 0.27, abs(uv.x - 0.5) - v * 0.12);
		float mm = sst(0.30, 0.26, md) * step(0.35, mr) * flank * sst(0.02, 0.1, v);
		if (mm > 0.0) {
			vec3 sh = greenery(gp * vec2(0.9, 0.5) * 2.0 + mr * 9.0, mr * 5.0, 1.0, 0.9 * step(0.6, mr) + 0.35);
			sh *= 0.85 + 0.35 * sst(0.3, -0.2, (mf.y - mc.y));
			grass = mix(grass, sh, mm);
		}
	}
	// narrow fountain channels beside the path, catching sky and sun
	{
		float cdx = abs(uv.x - 0.5 - wob) - (hw + 0.05 + 0.05 * v);
		float cw = 0.006 + 0.016 * v;
		float cm = sst(cw, cw * 0.55, abs(cdx)) * sst(0.015, 0.06, v);
		if (cm > 0.0) {
			float rip = vn(vec2(gx * 6.0, z * 8.0 - TIME * 0.8));
			vec3 wcol = mix(vec3(0.30, 0.68, 0.78), vec3(1.0, 0.86, 0.62), pow(rip, 3.0) * 0.8);
			wcol = mix(wcol, vec3(0.95, 0.75, 0.5), 0.25 * exp(-abs(uv.x * aspect - SUN.x) * 2.0));
			grass = mix(grass, wcol, cm * 0.9);
			grass = mix(grass, vec3(0.88, 0.80, 0.62), sst(cw * 1.25, cw * 0.95, abs(cdx)) * (1.0 - cm) * 0.6);
		}
	}
	// path stone
	vec3 stone = mix(vec3(0.80, 0.74, 0.62), vec3(0.90, 0.84, 0.72), fbm3(gp * vec2(2.0, 0.8)));
	float rowj = sst(0.44, 0.5, abs(fract(z * 0.55) - 0.5));
	float colj = sst(0.44, 0.5, abs(fract(gx * 0.9 + 0.5 * floor(z * 0.55)) - 0.5));
	stone *= 1.0 - 0.13 * max(rowj, colj);
	stone += vec3(0.07, 0.04, 0.0) * (1.0 - dx / max(hw, 0.01));
	// soft darker grass lip along the edges
	vec3 c = mix(grass, stone, pm);
	float lip = sst(0.0, 0.03, pm) * (1.0 - sst(0.3, 0.7, pm));
	c *= 1.0 - 0.1 * lip;
	// fade into the distance haze
	float dist = sst(0.16, 0.0, v);
	c = mix(c, vec3(0.80, 0.80, 0.78), dist * 0.55);
	return c;
}

vec3 over(vec3 base, vec4 layer) {
	return mix(base, layer.rgb, layer.a);
}

void fragment() {
	vec2 uv = UV;
	vec2 p0 = vec2((uv.x - 0.5) * aspect + 0.75, uv.y);

	// ----- sky -----
	vec2 ps = p0 + look * 0.3;
	vec3 col = sky(ps);

	// ----- far horizon & river -----
	vec2 pf = p0 + look * vec2(0.6, 0.3);
	float done = 0.0;
	col = far_scene(pf, col, done);

	// ----- far ziggurat, very hazy -----
	vec4 z1 = zig(pf, 1.03, 0.255, 0.052, 0.045, 0.035, 5.0, 3.0, 0.0, 0.2);
	z1.rgb = haze(z1.rgb, 0.68, pf);
	col = over(col, z1);
	vec4 z1b = zig(pf, 0.16, 0.33, 0.045, 0.04, 0.03, 4.0, 8.0, 0.0, 0.2);
	z1b.rgb = haze(z1b.rgb, 0.75, pf);
	col = over(col, z1b);

	// far tree line on the river's near bank: hazy palms and cypress
	{
		float tx = pf.x;
		float cellv = tx * 46.0;
		float cr = h12(vec2(floor(cellv), 4.0));
		float tri = 1.0 - abs(fract(cellv) - 0.5) * 2.0;
		float top = 0.531 - 0.010 * fbm3(vec2(tx * 16.0, 5.0)) - 0.034 * cr * pow(tri, 1.6) * step(0.72, cr);
		if (pf.y > top && pf.y < 0.546) {
			vec3 tc = mix(vec3(0.16, 0.36, 0.28), vec3(0.55, 0.70, 0.45), sst(top, 0.546, pf.y) * 0.8);
			tc = haze(tc, 0.5, pf);
			col = mix(col, tc, sst(top - 0.001, top + 0.002, pf.y) * 0.95);
		}
	}

	// ----- ground and path -----
	vec2 pm = p0 + look * vec2(0.9, 0.5);
	float pathm;
	if (uv.y > 0.545) {
		vec3 gcol = ground(uv, pm, pathm);
		// contact shadows under the mid terraces
		float sh1 = exp(-max(pm.y - 0.632, 0.0) * 28.0) * sst(0.62, 0.40, abs(pm.x - 0.20)) * step(0.632, pm.y + 0.02);
		float sh2 = exp(-max(pm.y - 0.632, 0.0) * 28.0) * sst(0.56, 0.32, abs(pm.x - 1.30)) * step(0.632, pm.y + 0.02);
		gcol *= 1.0 - 0.45 * max(sh1, sh2);
		col = gcol;
	}

	// ----- gate at the end of the path -----
	vec4 gt = gate(pm, 0.75, 0.585, 0.105);
	gt.rgb = haze(gt.rgb, 0.30, pm);
	col = over(col, gt);

	// ----- mid ziggurats -----
	vec4 z2 = zig(pm, 1.30, 0.20, 0.072, 0.075, 0.052, 6.0, 5.0, 0.6, 0.3);
	z2.rgb = haze(z2.rgb, 0.26, pm);
	col = over(col, z2);
	vec4 z3 = zig(pm, 0.20, 0.09, 0.09, 0.095, 0.060, 6.0, 1.0, 0.8, 0.3);
	z3.rgb = haze(z3.rgb, 0.12, pm);
	col = over(col, z3);

	// ----- near terraces -----
	vec2 pn = p0 + look * vec2(1.4, 0.8);
	vec4 z4 = zig(pn, -0.12, 0.46, 0.135, 0.24, 0.08, 4.0, 2.0, 1.0, 0.5);
	col = over(col, z4);
	vec4 z5 = zig(pn, 1.62, 0.52, 0.12, 0.24, 0.08, 4.0, 7.0, 1.0, 0.5);
	col = over(col, z5);

	// ----- global sun scatter, grade -----
	float ds = length((p0 - SUN) * vec2(0.8, 1.0));
	col += SUNC * 0.05 * exp(-ds * 2.5);
	col *= mix(vec3(1.0), vec3(1.06, 1.0, 0.92), sst(0.9, 0.2, uv.x));
	// gentle vignette
	vec2 vv = uv - 0.5;
	col *= 1.0 - 0.28 * dot(vv, vv);
	// soft shoulder tone map
	vec3 over1 = max(col - 0.8, vec3(0.0));
	col = min(col, vec3(0.8)) + 0.2 * tanh(over1 / 0.2);
	// dither
	col += (h12(FRAGCOORD.xy) - 0.5) / 255.0;
	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
