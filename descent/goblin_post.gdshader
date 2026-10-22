shader_type canvas_item;

// Post for the goblin cinematic: localized heat shimmer, chromatic fringe, halation bloom from screen mips,
// filmic grade (cold shadows, ember highlights), vignette, luminance-weighted film grain, flash.

uniform sampler2D scr : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform float T = 0.0;
uniform float shimmer = 0.0;
uniform float aberr = 0.002;
uniform float bloom = 0.5;
uniform float vig = 0.6;
uniform float grain = 0.06;
uniform float expo = 1.0;
uniform float flash = 0.0;
uniform float aspect = 1.78;
uniform vec2 lpos = vec2(0.3, 1.1);

vec3 aces(vec3 x) {
	return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0.0, 1.0);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	// heat shimmer: rising warp, strongest near the ember source below
	vec2 nz = texture(noise_tex, uv * vec2(2.5, 3.5) + vec2(T * 0.03, -T * 0.28)).rg - 0.5;
	float near = exp(-length((uv - lpos) * vec2(aspect, 1.0)) * 1.4);
	uv += nz * shimmer * (0.25 + near);
	vec2 dir = uv - vec2(0.5);
	float rr = length(dir * vec2(aspect, 1.0));
	// chromatic fringe grows toward the edges
	vec3 col;
	float ab = aberr * (0.3 + rr * 1.6);
	col.r = textureLod(scr, uv + dir * ab, 0.0).r;
	col.g = textureLod(scr, uv, 0.0).g;
	col.b = textureLod(scr, uv - dir * ab, 0.0).b;
	// soft diffusion (tiny blur) for a filmic lens
	vec3 soft = textureLod(scr, uv, 1.5).rgb;
	col = mix(col, soft, 0.18);
	vec3 b = textureLod(scr, uv, 2.5).rgb * 0.30 + textureLod(scr, uv, 3.5).rgb * 0.30 + textureLod(scr, uv, 4.5).rgb * 0.25 + textureLod(scr, uv, 5.5).rgb * 0.2;
	b = max(b - 0.06, 0.0);
	col += b * bloom * vec3(1.0, 0.72, 0.50);
	col *= expo;
	col += vec3(1.0, 0.82, 0.55) * flash;
	col = aces(col * 0.95);
	col = mix(col, col * col * (3.0 - 2.0 * col), 0.45);
	col = max(col - 0.008, 0.0) * 1.01;
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(l), col, 0.84);
	col *= mix(vec3(0.80, 0.92, 1.16), vec3(1.10, 0.97, 0.82), smoothstep(0.0, 0.40, l));
	float rv = length((SCREEN_UV - 0.5) * vec2(aspect, 1.0));
	float v = 1.0 - vig * pow(clamp(rv * 1.1, 0.0, 1.5), 2.3);
	col *= clamp(v, 0.18, 1.0);
	float g = texture(noise_tex, SCREEN_UV * 11.0 + vec2(fract(T * 7.0) * 3.0, fract(T * 3.1))).r - 0.5;
	float g2 = texture(noise_tex, SCREEN_UV * 23.0 + vec2(fract(T * 5.3) * 2.0, fract(T * 1.7))).g - 0.5;
	col += (g + g2) * 0.5 * grain * (1.1 - l);
	COLOR = vec4(max(col, 0.0), 1.0);
}
