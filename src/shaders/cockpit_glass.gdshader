// Cockpit canopy: faint scanlines and darkened, slightly tinted edges.
shader_type canvas_item;

uniform vec4 tint : source_color = vec4(0.2, 0.6, 1.0, 1.0);
uniform float scan = 0.035;

void fragment() {
	float lines = 0.5 + 0.5 * sin(FRAGCOORD.y * 1.6);
	vec2 p = UV * 2.0 - 1.0;
	float edge = smoothstep(0.75, 1.35, length(p * vec2(0.9, 1.0)));
	vec3 col = mix(vec3(0.0), tint.rgb * 0.15, edge * 0.5);
	COLOR = vec4(col, lines * scan + edge * 0.55);
}
