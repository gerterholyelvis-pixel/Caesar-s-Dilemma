shader_type canvas_item;

// Post for the goblin cinematic: localized heat shimmer, depth-of-field with luminance-weighted bokeh, chromatic fringe,
// halation bloom from screen mips with anamorphic streaks and lens dirt, unsharp detail, filmic grade (cold shadows,
// ember highlights), vignette, luminance-weighted film grain, flash.

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
uniform vec2 focus = vec2(0.5, 0.44);   // the in-focus point (screen uv): the face
uniform float dof = 0.7;                // depth-of-field strength, 0 = off
uniform float dirt = 0.45;              // lens dirt amount
uniform float streak = 0.5;             // anamorphic streak amount

vec3 aces(vec3 x) {
	return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0.0, 1.0);
}

float nz(vec2 p) {
	return texture(noise_tex, p).r;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	// heat shimmer: rising warp, strongest near the ember source below
	vec2 hn = texture(noise_tex, uv * vec2(2.5, 3.5) + vec2(T * 0.03, -T * 0.28)).rg - 0.5;
	float near = exp(-length((uv - lpos) * vec2(aspect, 1.0)) * 1.4);
	uv += hn * shimmer * (0.25 + near);
	vec2 dir = uv - vec2(0.5);
	float rr = length(dir * vec2(aspect, 1.0));

	// --- depth of field: sharp around the face, soft bokeh toward the edges ---
	float rf = length((uv - focus) * vec2(aspect * 0.75, 1.0));
	float coc = dof * smoothstep(0.30, 0.95, rf) * 0.020;
	vec3 c0 = textureLod(scr, uv, 0.0).rgb;
	vec3 col = c0;
	if (coc > 0.0004) {
		vec3 acc = c0 * 1.0;
		float ws = 1.0;
		for (int i = 0; i < 14; i++) {
			float a = float(i) * 2.39996;
			float r = sqrt((float(i) + 0.5) / 14.0);
			vec2 o = vec2(cos(a), sin(a)) * r * coc * vec2(1.0 / aspect, 1.0);
			vec3 s = textureLod(scr, uv + o, 0.0).rgb;
			float w = 1.0 + dot(s, vec3(0.3, 0.55, 0.15)) * 2.5;
			acc += s * w;
			ws += w;
		}
		col = acc / ws;
	}
	// chromatic fringe grows toward the edges (applied as per-channel deltas so the bokeh stays intact)
	float ab = aberr * (0.3 + rr * 1.6);
	col.r += textureLod(scr, uv + dir * ab, 0.0).r - c0.r;
	col.b += textureLod(scr, uv - dir * ab, 0.0).b - c0.b;
	// soft diffusion (tiny blur) for a filmic lens, then unsharp detail where in focus
	vec3 soft = textureLod(scr, uv, 1.5).rgb;
	float sharp_k = 0.30 * (1.0 - smoothstep(0.0, 0.0012, coc));
	col += (c0 - soft) * sharp_k;
	col = mix(col, soft, 0.10);
	// halation bloom
	vec3 b = textureLod(scr, uv, 2.5).rgb * 0.42 + textureLod(scr, uv, 3.5).rgb * 0.32 + textureLod(scr, uv, 4.5).rgb * 0.18 + textureLod(scr, uv, 5.5).rgb * 0.08;
	b = max(b - 0.10, 0.0);
	col += b * bloom * vec3(1.0, 0.78, 0.62);
	// anamorphic streaks: cold horizontal flares off the brightest points
	vec3 st = vec3(0.0);
	for (int i = 1; i <= 6; i++) {
		float o = float(i) * 0.016;
		float w = exp(-float(i) * 0.42);
		st += max(textureLod(scr, uv + vec2(o, 0.0), 2.5).rgb - 1.1, 0.0) * w;
		st += max(textureLod(scr, uv - vec2(o, 0.0), 2.5).rgb - 1.1, 0.0) * w;
	}
	col += st * vec3(0.55, 0.75, 1.0) * 0.12 * streak;
	// lens dirt: smudges and specks that only show where the light is strong
	float d1 = smoothstep(0.55, 0.85, nz(uv * vec2(1.7, 1.1) + 3.1) * 0.65 + nz(uv * vec2(4.3, 2.9) + 9.2) * 0.45);
	float d2 = smoothstep(0.78, 0.95, nz(uv * vec2(14.0, 9.0) + 1.7));
	float bl = dot(b, vec3(0.3, 0.55, 0.15));
	col += (d1 * 0.7 + d2 * 0.9) * clamp(bl * 1.6, 0.0, 1.0) * dirt * vec3(1.0, 0.78, 0.55) * 0.45;
	col *= expo;
	col += vec3(1.0, 0.82, 0.55) * flash;
	col = aces(col * 0.95);
	col = mix(col, col * col * (3.0 - 2.0 * col), 0.45);
	col = max(col - 0.008, 0.0) * 1.01;
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(l), col, 0.88);
	// split tone: teal-blue shadows, warm highlights
	col *= mix(vec3(0.78, 0.94, 1.20), vec3(1.07, 0.98, 0.86), smoothstep(0.0, 0.45, l));
	float rv = length((SCREEN_UV - 0.5) * vec2(aspect, 1.0));
	float v = 1.0 - vig * pow(clamp(rv * 1.1, 0.0, 1.5), 2.3);
	col *= clamp(v, 0.18, 1.0);
	vec2 fc = FRAGCOORD.xy;
	float g = fract(sin(dot(fc + fract(T * 7.31) * vec2(311.0, 173.0), vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
	float g2 = fract(sin(dot(floor(fc * 0.5) + fract(T * 5.17) * vec2(97.0, 211.0), vec2(39.3468, 11.135))) * 24634.6345) - 0.5;
	col += (g + g2) * 0.5 * grain * (1.1 - l);
	COLOR = vec4(max(col, 0.0), 1.0);
}
