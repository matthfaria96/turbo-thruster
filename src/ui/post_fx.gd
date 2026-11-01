class_name PostFx
extends CanvasLayer
## Screen-space effects layer under the HUD: aberration, warp and colour
## pulses. Game code calls `kick()` and `pulse()`; values decay on their own.

const SHADER := preload("res://src/shaders/post_fx.gdshader")

var _mat: ShaderMaterial
var _kick := 0.0
var _pulse := 0.0
var _pulse_color := Color.WHITE
var _speed_k := 0.0


func _ready() -> void:
	layer = 4
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	rect.material = _mat
	add_child(rect)


## Impact kick: aberration + warp spike that fades out.
func kick(amount: float) -> void:
	_kick = maxf(_kick, clampf(amount, 0.0, 1.0))


## Short coloured flash bleeding in from the screen edges.
func pulse(color: Color, amount := 0.6) -> void:
	_pulse_color = color
	_pulse = maxf(_pulse, clampf(amount, 0.0, 1.0))


## 0..1 how fast the ship is flying (drives the constant warp streaks).
func set_speed(k: float) -> void:
	_speed_k = clampf(k, 0.0, 1.0)


func _process(delta: float) -> void:
	_kick = move_toward(_kick, 0.0, delta * 2.6)
	_pulse = move_toward(_pulse, 0.0, delta * 2.2)
	var fx := float(Save.settings.get("glow", 1.0))
	_mat.set_shader_parameter("aberration", (0.12 + _speed_k * 0.45 + _kick * 2.0) * fx)
	# The radial warp reads the screen 18 times per pixel: too much for phones.
	var warp := 0.0 if Mobile.enabled else (_speed_k * _speed_k * 0.4 + _kick * 0.8) * fx
	_mat.set_shader_parameter("warp", warp)
	_mat.set_shader_parameter("pulse", _pulse * fx)
	_mat.set_shader_parameter("pulse_color", _pulse_color)
