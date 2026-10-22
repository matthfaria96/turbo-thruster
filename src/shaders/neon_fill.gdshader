// Translucent glassy face fill behind the neon edges.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform vec3 color : source_color = vec3(1.0);
uniform float strength = 0.22;
instance uniform float hit = 0.0;
instance uniform float fade = 1.0;
instance uniform float phase = 0.0;

void fragment() {
	float pulse = 0.5 + 0.5 * sin(TIME * 6.0 + phase);
	float facing = abs(dot(NORMAL, VIEW));
	float glass = mix(0.55, 1.0, 1.0 - facing);
	ALBEDO = (color * strength * glass * (1.0 + pulse + hit * 2.0)) * fade;
}
