// Tunnel wall: dim tinted grid that fades with distance. Kept below the
// glow threshold on purpose so ship, enemies and bullets always stand out.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform vec3 tint : source_color = vec3(0.3, 0.5, 1.0);
uniform float brightness = 1.0;
uniform float flash = 0.0;

varying float view_dist;

void vertex() {
	view_dist = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}

float grid_line(float v) {
	float w = max(fwidth(v), 1e-4);
	return 1.0 - min(abs(fract(v - 0.5) - 0.5) / w, 1.0);
}

void fragment() {
	float minor = max(grid_line(UV.x), grid_line(UV.y));
	float major = grid_line(UV.y / 8.0);
	float fade = exp(-view_dist * 0.011);
	vec3 col = tint * (0.022 + minor * 0.15 + major * 0.24) * brightness * fade;
	ALBEDO = col + vec3(flash) * (0.4 + major);
}
