// Deep-space nebula behind the translucent tunnel. Kept dim.
shader_type sky;

uniform vec3 color_a : source_color = vec3(0.05, 0.12, 0.25);
uniform vec3 color_b : source_color = vec3(0.18, 0.05, 0.22);
uniform float intensity = 1.0;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = EYEDIR;
	float n = fbm(d * 2.2);
	float m = fbm(d * 4.5);
	vec3 neb = mix(color_a, color_b, smoothstep(0.35, 0.75, m)) * smoothstep(0.4, 0.85, n) * 0.9;
	float stars = pow(hash(floor(d * 300.0)), 400.0) * 1.2;
	COLOR = (neb + vec3(stars) * 0.6) * intensity;
}
