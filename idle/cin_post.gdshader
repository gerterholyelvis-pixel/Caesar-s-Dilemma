shader_type canvas_item;
// Lens/film post for the First Sprout cinematic: bloom, anamorphic streak, chromatic edge, grade, vignette, grain.
uniform sampler2D scr : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float t = 0.0;
uniform float exposure = 0.9;
uniform float bloom = 0.7;
uniform float streak = 0.35;
uniform float vignette = 0.55;
uniform float grain = 0.045;
uniform vec2 res = vec2(1920.0, 1080.0);

float hash(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }

vec3 aces(vec3 x) { return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0.0, 1.0); }

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float r2 = dot(c, c);
	vec2 ca = c * r2 * 0.012;
	vec3 col;
	col.r = textureLod(scr, uv + ca, 0.0).r;
	col.g = textureLod(scr, uv, 0.0).g;
	col.b = textureLod(scr, uv - ca, 0.0).b;
	// bloom from the mip chain
	vec3 b = textureLod(scr, uv, 2.5).rgb * 0.30 + textureLod(scr, uv, 3.5).rgb * 0.28 + textureLod(scr, uv, 4.5).rgb * 0.24 + textureLod(scr, uv, 5.5).rgb * 0.18;
	col += max(b - 0.30, 0.0) * bloom * 1.3;
	// anamorphic horizontal streak, cyan-tinted
	vec3 st = vec3(0.0);
	for (int i = -6; i <= 6; i++) {
		float k = float(i) / 6.0;
		vec3 sm = textureLod(scr, uv + vec2(k * 0.16, 0.0), 3.0).rgb;
		st += max(sm - 0.9, 0.0) * (1.0 - abs(k));
	}
	col += st * streak * vec3(0.35, 0.8, 1.0) * 0.35;
	col *= exposure;
	// grade: teal shadows, warm highlights
	float l = dot(col, vec3(0.3, 0.59, 0.11));
	col = mix(col, col * vec3(0.86, 1.02, 1.04) + vec3(0.0, 0.006, 0.01), 1.0 - smoothstep(0.0, 0.5, l));
	col = mix(col, col * vec3(1.06, 1.0, 0.9), smoothstep(0.3, 1.5, l));
	col = aces(col * 1.05);
	col = pow(col, vec3(1.0 / 1.02));
	col = mix(vec3(dot(col, vec3(0.3, 0.59, 0.11))), col, 1.08);
	col *= 1.0 - vignette * smoothstep(0.12, 0.62, r2);
	float g = hash(FRAGCOORD.xy + fract(t * 7.0) * 100.0) - 0.5;
	col += g * grain * (1.0 - 0.5 * l);
	COLOR = vec4(max(col, 0.0), 1.0);
}
