shader_type canvas_item;

uniform vec4 tint : source_color = vec4(1.0, 0.12, 0.2, 1.0);
uniform float amount = 0.0;

void fragment() {
	float v = smoothstep(0.5, 1.4, length(UV * 2.0 - 1.0));
	COLOR = vec4(tint.rgb, v * amount);
}
