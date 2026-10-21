shader_type canvas_item;

// LAYER: sky_back (opaque). Gradient atmosphere only. No moon/stars/clouds here.
// Deep-twilight sky: Rayleigh-style blue-to-teal-to-violet gradient, warm Mie glow
// toward a sun hidden below the horizon, thin airglow, faint high aurora curtains.

uniform float aspect = 1.5;
uniform vec2 look = vec2(0.0);

const vec3 SUN_DIR = normalize(vec3(0.55, -0.16, 0.82));

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec3 aurora(vec3 rd) {
	if (rd.y < 0.22 || rd.y > 0.95) return vec3(0.0);
	// project onto a high plane
	vec2 q = rd.xz / (rd.y + 0.15);
	float w = vnoise(vec2(q.x * 1.6, q.y * 0.9)) * 2.0 + vnoise(vec2(q.x * 3.7 + 7.0, q.y * 1.7)) * 0.7;
	float curtain = sin(q.x * 2.3 + w * 2.2 + q.y * 3.0);
	curtain = pow(max(1.0 - abs(curtain), 0.0), 5.0);
	float rays = 0.6 + 0.4 * vnoise(vec2(q.x * 38.0, 0.5));
	float vert = smoothstep(0.22, 0.38, rd.y) * (1.0 - smoothstep(0.55, 0.95, rd.y));
	// green low, violet-magenta at the top edge
	vec3 col = mix(vec3(0.10, 0.85, 0.55), vec3(0.45, 0.25, 0.85), smoothstep(0.3, 0.8, rd.y));
	return col * curtain * rays * vert * 0.075;
}

// Harmonious analogous palette: electric blue -> cyan-teal -> violet -> magenta.
vec3 nebula_palette(float t) {
	return 0.5 + 0.5 * cos(6.28318 * (vec3(t) + vec3(0.58, 0.72, 0.86)));
}

// Fractal nebula: domain-warped noise fed into a Kali-style inversion fractal (IFS),
// colored by an orbit trap so the filigree shifts smoothly through the palette.
vec3 nebula(vec3 rd) {
	if (rd.y < -0.02) return vec3(0.0);
	vec2 uv = rd.xy / max(rd.z, 0.2);
	float tm = TIME * 0.02;
	vec2 w = vec2(vnoise(uv * 1.6 + vec2(tm, 0.0)), vnoise(uv * 1.6 + vec2(5.2, -tm)));
	vec2 z = uv * 1.15 + (w - 0.5) * 1.4 + vec2(0.3, 0.1);
	float acc = 0.0;
	float trap = 1e3;
	for (int i = 0; i < 8; i++) {
		z = abs(z) / max(dot(z, z), 0.08) - vec2(0.78, 0.86 + 0.04 * sin(TIME * 0.05));
		acc += exp(-3.2 * length(z));
		trap = min(trap, abs(z.x * z.y));
	}
	float f = pow(clamp(acc * 0.20, 0.0, 1.0), 1.4);
	vec3 col = nebula_palette(0.04 + 0.30 * clamp(trap * 1.5, 0.0, 1.0) + 0.06 * uv.x);
	// soft cloudy body underneath the filigree so it reads as gas, not wire
	float body = vnoise(uv * 2.4 + w * 3.0) * 0.6 + vnoise(uv * 5.0 - w * 2.0) * 0.3;
	vec3 neb = col * (f * 0.95 + body * body * 0.30);
	// fade in above the horizon, keep it away from the moon so the moon stays clean
	float vis = smoothstep(0.0, 0.22, rd.y) * (1.0 - 0.55 * smoothstep(0.9, 1.0, rd.y));
	float moon_ang = acos(clamp(dot(rd, normalize(vec3(-0.38, 0.42, 0.82))), -1.0, 1.0));
	vis *= smoothstep(0.08, 0.45, moon_ang);
	return neb * vis * 0.55;
}

vec3 sky(vec3 rd) {
	float y = rd.y;
	float ay = max(y, 0.0);
	float mu = dot(rd, SUN_DIR);
	// sun-azimuth proximity on horizontal plane (soft, wide)
	vec2 h = normalize(rd.xz + 1e-5);
	float az = dot(h, normalize(SUN_DIR.xz)) * 0.5 + 0.5;

	// Rayleigh-ish vertical gradient (multi-stop, in linear light)
	vec3 zen = vec3(0.0035, 0.0055, 0.030);
	vec3 up2 = vec3(0.010, 0.022, 0.085);
	vec3 teal = vec3(0.030, 0.150, 0.230);
	vec3 viol = vec3(0.230, 0.110, 0.320);
	vec3 rose = vec3(0.720, 0.250, 0.300);
	vec3 amber = vec3(1.000, 0.480, 0.200);

	vec3 col = zen;
	col = mix(col, up2, smoothstep(0.85, 0.45, y));
	col = mix(col, teal, smoothstep(0.42, 0.15, y) * 0.9);
	col = mix(col, viol, smoothstep(0.20, 0.07, y));
	col = mix(col, rose, smoothstep(0.085, 0.02, y));
	col = mix(col, amber, smoothstep(0.035, 0.0, y));

	// Mie forward scatter: wide warm lobe toward the sun side, strongest at horizon
	float mie = pow(max(mu, 0.0), 6.0);
	float lobe = exp(-ay * 9.0);
	col += vec3(0.95, 0.38, 0.18) * mie * lobe * 0.75;
	col += vec3(0.60, 0.22, 0.30) * pow(max(mu, 0.0), 2.0) * exp(-ay * 4.5) * 0.18;
	// anti-solar side: cooler purple twilight (Belt of Venus feel)
	col += vec3(0.20, 0.10, 0.26) * (1.0 - az) * exp(-ay * 7.0) * 0.30;

	// thin horizon airglow band
	col += vec3(0.95, 0.52, 0.30) * exp(-ay * 55.0) * 0.30;
	col += vec3(0.30, 0.65, 0.55) * exp(-pow((y - 0.20) * 9.0, 2.0)) * 0.025;

	// below horizon: dark warm haze that hands off to the cloud layers
	float below = smoothstep(0.0, -0.9, y);
	vec3 under = vec3(0.16, 0.13, 0.32) + vec3(0.35, 0.16, 0.14) * exp(-max(-y, 0.0) * 6.0);
	col = mix(col, under, below);

	col += aurora(rd) * 1.8;
	col += nebula(rd);
	// richer, more saturated twilight overall
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = max(mix(vec3(lum), col, 1.35), 0.0);
	return col;
}

void fragment() {
	vec2 p = (UV - 0.5) * vec2(aspect, 1.0) - look;
	vec3 rd = normalize(vec3(p.x, -p.y - 0.10, 0.95));
	vec3 col = sky(rd);
	// filmic-ish tonemap (soft shoulder), keep HDR sane (<1)
	col = 1.0 - exp(-col * 1.25);
	// triangular-PDF dither with interleaved gradient noise to kill banding
	float n1 = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
	float n2 = fract(52.9829189 * fract(dot(FRAGCOORD.xy + 17.0, vec2(0.06711056, 0.00583715))));
	col += (n1 + n2 - 1.0) / 255.0 * 1.5;
	COLOR = vec4(max(col, 0.0), 1.0);
}
