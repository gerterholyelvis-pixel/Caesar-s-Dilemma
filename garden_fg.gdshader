shader_type canvas_item;

// GARDEN FOREGROUND (par 1.5). A handful of dark, soft, recursive fractal fronds and hanging
// tendrils with glowing tips, entering from the top and the sides. Centre / lower-centre stay clear.
uniform float aspect = 1.5;
uniform vec2 look = vec2(0.0);
uniform float cam = 0.0;
uniform float span = 3.0;
uniform float par = 1.5;

float h21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

mat2 rot(float a) {
	float c = cos(a), s = sin(a);
	return mat2(vec2(c, s), vec2(-s, c));
}

// Recursive binary frond in a local frame: root at origin, growing along +y with unit length.
// Each level: draw a segment, fold, rotate, scale down. x = distance (world units), y = tip distance
vec2 frond(vec2 p, float ang, float bend, float r, float wroot) {
	float d = 1e3;
	float sc = 1.0;
	float wi = wroot;
	for (int i = 0; i < 6; i++) {
		float t = clamp(p.y, 0.0, 1.0);
		float dd = length(p - vec2(0.0, t)) * sc - wi;
		d = min(d, dd);
		p.y -= 1.0;
		p = rot(bend) * p;
		p.x = abs(p.x);
		p = rot(ang) * p;
		p /= r;
		sc *= r;
		wi *= 0.72;
	}
	return vec2(d, length(p) * sc);
}

// x, y, direction angle (0 = hanging down), length
const vec4 INST[10] = vec4[](
	vec4(-0.78, -0.03, 0.10, 0.20),
	vec4(0.72, -0.03, -0.12, 0.17),
	vec4(-0.95, 0.40, 1.55, 0.17),
	vec4(1.62, -0.03, 0.14, 0.18),
	vec4(2.05, -0.03, -0.10, 0.19),
	vec4(2.95, 0.34, -1.55, 0.17),
	vec4(3.85, -0.03, 0.12, 0.20),
	vec4(5.22, -0.03, -0.10, 0.18),
	vec4(3.70, 0.36, 1.50, 0.16),
	vec4(5.32, 0.30, -1.50, 0.15)
);

void fragment() {
	float sx = (UV.x - 0.5) * aspect;
	float X = sx + cam * span * par - look.x * (0.4 + par);
	float Y = UV.y - look.y * (0.3 + 0.5 * par);
	vec2 P = vec2(X, Y);

	float dmin = 1e3;
	vec3 glow = vec3(0.0);
	for (int i = 0; i < 10; i++) {
		vec4 s = INST[i];
		vec2 q = P - s.xy;
		if (length(q) > 3.6 * s.w) continue;
		float a = s.z;
		vec2 dir = vec2(sin(a), cos(a));
		vec2 perp = vec2(cos(a), -sin(a));
		vec2 pl = vec2(dot(q, perp), dot(q, dir)) / s.w;
		float sw = 0.05 * sin(TIME * 0.5 + float(i) * 2.1);
		vec2 f = frond(pl, 0.46 + sw * 0.4, 0.07 + 0.2 * sw * 0.2, 0.70, 0.013 / s.w);
		float d = f.x * s.w;
		dmin = min(dmin, d);
		float tip = f.y * s.w;
		vec3 gc = (mod(float(i), 2.0) < 0.5) ? vec3(1.0, 0.72, 0.28) : vec3(0.95, 0.35, 0.75);
		glow += gc * (exp(-pow(tip / 0.010, 2.0)) * 0.6 + exp(-pow(tip / 0.040, 2.0)) * 0.16);
	}

	// keep the centre and lower centre completely clear
	float clear = smoothstep(0.42, 0.72, abs(sx)) * 0.0 + 1.0 - (1.0 - smoothstep(0.40, 0.75, abs(sx))) * smoothstep(0.05, 0.5, Y);
	// also no tendrils reaching down through the dialogue band
	clear *= 1.0 - (1.0 - smoothstep(0.55, 0.85, abs(sx))) * smoothstep(0.50, 0.62, Y);

	float body = (1.0 - smoothstep(-0.002, 0.007, dmin)) * 0.92;
	vec3 bc = vec3(0.010, 0.030, 0.048);
	float rim = exp(-pow((dmin + 0.003) / 0.005, 2.0));
	bc += vec3(0.10, 0.45, 0.50) * rim * 0.30;
	float halo = exp(-max(dmin, 0.0) / 0.03) * 0.07;
	vec3 hc = vec3(0.30, 0.12, 0.50);

	float ga = clamp(max(glow.r, max(glow.g, glow.b)), 0.0, 1.0) * 0.9;
	vec3 gcol = glow / max(max(glow.r, max(glow.g, glow.b)), 0.001);

	float a1 = 1.0 - (1.0 - body) * (1.0 - halo);
	vec3 c1 = (bc * body + hc * halo * (1.0 - body)) / max(a1, 0.0001);
	float a2 = 1.0 - (1.0 - a1) * (1.0 - ga);
	vec3 c2 = (c1 * a1 + gcol * ga * (1.0 - a1)) / max(a2, 0.0001);

	c2 += (h21(FRAGCOORD.xy) - 0.5) * (1.5 / 255.0);
	COLOR = vec4(c2, a2 * clear);
}
