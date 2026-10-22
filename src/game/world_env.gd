class_name WorldEnv
extends WorldEnvironment
## Shared environment: vivid nebula sky, ACES tonemapping with boosted
## saturation and a wide multi-level HDR bloom. Gameplay objects are
## rendered above 1.0 so they bloom; tunnel and sky stay below.

const SKY_SHADER := preload("res://src/shaders/sky.gdshader")

var tint := Color(0.3, 0.5, 1.0)


func _ready() -> void:
	var env := Environment.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	sky_mat.set_shader_parameter("color_a", tint.darkened(0.7))
	sky_mat.set_shader_parameter("color_b", Color(tint.b, tint.r * 0.5, tint.g, 1.0).darkened(0.72))
	sky_mat.set_shader_parameter("intensity", 0.6)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.22
	env.adjustment_contrast = 1.06
	env.adjustment_brightness = 1.02
	env.glow_normalized = false
	env.glow_hdr_threshold = 0.95
	env.glow_bloom = 0.0
	env.glow_strength = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	for i in 7:
		env.set_glow_level(i, i in [1, 2, 3, 4, 5])
	environment = env
	_apply_settings()
	Save.settings_changed.connect(_apply_settings)


func _apply_settings() -> void:
	var strength := float(Save.settings.glow)
	environment.glow_enabled = strength > 0.01
	environment.glow_intensity = 0.9 * strength
