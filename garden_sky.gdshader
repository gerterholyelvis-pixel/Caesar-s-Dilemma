shader_type canvas_item;

// GARDEN SKY: twilight gradient, ringed planet, orbit-trap Julia filigree, far crystal islands, soft stars.
uniform float aspect = 1.5;
uniform vec2 look = vec2(0.0);
uniform float cam = 0.0;
uniform float span = 3.0;
uniform float par = 0.06;

float h11(float p) {
	p = fract(p * 0.1031); p *= p + 33.33; p *= p + p; return fract(p);
}
float h21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
vec3 hash3(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yxz + 33.33);
	return fract((p3.xxy + p3.yzz) * p3.zyx);
}

// triangle spire: apex at (0,-h), base half-width w at y=0; returns coverage
float spire(vec2 p, float h, float w, float aa) {
	float t = clamp(-p.y / h, 0.0, 1.0);
	float hw = w * (1.0 - t);
	float inside = 1.0 - smoothstep(hw - aa, hw + aa, abs(p.x));
	return inside * step(p.y, 0.0) * step(-h, p.y);
}

// one floating crystal island; returns vec2(coverage, shade)
vec2 island(vec2 p, float sz, float seed, float aa) {
	p /= sz;
	float a = aa / sz;
	float bw = 0.34 * (1.0 - clamp(p.y / 0.38, 0.0, 1.0));
	bw *= 1.0 + 0.12 * sin(p.y * 18.0 + seed * 7.0);
	float body = (1.0 - smoothstep(bw - a, bw + a, abs(p.x))) * step(0.0, p.y) * step(p.y, 0.38);
	float s = 0.0;
	float h0 = 0.42 + 0.3 * h11(seed + 1.3);
	float w0 = 0.07 + 0.03 * h11(seed + 2.1);
	float lean = (h11(seed + 3.7) - 0.5) * 0.2;
	vec2 q = p;
	q.x += lean * clamp(-q.y / h0, 0.0, 1.0);
	s = max(s, spire(q, h0, w0, a));
	s = max(s, spire(p - vec2(-0.17, 0.0), h0 * 0.52, w0 * 0.6, a));
	s = max(s, spire(p - vec2(0.15, 0.0), h0 * 0.38, w0 * 0.5, a));
	s = max(s, spire(p - vec2(0.26, 0.0), h0 * 0.2, w0 * 0.35, a));
	float cov = max(body, s);
	float shade = clamp(0.5 + p.x * 1.6 + (s > 0.5 ? 0.15 : -0.1), 0.0, 1.0);
	return vec2(cov, shade);
}

void fragment() {
	float X = (UV.x - 0.5) * aspect + cam * span * par - look.x * (0.4 + par);
	float Y = UV.y - look.y * (0.3 + 0.5 * par);
	vec2 P = vec2(X, Y);
	float aa = 1.5 / 1080.0;

	// gradient: deep teal-violet -> violet -> magenta haze -> warm amber
	vec3 cTop = vec3(0.020, 0.055, 0.115);
	vec3 cUp  = vec3(0.060, 0.115, 0.230);
	vec3 cMid = vec3(0.260, 0.150, 0.420);
	vec3 cLow = vec3(0.640, 0.300, 0.480);
	vec3 cHor = vec3(0.980, 0.640, 0.360);
	float y = clamp(Y, 0.0, 1.0);
	vec3 col = mix(cTop, cUp, smoothstep(0.0, 0.28, y));
	col = mix(col, cMid, smoothstep(0.22, 0.52, y));
	col = mix(col, cLow, smoothstep(0.46, 0.72, y));
	col = mix(col, cHor, smoothstep(0.66, 0.92, y));
	col += vec3(0.0, 0.10, 0.12) * smoothstep(0.6, 0.0, abs(Y - 0.3)) * 0.35;
	col += vec3(0.30, 0.14, 0.04) * exp(-pow(length(vec2((X - 0.45) * 0.7, (Y - 0.85))) * 2.2, 2.0));

	// stars
	{
		vec2 g = vec2(X, Y) * 38.0;
		vec2 id = floor(g);
		vec2 f = fract(g) - 0.5;
		vec3 r = hash3(id);
		vec2 o = (r.xy - 0.5) * 0.6;
		float d = length(f - o);
		float tw = 0.6 + 0.4 * sin(TIME * (0.6 + r.z * 1.5) + r.x * 40.0);
		float st = smoothstep(0.07, 0.0, d) * step(0.86, r.z) * tw;
		st *= smoothstep(0.55, 0.12, Y);
		col += vec3(0.8, 0.9, 1.0) * st * 0.9;
	}

	// Julia filigree: distance-estimated boundary lace (self-similar), thin glowing lines
	{
		vec2 z = (P - vec2(-0.30, 0.215)) * 2.7;
		z = vec2(z.x, -z.y);
		float t = TIME * 0.03;
		vec2 c = vec2(-0.79 + 0.015 * sin(t), 0.15 + 0.015 * cos(t * 1.3));
		vec2 dz = vec2(1.0, 0.0);
		float n = 0.0;
		float esc = 0.0;
		for (int i = 0; i < 22; i++) {
			dz = 2.0 * vec2(z.x * dz.x - z.y * dz.y, z.x * dz.y + z.y * dz.x);
			z = vec2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y) + c;
			if (dot(z, z) > 400.0) { esc = 1.0; break; }
			n += 1.0;
		}
		float r2 = dot(z, z);
		float de = esc > 0.5 ? 0.25 * sqrt(r2) * log(r2) / max(length(dz), 1e-6) : 0.0;
		float dpx = de / 2.7;
		float line = exp(-dpx * 420.0);
		float halo = exp(-dpx * 14.0) * 0.8 + exp(-dpx * 50.0) * 0.6;
		float mask = smoothstep(0.66, 0.08, Y) * smoothstep(-1.05, -0.35, X) * smoothstep(0.75, 0.15, X);
		float sm = n - log2(max(log(max(r2, 1.0001)) * 0.5, 1e-4));
		vec3 lc = mix(vec3(0.20, 0.85, 0.85), vec3(1.0, 0.72, 0.38), clamp(0.5 + 0.5 * sin(sm * 0.45 + Y * 5.0), 0.0, 1.0));
		col += mix(vec3(0.22, 0.10, 0.45), vec3(0.08, 0.40, 0.50), clamp(Y * 2.0, 0.0, 1.0)) * (esc > 0.5 ? halo : 0.9) * mask * 0.26;
		col += lc * line * mask * 0.7 * esc;
		
	}

	// ringed planet
	{
		vec2 pc = P - vec2(0.55, 0.255);
		float R = 0.135;
		float tilt = -0.28;
		float ct = cos(tilt);
		float st2 = sin(tilt);
		vec2 q = vec2(ct * pc.x - st2 * pc.y, st2 * pc.x + ct * pc.y);
		float dd = length(pc);
		col += vec3(0.55, 0.30, 0.75) * exp(-max(dd - R, 0.0) * 9.0) * 0.18;
		vec2 e = vec2(q.x, q.y / 0.22);
		float re = length(e);
		float ringIn = 0.19;
		float ringOut = 0.33;
		float ringA = smoothstep(ringIn - 0.004, ringIn + 0.004, re) * (1.0 - smoothstep(ringOut - 0.004, ringOut + 0.004, re));
		float bands = 0.55 + 0.45 * sin(re * 150.0) * sin(re * 41.0 + 1.0);
		float gap = smoothstep(0.0, 0.006, abs(re - 0.262) - 0.006);
		ringA *= gap * (0.55 + 0.45 * bands);
		bool front = q.y > 0.0;
		float s = 1.0 - smoothstep(R - aa, R + aa, dd);
		vec3 n = vec3(pc / R, 0.0);
		n.z = sqrt(max(1.0 - dot(n.xy, n.xy), 0.0));
		vec3 L = normalize(vec3(-0.7, -0.35, 0.65));
		float dif = clamp(dot(n, L), 0.0, 1.0);
		float band = 0.5 + 0.5 * sin(q.y / R * 3.2 + sin(q.x / R * 1.5 + 1.0) * 0.5);
		vec3 pCol = mix(vec3(0.38, 0.16, 0.55), vec3(0.96, 0.62, 0.42), band * 0.7 + 0.1);
		pCol = mix(pCol, vec3(0.20, 0.70, 0.75), smoothstep(0.6, 1.0, 0.5 + 0.5 * sin(q.y / R * 2.0 + 2.0)) * 0.2);
		vec3 lit = pCol * (0.08 + 1.05 * pow(dif, 0.9)) + vec3(0.30, 0.70, 0.95) * pow(1.0 - n.z, 3.0) * 0.45;
		float shadowBand = smoothstep(0.05, 0.0, abs(q.y + 0.035));
		lit *= 1.0 - 0.45 * shadowBand;
		vec3 ringCol = mix(vec3(0.95, 0.75, 0.6), vec3(0.55, 0.45, 0.85), smoothstep(0.19, 0.33, re));
		ringCol *= 0.75 + 0.5 * clamp(0.6 - q.x * 1.2, 0.0, 1.0);
		if (!front) col = mix(col, ringCol, ringA * 0.8);
		col = mix(col, lit, s);
		if (front) col = mix(col, ringCol, ringA * 0.9);
	}

	// small moon
	{
		vec2 mc = P - vec2(-0.62, 0.17);
		float r = 0.028;
		float d = length(mc);
		float s = 1.0 - smoothstep(r - aa, r + aa, d);
		vec3 n = vec3(mc / r, 0.0);
		n.z = sqrt(max(1.0 - dot(n.xy, n.xy), 0.0));
		float dif = clamp(dot(n, normalize(vec3(0.8, -0.3, 0.6))), 0.0, 1.0);
		col += vec3(0.5, 0.8, 0.9) * exp(-max(d - r, 0.0) * 45.0) * 0.12;
		col = mix(col, vec3(0.55, 0.85, 0.9) * (0.06 + dif), s);
	}

	// distant crystal islands in haze
	{
		for (int row = 0; row < 2; row++) {
			float depth = float(row);
			float scale = mix(1.0, 0.62, depth);
			float spacing = mix(0.95, 0.8, depth);
			float xo = X * mix(1.0, 0.9, depth) + depth * 0.37;
			float ci = floor(xo / spacing);
			for (int k = -1; k <= 1; k++) {
				float cid = ci + float(k);
				vec3 r = hash3(vec2(cid, depth + 7.0));
				
				float cx = (cid + 0.2 + 0.6 * r.x) * spacing;
				float cy = mix(0.30, 0.50, r.y) + depth * 0.045;
				cy += 0.02 * sin(TIME * 0.2 + cid * 3.0);
				vec2 pp = vec2(xo - cx, Y - cy);
				float sz = (0.17 + 0.09 * r.z) * scale;
				vec2 isl = island(pp, sz, cid * 1.7 + depth * 5.0, aa);
				if (isl.x > 0.001) {
					float hz = mix(0.62, 0.8, depth);
					vec3 ic = mix(vec3(0.12, 0.10, 0.28), vec3(0.95, 0.60, 0.50), isl.y * isl.y);
					ic = mix(ic, mix(vec3(0.28, 0.20, 0.45), vec3(0.75, 0.42, 0.50), smoothstep(0.3, 0.6, Y)), hz);
					col = mix(col, ic, isl.x * mix(0.95, 0.8, depth));
				}
			}
		}
		col = mix(col, vec3(0.95, 0.60, 0.45), smoothstep(0.50, 0.95, Y) * 0.28);
	}

	// tonemap + dither
	col = col / (1.0 + col * 0.18);
	col = pow(col, vec3(0.95));
	float dn = h21(FRAGCOORD.xy + fract(TIME) * 13.0) + h21(FRAGCOORD.xy * 1.37 + 9.1) - 1.0;
	col += dn / 255.0;
	COLOR = vec4(col, 1.0);
}
