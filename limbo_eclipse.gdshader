shader_type canvas_item;

// LIMBO / ECLIPSE: a huge slow black sun with a cold corona hangs over a ruined gate.
// Thin light shafts fall through fog, broken monoliths drift, the plain mirrors the corona.

uniform float aspect = 1.5;

const float HZ = 0.52;

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
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(11.7, 4.3);
		a *= 0.5;
	}
	return v;
}

float fbm3(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(11.7, 4.3);
		a *= 0.5;
	}
	return v;
}

float column(vec2 uv, float x, float w, float h, float broken) {
	float inx = 1.0 - smoothstep(w * 0.8, w, abs(uv.x - x));
	float top = HZ - h + broken * 0.024 * (noise(vec2(uv.x * 220.0, x * 40.0)) - 0.5) + broken * 0.008 * step(x, uv.x);
	float iny = smoothstep(top - 0.002, top + 0.002, uv.y) * (1.0 - smoothstep(HZ - 0.002, HZ + 0.004, uv.y));
	return inx * iny;
}

// signed distance to a rotated, chipped slab (aspect-corrected space)
float slab(vec2 p, vec2 c, vec2 hs, float ang, float seed) {
	vec2 q = p - c;
	float ca = cos(ang);
	float sa = sin(ang);
	q = vec2(ca * q.x + sa * q.y, -sa * q.x + ca * q.y);
	q.x += (noise(vec2(q.y * 22.0, seed)) - 0.5) * 0.012;
	q.y += (noise(vec2(q.x * 22.0, seed + 5.0)) - 0.5) * 0.012;
	hs.x *= 1.0 - 0.25 * smoothstep(-hs.y, hs.y, q.y);
	vec2 d = abs(q) - hs;
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

void fragment() {
	vec2 uv = UV;
	vec2 pa = vec2(uv.x * aspect, uv.y);
	float t = TIME;

	vec3 horizon_col = vec3(0.50, 0.50, 0.52);
	vec3 coolw = vec3(0.80, 0.86, 0.95);
	vec3 col;

	vec2 sc = vec2(0.34 * aspect, 0.25);
	float R = 0.115;
	vec2 dv = pa - sc;
	float d = length(dv);
	float ang = atan(dv.y, dv.x);

	if (uv.y < HZ) {
		float sy = clamp((HZ - uv.y) / HZ, 0.0, 1.0);
		col = mix(horizon_col, vec3(0.075, 0.08, 0.10), pow(sy, 0.6));
		col += coolw * exp(-d * 3.2) * 0.30;
		col += coolw * exp(-max(d - R, 0.0) * 14.0) * 0.28;

		// cracked / rippling halo rings
		float rip = fbm3(vec2(ang * 3.0 + t * 0.03, d * 18.0)) - 0.5;
		float rr = d + rip * 0.018;
		float ring1 = exp(-pow((rr - R * 1.75) * 60.0, 2.0));
		float ring2 = exp(-pow((rr - R * 2.6) * 90.0, 2.0));
		float cr = 1.0 - smoothstep(0.0, 0.18, abs(fbm3(vec2(ang * 6.0, d * 30.0) + 7.0) - 0.5));
		col += coolw * ring1 * (0.08 + 0.10 * cr) * exp(-d * 1.5);
		col += coolw * ring2 * 0.05 * (0.4 + cr);

		float f = fbm(vec2(pa.x * 1.2 + t * 0.012, pa.y * 4.0));
		col = mix(col, horizon_col * 0.85, smoothstep(0.35, 0.8, f) * 0.30 * (1.0 - sy * 0.7));

		// thin vertical light shafts falling from the corona
		float sx = pa.x - sc.x;
		float shn = noise(vec2(pa.x * 70.0 + 3.0, t * 0.05)) * 0.6 + noise(vec2(pa.x * 23.0, 9.0)) * 0.4;
		float shaft = smoothstep(0.48, 0.80, shn);
		float spread = exp(-pow(sx / (0.07 + max(uv.y - sc.y, 0.0) * 0.5), 2.0));
		float below = smoothstep(sc.y + R * 0.6, sc.y + R * 1.6, uv.y);
		col += coolw * shaft * spread * below * (0.22 + 0.10 * f);

		float ray = pow(noise(vec2(ang * 9.0 + 3.0 + t * 0.02, 1.0)), 4.0) * 0.6 + pow(noise(vec2(ang * 38.0, t * 0.04)), 7.0) * 0.4;
		col += coolw * ray * exp(-max(d - R, 0.0) * 11.0) * step(R, d) * 0.38;
		// black sun with razor corona rim
		float edge = smoothstep(R - 0.003, R + 0.002, d);
		float rim = exp(-pow((d - R) * 140.0, 2.0));
		float rimv = 0.55 + 0.45 * fbm3(vec2(ang * 4.0 - t * 0.05, 2.0));
		col = mix(vec3(0.012, 0.013, 0.018), col, edge);
		col += vec3(0.95, 0.98, 1.0) * rim * 0.75 * rimv;
		float limb = exp(-pow((d - R * 0.97) * 90.0, 2.0)) * (1.0 - edge) * smoothstep(-0.2, 0.8, sin(ang - 0.6));
		col += coolw * limb * 0.22;

		// drifting monolith fragments
		for (int i = 0; i < 3; i++) {
			float fi = float(i);
			vec2 c = vec2(0.13 * aspect, 0.17);
			vec2 hs = vec2(0.032, 0.095);
			float a0 = 0.35;
			float sd = 1.0;
			if (i == 1) { c = vec2(0.50 * aspect, 0.085); hs = vec2(0.020, 0.058); a0 = -0.55; sd = 4.0; }
			if (i == 2) { c = vec2(0.205 * aspect, 0.39); hs = vec2(0.016, 0.044); a0 = 0.9; sd = 8.0; }
			c.y += sin(t * 0.25 + fi * 2.1) * 0.008;
			float sdist = slab(pa, c, hs, a0 + sin(t * 0.12 + fi * 1.7) * 0.07, sd);
			float body = 1.0 - smoothstep(-0.0015, 0.0015, sdist);
			vec3 mono = vec3(0.045, 0.05, 0.065);
			vec2 toS = normalize(sc - c);
			float facing = clamp(dot(normalize(pa - c + vec2(1e-4)), toS) * 0.5 + 0.5, 0.0, 1.0);
			float rimz = exp(-pow((sdist + 0.002) * 260.0, 2.0)) * facing * facing;
			mono += coolw * rimz * 1.0;
			float haze = 0.3 + 0.25 * smoothstep(0.1, 0.45, uv.y);
			col = mix(col, mix(mono, col, haze), body);
		}
	} else {
		float dy = max(uv.y - HZ, 0.006);
		float z = 0.07 / dy;
		vec2 xz = vec2((uv.x - 0.5) * aspect * z * 1.6, z + t * 0.12);
		float n = fbm(xz * 0.6);
		float crack = (1.0 - smoothstep(0.0, 0.014, abs(fbm(xz * 1.4 + 3.0) - 0.5))) * smoothstep(0.12, 0.30, dy);
		vec3 ground = mix(vec3(0.10, 0.10, 0.12), vec3(0.42, 0.42, 0.44), smoothstep(0.25, 0.75, n));
		ground *= 1.0 - crack * 0.4;
		// long cold reflection of the corona
		float rx = uv.x * aspect - sc.x;
		float rw = 0.015 + dy * 0.22;
		float ripple = noise(vec2(rx * 30.0, dy * 45.0 - t * 0.2));
		float refl = exp(-pow(rx / rw, 2.0)) * exp(-dy * 2.2) * (0.55 + 0.7 * ripple);
		float pool = exp(-pow(rx / (R * 0.8), 2.0)) * exp(-dy * 12.0);
		ground += coolw * refl * 0.55;
		ground *= 1.0 - pool * 0.5;
		// broad glow behind the angel
		ground += coolw * exp(-pow((uv.x - 0.40) * 3.0, 2.0)) * exp(-dy * 2.5) * 0.10;
		float fog = 1.0 - exp(-dy * 11.0);
		col = mix(horizon_col, ground, clamp(fog, 0.0, 1.0));
	}

	// distant broken gate under the eclipse
	float s = 0.0;
	s = max(s, column(uv, 0.285, 0.011, 0.20, 1.0));
	s = max(s, column(uv, 0.395, 0.011, 0.23, 1.0));
	float lint = (1.0 - smoothstep(0.004, 0.008, abs(uv.y - (HZ - 0.205)))) * step(0.285, uv.x) * step(uv.x, 0.395) * step(0.2, noise(vec2(uv.x * 40.0, 1.0)) + 0.35);
	s = max(s, lint * 0.9);
	s = max(s, column(uv, 0.12, 0.014, 0.12, 2.0));
	s = max(s, column(uv, 0.21, 0.010, 0.07, 2.0));
	s = max(s, column(uv, 0.62, 0.016, 0.13, 2.0));
	s = max(s, column(uv, 0.86, 0.011, 0.09, 2.0));
	col = mix(col, mix(vec3(0.10, 0.10, 0.12), horizon_col, 0.45), s * 0.95);

	// mist hugging the horizon
	float m = fbm(vec2(pa.x * 2.0 - t * 0.03, uv.y * 14.0 + t * 0.01));
	col = mix(col, horizon_col, exp(-abs(uv.y - HZ) * 14.0) * (0.30 + 0.45 * m));

	// drain: nearly grey, cold bias
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(lum), col, 0.5);
	col = 1.0 - exp(-col * 1.3);

	vec2 q = uv - 0.5;
	col *= 1.0 - dot(q, q) * 0.9;

	float dn = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453);
	col += (dn - 0.5) / 120.0;
	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
