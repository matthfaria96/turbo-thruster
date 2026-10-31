// Thick neon line: each edge is a quad expanded toward the camera in view
// space. CUSTOM0.xyz holds the other endpoint, UV.x the side (-1/+1).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, skip_vertex_transform;

#include "res://src/shaders/compat.gdshaderinc"

uniform vec3 color : source_color = vec3(1.0);
uniform float energy = 2.4;
uniform float width = 0.07;
uniform float min_pixel = 0.0022;
instance uniform float hit = 0.0;
instance uniform float fade = 1.0;
instance uniform float phase = 0.0;

varying float near_fade;

void vertex() {
	vec3 a = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 b = (MODELVIEW_MATRIX * vec4(CUSTOM0.xyz, 1.0)).xyz;
	vec3 dir = normalize(b - a);
	vec3 side = normalize(cross(dir, a));
	float w = max(width, -a.z * min_pixel);
	VERTEX = a - dir * w * 0.5 + side * UV.x * w;
	near_fade = smoothstep(1.5, 5.0, -a.z);
}

void fragment() {
	float pulse = 0.5 + 0.5 * sin(TIME * 6.0 + phase);
	float edge = 1.0 - abs(UV.x);
	float core = smoothstep(0.0, 0.6, edge);
	vec3 c = mix(color, vec3(1.0), 0.12 * core + hit * 0.35);
	ALBEDO = c * energy * (0.35 + core) * (1.0 + pulse * 0.3) * fade * near_fade;
	ALBEDO = compat_color(ALBEDO);
}
