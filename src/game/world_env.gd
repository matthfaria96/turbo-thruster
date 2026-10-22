class_name WorldEnv
extends WorldEnvironment
## Shared environment: dim nebula sky and an HDR bloom tuned so only bright
## gameplay objects (> 1.0) glow. Tunnel walls and sky stay below threshold.

const SKY_SHADER := preload("res://src/shaders/sky.gdshader")

var tint := Color(0.3, 0.5, 1.0)


func _ready() -> void:
	var env := Environment.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	sky_mat.set_shader_parameter("color_a", tint.darkened(0.82))
	sky_mat.set_shader_parameter("color_b", Color(tint.b, tint.r * 0.4, tint.g, 1.0).darkened(0.8))
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.glow_normalized = false
	env.glow_hdr_threshold = 0.95
	env.glow_bloom = 0.0
	env.glow_strength = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	for i in 7:
		env.set_glow_level(i, i in [1, 2, 3, 4, 5])
	environment = env
	_apply_settings()
	Save.settings_changed.connect(_apply_settings)


func _apply_settings() -> void:
	var strength := float(Save.settings.glow)
	environment.glow_enabled = strength > 0.01
	environment.glow_intensity = 0.85 * strength
