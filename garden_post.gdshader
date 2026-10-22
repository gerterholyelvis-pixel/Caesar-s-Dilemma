shader_type canvas_item;

// GARDEN POST: cinematic finishing pass. Reads the (LDR) screen behind it.
// Order: edge DOF + chromatic aberration, mip-chain bloom, anamorphic streak, grade, filmic curve, dust, vignette, grain.
uniform float aspect = 1.5;
uniform vec2 look = vec2(0.0);
uniform float cam = 0.0;
uniform float span = 3.0;
uniform float par = 0.0;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1, 0)), f.x), mix(hash12(i + vec2(0, 1)), hash12(i + vec2(1, 1)), f.x), f.y);
}
float luma(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

vec3 bright(vec2 uv, float lod) {
	vec3 c = textureLod(screen_tex, uv, lod).rgb;
	float l = luma(c);
	float k = clamp((l - 0.55) * 2.2, 0.0, 1.0);
	return c * k * k;
}

vec3 aces(vec3 x) {
	return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0.0, 1.0);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;
	vec2 cc = (uv - 0.5) * vec2(aspect, 1.0);
	float r2 = dot(cc, cc);
	float edge = smoothstep(0.10, 0.50, r2);

	// chromatic aberration + edge defocus
	vec2 dir = normalize(cc + 1e-5) * vec2(1.0 / aspect, 1.0);
	float ca = edge * 2.2;
	float dof = edge * 1.1;
	vec3 col;
	col.r = textureLod(screen_tex, uv + dir * px * ca, dof).r;
	col.g = textureLod(screen_tex, uv, dof).g;
	col.b = textureLod(screen_tex, uv - dir * px * ca, dof).b;

	// bloom from the mip chain (4 scales x 4 taps)
	vec3 bl = vec3(0.0);
	for (int i = 0; i < 4; i++) {
		float lod = 3.0 + float(i) * 1.5;
		vec2 s = px * exp2(lod) * 0.6;
		bl += bright(uv + vec2(s.x, s.y), lod) + bright(uv + vec2(-s.x, s.y), lod)
			+ bright(uv + vec2(s.x, -s.y), lod) + bright(uv + vec2(-s.x, -s.y), lod);
	}
	bl *= 0.25 / 4.0;
	bl *= vec3(1.05, 1.0, 0.94);

	// anamorphic horizontal glare on the brightest highlights
	vec3 st = vec3(0.0);
	for (int i = -3; i <= 3; i++) {
		if (i == 0) continue;
		float fi = float(i);
		float w = exp(-abs(fi) * 0.45);
		vec2 u = uv + vec2(fi * 0.09 / aspect, 0.0);
		vec3 c = textureLod(screen_tex, u, 4.0).rgb;
		float k = clamp((luma(c) - 0.78) * 4.0, 0.0, 1.0);
		st += c * k * k * w;
	}
	st *= vec3(0.55, 0.85, 1.0) * 0.04;

	col += bl * 0.75 + st;

	// grade: split-tone, gentle saturation
	float l = luma(col);
	vec3 shadowTint = vec3(0.90, 1.00, 1.08);
	vec3 highTint = vec3(1.07, 1.01, 0.90);
	col *= mix(shadowTint, highTint, smoothstep(0.08, 0.85, l));
	col = mix(vec3(l), col, 1.06);

	// filmic shoulder (inputs are already display-referred, so blend)
	vec3 tm = aces(col * 0.92);
	col = mix(col, tm * 1.04, 0.55);

	// lens dust lit by bright regions
	vec2 dp = uv * vec2(aspect, 1.0) * 5.0;
	float dust = smoothstep(0.62, 0.95, vnoise(dp) * 0.6 + vnoise(dp * 2.7 + 7.0) * 0.4);
	float glow = luma(textureLod(screen_tex, uv, 6.0).rgb);
	col += dust * glow * glow * 0.06 * vec3(1.0, 0.92, 0.8);

	// soft warm vignette, never black
	float vg = smoothstep(0.12, 0.62, r2);
	col *= mix(1.0, 0.80, vg);
	col = mix(col, col * vec3(1.06, 0.97, 0.88) + vec3(0.012, 0.008, 0.004), vg * 0.5);

	// film grain + dither
	float t = floor(TIME * 24.0);
	float g = hash12(FRAGCOORD.xy + t * 17.13) + hash12(FRAGCOORD.xy * 1.37 + t * 5.7) - 1.0;
	float lm = luma(col);
	col += g * 0.028 * (0.4 + 1.6 * lm * (1.0 - lm) * 2.0);
	col += (hash12(FRAGCOORD.xy + 91.7) - 0.5) / 255.0;

	COLOR = vec4(max(col, vec3(0.0)), 1.0);
}
