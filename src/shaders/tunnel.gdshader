// Tunnel: translucent dark glass panels + neon grid. Ripples (explosions)
// push the wall outward like the Geometry Wars grid and light it up.
// Base brightness stays below the glow threshold so gameplay pops.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

uniform vec3 tint : source_color = vec3(0.3, 0.5, 1.0);
uniform float brightness = 1.0;
uniform float flash = 0.0;
uniform float now = 0.0;
uniform vec4 ripples[8];
uniform float ripple_strength[8];

varying float view_dist;
varying float wave;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float total = 0.0;
	for (int i = 0; i < 8; i++) {
		float t = now - ripples[i].w;
		if (t < 0.0 || t > 1.6) continue;
		float d = distance(world, ripples[i].xyz);
		float front = t * 34.0;
		float ring = exp(-pow(d - front, 2.0) / 10.0);
		total += ring * ripple_strength[i] * exp(-t * 2.6);
	}
	wave = total;
	VERTEX -= NORMAL * total * 1.6;
	view_dist = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}

float grid_line(float v, float sharp) {
	float w = max(fwidth(v), 1e-4) * sharp;
	return 1.0 - min(abs(fract(v - 0.5) - 0.5) / w, 1.0);
}

void fragment() {
	float minor = max(grid_line(UV.x, 1.2), grid_line(UV.y, 1.2));
	float halo = max(grid_line(UV.x, 5.0), grid_line(UV.y, 5.0)) * 0.35;
	float major = grid_line(UV.y / 8.0, 1.6);
	float fade = exp(-view_dist * 0.010);
	float light = (minor * 0.15 + halo * 0.07 + major * 0.18) * brightness;
	vec3 lines = tint * light * (1.0 + wave * 3.0);
	vec3 panel = tint * 0.035 + vec3(0.0, 0.004, 0.012);
	ALBEDO = (panel + lines) * fade + vec3(flash) * (0.3 + major);
	ALPHA = clamp(0.7 + light * 0.4 + wave, 0.0, 1.0) * mix(0.55, 1.0, fade);
}
