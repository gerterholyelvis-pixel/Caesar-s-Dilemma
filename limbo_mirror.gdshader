shader_type canvas_item;

// LIMBO - The Drowned World: a black mirror-water plain reflecting a layered charcoal sky,
// a pale light hung from a single thread, a lone teal-silver seam of aurora and a broken gate.
// Slow ripples spread from where the traveller stands; lost souls rise from the water.

uniform float aspect = 1.5;

const float HZ = 0.52;
const vec2 LAMP = vec2(0.36, 0.215);
const vec2 STAND = vec2(0.40, 0.80);

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(11.7, 4.3);
		a *= 0.5;
	}
	return v;
}

float column(vec2 uv, float x, float w, float h, float rough) {
	float taper = 1.0 + (uv.y - (HZ - h)) * 0.5;
	float inx = 1.0 - smoothstep(w * 0.8 * taper, w * taper, abs(uv.x - x));
	float top = HZ - h + rough * 0.012 * (noise(vec2(uv.x * 500.0, 1.0)) - 0.5) * 2.0;
	float iny = smoothstep(top - 0.002, top + 0.002, uv.y) * (1.0 - smoothstep(HZ - 0.004, HZ, uv.y));
	return inx * iny;
}

float ruins(vec2 uv) {
	float s = 0.0;
	// the great gate: two pillars, a half-fallen arch, a sunken sill
	s = max(s, column(uv, 0.13, 0.014, 0.27, 1.0));
	s = max(s, column(uv, 0.25, 0.014, 0.235, 2.5));
	vec2 c = vec2(0.19, HZ - 0.235);
	vec2 e = vec2((uv.x - c.x) / 0.063, (uv.y - c.y) / 0.075);
	float ring = abs(length(e) - 1.0);
	float arch = (1.0 - smoothstep(0.05, 0.12, ring)) * step(uv.y, c.y + 0.002) * (1.0 - step(0.215, uv.x));
	s = max(s, arch);
	s = max(s, (1.0 - smoothstep(0.0, 0.004, abs(uv.y - (HZ - 0.012)))) * step(0.10, uv.x) * step(uv.x, 0.28));
	s = max(s, column(uv, 0.055, 0.009, 0.10, 2.0));
	s = max(s, column(uv, 0.64, 0.007, 0.06, 2.0));
	s = max(s, column(uv, 0.87, 0.010, 0.12, 2.0));
	s = max(s, column(uv, 0.93, 0.006, 0.05, 2.0));
	return s;
}

// the sky seen straight on; uv.y < HZ. aurout: aurora light, added after colour grading.
vec3 sky(vec2 uv, float t, out vec3 aurout) {
	vec2 pa = vec2(uv.x * aspect, uv.y);
	float sy = clamp((HZ - uv.y) / HZ, 0.0, 1.0);
	vec3 hz_col = vec3(0.50, 0.52, 0.54);
	vec3 col = mix(hz_col, vec3(0.055, 0.060, 0.075), pow(sy, 0.6));

	float f1 = fbm(vec2(pa.x * 1.1 + t * 0.010, pa.y * 3.5));
	float f2 = fbm(vec2(pa.x * 2.3 - t * 0.017 + 7.0, pa.y * 7.0 + 3.0));
	col = mix(col, vec3(0.30, 0.32, 0.35), smoothstep(0.38, 0.85, f1) * 0.38 * (1.0 - sy * 0.55));
	col = mix(col, vec3(0.16, 0.17, 0.20), smoothstep(0.45, 0.9, f2) * 0.30 * sy);

	// the hung light
	vec2 lp = vec2(LAMP.x * aspect, LAMP.y);
	float d = length(pa - lp);
	col += vec3(0.80, 0.88, 0.92) * exp(-d * 4.5) * 0.32;
	col += vec3(0.85, 0.92, 0.95) * exp(-d * 14.0) * 0.30;
	col += vec3(0.80, 0.90, 0.92) * (1.0 - smoothstep(0.050, 0.062, d)) * 0.55;
	col += vec3(0.9, 0.95, 0.95) * (1.0 - smoothstep(0.0, 0.040, d)) * 0.25;
	col += vec3(0.70, 0.85, 0.88) * exp(-abs(d - 0.115) * 70.0) * 0.10;

	// the thread it hangs from, rising out of sight
	float thr = (1.0 - smoothstep(0.0007, 0.0018, abs(uv.x - LAMP.x - 0.003 * sin(uv.y * 9.0 + t * 0.3)))) * step(uv.y, LAMP.y - 0.055);
	col += vec3(0.55, 0.65, 0.68) * thr * 0.35 * smoothstep(0.0, 0.12, uv.y);

	// aurora seam: a sinuous ribbon with falling rays, strongest on the left
	float h = HZ - uv.y;
	float wob = (fbm(vec2(pa.x * 1.6 + t * 0.02, 2.0)) - 0.5) * 0.11 + 0.025 * sin(pa.x * 3.2 + t * 0.07);
	float cy = 0.14 + wob;
	float band = exp(-pow((h - cy) / 0.020, 2.0));
	float rays = 0.45 + 0.55 * noise(vec2(pa.x * 55.0 + wob * 80.0, t * 0.2));
	float drape = smoothstep(cy - 0.01, cy, h) * (1.0 - smoothstep(cy, cy + 0.17, h));
	float below = smoothstep(cy + 0.01, cy - 0.12, h) * step(0.001, h);
	float side = mix(1.0, 0.28, smoothstep(0.38, 0.72, uv.x));
	float curtain = band + 0.0 * drape + 0.5 * below * (0.4 + 0.6 * noise(vec2(pa.x * 22.0, t * 0.06)));
	vec3 aur = mix(vec3(0.20, 0.55, 0.55), vec3(0.62, 0.82, 0.84), band);
	aurout = aur * curtain * rays * side;

	// ruins
	float s = ruins(uv);
	aurout *= 1.0 - s;
	col = mix(col, mix(vec3(0.05, 0.055, 0.07), hz_col, 0.20), s * 0.93);
	// mist pooled at the foot of the ruins
	col = mix(col, hz_col, s * smoothstep(0.12, 0.0, h) * 0.45);
	return col;
}

vec3 souls(vec2 uv, float t) {
	vec3 acc = vec3(0.0);
	for (int L = 0; L < 3; L++) {
		float fl = float(L);
		float N = 11.0 + fl * 7.0;
		vec2 p = vec2(uv.x * aspect * N, (uv.y - HZ + 0.02) * N * 0.9);
		float rise = t * (0.18 + 0.06 * fl) + fl * 0.37;
		vec2 id = vec2(floor(p.x), floor(p.y + rise));
		float hs = hash(id + fl * 19.0);
		float hs2 = hash(id + 41.7 + fl * 7.0);
		float fy = fract(p.y + rise);
		vec2 q = vec2(fract(p.x) - 0.5, fy - 0.5);
		q.x -= (hs - 0.5) * 0.5 + 0.12 * sin(t * (0.6 + hs2) + hs * 6.28 + fy * 4.0);
		float life = smoothstep(0.0, 0.25, fy) * (1.0 - smoothstep(0.35, 1.0, fy));
		float on = step(0.88, hs2);
		float r = length(q);
		float tw = 0.6 + 0.4 * sin(t * 2.0 + hs * 40.0);
		acc += vec3(0.62, 0.90, 0.92) * (exp(-r * r * 420.0) * 1.0 + exp(-r * 8.0) * 0.08) * life * on * tw;
	}
	float up = smoothstep(0.30, 0.50, uv.y);
	float hide = 1.0 - 0.85 * smoothstep(0.43, 0.48, uv.x) * (1.0 - smoothstep(0.78, 0.84, uv.x)) * smoothstep(0.40, 0.45, uv.y) * (1.0 - smoothstep(0.88, 0.92, uv.y));
	return acc * hide * up;
}

void fragment() {
	vec2 uv = UV;
	float t = TIME;
	vec3 col;
	vec3 aura;
	vec3 hz_col = vec3(0.50, 0.52, 0.54);

	if (uv.y < HZ) {
		col = sky(uv, t, aura);
	} else {
		float dy = uv.y - HZ;

		// ripples spreading across the water plane from where the traveller stands
		vec2 rd = vec2((uv.x - STAND.x) * aspect, (uv.y - STAND.y) * 2.6);
		float rr = length(rd);
		float rip = 0.0;
		float ripd = 0.0;
		for (int k = 0; k < 5; k++) {
			float ph = fract(t * 0.10 + float(k) * 0.2);
			float rad = ph * 1.5;
			float w = 0.011 + ph * 0.014;
			float x = (rr - rad) / w;
			float env = (1.0 - ph) * (1.0 - ph) * smoothstep(0.02, 0.10, rr);
			rip += exp(-x * x) * env;
			ripd += -2.0 * x * exp(-x * x) * env;
		}
		float quiet = 1.0 - 0.7 * smoothstep(0.55, 0.62, uv.x) * smoothstep(0.58, 0.64, uv.y);
		rip *= quiet;
		ripd *= quiet;

		float swell = noise(vec2(uv.x * 9.0 + t * 0.03, pow(dy, 0.55) * 38.0 - t * 0.08));
		float sw2 = noise(vec2(uv.x * 22.0 - t * 0.05, pow(dy, 0.55) * 80.0 + t * 0.06));

		float yr = HZ - dy * 0.92;
		float wob = ripd * 0.0045 + (swell - 0.5) * 0.007 + (sw2 - 0.5) * 0.0025;
		vec2 ruv = vec2(uv.x + (swell - 0.5) * 0.016 * smoothstep(0.0, 0.3, dy) + ripd * 0.003, clamp(yr + wob, 0.001, HZ - 0.0005));
		vec3 refl = sky(ruv, t, aura);
		aura *= 0.6;

		float fres = mix(0.95, 0.52, smoothstep(0.0, 0.45, dy));
		vec3 deep = vec3(0.020, 0.024, 0.032);
		col = mix(deep, refl, fres);
		col += vec3(0.5, 0.65, 0.68) * rip * 0.30;
		col += vec3(0.7, 0.8, 0.82) * max(ripd, 0.0) * 0.045;

		float mist = fbm(vec2(uv.x * 3.5 - t * 0.025, dy * 30.0 + t * 0.01));
		col = mix(col, hz_col * 0.9, exp(-dy * 18.0) * (0.35 + 0.45 * mist));
		col = mix(col, vec3(0.26, 0.29, 0.31), smoothstep(0.55, 0.8, mist) * 0.12 * exp(-dy * 4.0));
	}

	col += souls(uv, t) * 0.55;

	col = mix(col, hz_col * 1.05, exp(-abs(uv.y - HZ) * 90.0) * 0.5);

	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(lum), col, 0.60);
	col += aura * 0.5;
	col = 1.0 - exp(-col * 1.5);

	vec2 q = uv - 0.5;
	col *= 1.0 - dot(q, q) * 0.95;

	vec3 p3 = fract(vec3(FRAGCOORD.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	float dn = fract((p3.x + p3.y) * p3.z);
	col += (dn - 0.5) / 160.0;
	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
