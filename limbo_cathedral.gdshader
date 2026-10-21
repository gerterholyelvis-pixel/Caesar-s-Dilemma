shader_type canvas_item;

// LIMBO - THE BONE CATHEDRAL. A drained ash plain running up a pale path to a colossal, half-collapsed
// gateway. Giant gothic ribs recede toward it in atmospheric perspective; chains hang from the dark.

uniform float aspect = 1.5;

const float HZ = 0.52;      // horizon height in UV
const float X0 = -0.15;     // nave axis in aspect-corrected x (uv.x = 0.40)

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(11.7, 4.3);
		a *= 0.5;
	}
	return v;
}

float fbm3(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(11.7, 4.3);
		a *= 0.5;
	}
	return v;
}

float edge(float x, float w) {
	return smoothstep(-w, w, x);
}

// pointed-arch signed distance (negative inside the opening). a = half width, R = arc radius, sp = spring height
float arch_sd(vec2 q, float a, float R, float sp) {
	return length(vec2(abs(q.x) - (a - R), max(q.y - sp, 0.0))) - R;
}

void fragment() {
	vec2 uv = UV;
	float t = TIME;
	float gx = (uv.x - 0.5) * aspect - X0;   // x relative to the nave axis
	float h = HZ - uv.y;                      // height above the horizon
	vec2 gp = vec2(gx, h);

	vec3 fogc = vec3(0.43, 0.46, 0.50);       // cold ash horizon haze
	vec3 lightc = vec3(1.0, 0.92, 0.78);     // the one accent: a pale, faintly warm light
	vec3 col;

	// ---------- sky ----------
	{
		float sy = clamp(h / HZ, 0.0, 1.0);
		vec3 top = vec3(0.035, 0.04, 0.055);
		col = mix(fogc * 0.9, top, pow(sy, 0.7));
		float f = fbm3(vec2(gx * 1.1 + t * 0.012, h * 3.2));
		col = mix(col, fogc * 0.55, smoothstep(0.35, 0.8, f) * 0.32 * (1.0 - sy * 0.6));
	}

	// ---------- ground ----------
	float dy = max(uv.y - HZ, 0.0);
	float isg = step(HZ, uv.y);
	vec3 gcol = fogc;
	if (uv.y > HZ) {
		float dyy = max(dy, 0.006);
		float z = 0.07 / dyy;
		vec2 xz = vec2(gx * z * 1.6, z + t * 0.12);
		float n = fbm(xz * 0.6);
		float crack = 1.0 - smoothstep(0.0, 0.035, abs(fbm3(xz * 1.4 + 3.0) - 0.5));
		vec3 ground = mix(vec3(0.07, 0.075, 0.09), vec3(0.34, 0.345, 0.36), smoothstep(0.25, 0.75, n));
		float crack2 = 1.0 - smoothstep(0.0, 0.02, abs(fbm3(xz * 3.2 + 7.0) - 0.5));
		ground *= (1.0 - crack * 0.8) * (1.0 - crack2 * 0.28);
		// wind-blown dust streaks, stretched along x
		float ds = fbm3(vec2(xz.x * 0.12 - t * 0.35, xz.y * 2.2));
		ground += vec3(0.30, 0.31, 0.33) * smoothstep(0.52, 0.85, ds) * 0.22;
		// the pale path of light leading to the gate
		float pw = 0.06 + dyy * 0.55;
		float warp = (noise(vec2(z * 2.0, 3.0)) - 0.5) * 0.03;
		float path = exp(-pow(abs(gx + warp) / pw, 2.0) * 1.2);
		ground = mix(ground, vec3(0.46, 0.47, 0.48) * (0.75 + 0.5 * n), path * 0.6);
		ground += lightc * path * 0.18 * exp(-dyy * 2.0);
		float fog = 1.0 - exp(-dyy * 6.0);
		gcol = mix(fogc, ground, clamp(fog, 0.0, 1.0));
		gcol += lightc * path * 0.30 * exp(-dyy * 5.0);
	}
	col = mix(col, gcol, isg);
	// ---------- the gateway (colossal, half collapsed) ----------
	vec2 g = gp / 1.8;
	// luminous haze behind it, so the ruin reads as a dark silhouette
	{
		vec2 d = vec2(g.x * 0.8, g.y - 0.14);
		float r = length(d) * 1.8;
		col += lightc * exp(-r * 2.6) * 0.34;
	}
	{
		float topc = 0.23 - max(g.x, 0.0) * 0.9 + (noise(vec2(g.x * 40.0, 1.0)) - 0.5) * 0.035 + (noise(vec2(g.x * 120.0, 7.0)) - 0.5) * 0.012 - 0.07 * smoothstep(0.55, 0.75, noise(vec2(g.x * 9.0, 3.0)));
		topc = max(topc, 0.10 + (noise(vec2(g.x * 30.0, 4.0)) - 0.5) * 0.03);
		float body = edge(0.21 - abs(g.x) + (noise(vec2(g.y * 45.0, 2.0)) - 0.5) * 0.014, 0.0015) * edge(topc - g.y, 0.0015);
		float tl = 0.36 + max(0.035 - abs(g.x + 0.175), 0.0) * 3.0;
		float towL = edge(0.035 - abs(g.x + 0.175), 0.0015) * edge(tl - g.y, 0.0015);
		float tr = 0.20 + (noise(vec2(g.x * 60.0, 9.0)) - 0.5) * 0.04;
		float towR = edge(0.035 - abs(g.x - 0.175), 0.0015) * edge(tr - g.y, 0.0015);
		float m = max(body, max(towL, towR)) * edge(g.y + 0.002, 0.0015);
		float od = arch_sd(g, 0.075, 0.15, 0.06);
		float open = edge(-od, 0.0015) * edge(g.y, 0.0015);
		float lq = arch_sd(vec2(abs(g.x) - 0.125, g.y - 0.05), 0.012, 0.026, 0.07);
		float lan = edge(-lq, 0.0012) * edge(g.y - 0.05, 0.0012) * edge(0.01 - abs(g.x) + 0.125, 0.0);
		float gl = max(open, lan * 0.85) * m;
		float mot = fbm3(gp * vec2(9.0, 14.0));
		vec3 gc = mix(vec3(0.04, 0.045, 0.065), vec3(0.14, 0.15, 0.18), mot);
		gc = mix(gc, fogc * 1.05, clamp(0.08 + 0.45 * exp(-max(gp.y, 0.0) * 4.0) + 0.6 * exp(-max(gp.y, 0.0) * 14.0), 0.0, 0.95));
		col = mix(col, gc, m * (1.0 - gl));
		float inner = mix(0.55, 1.05, smoothstep(0.3, 0.0, g.y)) * (0.7 + 0.3 * (1.0 - clamp(abs(g.x) / 0.08, 0.0, 1.0)));
		col = mix(col, lightc * inner * 1.7, gl);
	}
	// rays from the gate
	{
		vec2 d = vec2(g.x, g.y - 0.08);
		float r = length(d) * 1.8;
		float up = smoothstep(-0.1, 0.15, g.y);
		float ang = atan(d.x, d.y);
		float rays = noise(vec2(ang * 9.0, t * 0.04)) * 0.6 + noise(vec2(ang * 23.0, 5.0 - t * 0.03)) * 0.4;
		col += lightc * smoothstep(0.5, 0.95, rays) * exp(-r * 2.8) * 0.2 * up;
	}

	// ---------- the ribs: receding gothic arches ----------
	{
		const float F = 0.45;
		for (int k = 0; k < 5; k++) {
			float i = 3.0 - float(k);
			float s = pow(0.62, i);
			vec2 q = vec2(gp.x, gp.y) / s + vec2(0.0, F);
			float aa = 0.0016 / s;
			float side = step(0.0, q.x);
			float br = hash(vec2(i, side) + 3.1);
			float d = arch_sd(q, 0.40, 0.56, 0.15);
			d += (noise(q * 7.0 + i * 7.0) - 0.5) * 0.02;
			float ang = atan(q.y - 0.15, abs(q.x) - (0.40 - 0.56));
			float th = 0.03;
			float m = edge(d, aa) * (1.0 - edge(d - th, aa));
			// a second, thinner inner bone
			m = max(m, edge(d - 0.08, aa) * (1.0 - edge(d - 0.092, aa)) * 0.7);
			float u = fract(ang * 4.5 + i * 0.37);
			m *= smoothstep(0.0, 0.05, u) * (1.0 - smoothstep(0.95, 1.0, u) * 0.0);
			// collapsed crowns
			float cut = br > 0.5 ? 9.0 : mix(0.5, 1.0, br * 2.0);
			m *= 1.0 - edge(q.y - cut + (noise(vec2(q.x * 20.0, i)) - 0.5) * 0.12, 0.01);
			// feet dissolve into the mist
			m *= smoothstep(0.38, 0.62, q.y);
			float dep = clamp(i / 3.0, 0.0, 1.0);
			// atmospheric perspective: fog builds up between layers
			col = mix(col, fogc * 0.85, 0.10 * exp(-max(gp.y, 0.0) * 2.0) * step(0.0, i));
			vec3 rc = mix(vec3(0.03, 0.035, 0.05), fogc * 0.95, pow(dep, 0.75) * 0.92);
			float rim = (1.0 - smoothstep(0.0, th, d)) * smoothstep(0.1, 0.5, q.y);
			rc += lightc * rim * 0.12 * (0.3 + dep);
			col = mix(col, rc, m * 0.97);
		}
	}

	// ---------- hanging chains ----------
	{
		float cA = 0.0;
		for (int k = 0; k < 3; k++) {
			float kf = float(k);
			float N = 8.0 + 6.0 * kf;
			float cx = uv.x * aspect * N + kf * 13.7;
			float id = floor(cx);
			float fx = fract(cx) - 0.5;
			float hh = hash(vec2(id, kf + 5.0));
			float h2 = hash(vec2(id, kf + 9.0));
			float xo = (hh - 0.5) * 0.4 + 0.02 * sin(t * 0.35 + hh * 6.28) * uv.y;
			float w = (0.0030 + 0.0014 * (2.0 - kf)) * N / aspect;
			float line = 1.0 - smoothstep(w * 0.55, w, abs(fx - xo));
			float len = 0.16 + 0.30 * h2;
			float ymask = 1.0 - smoothstep(len - 0.02, len, uv.y);
			float link = 0.55 + 0.45 * step(0.0, sin(uv.y * (330.0 - 60.0 * kf) + hh * 6.0));
			float on = step(0.42, hh);
			cA = max(cA, line * ymask * link * on * (0.6 - 0.13 * kf));
		}
		col = mix(col, vec3(0.04, 0.045, 0.06), cA);
		// the pale lantern on its chain, upper right
		vec2 lp = vec2((0.66 - 0.5) * aspect, 0.25);
		vec2 pa = vec2((uv.x - 0.5) * aspect, uv.y);
		float ld = length(pa - lp);
		float lch = (1.0 - smoothstep(0.0009, 0.0016, abs(pa.x - lp.x))) * step(uv.y, lp.y);
		col = mix(col, vec3(0.04, 0.045, 0.06), lch * 0.55);
		col += lightc * exp(-ld * 9.0) * 0.20;
		col = mix(col, lightc * 1.05, 1.0 - smoothstep(0.016, 0.024, ld));
	}

	// ---------- mist ----------
	{
		float m = fbm3(vec2(gx * 2.0 - t * 0.03, uv.y * 12.0 + t * 0.01));
		float band = exp(-abs(uv.y - HZ - 0.02) * 12.0);
		col = mix(col, fogc * 1.04, clamp(band * (0.35 + 0.5 * m), 0.0, 1.0));
		// glow behind where the angel stands, lifting the mist around it
		vec2 ap = vec2(0.40, 0.68);
		vec2 dd = (uv - ap) * vec2(aspect, 1.0);
		col += vec3(0.34, 0.35, 0.37) * exp(-dot(dd, dd) * 14.0) * 0.30;
	}

	// ---------- grade ----------
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(lum), col, 0.58);
	col = 1.0 - exp(-col * 1.4);
	vec2 q2 = uv - 0.5;
	col *= 1.0 - dot(q2, q2) * 0.9;
	float dn = hash(FRAGCOORD.xy + fract(TIME) * 61.0);
	col += (dn - 0.5) / 120.0;
	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
