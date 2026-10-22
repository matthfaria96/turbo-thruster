// Velocity-aligned spark/bullet streak. Instance Y axis = direction*length,
// X axis length = width. Always faces the camera around its own axis.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, skip_vertex_transform;

uniform float energy = 3.0;
uniform float core = 0.6;

varying float near_fade;

void vertex() {
	vec3 pos = MODEL_MATRIX[3].xyz;
	vec3 axis = MODEL_MATRIX[1].xyz;
	float w = length(MODEL_MATRIX[0].xyz);
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 dir = length(axis) > 1e-5 ? normalize(axis) : vec3(0.0, 1.0, 0.0);
	vec3 side = normalize(cross(dir, cam - pos + vec3(1e-4)));
	vec3 world = pos + side * VERTEX.x * w + axis * VERTEX.y;
	VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	near_fade = smoothstep(2.0, 7.0, -VERTEX.z);
}

void fragment() {
	float x = 1.0 - abs(UV.x * 2.0 - 1.0);
	float y = 1.0 - abs(UV.y * 2.0 - 1.0);
	float a = smoothstep(0.0, 1.0, x) * smoothstep(0.0, 0.5, y);
	vec3 c = mix(COLOR.rgb, vec3(1.0), core * x * x);
	ALBEDO = c * energy * a;
	ALBEDO *= near_fade;
	ALPHA = COLOR.a * a * near_fade;
}
