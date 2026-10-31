// Swirling portal disc.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

#include "res://src/shaders/compat.gdshaderinc"

uniform vec3 color : source_color = vec3(0.4, 0.85, 1.0);
uniform float intensity = 1.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float swirl = sin(a * 5.0 + r * 14.0 - TIME * 7.0) * 0.5 + 0.5;
	float mask = smoothstep(1.0, 0.25, r);
	vec3 c = mix(color, vec3(1.0), smoothstep(0.4, 0.0, r));
	ALBEDO = c * (0.35 + swirl * 0.9) * mask * intensity * 1.8;
	ALPHA = mask;
	ALBEDO = compat_color(ALBEDO);
}
