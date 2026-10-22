// Tunnel: translucent dark glass panels + neon grid. Ripples (explosions)
// push the wall outward and light it up in the explosion's colour, like
// the Geometry Wars grid. "Flow" streaks race along the tunnel faster as
// the ship speeds up. Base brightness stays below the glow threshold.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

uniform vec3 tint : source_color = vec3(0.3, 0.5, 1.0);
uniform float brightness = 1.0;
uniform float flash = 0.0;
uniform float now = 0.0;
uniform float flow = 0.0;        // 0..1 ship speed factor
uniform float flow_offset = 0.0; // distance travelled, drives the streaks
uniform vec4 ripples[8];
uniform vec4 ripple_colors[8];
uniform float ripple_strength[8];

varying float view_dist;
varying float wave;
varying vec3 wave_color;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float total = 0.0;
	vec3 col = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		float t = now - ripples[i].w;
		if (t < 0.0 || t > 1.8) continue;
		float d = distance(world, ripples[i].xyz);
		float front = t * 36.0;
		float ring = exp(-pow(d - front, 2.0) / 12.0);
		float k = ring * ripple_strength[i] * exp(-t * 2.4);
		total += k;
		col += ripple_colors[i].rgb * k;
	}
	wave = total;
	wave_color = total > 0.001 ? col / total : tint;
	VERTEX -= NORMAL * total * 1.8;
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
	// Light streaks racing down the long grid lines.
	float lane = step(0.985, grid_line(UV.x, 1.6));
	float phase = fract(UV.y * 0.08 - flow_offset * 0.11 + UV.x * 0.37);
	float streak = lane * pow(1.0 - phase, 14.0) * flow * 2.2;
	float light = (minor * 0.15 + halo * 0.07 + major * 0.18) * brightness;
	vec3 lines = tint * light * (1.0 + wave * 2.0) + wave_color * wave * (0.9 + light * 2.0);
	vec3 panel = tint * 0.035 + vec3(0.0, 0.004, 0.012);
	ALBEDO = (panel + lines + tint * streak) * fade + vec3(flash) * (0.3 + major);
	ALPHA = clamp(0.7 + light * 0.4 + wave + streak * 0.3, 0.0, 1.0) * smoothstep(0.06, 0.45, fade);
}
