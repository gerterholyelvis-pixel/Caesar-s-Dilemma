shader_type canvas_item;
render_mode blend_disabled;

// THE FALL: analytic pseudo-3D chasm. A noise-displaced cylinder of rock around the camera axis (narrow throat that opens into a vast
// chasm), carved at six "vista" stations with readable gothic hell architecture: bone cathedral, furnace arcade, colossal face,
// burning cathedral facade, shattered stairway + broken bridge, lava-spouting gargoyle. Two mid-air cylinders carry hanging
// chains, hooks and cages as lit silhouettes. Ray-marched smoke volume, smoke banks, a lake of fire far below.

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform float T = 0.0;
uniform float camY = 0.0;
uniform float phi = -1.3;       // pitch: -pi/2 looks up, +pi/2 looks straight down
uniform float yaw = 0.0;
uniform float roll = 0.0;
uniform float fl = 0.8;
uniform vec2 res = vec2(960.0, 640.0);
uniform vec2 cam_off = vec2(0.0);
uniform vec2 shake = vec2(0.0);
uniform float heat = 0.0;
uniform float fogd = 0.03;
uniform float fog_extra = 0.0;
uniform float ceilY = 690.0;
uniform float floorY = 920.0;
uniform float lake = 1.0;
uniform float expo = 1.0;
uniform float limbo_light = 1.0;
uniform float smoke_amt = 0.6;
uniform float flash = 0.0;
uniform float chain_amt = 0.0;
uniform float vY[6];
uniform float vA[6];

const float R0 = 15.0;
const float RV = 46.0;

float h21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
vec2 h22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float R_at(float Y) {
	return mix(R0, RV, smoothstep(55.0, 125.0, Y));
}

float M(float d) { return smoothstep(0.5, -0.5, d); }

float sbox(vec2 p, vec2 b) {
	vec2 d = abs(p) - b;
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

// pointed arch, y up. half span w, centre offset c (depressed when c < w), springing line at ys. Open below.
float arch(vec2 p, float w, float c, float ys) {
	float t = max(length(p - vec2(-c, ys)), length(p - vec2(c, ys))) - (w + c);
	return p.y > ys ? t : abs(p.x) - w;
}

// ---------------------------------------------------------------- vista reliefs (p.x arc length, p.y up) -----
// pr = protrusion toward the camera, feat = emissive, halo = warm light wash, bone = pale bone/limestone material
void v_ribs(vec2 p, float n, inout float pr, inout float feat, inout float halo, inout float bone) {
	float dO = arch(p, 30.0, 9.0, -14.0);
	float dI = dO + 4.5;
	float frame = M(dO) * (1.0 - M(dI));
	float inside = M(dI);
	float ax = abs(p.x);
	float spine = M(ax - (2.4 + 0.8 * sin(p.y * 0.85))) * inside;
	float q = (p.y + 0.30 * ax + 0.011 * ax * ax) / 11.0;
	float cell = floor(q);
	float dyv = (fract(q) - 0.5) * 11.0;
	float hr = h21(vec2(cell, p.x > 0.0 ? 1.0 : 2.0));
	float th = 2.6 * (1.0 - 0.5 * ax / 27.0);
	float tube = sqrt(clamp(1.0 - (dyv / th) * (dyv / th), 0.0, 1.0));
	float reach = 15.0 + 11.0 * hr;
	float rib = tube * smoothstep(2.4, 4.0, ax) * (1.0 - smoothstep(reach - 2.0, reach, ax)) * inside * step(0.08, hr);
	pr += frame * 5.0 - inside * 4.5 + max(spine * 11.0, rib * 10.0);
	bone = max(bone, max(frame, max(spine, rib)));
	feat += inside * (1.0 - max(spine, rib)) * 0.10 * (0.5 + n);
	halo += inside * (1.0 - 0.6 * rib);
}

void v_furn(vec2 p, float n, inout float pr, inout float feat, inout float halo, inout float bone) {
	float kk = round(p.x / 22.0);
	float lx = p.x - kk * 22.0;
	float dW = arch(vec2(lx, p.y), 7.5, 2.5, 4.0);
	float on = step(abs(kk), 1.0) * step(-20.0, p.y);
	float hole = M(dW) * on;
	float frame = M(dW - 3.0) * (1.0 - M(dW)) * on;
	float bars = step(abs(fract(lx * 0.62 + 0.5) - 0.5), 0.10);
	float fl_ = 0.75 + 0.35 * sin(T * 7.0 + p.y * 0.4 + kk * 4.0) * n;
	pr += frame * 6.0 - hole * 8.0 + hole * bars * 6.0;
	bone = max(bone, frame * 0.4);
	feat += hole * (1.0 - bars) * (0.9 + 0.9 * smoothstep(8.0, -20.0, p.y)) * fl_ * 1.2;
	halo += hole * 1.1 + M(dW - 9.0) * on * 0.5;
}

void v_face(vec2 p, float n, inout float pr, inout float feat, inout float halo, inout float bone) {
	float dO = arch(p, 26.0, 8.0, -4.0);
	float dI = dO + 3.0;
	float frame = M(dO) * (1.0 - M(dI));
	float inside = M(dI);
	vec2 s = vec2(p.x / 17.0, (p.y + 1.0) / 21.0);
	float wx = 0.80 * (1.0 - 0.42 * smoothstep(-0.05, -0.95, s.y));
	float e = (s.x / wx) * (s.x / wx) + (s.y / 0.98) * (s.y / 0.98);
	float plate = smoothstep(1.0, 0.92, e);
	float yb = 0.36 + 0.5 * abs(s.x);
	float brow = smoothstep(0.13, 0.03, abs(s.y - yb)) * smoothstep(0.80, 0.62, abs(s.x));
	vec2 ep = vec2(abs(s.x) - 0.34, s.y - 0.22);
	vec2 ee = ep / vec2(0.21, 0.12);
	float EQ = dot(ee, ee);
	float eye = smoothstep(1.0, 0.75, EQ);
	float eyecore = smoothstep(0.6, 0.0, EQ);
	vec2 np = vec2(s.x / 0.075, (s.y + 0.14) / 0.17);
	float nose = smoothstep(1.0, 0.7, dot(np, np));
	float bridge = smoothstep(0.07, 0.02, abs(s.x)) * smoothstep(-0.05, 0.1, s.y) * smoothstep(0.45, 0.3, s.y);
	vec2 mp = vec2(s.x / 0.34, (s.y + 0.60) / 0.23);
	float mouth = smoothstep(1.0, 0.8, dot(mp, mp));
	float xt = min(abs(s.x) / 0.34, 1.0);
	float cap = 0.23 * sqrt(max(1.0 - xt * xt, 0.0));
	float tri = abs(fract(s.x * 9.0) - 0.5) * 2.0;
	float tl = 0.13 * (1.0 - tri);
	float teeth = max(step(-0.60 + cap - tl, s.y) * step(0.0, s.y + 0.60), step(s.y, -0.60 - cap + tl * 0.8) * step(s.y + 0.60, 0.0)) * mouth;
	vec2 cp = vec2(abs(s.x) - 0.52, (s.y + 0.10) / 1.3);
	float cheek = smoothstep(0.2, 0.0, length(cp));
	float hx = abs(s.x);
	float ht = clamp((hx - 0.62) / 0.55, 0.0, 1.0);
	float hyc = 0.50 + 0.68 * ht;
	float hth = 0.17 * (1.0 - ht * 0.9);
	float horn = smoothstep(hth, hth * 0.5, abs(s.y - hyc)) * smoothstep(0.58, 0.64, hx) * smoothstep(1.22, 1.14, hx);
	float crack = smoothstep(0.016, 0.0, abs(s.x - 0.07 * sin(s.y * 11.0) - 0.03)) * smoothstep(0.38, 0.5, s.y) * plate;
	pr += frame * 3.0 - inside * 4.0 + plate * 9.0 + brow * 3.5 + cheek * 3.0 + bridge * 2.0 + horn * 7.0 * inside
		- eye * 9.0 - nose * 6.0 - mouth * 12.0 + teeth * 9.0 - crack * 2.0;
	bone = max(bone, max(max(plate, horn), frame * 0.5));
	feat += eyecore * 4.0 * (0.85 + 0.25 * sin(T * 3.0)) + mouth * (1.0 - teeth) * (0.4 + 0.9 * smoothstep(-0.2, -0.9, s.y)) + crack * 0.9 + teeth * mouth * 0.25;
	halo += exp(-EQ * 0.5) * 0.45 + mouth * 0.7 + inside * 0.2;
}

void v_facade(vec2 p, float n, inout float pr, inout float feat, inout float halo, inout float bone) {
	float u = p.x / 12.0;
	float pierd = abs(fract(u) - 0.5) * 12.0;
	float inx = step(abs(p.x), 42.0);
	float topw = 1.9 * clamp(1.0 - (p.y - 22.0) / 10.0, 0.0, 1.0);
	float pier = M(pierd - topw) * step(p.y, 33.0) * inx;
	float kk = round(p.x / 12.0);
	float lx = p.x - kk * 12.0;
	float ak = abs(kk);
	float dW = arch(vec2(lx, p.y), 3.9, 1.4, 5.0 - 3.2 * ak);
	float on = step(ak, 3.0) * step(-30.0, p.y);
	float win = M(dW) * on * inx;
	float wfr = M(dW - 1.4) * (1.0 - M(dW)) * on * inx;
	float mull = M(abs(lx) - 0.30) + M(abs(fract((p.y + 6.0) / 7.0) - 0.5) * 7.0 - 0.28);
	vec2 rp = p - vec2(0.0, 19.0);
	float rr = length(rp);
	float ang = atan(rp.y, rp.x);
	float ring = M(abs(rr - 8.6) - 1.1);
	float rin = M(rr - 7.5);
	float dsp = abs(fract(ang * 8.0 / TAU) - 0.5) * TAU * rr / 8.0;
	float spokes = M(dsp - 0.55) * rin * smoothstep(1.4, 2.0, rr);
	float hub = M(rr - 2.0);
	float rings2 = M(abs(rr - 4.6) - 0.35) * rin;
	float rosef = rin * (1.0 - clamp(spokes + hub + rings2, 0.0, 1.0));
	float corn = M(abs(p.y - 11.5) - 0.9) * inx;
	pr += pier * 6.0 + wfr * 2.0 - win * 5.0 + ring * 4.0 - rin * 5.0 + max(spokes, max(hub, rings2)) * 3.0 + corn * 3.5;
	bone = max(bone, 0.25 * pier);
	float wg = win * (1.0 - clamp(mull, 0.0, 1.0) * 0.9);
	feat += wg * (0.7 + 1.1 * smoothstep(0.0, -28.0, p.y)) * (0.8 + 0.4 * sin(T * 5.0 + kk * 3.0 + p.y * 0.3)) + rosef * 1.3 * (0.8 + 0.3 * n);
	halo += win * 0.9 + rin * 1.0;
}

void v_stairs(vec2 p, float n, inout float pr, inout float feat, inout float halo, inout float bone) {
	float inx = step(abs(p.x), 44.0);
	float notgap = 1.0 - M(abs(p.x - 13.0) - 4.5 - 2.0 * n);
	float deck = M(abs(p.y + 5.5) - 1.6) * inx * notgap;
	float posts = step(fract(p.x / 2.4), 0.36) * M(abs(p.y + 2.6) - 1.4) * inx * notgap;
	float rail = M(abs(p.y + 1.3) - 0.4) * inx * notgap;
	float fx = (fract(p.x / 14.0) - 0.5) * 14.0;
	float dA = arch(vec2(fx, p.y + 24.0), 4.8, 1.8, 6.0);
	float opening = M(dA) * step(-24.0, p.y);
	float body = step(-24.0, p.y) * step(p.y, -7.0) * inx * notgap;
	float arcade = body * (1.0 - opening);
	float s = floor((p.x + 40.0) / 3.4);
	float tread = -2.0 + 2.0 * s;
	float stair = step(0.0, s) * step(s, 9.0) * step(0.2, h21(vec2(s, 3.0))) * M(abs(p.y - (tread - 2.8)) - 2.8) * (1.0 - M(abs(fract((p.x + 40.0) / 3.4) - 0.5) * 3.4 - 1.65)) ;
	stair = step(0.0, s) * step(s, 9.0) * step(0.18, h21(vec2(s, 3.0))) * step(p.y, tread) * step(tread - 5.5, p.y);
	vec2 gp = p - vec2(20.0, -4.0);
	float dG = arch(gp, 9.0, 3.0, 14.0);
	float gate = M(dG) * step(0.0, gp.y);
	float gfr = M(dG - 2.6) * (1.0 - M(dG)) * step(0.0, gp.y);
	pr += (deck + arcade) * 8.0 + (posts + rail) * 8.0 - opening * 2.0 + stair * 6.0 + gfr * 7.0 - gate * 4.0;
	bone = max(bone, 0.2 * (deck + arcade));
	feat += gate * (0.9 + 0.8 * smoothstep(0.0, 20.0, gp.y)) * (0.8 + 0.4 * n) * 1.3;
	halo += gate * 1.4 + M(dG - 10.0) * 0.5;
}

void v_lava(vec2 p, float n, inout float pr, inout float feat, inout float halo, inout float bone) {
	vec2 mq = p - vec2(0.0, 17.0);
	float head = smoothstep(1.0, 0.9, length(mq / vec2(12.0, 8.5)));
	vec2 mo = (p - vec2(0.0, 15.0)) / vec2(6.4, 2.9);
	float mouth = smoothstep(1.0, 0.8, dot(mo, mo));
	float tri = abs(fract(p.x * 0.55) - 0.5) * 2.0;
	float fang = step(15.0 + 2.9 * sqrt(max(1.0 - (p.x / 6.4) * (p.x / 6.4), 0.0)) - 3.0 * (1.0 - tri), p.y) * mouth;
	vec2 e1 = vec2(abs(p.x) - 6.0, p.y - 21.0) / vec2(2.0, 1.1);
	float eyes = smoothstep(1.0, 0.5, dot(e1, e1));
	float brow = smoothstep(1.0, 0.0, abs(p.y - 23.2 - 0.35 * abs(p.x)) / 1.5) * smoothstep(12.0, 9.0, abs(p.x));
	float flow = 0.75 + 0.5 * sin(p.y * 0.9 + T * 5.5 + n * 6.0);
	float sx = p.x - 0.9 * sin(p.y * 0.12 + T * 0.3);
	float w0 = 3.0 + 0.05 * (14.0 - p.y);
	float stream = smoothstep(w0, w0 - 1.0, abs(sx)) * step(p.y, 14.5) * step(-8.8, p.y);
	float ledge = M(sbox(p - vec2(0.0, -10.5), vec2(17.0, 1.9)) - 1.0);
	float pool = M(abs(p.y + 8.2) - 0.5) * step(abs(p.x), 15.5);
	float sx2 = abs(p.x) - 11.0;
	float sx3 = abs(p.x);
	float s2 = smoothstep(2.4, 1.2, abs(sx2 - 0.8 * sin(p.y * 0.2 + T * 0.4))) * step(p.y, -9.0);
	float s3 = smoothstep(2.0, 0.8, sx3 - 0.5 * sin(p.y * 0.25 + 1.0)) * step(p.y, -9.0) * smoothstep(1.0, 3.0, abs(p.y + 9.0));
	float lower = max(s2, s3);
	pr += head * 10.0 - mouth * 8.0 + fang * 6.0 + brow * 3.0 + ledge * 9.0 - stream * 1.5 - lower * 1.5;
	bone = max(bone, 0.15 * head);
	feat += (stream * 1.9 + lower * 1.5) * flow + mouth * 1.1 * (1.0 - fang) + eyes * 2.0 + pool * ledge * 1.4;
	float sc_ = min(abs(sx), abs(abs(p.x) - 11.0));
	halo += exp(-sc_ * sc_ / 120.0) * 0.8 * step(p.y, 15.0) + mouth * 0.8 + eyes * 0.6;
}

// wall radius at (angle a, depth Y)
float wall_r(float a, float Y, float lod, out float feat, out float tx, out float halo, out float bone, out float rel) {
	float u = a * 0.15915494;
	float n1 = textureLod(noise_tex, vec2(u * 3.0, Y * 0.016), lod).r;
	float n2 = textureLod(noise_tex, vec2(u * 9.0 + 0.37, Y * 0.045 + 0.2), lod).r;
	float n3 = textureLod(noise_tex, vec2(u * 27.0 + 0.11, Y * 0.11), lod).r;
	tx = n2 * 0.55 + n3 * 0.45;
	float R = R_at(Y);
	float cav = smoothstep(ceilY - 10.0, ceilY + 55.0, Y);
	float r = R * (1.0 + 0.10 * (n1 - 0.5)) + 2.2 * (n2 - 0.5) + 1.0 * (n3 - 0.5);
	r += cav * 100.0;
	feat = 0.0;
	halo = 0.0;
	bone = 0.0;
	rel = 0.0;
	int k = 0;
	float dyb = 1e4;
	for (int i = 0; i < 6; i++) {
		float dd = abs(Y - vY[i]);
		if (dd < dyb) { dyb = dd; k = i; }
	}
	if (dyb < 36.0) {
		float dy = Y - vY[k];
		float da = a - vA[k];
		da -= TAU * floor((da + PI) / TAU);
		float lx = da * R;
		float env = (1.0 - smoothstep(30.0, 36.0, dyb)) * (1.0 - smoothstep(42.0, 49.0, abs(lx)));
		if (env > 0.001) {
			vec2 p = vec2(lx, -dy);
			float pr = 0.0;
			float ft = 0.0;
			float ha = 0.0;
			float bo = 0.0;
			if (k == 0) v_ribs(p, n3, pr, ft, ha, bo);
			else if (k == 1) v_furn(p, n3, pr, ft, ha, bo);
			else if (k == 2) v_face(p, n3, pr, ft, ha, bo);
			else if (k == 3) v_facade(p, n3, pr, ft, ha, bo);
			else if (k == 4) v_stairs(p, n3, pr, ft, ha, bo);
			else v_lava(p, n3, pr, ft, ha, bo);
			r -= pr * env * (0.85 + 0.3 * n3);
			rel = pr * env;
			feat = ft * env;
			halo = ha * env;
			bone = bo * env;
		}
	}
	return r;
}

vec3 floor_col(vec2 xz, float t) {
	vec2 g = xz * 0.05;
	vec2 ip = floor(g);
	vec2 fp = fract(g);
	float F1 = 8.0;
	float F2 = 8.0;
	vec2 cid = ip;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 nb = vec2(float(i), float(j));
			vec2 df = nb + h22(ip + nb) - fp;
			float dd = dot(df, df);
			if (dd < F1) { F2 = F1; F1 = dd; cid = ip + nb; }
			else if (dd < F2) { F2 = dd; }
		}
	}
	float edge = sqrt(F2) - sqrt(F1);
	float flow = texture(noise_tex, xz * 0.012 + vec2(T * 0.01, 0.0)).r;
	float lc = clamp(lake, 0.12, 1.0);
	float soft = 0.02 + t * 0.0008;
	float lav = smoothstep(0.20 * lc + soft, 0.0, edge) * (0.55 + 0.9 * flow);
	float hc = h21(cid);
	vec3 plate = vec3(0.010, 0.009, 0.013) + vec3(0.03, 0.028, 0.04) * hc * hc;
	plate += vec3(1.0, 0.30, 0.05) * smoothstep(0.7, 0.0, edge) * 0.10 * lake;
	plate += vec3(0.5, 0.55, 0.65) * step(0.90, hc) * 0.05;
	vec3 lava = vec3(1.0, 0.22, 0.03) * (0.9 + 1.5 * lav) + vec3(0.3, 0.12, 0.0) * flow;
	return mix(plate, lava * lake * 0.5, clamp(lav * 1.1, 0.0, 1.0));
}

float lava_glow(float Y) {
	return (0.35 + 0.85 * smoothstep(60.0, floorY, Y)) * smoothstep(0.08, 0.45, heat) * (0.25 + 0.75 * lake);
}

vec3 fog_color(float yy, float dy) {
	vec3 ash = vec3(0.17, 0.162, 0.152);
	vec3 soot = vec3(0.048, 0.040, 0.038);
	vec3 c = mix(ash, soot, smoothstep(0.0, 0.45, heat));
	vec3 warm = mix(vec3(0.95, 0.30, 0.055), vec3(1.0, 0.5, 0.14), smoothstep(0.6, 1.0, heat));
	float g = lava_glow(yy);
	c += warm * g * (0.07 + 1.4 * pow(max(dy, 0.0), 2.5));
	return c;
}

vec3 sky_col(vec3 d, vec2 o) {
	float tt = (-45.0 - camY) / d.y;
	vec2 hit = o + d.xz * tt;
	float r = length(hit);
	float tt2 = (-20.0 - camY) / d.y;
	vec2 hc = (o + d.xz * tt2) * 0.012 + vec2(T * 0.01, 0.0);
	float n = texture(noise_tex, hc).r;
	vec3 base = vec3(0.16, 0.158, 0.155) * (0.5 + 1.1 * n);
	base += vec3(0.20, 0.20, 0.21) * exp(-r * 0.02) * 0.6;
	float er = 17.0;
	float ring = exp(-max(r - er, 0.0) * 0.30) * smoothstep(er - 1.2, er + 0.6, r);
	float core = exp(-max(r - er, 0.0) * 0.08);
	vec3 c = base + vec3(0.85, 0.86, 0.90) * ring * 1.5 + vec3(0.30, 0.31, 0.34) * core * 0.35;
	c *= smoothstep(er - 0.6, er + 0.4, r) * 0.97 + 0.03;
	return c * limbo_light;
}

// ray-marched smoke volume along [0, tmax]: returns (in-scatter rgb, transmittance)
vec4 vol(vec2 o, vec2 h, float dy, float tmax, float seed) {
	float tm = min(tmax, 170.0);
	float dt = tm / 4.0;
	vec3 S = vec3(0.0);
	float Tr = 1.0;
	float jit = h21(vec2(seed, T * 13.0));
	for (int i = 0; i < 4; i++) {
		float tt = (float(i) + 0.3 + 0.5 * jit) * dt;
		vec2 hp = o + h * tt;
		float Yy = camY + dy * tt;
		vec2 cu = hp * 0.022 + vec2(Yy * 0.017, Yy * 0.009) + vec2(T * 0.006, 0.0);
		float n = texture(noise_tex, cu).r * 0.65 + texture(noise_tex, cu * 2.7 + vec2(0.31, 0.7)).r * 0.35;
		vec2 cu2 = hp * 0.022 + vec2((Yy - 7.0) * 0.017, (Yy - 7.0) * 0.009) + vec2(T * 0.006, 0.0);
		float nu = texture(noise_tex, cu2).r * 0.65 + texture(noise_tex, cu2 * 2.7 + vec2(0.31, 0.7)).r * 0.35;
		float sheen = clamp(0.5 + (nu - n) * 7.0, 0.0, 1.0);
		float dens = (fogd + fog_extra * 0.5) * (0.12 + 3.0 * smoothstep(0.36, 0.72, n));
		float ext = dens * dt;
		float aa = 1.0 - exp(-ext);
		// billows are lit from below by the lava, and rim-lit from above while in the upper shaft
		vec3 lc = fog_color(Yy, dy) * (0.35 + 0.9 * n) * (0.45 + 1.4 * sheen);
		lc += vec3(0.95, 0.78, 0.62) * flash * (0.3 + 2.0 * smoothstep(0.4, 0.8, n)) * 0.8;
		lc += vec3(0.55, 0.52, 0.5) * 0.35 * limbo_light * smoothstep(0.55, 0.85, n) * (1.0 - smoothstep(0.0, 0.5, heat));
		lc += vec3(1.0, 0.34, 0.07) * smoothstep(0.62, 0.95, n) * lava_glow(Yy) * 0.55;
		S += Tr * aa * lc;
		Tr *= 1.0 - aa;
	}
	return vec4(S, Tr);
}

// ---------------------------------------------------------------- mid-air silhouettes: chains, hooks, cages --------
float chain_sd(vec2 q, float L, float w) {
	float kk = floor(q.y / L);
	float best = 1e3;
	for (int i = -1; i <= 1; i++) {
		float k = kk + float(i);
		vec2 c = vec2(q.x, q.y - (k + 0.5) * L);
		float d;
		if (mod(k, 2.0) < 1.0) {
			vec2 e = c / vec2(w, L * 0.82);
			d = abs((length(e) - 1.0) * w * 0.9) - w * 0.36;
		} else {
			d = sbox(c, vec2(w * 0.40, L * 0.82));
		}
		best = min(best, d);
	}
	return best;
}

float hook_sd(vec2 q) {
	float d = sbox(q - vec2(0.0, 2.6), vec2(0.8, 2.9));
	vec2 c = q - vec2(2.8, 6.0);
	float ang = atan(c.y, c.x);
	float arc = abs(length(c) - 2.8) - 0.8;
	if (ang < -0.75) arc = 1e3;
	return min(d, arc);
}

float cage_sd(vec2 q, out float inside, out float bars) {
	vec2 c = q - vec2(0.0, 11.0);
	float body = sbox(c, vec2(3.3, 5.6));
	float dome = length(vec2(c.x / 3.3, (c.y + 5.6) / 4.2)) - 1.0;
	float sh = (c.y < -5.6) ? dome * 3.3 : body;
	inside = step(sh, 0.0);
	float b = step(abs(fract(c.x / 1.5 + 0.5) - 0.5) * 1.5, 0.20);
	float hp = step(abs(fract(c.y / 3.1 + 0.5) - 0.5) * 3.1, 0.22);
	bars = max(b, hp);
	float ring = abs(length(q - vec2(0.0, 1.5)) - 1.2) - 0.35;
	return min(abs(sh) - 0.38, ring);
}

vec4 mid_layer(vec2 o, vec2 h, float A, float B, float dy, float tcap, float rm, float sc, float seed, float amt) {
	float C = dot(o, o) - rm * rm;
	float disc = B * B - A * C;
	if (disc <= 0.0) return vec4(0.0);
	float tm = (-B + sqrt(disc)) / A;
	if (tm < 1.0 || tm > tcap) return vec4(0.0);
	float Ym = camY + tm * dy;
	if (Ym < 30.0 || Ym > ceilY + 20.0) return vec4(0.0);
	vec2 hp = o + h * tm;
	float am = atan(hp.y, hp.x);
	float cellH = 100.0 * sc;
	float c0 = floor(Ym / cellH);
	vec4 res_ = vec4(0.0);
	float aa = tm * 0.0026 + 0.04;
	for (int ci = 0; ci < 2; ci++) {
		float c = c0 + float(ci);
		for (int j = 0; j < 3; j++) {
			vec2 hs = h22(vec2(c * 3.7 + float(j) * 11.3 + seed, c * 1.3 + float(j) * 5.1 + seed * 0.37));
			if (hs.y > amt) continue;
			float aj = hs.x * TAU;
			float da = am - aj;
			da -= TAU * floor((da + PI) / TAU);
			float lx = da * rm;
			if (abs(lx) > 7.0 * sc) continue;
			float endY = (c + 0.2 + 0.7 * h21(hs + 4.0)) * cellH;
			float py = Ym - endY;
			if (py < -400.0 || py > 22.0 * sc) continue;
			vec2 q = vec2(lx - 1.8 * sc * sin(Ym * 0.022 / sc + T * 0.55 + hs.x * 9.0) * (0.4 + 0.6 * clamp(-py / (80.0 * sc), 0.0, 1.0)), py) / sc;
			float L = 5.4;
			float w = 1.75;
			float sdA = 1e3;
			float sdB = 1e3;
			float glow = 0.0;
			float barsA = 0.0;
			float insA = 0.0;
			bool cg = h21(hs * 7.0 + 1.0) > 0.5;
			if (q.y < 2.0) {
				sdA = chain_sd(q, L, w);
				sdB = chain_sd(q + vec2(0.0, 0.7), L, w);
			}
			float dd = 1e3;
			float dd2 = 1e3;
			if (q.y > -1.0) {
				if (cg) {
					float ins2;
					float b2;
					dd = cage_sd(q, ins2, b2);
					dd2 = cage_sd(q + vec2(0.0, 0.7), ins2, b2);
					insA = ins2;
					barsA = b2;
					sdA = min(sdA, dd);
					sdB = min(sdB, dd2);
					glow = insA * (1.0 - M((dd) * sc / aa * 0.5)) ;
				} else {
					dd = hook_sd(q);
					dd2 = hook_sd(q + vec2(0.0, 0.7));
					sdA = min(sdA, dd);
					sdB = min(sdB, dd2);
				}
			}
			float al = smoothstep(aa, -aa, sdA * sc);
			float cgl = 0.0;
			if (cg && q.y > -1.0) {
				float ins3;
				float b3;
				float dcc = cage_sd(q, ins3, b3);
				// cage interior: hot glow seen between the bars
				cgl = ins3 * (1.0 - b3) * smoothstep(0.1, -0.2, dcc + 0.4);
				al = max(al, cgl * 0.9);
			}
			if (al > 0.002) {
				float lit = clamp((sdB - sdA) / 0.7, 0.0, 1.0);
				float rim = smoothstep(-1.3, 0.0, sdA);
				float lg = lava_glow(Ym) * 2.0 + 0.05;
				vec3 hot = vec3(1.0, 0.36, 0.07);
				vec3 cc = vec3(0.004, 0.0035, 0.004) + hot * lg * (rim * lit * 1.1 + rim * 0.12);
				cc += vec3(0.55, 0.5, 0.46) * rim * (1.0 - lit) * 0.05 * limbo_light;
				cc = mix(cc, hot * (0.7 + 0.5 * h21(hs)) * 1.4, cgl * (1.0 - smoothstep(0.5, 0.9, al * 0.0 + (1.0 - cgl))));
				float fa = exp(-tm * 0.0022 * (1.0 + 6.0 * fogd * 10.0));
				float vis = clamp(fa, 0.0, 1.0);
				vec4 lay = vec4(cc, al * vis);
				res_.rgb = mix(res_.rgb, lay.rgb, lay.a);
				res_.a = res_.a + lay.a * (1.0 - res_.a);
			}
		}
	}
	return res_;
}

void fragment() {
	vec2 uv = UV + shake;
	vec2 p = (uv - 0.5) * vec2(res.x / res.y, 1.0);
	float cr = cos(roll);
	float sr = sin(roll);
	vec2 q = vec2(p.x * cr - p.y * sr, p.x * sr + p.y * cr);
	q.y = -q.y;
	vec3 F = vec3(0.0, sin(phi), cos(phi));
	vec3 Uv = vec3(0.0, -cos(phi), sin(phi));
	vec3 d = normalize(F * fl + vec3(1.0, 0.0, 0.0) * q.x + Uv * q.y);
	float cy = cos(yaw);
	float sy = sin(yaw);
	d.xz = vec2(d.x * cy - d.z * sy, d.x * sy + d.z * cy);
	vec2 o = cam_off;
	vec2 h = d.xz;
	float A = dot(h, h) + 1e-6;
	float B = dot(o, h);

	float rho = R_at(camY + 25.0);
	float t = 1.0;
	float a = 0.0;
	float Y = camY;
	float ff = 0.0;
	float tx = 0.5;
	float hl = 0.0;
	float bn = 0.0;
	float rl = 0.0;
	for (int i = 0; i < 3; i++) {
		float C = dot(o, o) - rho * rho;
		t = (-B + sqrt(max(B * B - A * C, 0.0))) / A;
		t = min(t, 900.0);
		Y = camY + t * d.y;
		vec2 hp = o + h * t;
		a = atan(hp.y, hp.x);
		float lod = clamp(log2(1.0 + t * 0.03), 0.0, 6.0);
		rho = wall_r(a, Y, lod, ff, tx, hl, bn, rl);
	}
	{
		float C = dot(o, o) - rho * rho;
		t = min((-B + sqrt(max(B * B - A * C, 0.0))) / A, 900.0);
	}

	vec3 col;
	float tf = (floorY - camY) / max(d.y, 1e-4);
	bool sky = d.y < 0.0 && Y < 0.0;
	bool is_floor = d.y > 0.0 && tf < t;
	float tend = t;
	float deep = clamp(Y / floorY, 0.0, 1.0);
	vec3 fcol = fog_color(Y, d.y);
	float fd = fogd + fog_extra;
	vec4 vv;

	if (sky) {
		col = sky_col(d, o);
		tend = 120.0;
		vv = vol(o, h, d.y, 40.0, 1.0);
		col = col * mix(1.0, vv.a, 0.8) + vv.rgb * 0.5;
	} else if (is_floor) {
		tend = tf;
		col = floor_col(o + h * tf, tf);
		vv = vol(o, h, d.y, tf, 2.0);
		col = col * mix(1.0, vv.a, 0.6) + vv.rgb * 0.35;
		float trf = exp(-tf * fd * 0.6);
		col = col * trf + fcol * (1.0 - trf) * 0.35;
	} else {
		float lodw = clamp(log2(1.0 + t * 0.03), 0.0, 6.0);
		float e = 0.45;
		float f2;
		float t2;
		float t3;
		float b2;
		float r2;
		float rA = wall_r(a + e / rho, Y, lodw, f2, t2, t3, b2, r2);
		float rY = wall_r(a, Y + e, lodw, f2, t2, t3, b2, r2);
		float s_a = (rA - rho) / e;
		float s_y = (rY - rho) / e;
		vec3 N = normalize(vec3(-1.0, s_a, s_y));
		float u = a * 0.15915494;
		float n3 = textureLod(noise_tex, vec2(u * 27.0 + 0.11, Y * 0.11), lodw).r;
		float n2 = textureLod(noise_tex, vec2(u * 9.0 + 0.37, Y * 0.045 + 0.2), lodw).r;
		float strata = 0.5 + 0.5 * sin(Y * 0.17 + tx * 2.5);
		vec3 rock = mix(vec3(0.030, 0.027, 0.030), vec3(0.14, 0.115, 0.10), smoothstep(0.3, 0.8, tx));
		rock *= 0.75 + 0.35 * strata;
		vec3 boneC = vec3(0.66, 0.55, 0.42) * (0.55 + 0.7 * n3) * (0.8 + 0.4 * n2);
		rock = mix(rock, boneC, clamp(bn, 0.0, 1.0));
		float lake_l = 0.2 + 0.8 * lake;
		float n1p = textureLod(noise_tex, vec2(u * 3.0, Y * 0.016), lodw).r;
		float pools = 0.12 + 1.5 * smoothstep(0.30, 0.68, n1p);
		float lg = lava_glow(Y) * (0.5 + 0.8 * lake_l) * pools * 0.8;
		float vdist = min(abs(Y - vY[0]), 1e4);
		// light from the lava far below and in front-below
		vec3 Lw = normalize(vec3(-0.55, 0.0, 0.85));
		float ndl = max(dot(N, Lw), 0.0);
		vec3 warmC = vec3(1.0, 0.36, 0.07);
		float up_l = max(dot(N, normalize(vec3(-0.5, 0.0, -0.8))), 0.0);
		vec3 coolL = vec3(0.60, 0.62, 0.68) * limbo_light * (0.8 * exp(-max(Y, 0.0) / 70.0) + 0.0);
		float ao = 1.0 - 0.85 * smoothstep(0.3, 5.0, -rl);
		col = rock * (warmC * (0.02 + 2.8 * lg) * (0.03 + ndl * ndl * 2.4) + coolL * (0.12 + up_l * 1.6) + vec3(0.034, 0.028, 0.03) + vec3(0.025, 0.008, 0.003) * heat) * ao;
		// wet obsidian glints
		float gl = pow(max(dot(N, normalize(Lw + vec3(0.8, 0.0, 0.0))), 0.0), 18.0) * smoothstep(0.55, 0.9, n3) * (1.0 - bn);
		col += warmC * gl * lg * 2.2;
		// rim light on projecting edges
		float edge = length(vec2(s_a, s_y));
		col += vec3(0.80, 0.66, 0.50) * smoothstep(1.4, 3.8, edge) * (0.03 + 0.45 * lg) * (0.4 + ndl) + vec3(0.30, 0.34, 0.42) * smoothstep(1.2, 3.5, edge) * up_l * 0.05;
		col += rock * vec3(1.0, 0.82, 0.66) * flash * (1.2 + 5.0 * edge * 0.15 + 4.0 * up_l) * (0.5 + 0.5 * smoothstep(0.35, 0.7, n2)) * exp(-t * 0.012);
		// lava veins
		float vn = textureLod(noise_tex, vec2(u * 5.0 + 0.77, Y * 0.003 - T * 0.009 + tx * 0.05), lodw).r;
		float vein = smoothstep(0.016, 0.0, abs(vn - 0.5)) * smoothstep(100.0, 260.0, Y);
		float crack = smoothstep(0.03, 0.0, abs(n3 - 0.5)) * smoothstep(100.0, 400.0, Y) * 0.5;
		col += vec3(1.0, 0.30, 0.05) * (vein * 0.7 + crack * 0.08) * heat * lake_l * (0.7 + 0.5 * sin(T * 2.0 + Y * 0.1));
		// carved openings and eyes: molten light, plus its wash on nearby stone
		vec3 hotc = mix(vec3(1.0, 0.22, 0.03), vec3(1.0, 0.86, 0.5), clamp(ff * 0.5, 0.0, 1.0));
		col += hotc * ff * 1.15 * (0.3 + 0.7 * smoothstep(0.0, 0.35, heat + 0.25));
		col += rock * warmC * hl * (0.6 + 1.6 * ndl) * 1.8 * (0.4 + 0.6 * smoothstep(0.0, 0.3, heat + 0.2));
		vv = vol(o, h, d.y, t, 3.0);
		col = col * vv.a + vv.rgb;
		float tr = exp(-t * fd * 0.5);
		col = col * tr + fcol * (1.0 - tr) * 0.6;
	}

	// mid-air chains, hooks, cages
	if (chain_amt > 0.001 && !sky) {
		float far_on = smoothstep(26.0, 34.0, R_at(Y));
		vec4 m1 = mid_layer(o, h, A, B, d.y, tend, 21.0, 1.5, 3.0, 0.55 * chain_amt);
		col = mix(col, m1.rgb, clamp(m1.a * far_on, 0.0, 1.0));
		vec4 m2 = mid_layer(o, h, A, B, d.y, tend, 13.0, 0.6, 9.0, 0.3 * chain_amt);
		col = mix(col, m2.rgb, clamp(m2.a * far_on, 0.0, 1.0));
	}

	// smoke banks: horizontal planes of cinder cloud punched through
	float S = 36.0;
	float dir = d.y >= 0.0 ? 1.0 : -1.0;
	float k0 = dir > 0.0 ? floor(camY / S) + 1.0 : floor(camY / S);
	for (int i = 1; i >= 0; i--) {
		float k = k0 + dir * float(i);
		float Yp = k * S;
		float tp = (Yp - camY) / d.y;
		if (tp > 0.5 && tp < tend && Yp > 4.0) {
			vec2 hp = o + d.xz * tp;
			vec2 cu = hp * 0.035 + vec2(k * 7.31, k * 3.17) + vec2(T * 0.02, 0.0);
			float dn = textureLod(noise_tex, cu, clamp(log2(1.0 + tp * 0.03), 0.0, 5.0)).r;
			dn = dn * 0.7 + 0.3 * textureLod(noise_tex, cu * 2.7 + 0.5, 2.0).r;
			float al = smoothstep(0.34, 0.66, dn) * smoothstep(0.0, 6.0, tp) * smoothstep(4.0, 16.0, Yp);
			al *= smoke_amt * exp(-tp * fd * 0.2);
			vec3 sc = fog_color(Yp, 0.0) * (0.6 + 0.9 * dn);
			sc += vec3(1.0, 0.3, 0.06) * smoothstep(0.7, 0.95, dn) * lava_glow(Yp) * 0.4;
			col = mix(col, sc, clamp(al, 0.0, 0.9));
		}
	}

	// lightning-like flashes in the ash storm
	col += vec3(0.62, 0.52, 0.45) * flash * 0.06;
	col *= expo;
	COLOR = vec4(col, 1.0);
}
