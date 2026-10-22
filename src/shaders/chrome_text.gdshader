// 80s chrome lettering: sky gradient above a hard horizon line, warm sunset
// below, a bright shine band sweeping across, and a subtle scanline flicker.
shader_type canvas_item;

uniform vec4 top : source_color = vec4(0.55, 0.95, 1.0, 1.0);
uniform vec4 mid : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 horizon : source_color = vec4(0.12, 0.08, 0.35, 1.0);
uniform vec4 low : source_color = vec4(1.0, 0.35, 0.75, 1.0);
uniform vec4 bottom : source_color = vec4(1.0, 0.8, 0.35, 1.0);
uniform float height = 64.0;   // text block height in local pixels
uniform float y_offset = 0.0;  // local y where the text starts
uniform float shine_speed = 0.35;

varying vec2 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	float a = texture(TEXTURE, UV).a;
	float v = clamp((local.y - y_offset) / max(height, 1.0), 0.0, 1.0);
	vec3 col;
	if (v < 0.52) {
		col = mix(top.rgb, mid.rgb, smoothstep(0.0, 0.5, v));
	} else if (v < 0.57) {
		col = horizon.rgb;
	} else {
		col = mix(low.rgb, bottom.rgb, smoothstep(0.57, 1.0, v));
	}
	// Diagonal shine band sweeping left to right.
	float band = fract((local.x * 0.0018 + local.y * 0.0009) - TIME * shine_speed);
	float shine = smoothstep(0.0, 0.03, band) * (1.0 - smoothstep(0.03, 0.08, band));
	col = mix(col, vec3(1.0), shine * 0.85);
	col *= 0.94 + 0.06 * sin(local.y * 1.4 + TIME * 3.0);
	COLOR = vec4(col, a * COLOR.a);
}
