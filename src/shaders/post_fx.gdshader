// Full-screen post effects: chromatic aberration that grows with speed and
// impacts, radial warp streaks at high speed, a colour pulse on hits/kills
// and gentle edge darkening. Drawn by a ColorRect over the 3D view.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float aberration = 0.0;   // 0..1
uniform float warp = 0.0;         // 0..1 radial blur strength
uniform vec4 pulse_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float pulse = 0.0;        // 0..1 additive colour flash from the edges
uniform float grain = 0.025;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float r = length(c);
	vec2 dir = normalize(c + 1e-5);
	// Chromatic aberration grows toward the edges.
	float ab = aberration * 0.012 * r;
	vec3 col;
	if (warp > 0.001) {
		// Radial blur: a few taps along the direction to the centre.
		vec3 acc = vec3(0.0);
		float total = 0.0;
		for (int i = 0; i < 6; i++) {
			float k = float(i) / 5.0;
			vec2 off = -dir * r * warp * 0.09 * k;
			float w = 1.0 - k * 0.6;
			acc.r += texture(screen, uv + off + dir * ab).r * w;
			acc.g += texture(screen, uv + off).g * w;
			acc.b += texture(screen, uv + off - dir * ab).b * w;
			total += w;
		}
		col = acc / total;
	} else {
		col.r = texture(screen, uv + dir * ab).r;
		col.g = texture(screen, uv).g;
		col.b = texture(screen, uv - dir * ab).b;
	}
	// Colour pulse bleeding in from the edges (kills, specials, hits).
	float edge = smoothstep(0.25, 0.9, r);
	col += pulse_color.rgb * pulse * edge * 0.9;
	// Subtle film grain keeps gradients from banding.
	col += (hash(uv * 1000.0 + vec2(TIME)) - 0.5) * grain;
	// Soft edge darkening.
	col *= 1.0 - smoothstep(0.55, 1.1, r) * 0.35;
	COLOR = vec4(col, 1.0);
}
