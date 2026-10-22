shader_type canvas_item;

uniform vec4 tint : source_color = vec4(1.0, 0.12, 0.2, 1.0);
uniform float amount = 0.0;
// -1 = hit from the left, 1 = from the right, 0 = all around.
uniform float side = 0.0;
uniform vec4 slow_tint : source_color = vec4(0.3, 0.8, 1.0, 1.0);
uniform float slow = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float v = smoothstep(0.5, 1.4, length(p));
	float bias = side == 0.0 ? 1.0 : clamp(0.25 + p.x * side * 1.2, 0.0, 1.6);
	float hurt = v * amount * bias;
	float s = smoothstep(0.35, 1.3, length(p)) * slow * 0.3;
	COLOR = vec4(mix(slow_tint.rgb, tint.rgb, hurt / max(hurt + s, 1e-4)), clamp(hurt + s, 0.0, 1.0));
}
