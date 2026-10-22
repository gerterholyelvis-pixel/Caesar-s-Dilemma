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
uniform float flash = 0.0;
uniform float bolt_amt = 0.0;
uniform float bolt_x = 0.5;
uniform float bolt_seed = 0.0;


float hh(float x) { return fract(sin(x * 127.1 + 311.7) * 43758.5453); }

float vnoise(float x) {
	float i = floor(x);
	float f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(hh(i), hh(i + 1.0), f);
}

// forked lightning bolt through the smoke, uv 0..1
float bolt(vec2 uv, float x0, float seed) {
	float y = uv.y;
	float off = 0.0;
	float amp = 0.20;
	float fr = 2.0;
	for (int i = 0; i < 5; i++) {
		off += (vnoise(y * fr + seed * 7.0 + float(i) * 13.0) - 0.5) * amp;
		amp *= 0.55;
		fr *= 2.1;
	}
	float x = x0 + off;
	float d = abs(uv.x - x);
	float g = 0.0016 / (d + 0.0016) * 0.6 + exp(-d * 45.0) * 0.18;
	// fork
	float yb = 0.30 + 0.2 * hh(seed);
	float xb = x0 + off * 0.0 + (y - yb) * (hh(seed + 3.0) - 0.5) * 1.6;
	float d2 = abs(uv.x - xb - (vnoise(y * 9.0 + seed) - 0.5) * 0.05);
	g += (0.0011 / (d2 + 0.0011) * 0.4) * step(yb, y) * (1.0 - smoothstep(yb, yb + 0.35, y));
	return g * smoothstep(-0.02, 0.06, y) * (1.0 - smoothstep(0.55, 0.85, y + 0.12 * hh(seed + 8.0)));
}

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

// screen-space flakes drifting up past a falling camera, streaked along their motion; one flake per cell
float flk(vec2 p, float sc, vec2 vel, float sz, float stretch, float seed, float dens) {
	vec2 q = p * sc + vel * T;
	vec2 id = floor(q);
	vec2 f = fract(q) - 0.5;
	float a = hh(id.x * 13.1 + id.y * 57.7 + seed);
	float b = hh(id.x * 91.3 + id.y * 17.9 + seed * 1.7);
	float k = hh(a * 7.0 + b * 3.0 + seed);
	vec2 d = f - (vec2(a, b) - 0.5) * 0.7;
	vec2 dir = normalize(vel);
	float al = dot(d, dir);
	float pe = dot(d, vec2(-dir.y, dir.x));
	float s = sz * (0.5 + k);
	float m = smoothstep(s, 0.0, abs(pe)) * smoothstep(stretch * (0.4 + k), 0.0, abs(al));
	float tw = 0.65 + 0.35 * sin(T * (4.0 + 7.0 * k) + b * 40.0);
	return m * tw * step(1.0 - dens, k * 0.5 + 0.5 * a);
}

void fragment() {
	vec2 p = (UV - 0.5) * vec2(res.x / res.y, 1.0) - nadir;
	vec3 c = vec3(0.0);
	if (ember_amt > 0.001) {
		float e = layer(p, 38.0, 70.0, 1.0, 4.0, 0.0014, 0.03) + layer(p, 50.0, 110.0, 17.0, 6.0, 0.0010, 0.025) + 0.7 * layer(p, 24.0, 45.0, 41.0, 3.0, 0.0020, 0.03);
		c += mix(vec3(1.0, 0.35, 0.06), vec3(1.0, 0.75, 0.3), hh(floor(e * 3.0))) * e * 3.5 * ember_amt;
	}
	if (ash_amt > 0.001) {
		float s = layer(p, 36.0, 60.0, 71.0, 0.0, 0.0045, 0.05) + layer(p, 54.0, 90.0, 5.0, 0.0, 0.0030, 0.04) + 1.3 * layer(p, 18.0, 30.0, 23.0, 0.0, 0.0090, 0.06);
		c += vec3(0.80, 0.74, 0.66) * s * 1.3 * ash_amt * (0.6 + 2.0 * flash);
	}
	vec2 pp = (UV - 0.5) * vec2(res.x / res.y, 1.0);
	float stv = 0.10 + speed * 0.016;
	if (ash_amt > 0.001) {
		float sa = flk(pp, 22.0, vec2(0.9, -4.2), 0.05, stv, 3.0, 0.55) * 0.8 + flk(pp, 40.0, vec2(1.1, -2.6), 0.07, stv * 0.8, 9.0, 0.5) * 0.6 + flk(pp, 9.0, vec2(1.6, -7.5), 0.035, stv * 1.4, 21.0, 0.45) * 1.3;
		c += vec3(0.82, 0.76, 0.68) * sa * ash_amt * (0.5 + 2.2 * flash) * 1.2;
	}
	if (ember_amt > 0.001) {
		float se = flk(pp, 26.0, vec2(0.3, -1.8), 0.06, stv * 0.7, 33.0, 0.4) + flk(pp, 14.0, vec2(-0.4, -3.2), 0.05, stv, 41.0, 0.35) * 1.4;
		c += vec3(1.0, 0.42, 0.10) * se * ember_amt * 2.2;
	}
	if (bolt_amt > 0.01) {
		vec2 uvb = vec2(UV.x, UV.y);
		float bg = bolt(uvb, bolt_x, bolt_seed);
		c += vec3(1.0, 0.88, 0.74) * bg * bolt_amt * 2.5;
	}
	c *= 1.0 + flash * 2.0;
	COLOR = vec4(c * expo, 1.0);
}
