// The Compatibility renderer (used by the web build) shows 3D colours as if
// they were decoded from sRGB one extra time, which crushes the dim neon
// (tunnel, sky, glass) to black. Encode them once more there so it matches
// the Mobile renderer; elsewhere this is a no-op.
vec3 compat_color(vec3 c) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 x = max(c, vec3(0.0));
	return mix(x * 12.92, 1.055 * pow(x, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), x));
#else
	return c;
#endif
}
