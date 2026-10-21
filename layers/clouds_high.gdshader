shader_type canvas_item;

// LAYER: clouds_high (alpha-blended). Cirrus, mare's tails, mackerel altocumulus, horizon haze.

uniform float aspect = 1.5;
uniform vec2 look = vec2(0.0);

const vec3 MOON_DIR = vec3(-0.38, 0.42, 0.82);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
			   mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float a = 0.5, s = 0.0;
	mat2 r = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 5; i++) {
		s += a * vnoise(p);
		p = r * p * 2.03 + 7.1;
		a *= 0.5;
	}
	return s;
}

void fragment() {
	vec2 p = (UV - 0.5) * vec2(aspect, 1.0) - look;
	vec3 rd = normalize(vec3(p.x, -p.y - 0.10, 0.95));
	float y = rd.y;
	float t = TIME;

	vec3 moonc = vec3(0.62, 0.72, 1.0);
	float mdot = max(dot(rd, normalize(MOON_DIR)), 0.0);
	float moonGlow = pow(mdot, 24.0) * 0.8 + pow(mdot, 6.0) * 0.25;

	// ---- cloud plane projection (perspective foreshortening toward horizon)
	float yy = max(y, 0.012);
	vec2 q = rd.xz / yy;               // plane coordinates, compress near horizon
	q *= 0.55;
	q.x += t * 0.012;                  // slow drift
	float fade = smoothstep(0.0, 0.16, y);          // atmospheric perspective
	float lowfade = 1.0 - smoothstep(0.55, 0.95, y);

	// ---- cirrus: stretched, sheared, domain warped
	vec2 w = vec2(fbm(q * 0.7 + t * 0.004), fbm(q * 0.7 + 9.3 - t * 0.003));
	vec2 cq = q + (w - 0.5) * 1.4;
	cq = vec2(cq.x * 0.55 + cq.y * 0.35, cq.y * 3.2);   // streak along x with slant
	float c1 = fbm(cq * vec2(1.1, 1.0) + vec2(t * 0.01, 0.0));
	float fil = fbm(vec2(cq.x * 2.5 + cq.y * 0.6, cq.y * 9.0) + 3.7);
	float cirrus = smoothstep(0.42, 0.78, c1) * (0.35 + 0.9 * fil);
	// mare's tails: curved hooks falling downward
	vec2 tq = vec2(q.x * 0.9 + 0.6 * sin(q.y * 0.8), q.y * 0.35);
	float tails = smoothstep(0.50, 0.80, fbm(vec2(tq.x * 1.6, tq.y * 0.5 - tq.x * 0.4) * vec2(1.0, 4.0) + 21.0));
	tails *= smoothstep(0.45, 0.7, fbm(q * 0.35 + 40.0));
	cirrus = clamp(cirrus + tails * 0.5, 0.0, 1.0);

	// ---- altocumulus mackerel patches
	vec2 mq = q * vec2(1.6, 2.4) + (w - 0.5) * 1.2;
	float cells = fbm(mq * 2.6 + 11.0);
	float patch = smoothstep(0.50, 0.78, fbm(q * 0.28 + 70.0));
	float mack = smoothstep(0.50, 0.66, cells) * (1.0 - smoothstep(0.66, 0.92, cells) * 0.4) * patch;
	mack *= smoothstep(0.02, 0.22, y);

	float dens = clamp(cirrus * 0.85 + mack * 0.9, 0.0, 1.0);
	dens *= fade * lowfade;

	// ---- lighting: cool lavender body, moon-silvered edges, warm horizon tint
	float edge = clamp(dens - fbm(cq * 1.3 + 2.0 + vec2(0.0, 0.25)) * 0.8 + 0.3, 0.0, 1.0);
	vec3 body = vec3(0.30, 0.34, 0.58);
	vec3 warm = vec3(0.85, 0.50, 0.55);
	vec3 col = mix(body, warm, exp(-y * 9.0) * 0.8);
	col = mix(col, moonc * 1.0, clamp(moonGlow * 1.6 + edge * 0.18, 0.0, 1.0));
	col += moonc * 0.35 * pow(mdot, 40.0);
	float alpha = dens * 0.42;
	alpha *= 1.0 - 0.5 * smoothstep(0.985, 1.0, mdot) ; // keep moon disc readable
	alpha *= 0.7 + 0.5 * moonGlow;

	// ---- horizon haze: layered bands above, soft veil
	float hz = abs(y);
	float bandN = fbm(vec2(rd.x / yy * 0.35 + t * 0.01, y * 40.0));
	float hazeCore = exp(-pow(max(y, 0.0) / 0.055, 1.4));
	float hazeMid = exp(-max(y, 0.0) * 11.0);
	float layers = 0.55 + 0.45 * sin(y * 140.0 + bandN * 6.0);
	float haze = hazeCore * 0.50 + hazeMid * 0.18 * (0.6 + 0.8 * bandN);
	haze += exp(-pow(max(y - 0.05, 0.0) / 0.03, 2.0)) * 0.05 * layers;
	haze *= smoothstep(-0.03, 0.0, y) * 0.5 + 0.5;      // slightly into the deck
	haze *= 1.0 - smoothstep(-0.16, -0.02, -y) * 0.0;
	vec3 hazeCol = mix(vec3(0.62, 0.52, 0.72), vec3(0.95, 0.62, 0.62), exp(-max(y, 0.0) * 25.0));
	hazeCol = mix(hazeCol, moonc, moonGlow * 0.5);
	// below horizon the deck covers; fade out gently
	haze *= smoothstep(-0.12, 0.0, y);

	// composite (straight alpha): combine cirrus + haze
	float a = alpha + haze * (1.0 - alpha);
	vec3 c = (col * alpha + hazeCol * haze * (1.0 - alpha)) / max(a, 1e-4);
	float n = hash(FRAGCOORD.xy + t);
	a = clamp(a + (n - 0.5) / 255.0, 0.0, 0.9);
	COLOR = vec4(c, a);
}
