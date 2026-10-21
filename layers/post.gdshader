shader_type canvas_item;

// LAYER: post (full-screen, drawn last, under the Start button).
// Filmic finishing: halation, CA, sharpen, S-curve, split-tone, indigo vignette, grain.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

uniform float aspect = 1.5;
uniform float ca_strength = 0.0016;
uniform float halation = 0.16;
uniform float sharpen = 0.22;
uniform float contrast = 0.55;
uniform float saturation = 1.06;
uniform float vignette_strength = 0.42;
uniform float grain_amount = 0.028;
uniform vec3 shadow_tint : source_color = vec3(0.30, 0.52, 0.62);   // teal
uniform vec3 highlight_tint : source_color = vec3(0.80, 0.62, 0.95); // soft violet
uniform vec3 vignette_color : source_color = vec3(0.05, 0.06, 0.17); // deep indigo

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec3 smp(vec2 uv, float lod) {
	return textureLod(screen_tex, uv, lod).rgb;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	vec2 cc = c * vec2(aspect, 1.0);
	float r2 = dot(cc, cc);

	// radial chromatic aberration (zero at center, grows toward edges)
	vec2 ca = c * r2 * ca_strength * 14.0;
	vec3 col;
	col.r = smp(uv + ca, 0.0).r;
	col.g = smp(uv, 0.0).g;
	col.b = smp(uv - ca, 0.0).b;

	// light unsharp mask using a blurred mip
	vec3 blur1 = smp(uv, 1.5);
	col += (col - blur1) * sharpen;

	// halation: wide soft glow of highlights, slightly warm-magenta fringe
	vec3 h = smp(uv, 4.0) * 0.5 + smp(uv, 5.5) * 0.5;
	vec3 hl = max(h - vec3(0.45), vec3(0.0));
	float lum_h = dot(hl, vec3(0.3, 0.5, 0.2));
	col += hl * halation + vec3(1.0, 0.55, 0.75) * lum_h * halation * 0.35;

	col = max(col, vec3(0.0));

	// soft-clamp HDR so highlights roll off instead of clipping (keeps some >1 for glow)
	col = mix(col, 1.0 - exp(-col * 1.25) , 0.0) ;

	// filmic S-curve around mid grey, in a perceptual-ish space
	vec3 g = pow(clamp(col, 0.0, 4.0), vec3(1.0 / 2.2 * 2.2)); // identity; screen is already display-referred
	float l = dot(g, vec3(0.2126, 0.7152, 0.0722));
	vec3 x = clamp(g, 0.0, 1.0);
	vec3 s = x * x * (3.0 - 2.0 * x);
	x = mix(x, s, contrast);
	// keep any >1 energy for bloom
	g = x + max(g - 1.0, 0.0);

	// split-toning
	l = clamp(dot(g, vec3(0.2126, 0.7152, 0.0722)), 0.0, 1.0);
	float sh = 1.0 - smoothstep(0.0, 0.55, l);
	float hi = smoothstep(0.45, 1.0, l);
	g = mix(g, g * (shadow_tint * 1.7), sh * 0.22);
	g = mix(g, g * (highlight_tint * 1.25), hi * 0.16);

	// saturation
	float gl = dot(g, vec3(0.2126, 0.7152, 0.0722));
	g = mix(vec3(gl), g, saturation);

	// indigo vignette: lift-tinted fade, never black
	float v = smoothstep(0.12, 0.85, r2 * 1.25);
	float vamt = v * vignette_strength;
	g = mix(g, g * 0.62 + vignette_color * 0.55, vamt);

	// film grain, strongest in mids, animated
	float t = floor(TIME * 24.0);
	float n = hash12(FRAGCOORD.xy + t * 17.13) + hash12(FRAGCOORD.xy * 1.7 + t * 3.7) - 1.0;
	float gm = 1.0 - abs(gl * 2.0 - 1.0) * 0.6;
	g += n * grain_amount * gm;

	COLOR = vec4(clamp(g, 0.0, 6.0), 1.0);
}
