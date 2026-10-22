// Soft additive billboard used by particles, bullets and sparks.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform float energy = 2.5;
uniform float core = 0.0;
uniform float flare = 0.0;
instance uniform vec4 tint : source_color = vec4(1.0);

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 c2 = UV * 2.0 - 1.0;
	float d = 1.0 - clamp(length(c2), 0.0, 1.0);
	float a = d * d;
	float star = (max(0.0, 1.0 - abs(c2.y) * 14.0) + max(0.0, 1.0 - abs(c2.x) * 14.0)) * (1.0 - length(c2)) * flare;
	a = max(a, star);
	vec3 c = mix(COLOR.rgb * tint.rgb, vec3(1.0), core * smoothstep(0.45, 0.8, d));
	ALBEDO = c * energy * a;
	ALPHA = COLOR.a * tint.a * a;
}
