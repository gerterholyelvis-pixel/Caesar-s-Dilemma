shader_type canvas_item;

// LIMBO: a drained, ash-grey purgatory. Pale hanging light in heavy fog, a cracked ash plain
// receding to a fogged horizon, and broken gate/pillar silhouettes in the distance.

uniform float aspect = 1.5;

const float HZ = 0.52;   // horizon height in UV

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

// vertical broken column: returns coverage 0..1
float column(vec2 uv, float x, float w, float h, float broken) {
	float inx = 1.0 - smoothstep(w * 0.8, w, abs(uv.x - x));
	float top = HZ - h + broken * 0.02 * sin(uv.x * 900.0);
	float iny = smoothstep(top - 0.002, top + 0.002, uv.y) * (1.0 - smoothstep(HZ - 0.002, HZ + 0.004, uv.y));
	return inx * iny;
}

void fragment() {
	vec2 uv = UV;
	vec2 pa = vec2(uv.x * aspect, uv.y);
	float t = TIME;

	vec3 horizon_col = vec3(0.60, 0.57, 0.55);
	vec3 col;

	if (uv.y < HZ) {
		float sy = clamp((HZ - uv.y) / HZ, 0.0, 1.0);
		col = mix(horizon_col, vec3(0.09, 0.09, 0.12), pow(sy, 0.55));
		// the pale, sickly light hanging in the fog
		vec2 sp = vec2(0.64 * aspect, 0.27);
		float d = length(pa - sp);
		col += vec3(1.0, 0.93, 0.80) * exp(-d * 5.0) * 0.32;
		col += vec3(1.0, 0.96, 0.88) * (1.0 - smoothstep(0.035, 0.05, d)) * 0.7;
		// slow fog banks in the sky
		float f = fbm(vec2(pa.x * 1.2 + t * 0.012, pa.y * 4.0));
		col = mix(col, horizon_col * 0.9, smoothstep(0.35, 0.8, f) * 0.35 * (1.0 - sy * 0.6));
	} else {
		float dy = max(uv.y - HZ, 0.006);
		float z = 0.07 / dy;
		vec2 xz = vec2((uv.x - 0.5) * aspect * z * 1.6, z + t * 0.12);
		float n = fbm(xz * 0.6);
		float crack = 1.0 - smoothstep(0.0, 0.035, abs(fbm(xz * 1.4 + 3.0) - 0.5));
		vec3 ground = mix(vec3(0.17, 0.165, 0.17), vec3(0.46, 0.43, 0.41), n);
		ground *= 1.0 - crack * 0.55;
		// the pale light's cold reflection on the plain
		float refl = exp(-abs(uv.x * aspect - 0.64 * aspect) * 3.0) * exp(-dy * 5.0);
		ground += vec3(0.9, 0.85, 0.75) * refl * 0.18;
		float fog = 1.0 - exp(-dy * 11.0);        // 0 at the horizon = full fog
		col = mix(horizon_col, ground, clamp(fog, 0.0, 1.0));
	}

	// distant broken gate and pillars, swallowed by fog
	float s = 0.0;
	s = max(s, column(uv, 0.41, 0.012, 0.20, 1.0));
	s = max(s, column(uv, 0.52, 0.012, 0.23, 1.0));
	// lintel between the gate posts
	float lint = (1.0 - smoothstep(0.0, 0.003, abs(uv.y - (HZ - 0.205)))) * step(0.41, uv.x) * step(uv.x, 0.52);
	s = max(s, lint * 0.9);
	s = max(s, column(uv, 0.16, 0.014, 0.12, 2.0));
	s = max(s, column(uv, 0.27, 0.010, 0.07, 2.0));
	s = max(s, column(uv, 0.70, 0.016, 0.15, 2.0));
	s = max(s, column(uv, 0.84, 0.011, 0.09, 2.0));
	col = mix(col, mix(vec3(0.20, 0.19, 0.21), horizon_col, 0.55), s * 0.95);

	// rolling mist hugging the horizon
	float m = fbm(vec2(pa.x * 2.0 - t * 0.03, uv.y * 14.0 + t * 0.01));
	col = mix(col, horizon_col * 1.05, exp(-abs(uv.y - HZ) * 14.0) * (0.35 + 0.5 * m));

	// drain the color: mostly grey, a touch of warm
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(lum), col, 0.55);
	col = 1.0 - exp(-col * 1.35);

	// soft dark vignette (charcoal, not black)
	vec2 q = uv - 0.5;
	col *= 1.0 - dot(q, q) * 0.9;

	float dn = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453);
	col += (dn - 0.5) / 120.0;
	COLOR = vec4(col, 1.0);
}
