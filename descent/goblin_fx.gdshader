shader_type canvas_item;
render_mode blend_add;

// Additive atmosphere over the goblin: volumetric ember haze rising from the lava below, god-rays from the ember
// source, three parallax layers of slow bokeh embers, and drifting dust motes caught in the light.

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform float T = 0.0;
uniform float aspect = 1.78;
uniform vec2 lpos = vec2(0.3, 1.1);
uniform float haze = 0.0;
uniform float embers = 0.0;
uniform float flick = 1.0;
uniform float rays = 0.0;
uniform float zoom = 1.0;
uniform vec2 pan = vec2(0.0);

float h21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec3 ember_layer(vec2 uv, float scale, float speed, float size, float seed, float dens) {
	vec2 p = uv * scale;
	p.y += T * speed;
	vec2 id = floor(p);
	vec2 f = fract(p) - 0.5;
	float h1 = h21(id + seed);
	float h2 = h21(id * 1.37 + seed + 7.1);
	float h3 = h21(id * 0.73 + seed + 19.3);
	if (h3 > dens) return vec3(0.0);
	vec2 off = (vec2(h1, h2) - 0.5) * 0.55;
	off.x += sin(T * (0.35 + h1 * 0.5) + h2 * 6.283) * 0.12;
	off.y += sin(T * (0.27 + h2 * 0.4) + h1 * 6.283) * 0.06;
	float d = length(f - off);
	float tw = 0.45 + 0.55 * sin(T * (1.1 + h1 * 2.4) + h2 * 30.0);
	tw = max(tw, 0.0);
	float g = exp(-pow(d / size, 2.0));
	vec3 c = mix(vec3(1.5, 0.26, 0.04), vec3(2.4, 1.15, 0.35), h2 * h2);
	return c * g * (0.25 + tw) * 0.9;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 q = (uv - 0.5) * vec2(aspect, 1.0);
	vec2 ld = (uv - lpos) * vec2(aspect, 1.0);
	float dist = length(ld);
	vec3 col = vec3(0.0);

	// volumetric haze: two scrolling noise octaves lit by the ember source
	float n1 = texture(noise_tex, uv * vec2(1.3, 0.9) * (1.0 + 0.0 * zoom) + vec2(T * 0.006, -T * 0.025)).r;
	float n2 = texture(noise_tex, uv * vec2(2.9, 2.1) + vec2(-T * 0.012, -T * 0.05) + n1 * 0.2).r;
	float plume = smoothstep(0.30, 0.82, n1 * 0.6 + n2 * 0.5);
	float lit = exp(-dist * 1.5) * flick;
	float floorglow = smoothstep(0.55, 1.2, uv.y) * 0.5;
	col += vec3(1.0, 0.28, 0.06) * plume * (lit * 0.22 + floorglow * 0.12 * flick) * haze;

	// god-rays fanned from the source
	float ang = atan(ld.x, -ld.y);
	float rn = texture(noise_tex, vec2(ang * 0.9 + 3.0, T * 0.012)).r;
	float rn2 = texture(noise_tex, vec2(ang * 2.6, -T * 0.02)).g;
	float ray = smoothstep(0.42, 0.9, rn * 0.65 + rn2 * 0.45);
	col += vec3(1.0, 0.42, 0.12) * ray * exp(-dist * 1.15) * 0.10 * rays * flick;

	// embers: far (small, slow), mid, near (large soft bokeh)
	vec2 eq = q + pan * 0.15;
	float up = clamp(0.45 + uv.y * 0.75, 0.0, 1.0);
	col += ember_layer(eq, 11.0, 0.020, 0.075, 1.0, 0.55) * 0.30 * embers * up;
	col += ember_layer(eq * 0.92 + 3.3, 6.0, 0.045, 0.085, 4.0, 0.50) * 0.42 * embers * up;
	col += ember_layer(eq * 0.8 + 9.1, 2.6, 0.075, 0.13, 8.0, 0.30) * 0.5 * embers;
	col += ember_layer(eq * 0.7 + 21.0, 1.3, 0.12, 0.16, 12.0, 0.12) * 0.05 * embers;

	// dust motes: tiny, pale, hanging in the light
	vec3 dm = ember_layer(eq * 1.3 + 40.0, 17.0, -0.004, 0.05, 20.0, 0.5);
	col += vec3(dm.r, dm.r * 0.75, dm.r * 0.5) * 0.30 * embers * smoothstep(1.4, 0.2, dist);

	COLOR = vec4(col, 1.0);
}
