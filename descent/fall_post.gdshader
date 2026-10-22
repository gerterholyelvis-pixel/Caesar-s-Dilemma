shader_type canvas_item;

// Post: heat shimmer, radial speed blur, bloom from screen mips, chromatic aberration, filmic grade, vignette, grain.

uniform sampler2D scr : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform float T = 0.0;
uniform float heat = 0.0;
uniform float shimmer = 0.0;
uniform float blur = 0.0;
uniform float aberr = 0.0;
uniform float bloom = 0.6;
uniform float vig = 0.6;
uniform float grain = 0.05;
uniform vec2 center = vec2(0.5, 0.5);
uniform float aspect = 1.5;

vec3 aces(vec3 x) {
	return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0.0, 1.0);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 nz = texture(noise_tex, uv * vec2(3.0, 4.0) + vec2(T * 0.05, -T * 0.35)).rg - 0.5;
	uv += nz * shimmer * (0.4 + uv.y);
	vec2 dir = uv - center;
	float rr = min(length(dir * vec2(aspect, 1.0)), 1.2);
	vec3 col = vec3(0.0);
	float wsum = 0.0;
	for (int i = 0; i < 7; i++) {
		float f = float(i) / 6.0;
		float w = 1.0 - f * 0.6;
		vec2 u2 = center + dir * (1.0 - blur * f * (0.3 + rr));
		vec3 s;
		s.r = textureLod(scr, center + (u2 - center) * (1.0 + aberr * rr), 0.0).r;
		s.g = textureLod(scr, u2, 0.0).g;
		s.b = textureLod(scr, center + (u2 - center) * (1.0 - aberr * rr), 0.0).b;
		col += s * w;
		wsum += w;
	}
	col /= wsum;
	vec3 b = textureLod(scr, uv, 2.5).rgb * 0.30 + textureLod(scr, uv, 3.5).rgb * 0.30 + textureLod(scr, uv, 4.5).rgb * 0.25 + textureLod(scr, uv, 5.5).rgb * 0.2;
	b = max(b - 0.10, 0.0);
	col += b * bloom * vec3(1.0, 0.86, 0.72);
	col = aces(col * 0.95);
	col = mix(col, col * col * (3.0 - 2.0 * col), 0.5);
	col = max(col - 0.012, 0.0) * 1.012;
	// grade: cold shadows, warm highlights, slight desaturation
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(l), col, 0.80);
	col *= mix(vec3(0.82, 0.93, 1.14), vec3(1.08, 0.98, 0.86), smoothstep(0.0, 0.45, l));
	float rv = length((SCREEN_UV - 0.5) * vec2(aspect, 1.0));
	float v = 1.0 - vig * pow(clamp(rv * 1.15, 0.0, 1.5), 2.2);
	col *= clamp(v, 0.34, 1.0);
	float g = texture(noise_tex, SCREEN_UV * 11.0 + vec2(fract(T * 7.0) * 3.0, fract(T * 3.1))).r - 0.5;
	col += g * grain;
	COLOR = vec4(max(col, 0.0), 1.0);
}
