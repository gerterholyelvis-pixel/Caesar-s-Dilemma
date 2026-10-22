shader_type canvas_item;

// GARDEN SKY (realistic pass): Rayleigh/Mie-style dusk gradient, lit volumetric-looking cloud decks,
// physical sun, textured moon + ringed gas giant lit from the sun side, stars, faint Julia aurora,
// hazy ridge landforms with aerial perspective. Output linear-ish, well exposed.
uniform float aspect = 1.5;
uniform vec2 look = vec2(0.0);
uniform float cam = 0.0;
uniform float span = 3.0;
uniform float par = 0.06;

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
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a = h21(i);
	float b = h21(i + vec2(1.0, 0.0));
	float c = h21(i + vec2(0.0, 1.0));
	float d = h21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
const mat2 ROT = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
float fbm5(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		s += a * vnoise(p);
		p = ROT * p * 2.03 + 11.7;
		a *= 0.5;
	}
	return s;
}
float fbm3(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		s += a * vnoise(p);
		p = ROT * p * 2.07 + 5.3;
		a *= 0.5;
	}
	return s;
}

// sky colour by altitude a (0 horizon .. 1 zenith) and angular distance to sun
vec3 skyBase(float a, float sd, vec2 sdir) {
	vec3 zen = vec3(0.030, 0.060, 0.170);
	vec3 mid = vec3(0.090, 0.150, 0.330);
	vec3 tea = vec3(0.220, 0.330, 0.450);
	vec3 pnk = vec3(0.700, 0.420, 0.480);
	vec3 hor = vec3(0.980, 0.600, 0.320);
	vec3 c = mix(hor, pnk, smoothstep(0.0, 0.10, a));
	c = mix(c, tea, smoothstep(0.07, 0.26, a));
	c = mix(c, mid, smoothstep(0.22, 0.55, a));
	c = mix(c, zen, smoothstep(0.50, 1.0, a));
	float m = exp(-sd * 3.0) * 0.50 + exp(-sd * 10.0) * 0.55 + exp(-sd * 36.0) * 0.8;
	c += vec3(1.0, 0.55, 0.22) * m * 0.55;
	float anti = clamp(0.5 - sdir.x * 0.9, 0.0, 1.0);
	c += vec3(0.20, 0.09, 0.24) * anti * smoothstep(0.55, 0.0, a) * 0.5;
	return c;
}

void fragment() {
	float X = (UV.x - 0.5) * aspect + cam * span * par - look.x * (0.4 + par);
	float Y = UV.y - look.y * (0.3 + 0.5 * par);
	vec2 P = vec2(X, Y);
	float aa = 1.5 / 1080.0;

	const vec2 SUN = vec2(-0.40, 0.50);
	float horizonY = 0.74;
	float alt = clamp((horizonY - Y) / horizonY, 0.0, 1.0);
	vec2 sv = P - SUN;
	float sd = length(vec2(sv.x, sv.y * 1.25));
	vec3 sunCol = vec3(1.0, 0.62, 0.30);

	vec3 col = skyBase(alt, sd, sv);

	// ---------- stars ----------
	float night = smoothstep(0.35, 0.85, alt);
	{
		vec2 g = P * 70.0;
		vec2 id = floor(g);
		vec2 f = fract(g) - 0.5;
		vec3 r = hash3(id);
		vec2 o = (r.xy - 0.5) * 0.7;
		float d = length(f - o);
		float mag = pow(r.z, 14.0);
		float tw = 0.85 + 0.15 * sin(TIME * (1.0 + r.x * 3.0) + r.y * 60.0);
		float s = exp(-d * d * 90.0) * step(0.93, r.z) * (0.10 + 0.6 * mag * 3.0) * tw;
		vec3 sc = mix(vec3(0.7, 0.8, 1.0), vec3(1.0, 0.85, 0.65), r.x);
		col += sc * s * night * 0.9;
		vec2 mp = vec2(P.x * 0.7 + P.y * 0.5, P.y * 0.7 - P.x * 0.5);
		float band = exp(-pow(mp.y - 0.05, 2.0) * 18.0);
		col += vec3(0.30, 0.34, 0.50) * band * max(fbm3(P * 14.0) - 0.30, 0.0) * 0.25 * night;
	}

	// ---------- faint Julia nebula / aurora ----------
	{
		vec2 z = (P - vec2(-0.05, 0.22)) * 2.5;
		z = vec2(z.x, -z.y);
		float t = TIME * 0.02;
		vec2 c = vec2(-0.79 + 0.012 * sin(t), 0.15 + 0.012 * cos(t * 1.3));
		vec2 dz = vec2(1.0, 0.0);
		float esc = 0.0;
		float n = 0.0;
		for (int i = 0; i < 18; i++) {
			dz = 2.0 * vec2(z.x * dz.x - z.y * dz.y, z.x * dz.y + z.y * dz.x);
			z = vec2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y) + c;
			if (dot(z, z) > 400.0) { esc = 1.0; break; }
			n += 1.0;
		}
		float r2 = dot(z, z);
		float de = esc > 0.5 ? 0.25 * sqrt(r2) * log(r2) / max(length(dz), 1e-6) / 2.5 : 0.0;
		float mask = smoothstep(0.55, 0.05, Y) * smoothstep(-0.9, -0.2, X) * smoothstep(0.9, 0.3, X);
		float soft = exp(-de * 22.0) * esc;
		float fine = exp(-de * 260.0) * esc;
		float grain = 0.6 + 0.8 * fbm3(P * 9.0 + TIME * 0.01);
		vec3 aur = mix(vec3(0.05, 0.50, 0.42), vec3(0.35, 0.18, 0.60), clamp(Y * 1.8 + 0.2 * sin(n), 0.0, 1.0));
		col += aur * (soft * 0.10 + fine * 0.10) * grain * mask * night;
	}

	// ---------- sun ----------
	{
		float R = 0.020;
		float d = length(sv);
		float disc = 1.0 - smoothstep(R - aa * 1.5, R + aa * 1.5, d);
		float mu = sqrt(max(1.0 - (d / R) * (d / R), 0.0));
		vec3 limb = vec3(1.0, 0.80, 0.50) * (0.55 + 0.45 * pow(mu, 0.6));
		col = mix(col, limb * 2.2, disc);
		col += sunCol * exp(-max(d - R, 0.0) * 22.0) * 0.45;
		col += vec3(1.0, 0.5, 0.2) * exp(-abs(sv.y) * 38.0) * exp(-abs(sv.x) * 2.2) * 0.12;
	}

	// ---------- moon ----------
	{
		vec2 mc = P - vec2(0.02, 0.10);
		float r = 0.030;
		float d = length(mc);
		col += vec3(0.45, 0.60, 0.75) * exp(-max(d - r, 0.0) * 26.0) * 0.10 * night;
		if (d < r + 0.004) {
			float s = 1.0 - smoothstep(r - aa, r + aa, d);
			vec3 n = vec3(mc / r, 0.0);
			n.z = sqrt(max(1.0 - dot(n.xy, n.xy), 0.0));
			float tex = fbm5(mc * 160.0 + 3.0);
			float crater = smoothstep(0.40, 0.62, vnoise(mc * 260.0));
			vec3 nn = normalize(n + vec3(tex - 0.5, tex - 0.5, 0.0) * 0.5);
			vec3 L = normalize(vec3(-0.85, 0.15, 0.5));
			float dif = clamp(dot(nn, L), 0.0, 1.0);
			float alb = 0.55 + 0.35 * tex - 0.12 * crater;
			vec3 mcol = vec3(0.80, 0.78, 0.74) * alb * (0.015 + 1.1 * dif) + vec3(0.05, 0.08, 0.13) * (1.0 - dif) * 0.5;
			col = mix(col, mcol, s);
		}
	}

	// ---------- ringed gas giant ----------
	{
		vec2 pc = P - vec2(0.55, 0.255);
		float R = 0.130;
		float tilt = -0.26;
		float ct = cos(tilt);
		float st2 = sin(tilt);
		vec2 q = vec2(ct * pc.x - st2 * pc.y, st2 * pc.x + ct * pc.y);
		float dd = length(pc);
		if (dd < 0.40) {
			col += vec3(0.35, 0.28, 0.55) * exp(-max(dd - R, 0.0) * 14.0) * 0.10;
			vec2 e = vec2(q.x, q.y / 0.21);
			float re = length(e);
			float ringIn = 0.18;
			float ringOut = 0.335;
			float ringA = smoothstep(ringIn - 0.003, ringIn + 0.003, re) * (1.0 - smoothstep(ringOut - 0.003, ringOut + 0.003, re));
			float rn = vnoise(vec2(re * 420.0, 1.7)) * 0.5 + vnoise(vec2(re * 1100.0, 8.1)) * 0.3 + 0.2 * vnoise(vec2(re * 90.0, 3.3));
			float cassini = smoothstep(0.004, 0.0, abs(re - 0.262) - 0.005);
			ringA *= (0.25 + 0.95 * rn) * (1.0 - 0.85 * cassini);
			ringA *= smoothstep(ringIn, ringIn + 0.02, re) * 0.9;
			vec2 ld = normalize(vec2(-0.95, 0.30));
			vec2 ee = e * vec2(1.0, 0.21);
			float along = dot(ee, ld);
			float across = abs(dot(ee, vec2(-ld.y, ld.x)));
			float shadow = (along < 0.0) ? smoothstep(R * 1.02, R * 0.90, across) : 0.0;
			vec3 ringCol = mix(vec3(0.78, 0.66, 0.52), vec3(0.50, 0.46, 0.55), smoothstep(0.18, 0.33, re));
			ringCol *= (0.35 + 0.8 * rn) * (1.0 - 0.9 * shadow) * 0.9;
			bool front = q.y > 0.0;
			float s = 1.0 - smoothstep(R - aa, R + aa, dd);
			vec3 n = vec3(pc / R, 0.0);
			n.z = sqrt(max(1.0 - dot(n.xy, n.xy), 0.0));
			vec3 L = normalize(vec3(-0.85, -0.05, 0.50));
			float dif = clamp(dot(n, L), 0.0, 1.0);
			float lat = q.y / R;
			float turb = fbm3(vec2(q.x / R * 2.2, lat * 9.0) + vec2(0.0, 2.0));
			float bandv = 0.5 + 0.5 * sin(lat * 11.0 + turb * 5.0);
			bandv = mix(bandv, vnoise(vec2(q.x / R * 3.0 + turb * 3.0, lat * 18.0)), 0.35);
			vec3 pa = vec3(0.62, 0.40, 0.34);
			vec3 pb = vec3(0.78, 0.66, 0.52);
			vec3 pc2 = vec3(0.34, 0.38, 0.46);
			vec3 pCol = mix(mix(pa, pb, bandv), pc2, smoothstep(0.5, 1.0, abs(lat)) * 0.65);
			float term = smoothstep(-0.05, 0.40, dot(n, L));
			vec3 lit = pCol * (0.012 + 1.15 * term);
			float rim = pow(1.0 - n.z, 3.0);
			lit += vec3(0.45, 0.60, 0.95) * rim * (0.10 + 0.5 * dif);
			lit *= 1.0 - 0.5 * smoothstep(0.06, 0.0, abs(lat + 0.12 * n.x + 0.04));
			if (!front) col = mix(col, ringCol, ringA);
			col = mix(col, lit, s);
			if (front) col = mix(col, ringCol, ringA);
		}
	}

	// ---------- cloud decks ----------
	{
		float dist = max(horizonY + 0.12 - Y, 0.02);
		vec2 cp = vec2(P.x * 0.85, 0.62 / dist);
		float wind = TIME * 0.0035;
		vec2 cq = cp * 2.2 + vec2(wind, 0.0);
		float base = fbm5(cq + vec2(0.0, 3.1));
		float big = fbm3(cq * 0.35 + 7.0);
		float cov = smoothstep(0.28, 0.60, big) * 0.8 + 0.3;
		float lo = 0.50 - cov * 0.20;
		float hi = 0.82 - cov * 0.15;
		float dens = smoothstep(lo, hi, base);
		vec2 sdp = normalize(vec2(-1.0, -0.35));
		float dens2 = smoothstep(lo, hi, fbm3(cq + sdp * 0.17 + vec2(0.0, 3.1)));
		float dens3 = smoothstep(lo, hi, vnoise(cq * 1.7 + sdp * 0.4 + 9.0));
		float occl = clamp(dens2 * 1.6 + dens3 * 0.5 - dens * 0.4, 0.0, 1.0);
		float shadow = exp(-occl * 1.6);
		float sunProx = exp(-sd * 2.2);
		vec3 lightC = mix(vec3(1.0, 0.70, 0.45), vec3(0.95, 0.62, 0.62), smoothstep(0.1, 0.8, alt));
		lightC = mix(lightC, vec3(0.70, 0.76, 0.95), smoothstep(0.45, 0.9, alt) * 0.75);
		vec3 shadeC = vec3(0.20, 0.19, 0.38) + skyBase(alt, 9.0, sv) * 0.30;
		vec3 cc = mix(shadeC, lightC, shadow);
		float thin = clamp(dens - dens2 * 0.9, 0.0, 1.0);
		cc += vec3(1.0, 0.82, 0.55) * thin * sunProx * 1.1;
		cc *= 0.82 + 0.35 * vnoise(cq * 6.0);
		float alpha = dens * 0.88;
		float hfade = smoothstep(0.0, 0.10, alt) * 0.9 + 0.1;
		alpha *= smoothstep(0.74, 0.50, Y) * hfade;
		alpha *= mix(1.0, 0.55, smoothstep(0.6, 1.0, alt));
		cc = mix(cc, skyBase(alt, sd, sv) * 1.1, smoothstep(0.25, 0.0, alt) * 0.7);
		col = mix(col, cc, alpha);
	}

	// ---------- distant ridges with aerial perspective ----------
	{
		vec3 haze = skyBase(0.01, sd, sv) * 1.05 + vec3(0.04, 0.02, 0.05);
		for (int row = 0; row < 3; row++) {
			float rf = float(row);
			float xo = X * mix(1.0, 0.8, rf * 0.5) + rf * 13.0;
			float f0 = 1.6 + rf * 0.9;
			float h = fbm5(vec2(xo * f0, rf * 5.0 + 2.0));
			float ridge = 1.0 - abs(vnoise(vec2(xo * f0 * 2.3, rf * 3.0)) * 2.0 - 1.0);
			float top = 0.640 + rf * 0.045 - (h * 0.16 + ridge * 0.05) * (1.0 - rf * 0.2);
			float below = Y - top;
			float m = smoothstep(-aa * 1.5, aa * 1.5, below);
			if (m > 0.0) {
				float h2 = fbm3(vec2((xo + 0.003) * f0, rf * 5.0 + 2.0));
				float slope = clamp((h2 - fbm3(vec2(xo * f0, rf * 5.0 + 2.0))) * 6.0, -1.0, 1.0);
				float hazeAmt = mix(0.80, 0.32, rf * 0.5);
				float tex = 0.7 + 0.6 * fbm3(vec2(xo * 40.0, Y * 40.0));
				vec3 rock = vec3(0.10, 0.10, 0.19) * tex;
				rock += sunCol * clamp(-slope, 0.0, 1.0) * 0.20 * exp(-sd * 1.0);
				vec3 hz = mix(haze, vec3(0.38, 0.36, 0.60), 0.55 - rf * 0.25); vec3 rc = mix(rock, hz, hazeAmt);
				vec3 mist = vec3(0.30, 0.26, 0.40) + sunCol * 0.30 * exp(-sd * 1.6);
				rc = mix(rc, mist, smoothstep(0.0, 0.12 + 0.03 * rf, below) * 0.65);
				col = mix(col, rc, m);
			}
		}
	}

	col += vec3(0.40, 0.22, 0.16) * smoothstep(0.62, 0.84, Y) * 0.35;

	col = col / (1.0 + col * 0.12);
	float dn = h21(FRAGCOORD.xy + fract(TIME) * 13.0) + h21(FRAGCOORD.xy * 1.37 + 9.1) - 1.0;
	col += dn / 255.0;
	COLOR = vec4(max(col, vec3(0.0)), 1.0);
}
