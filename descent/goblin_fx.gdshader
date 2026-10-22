shader_type canvas_item;
render_mode blend_add;

// Additive atmosphere over the goblin: layered volumetric haze (warm from the ember, cold from the moon shaft),
// two families of god-rays, parallax bokeh embers with bright rims, and dust motes that flare inside the light shafts.

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
uniform vec2 cold_pos = vec2(0.84, -0.28);   // where the cold moon shaft comes from (screen uv)
uniform float cold = 1.0;                    // 0 disables the cold light family

float h21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// parallax particle layer. ring > 0 makes soft discs with a bright rim (out-of-focus bokeh)
vec3 ember_layer(vec2 uv, float scale, float speed, float size, float seed, float dens, float ring) {
	vec2 p = uv * scale;
	p.y += T * speed;
	vec2 id = floor(p);
	vec2 f = fract(p) - 0.5;
	float h1 = h21(id + seed);
	float h2 = h21(id * 1.37 + seed + 7.1);
	float h3 = h21(id * 0.73 + seed + 19.3);
	if (h3 > dens) return vec3(0.0);
	vec2 off = (vec2(h1, h2) - 0.5) * 0.82;
	off.x += sin(T * (0.35 + h1 * 0.5) + h2 * 6.283) * 0.12;
	off.y += sin(T * (0.27 + h2 * 0.4) + h1 * 6.283) * 0.06;
	float d = length(f - off);
	float tw = max(0.45 + 0.55 * sin(T * (1.1 + h1 * 2.4) + h2 * 30.0), 0.0);
	float g = exp(-pow(d / size, 2.0));
	if (ring > 0.0) {
		float disc = smoothstep(size * 1.25, size * 0.95, d);
		float rim = smoothstep(size * 0.55, size * 1.05, d) * disc;
		g = disc * 0.35 + rim * ring;
	}
	vec3 c = mix(vec3(1.5, 0.26, 0.04), vec3(2.4, 1.15, 0.35), h2 * h2);
	return c * g * (0.25 + tw) * 0.9;
}

float nz(vec2 p) {
	return texture(noise_tex, p).r;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 q = (uv - 0.5) * vec2(aspect, 1.0);
	vec2 ld = (uv - lpos) * vec2(aspect, 1.0);
	float dist = length(ld);
	vec3 col = vec3(0.0);

	// --- volumetric haze: three scrolling octaves ---
	float n1 = nz(uv * vec2(1.3, 0.9) + vec2(T * 0.006, -T * 0.025));
	float n2 = nz(uv * vec2(2.9, 2.1) + vec2(-T * 0.012, -T * 0.05) + n1 * 0.2);
	float n3 = nz(uv * vec2(6.1, 4.4) + vec2(T * 0.02, -T * 0.07) + n2 * 0.15);
	float plume = smoothstep(0.30, 0.82, n1 * 0.55 + n2 * 0.45 + (n3 - 0.5) * 0.25);
	float lit = exp(-dist * 1.7) * flick;
	float floorglow = smoothstep(0.55, 1.2, uv.y) * 0.5;
	col += vec3(1.0, 0.26, 0.05) * plume * (lit * 0.12 + floorglow * 0.08 * flick) * haze;
	// cold mist drifting in from the upper right: the counter-colour to the ember
	vec2 cd = (uv - cold_pos) * vec2(aspect, 1.0);
	float cdist = length(cd);
	float cmist = smoothstep(0.38, 0.80, n2 * 0.6 + n1 * 0.4) * exp(-cdist * 1.2);
	col += vec3(0.07, 0.20, 0.32) * cmist * 0.55 * haze * cold;

	// --- god-rays: ember fan from below, cold shaft from the upper right ---
	float ang = atan(ld.x, -ld.y);
	float rn = nz(vec2(ang * 0.9 + 3.0, T * 0.012));
	float rn2 = texture(noise_tex, vec2(ang * 2.6, -T * 0.02)).g;
	float ray = smoothstep(0.42, 0.9, rn * 0.65 + rn2 * 0.45);
	col += vec3(1.0, 0.40, 0.11) * ray * exp(-dist * 1.2) * 0.065 * rays * flick;

	float cang = atan(cd.x, -cd.y);
	float cn = nz(vec2(cang * 1.7 + 11.0, T * 0.008));
	float cn2 = texture(noise_tex, vec2(cang * 4.3 + 5.0, -T * 0.014)).g;
	float beam = smoothstep(0.34, 0.80, cn * 0.62 + cn2 * 0.46);
	float cfall = exp(-cdist * 0.85);
	col += vec3(0.16, 0.42, 0.66) * beam * cfall * 0.24 * rays * cold;

	// --- embers: far (small, slow), mid, near (large soft bokeh with rims) ---
	vec2 eq = q + pan * 0.15;
	float up = clamp(0.45 + uv.y * 0.75, 0.0, 1.0);
	col += ember_layer(eq, 11.0, 0.020, 0.075, 1.0, 0.55, 0.0) * 0.30 * embers * up;
	col += ember_layer(eq * 0.92 + 3.3, 6.0, 0.045, 0.085, 4.0, 0.50, 0.0) * 0.42 * embers * up;
	col += ember_layer(eq * 0.8 + 9.1, 2.6, 0.075, 0.13, 8.0, 0.30, 0.0) * 0.5 * embers;
	// foreground bokeh: big defocused discs, drifting fast across the lens
	col += ember_layer(eq * 0.62 + 21.0, 1.3, 0.12, 0.30, 12.0, 0.16, 1.0) * 0.10 * embers;
	col += ember_layer(eq * 0.50 + 33.0, 0.9, 0.17, 0.34, 16.0, 0.10, 1.0) * vec3(0.5, 0.9, 1.3) * 0.05 * embers * cold;

	// --- dust motes: pale, hanging in the light, flaring inside the shafts ---
	float shaft = clamp(beam * cfall * 3.0 * cold + ray * exp(-dist * 1.2) * 1.2, 0.0, 3.0);
	vec3 dm = ember_layer(eq * 1.3 + 40.0, 17.0, -0.004, 0.05, 20.0, 0.34, 0.0);
	col += vec3(dm.r, dm.r * 0.8, dm.r * 0.62) * (0.18 + 0.55 * shaft) * embers * smoothstep(1.5, 0.1, dist);
	vec3 dm2 = ember_layer(eq * 2.3 + 71.0, 31.0, 0.006, 0.045, 24.0, 0.22, 0.0);
	col += vec3(0.55, 0.85, 1.15) * dm2.r * (0.08 + 0.85 * shaft) * embers * 0.35;

	COLOR = vec4(col, 1.0);
}
