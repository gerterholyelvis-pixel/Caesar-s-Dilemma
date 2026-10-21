shader_type canvas_item;
render_mode blend_add;

// LAYER: celestial (additive over sky_back). Stars + moon + halo only.
// See CONTRACT.md for the shared camera model.

uniform float aspect = 1.5;
uniform vec2 look = vec2(0.0);

const vec3 MOON_DIR = vec3(-0.38, 0.42, 0.82);
const float MOON_R = 0.080;

float h1(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}
vec3 h33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}
float n3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(h1(i), h1(i + vec3(1, 0, 0)), f.x), mix(h1(i + vec3(0, 1, 0)), h1(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h1(i + vec3(0, 0, 1)), h1(i + vec3(1, 0, 1)), f.x), mix(h1(i + vec3(0, 1, 1)), h1(i + vec3(1, 1, 1)), f.x), f.y),
		f.z);
}
float fbm(vec3 p, int oct) {
	float a = 0.5, s = 0.0;
	for (int i = 0; i < oct; i++) {
		s += a * n3(p);
		p = p * 2.03 + vec3(1.7, 9.2, 3.1);
		a *= 0.5;
	}
	return s;
}

// crater field: returns (depth profile, ray brightness) via 3D voronoi-ish cells
vec2 craters(vec3 p, float scale) {
	vec3 q = p * scale;
	vec3 c = floor(q);
	vec3 f = fract(q);
	float bowl = 0.0;
	float rim = 0.0;
	for (int x = -1; x <= 1; x++)
	for (int y = -1; y <= 1; y++)
	for (int z = -1; z <= 1; z++) {
		vec3 o = vec3(float(x), float(y), float(z));
		vec3 r = h33(c + o + scale);
		if (r.x > 0.55) continue;
		vec3 cp = o + 0.2 + 0.6 * r;
		float rad = 0.12 + 0.30 * r.y * r.y;
		float d = length(f - cp) / rad;
		bowl += (1.0 - smoothstep(0.0, 1.0, d)) * (0.5 + 0.5 * r.z);
		rim += exp(-pow((d - 1.0) * 5.0, 2.0)) * (0.5 + 0.5 * r.z);
	}
	return vec2(bowl, rim);
}

vec3 stars(vec3 rd, float y) {
	vec3 col = vec3(0.0);
	// dense faint layer + medium layer
	for (int L = 0; L < 3; L++) {
		float sc = L == 0 ? 210.0 : (L == 1 ? 120.0 : 46.0);
		float thr = L == 0 ? 0.80 : (L == 1 ? 0.90 : 0.955);
		vec3 sd = rd * sc;
		vec3 cell = floor(sd) + float(L) * 17.0;
		vec3 fp = fract(sd);
		vec3 r = h33(cell);
		float on = step(thr, h1(cell + 5.3));
		// position inside the cell, projected on the view plane
		vec3 sp = 0.25 + 0.5 * r;
		float d = length(fp - sp);
		float mag = pow(h1(cell + 11.7), 2.5);  // many faint, few bright
		float size = L == 2 ? 0.07 : 0.10;
		float core = exp(-pow(d / size, 2.0));
		float halo = exp(-d * 14.0) * 0.12;
		float tw = 0.78 + 0.22 * sin(TIME * (1.5 + 3.0 * r.x) + r.y * 60.0);
		float b = (core + halo) * mag * tw;
		b *= (L == 0 ? 0.45 : (L == 1 ? 0.9 : 1.6));
		// temperature: blue-white .. yellow-orange
		float t = h1(cell + 2.2);
		vec3 tint = t < 0.55 ? vec3(0.78, 0.88, 1.0) : (t < 0.85 ? vec3(1.0, 0.97, 0.9) : vec3(1.0, 0.78, 0.58));
		col += tint * b * on;
		// diffraction spikes on the brightest few
		if (L == 2 && mag > 0.45) {
			vec2 e = fp.xy - sp.xy;
			float sx = exp(-abs(e.y) * 90.0) * exp(-abs(e.x) * 11.0);
			float sy = exp(-abs(e.x) * 90.0) * exp(-abs(e.y) * 11.0);
			col += tint * (sx + sy) * mag * 0.5 * on * tw;
		}
	}
	return col;
}

vec3 milky(vec3 rd) {
	vec3 n = normalize(vec3(0.55, 0.62, -0.55));
	float s = dot(rd, n);
	float band = exp(-pow(s / 0.17, 2.0));
	float core = exp(-pow(s / 0.06, 2.0));
	float cloud = fbm(rd * 5.0, 5);
	float fine = fbm(rd * 22.0 + 4.0, 3);
	float dust = smoothstep(0.42, 0.62, fbm(rd * 9.0 + 7.0, 4));
	float dens = band * (0.35 + 0.9 * cloud) * (1.0 - 0.7 * dust * core) + core * 0.4 * fine;
	vec3 c = mix(vec3(0.34, 0.40, 0.58), vec3(0.62, 0.52, 0.42), clamp(core * cloud * 1.5, 0.0, 1.0));
	return c * dens * 0.075;
}

vec3 moon_layer(vec3 rd) {
	vec3 M = normalize(MOON_DIR);
	vec3 T = normalize(cross(vec3(0.0, 1.0, 0.0), M));
	vec3 B = cross(M, T);
	float md = dot(rd, M);
	float ang = acos(clamp(md, -1.0, 1.0));
	vec3 col = vec3(0.0);

	// halo + corona ring (physically: glow falls off ~1/ang, plus aureole ring)
	float a = ang / MOON_R;
	col += vec3(0.50, 0.62, 0.95) * 0.20 / (1.0 + pow(a * 0.9, 2.0) * 1.2);
	col += vec3(0.45, 0.58, 1.0) * exp(-ang * 8.0) * 0.30;
	col += vec3(0.30, 0.42, 0.85) * exp(-ang * 2.6) * 0.10;
	float ring = exp(-pow((ang - 0.215) / 0.045, 2.0));
	vec3 ringc = mix(vec3(0.55, 0.75, 1.0), vec3(1.0, 0.8, 0.6), smoothstep(0.17, 0.26, ang));
	col += ringc * ring * 0.028 * (0.7 + 0.3 * n3(rd * 40.0));

	// disc
	vec3 dv = rd - M * md;
	vec2 uv = vec2(dot(dv, T), dot(dv, B)) / (md * MOON_R); // approx tangent plane coords
	float r2 = dot(uv, uv);
	float aa = 1.0 - smoothstep(0.985, 1.005, sqrt(r2));
	if (r2 < 1.1) {
		float z = sqrt(max(1.0 - r2, 0.0));
		vec3 nrm = vec3(uv, z);
		// selenographic position (fixed to the rock, not the view)
		vec3 sp = vec3(uv.x * 0.9 + 0.3, uv.y * 0.9 - 0.2, z * 0.9) * 1.0 + vec3(3.1, 1.3, 2.2);

		float warp = fbm(sp * 2.2, 3);
		float mare = fbm(sp * 1.7 + warp * 1.2, 5);
		float maria = smoothstep(0.50, 0.60, mare);
		float fine = fbm(sp * 14.0, 4);
		float fine2 = n3(sp * 55.0);

		vec2 c1 = craters(sp, 3.0);
		vec2 c2 = craters(sp + 5.0, 7.0);
		vec2 c3 = craters(sp + 11.0, 16.0);
		float bowl = c1.x * 0.5 + c2.x * 0.4 + c3.x * 0.3;
		float rim = c1.y * 0.5 + c2.y * 0.4 + c3.y * 0.3;

		vec3 highland = vec3(0.80, 0.78, 0.73);
		vec3 marec = vec3(0.34, 0.36, 0.38);
		vec3 alb = mix(highland, marec, maria * 0.9);
		alb *= 0.85 + 0.3 * fine;
		alb *= 1.0 - 0.18 * fine2 * (1.0 - maria);
		alb *= 1.0 - 0.28 * clamp(bowl, 0.0, 1.0) * (0.5 + 0.5 * maria);
		alb += vec3(0.9, 0.9, 0.85) * rim * 0.12 * (1.0 - maria * 0.6);

		// bright ray crater (Tycho-like) with radial rays
		vec2 tc = uv - vec2(-0.18, -0.58);
		float tr = length(tc);
		float ang2 = atan(tc.y, tc.x);
		float rays = pow(n3(vec3(ang2 * 3.2, 1.0, 2.0)) * 0.6 + n3(vec3(ang2 * 9.0, 3.0, 1.0)) * 0.4, 2.0);
		alb += vec3(1.0, 1.0, 0.95) * (rays * exp(-tr * 2.4) * 0.30 + exp(-tr * 22.0) * 0.45);
		// second ray crater (Copernicus-like) on the mare
		vec2 cc = uv - vec2(-0.12, 0.12);
		float cr = length(cc);
		alb += vec3(0.9) * (exp(-cr * 26.0) * 0.35 + exp(-cr * 6.0) * 0.06 * rays);

		// lighting: waxing gibbous, light from the right
		vec3 L = normalize(vec3(0.52, 0.12, 0.85));
		// fake relief from the albedo-derived noise for subtle shading near terminator
		vec3 rn = normalize(nrm + vec3(fine - 0.5, fbm(sp * 14.0 + 9.0, 3) - 0.5, 0.0) * 0.25 + vec3(rim - bowl * 0.6, 0.0, 0.0) * 0.08);
		float ndl = dot(rn, L);
		float lit = smoothstep(-0.05, 0.35, ndl);
		// lunar photometry: nearly Lambert-free (Lommel-Seeliger-like flat), opposition-brightened
		float mu0 = max(ndl, 0.0), mu = z;
		float ls = mu0 / (mu0 + mu + 0.02);
		float shade = mix(lit * 0.9, ls * 2.0, 0.5);
		float limb = mix(0.72, 1.0, smoothstep(0.0, 0.5, z));
		vec3 surf = alb * shade * limb * 1.9;
		// earthshine on the dark side
		surf += vec3(0.30, 0.36, 0.5) * alb * 0.045 * (1.0 - lit);
		// faint blue-warm tint so it feels photographed
		surf *= vec3(1.02, 1.0, 0.96);
		// a gentle roll-off so the brightest pixels sit just above bloom threshold
		col = col * (1.0 - aa) + surf * aa;
	}
	return col;
}

vec3 celestial(vec3 rd) {
	float y = clamp(rd.y, -1.0, 1.0);
	float ext = smoothstep(0.0, 0.22, y);  // atmospheric extinction near horizon
	vec3 col = vec3(0.0);
	col += stars(rd, y) * mix(0.0, 1.0, ext) * 0.9;
	col += milky(rd) * ext;
	// keep stars/galaxy away from the moon glare
	float md = dot(rd, normalize(MOON_DIR));
	float glare = smoothstep(0.04, 0.45, acos(clamp(md, -1.0, 1.0)));
	col *= mix(0.15, 1.0, glare);
	col += moon_layer(rd);
	return col * smoothstep(-0.02, 0.0, y);
}

void fragment() {
	vec2 p = (UV - 0.5) * vec2(aspect, 1.0) - look;
	vec3 rd = normalize(vec3(p.x, -p.y - 0.10, 0.95));
	COLOR = vec4(celestial(rd), 1.0);
}
