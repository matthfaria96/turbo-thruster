// Solid neon body: unshaded, rim-lit, HDR so the glow pass picks it up.
shader_type spatial;
render_mode unshaded, cull_back;

#include "res://src/shaders/compat.gdshaderinc"

uniform vec3 color : source_color = vec3(1.0);
uniform float energy = 1.5;
uniform float hit = 0.0;
uniform float fade = 1.0;

void fragment() {
	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 c = color * energy * (0.55 + 1.2 * rim * rim);
	ALBEDO = mix(c, c * 1.5 + vec3(0.5), hit) * fade;
	ALBEDO = compat_color(ALBEDO);
}
