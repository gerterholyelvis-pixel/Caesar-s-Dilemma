shader_type canvas_item;
render_mode blend_add;

// Embers and ash flakes rushing outward from the nadir as we fall: stretched by speed (motion streaks).

uniform float T = 0.0;
uniform float camY = 0.0;
uniform float speed = 1.0;
uniform float fl = 0.8;
uniform vec2 res = vec2(960.0, 640.0);
uniform vec2 nadir = vec2(0.0);
uniform float ember_amt = 0.0;
uniform float ash_amt = 0.0;
uniform float expo = 1.0;


float hh(float x) { return fract(sin(x * 127.1 + 311.7) * 43758.5453); }

float layer(vec2 p, float N, float Lz, float seed, float rise, float size, float len_s) {
	float r = length(p);
	float a = atan(p.y, p.x) + 3.14159265;
	float ai = a / TAU * N;
	float id = floor(ai);
	float fa = fract(ai) - 0.5;
	float h1 = hh(id + seed);
	float h2 = hh(id * 1.7 + seed + 3.3);
	float h3 = hh(id * 2.9 + seed + 9.1);
	float rho = mix(1.2, 16.0, h1 * h1);
	float zr = mod(h2 * Lz - rise * T - camY, Lz) + 0.4;
	float sv = (speed + abs(rise)) * len_s;
	float rp = fl * rho / zr;
	float rp2 = fl * rho / (zr + sv);
	float along = smoothstep(rp2 - 0.002, rp2 + 0.01, r) * (1.0 - smoothstep(rp * 0.98, rp * 1.02 + 0.004, r));
	float arc = (fa - (h3 - 0.5) * 0.5) * (TAU / N) * r;
	float th = size * (0.5 + h1) * (0.3 + r * 0.9) + 0.0006;
	float cross_s = smoothstep(th, 0.0, abs(arc));
	float far_f = smoothstep(Lz, Lz * 0.55, zr);
	float tw = 0.6 + 0.4 * sin(T * (3.0 + h3 * 6.0) + h2 * 30.0);
	float head = smoothstep(rp2, rp, r);   // brighter at the leading end
	return along * cross_s * far_f * tw * (0.35 + 0.9 * head);
}

void fragment() {
	vec2 p = (UV - 0.5) * vec2(res.x / res.y, 1.0) - nadir;
	vec3 c = vec3(0.0);
	if (ember_amt > 0.001) {
		float e = layer(p, 38.0, 70.0, 1.0, 4.0, 0.0014, 0.03) + layer(p, 50.0, 110.0, 17.0, 6.0, 0.0010, 0.025) + 0.7 * layer(p, 24.0, 45.0, 41.0, 3.0, 0.0020, 0.03);
		c += mix(vec3(1.0, 0.35, 0.06), vec3(1.0, 0.75, 0.3), hh(floor(e * 3.0))) * e * 3.5 * ember_amt;
	}
	if (ash_amt > 0.001) {
		float s = layer(p, 36.0, 60.0, 71.0, 0.0, 0.0030, 0.05) + layer(p, 54.0, 90.0, 5.0, 0.0, 0.0020, 0.04);
		c += vec3(0.55, 0.53, 0.50) * s * 0.9 * ash_amt;
	}
	COLOR = vec4(c * expo, 1.0);
}
