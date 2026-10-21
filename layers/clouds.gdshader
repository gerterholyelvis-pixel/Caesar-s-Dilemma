shader_type canvas_item;

// LAYER: clouds (alpha-blended over everything behind). Raymarched cloud deck below the horizon.
// Outputs NON-premultiplied color with alpha = 1 - transmittance.
// See CONTRACT.md for the shared camera model.

uniform float aspect = 1.5;
uniform vec2 look = vec2(0.0);

const vec3 MOON_DIR = vec3(-0.38, 0.42, 0.82);
const float TOP = -1.0;
const float BOT = -3.2;

float h3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float n3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(h3(i), h3(i + vec3(1, 0, 0)), f.x), mix(h3(i + vec3(0, 1, 0)), h3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h3(i + vec3(0, 0, 1)), h3(i + vec3(1, 0, 1)), f.x), mix(h3(i + vec3(0, 1, 1)), h3(i + vec3(1, 1, 1)), f.x), f.y),
		f.z);
}

float density(vec3 pos, int oct) {
	vec3 q = pos * 0.33 + vec3(TIME * 0.045, 0.0, TIME * 0.01);
	float d = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		if (i >= oct) break;
		d += a * n3(q);
		q = q * 2.07 + vec3(3.1, 1.7, 5.3);
		a *= 0.5;
	}
	float hf = clamp((pos.y - BOT) / (TOP - BOT), 0.0, 1.0);
	float shape = smoothstep(0.0, 0.3, hf) * (1.0 - smoothstep(0.55, 1.0, hf));
	return clamp((d - 0.34) * 3.4, 0.0, 1.0) * shape;
}

void fragment() {
	vec2 p = (UV - 0.5) * vec2(aspect, 1.0) - look;
	vec3 rd = normalize(vec3(p.x, -p.y - 0.10, 0.95));
	vec3 acc = vec3(0.0);
	float T = 1.0;
	if (rd.y < -0.004) {
		float depth = -rd.y;                       // 0 at horizon, larger looking down
		float haze = exp(-depth * 5.0);            // 1 at the horizon, fades quickly
		vec3 warm = vec3(1.00, 0.62, 0.50);        // sunset light, ONLY near the horizon
		vec3 shade_col = vec3(0.07, 0.06, 0.24);   // cool indigo shadows
		vec3 lit_col = vec3(0.70, 0.64, 0.90);     // pearl lavender-white moonlit tops
		float t0 = TOP / rd.y;
		float t1 = min(BOT / rd.y, t0 + 7.0);
		float steps = 18.0;
		float dt = (t1 - t0) / steps;
		vec3 L = normalize(MOON_DIR);
		float jitter = fract(sin(dot(UV * 1000.0, vec2(12.9898, 78.233))) * 43758.5453);
		for (int i = 0; i < 18; i++) {
			float t = t0 + (float(i) + jitter) * dt;
			vec3 pos = rd * t;
			float d = density(pos, 5);
			if (d > 0.01) {
				float shadow = 0.0;
				for (int j = 1; j <= 2; j++) {
					shadow += density(pos + L * (float(j) * float(j)) * 0.45, 2);
				}
				float light = exp(-shadow * 2.4);
				float hf = clamp((pos.y - BOT) / (TOP - BOT), 0.0, 1.0);
				vec3 c = mix(shade_col, lit_col, clamp(light * (0.3 + 0.7 * hf), 0.0, 1.0));
				// silver lining on thin edges facing the moon
				float rim = pow(clamp(1.0 - d, 0.0, 1.0), 3.0) * light;
				c += vec3(0.85, 0.95, 1.0) * rim * 0.30;
				// sunset-warmed undersides toward the horizon
				c = mix(c, c * warm * 1.5, haze * (1.0 - hf * 0.6) * 0.85);
				float a = 1.0 - exp(-d * dt * 3.4);
				acc += T * a * c;
				T *= 1.0 - a;
				if (T < 0.03) break;
			}
		}
		// continuous cloud floor so gaps never show black: soft violet fog graded to warm at the horizon
		float fogw = smoothstep(0.0, 0.07, depth) * 0.55;
		vec3 fog = mix(vec3(0.12, 0.10, 0.30), warm * 0.95, haze * 0.8);
		fog *= 0.75 + 0.25 * n3(vec3(rd.x / depth * 0.8 + TIME * 0.02, 1.0, rd.z / depth * 0.8));
		acc += T * fog * fogw;
		T *= (1.0 - fogw);
		// atmospheric haze at the horizon
		acc = mix(acc, warm * 0.9 * (1.0 - T), haze * 0.25);
	}
	float alpha = clamp(1.0 - T, 0.0, 1.0);
	vec3 col = alpha > 0.001 ? acc / alpha : vec3(0.0);
	col = 1.0 - exp(-col * 1.1);
	COLOR = vec4(col, alpha);
}
