class_name WorldEnv
extends WorldEnvironment
## Shared environment: black background and an HDR bloom tuned so that only
## bright gameplay objects (> 1.0) glow. Tunnel walls stay below threshold.


func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0)
	env.glow_normalized = false
	env.glow_hdr_threshold = 0.95
	env.glow_bloom = 0.0
	env.glow_strength = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	for i in 7:
		env.set_glow_level(i, i in [1, 2, 3, 4])
	environment = env
	_apply_settings()
	Save.settings_changed.connect(_apply_settings)


func _apply_settings() -> void:
	var strength := float(Save.settings.glow)
	environment.glow_enabled = strength > 0.01
	environment.glow_intensity = 0.9 * strength
