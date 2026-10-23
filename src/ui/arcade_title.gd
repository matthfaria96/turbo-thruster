class_name ArcadeTitle
extends Control
## Animated 80s arcade heading: chrome-gradient letters with a solid neon
## outline, stacked 3D extrusion, an outer glow, a sweeping shine and a
## pop-in + gentle bob. Sizes are fixed so layouts never jump.

const SHADER := preload("res://src/shaders/chrome_text.gdshader")
const DEPTH := 5

var _text := ""
var _size := 64
var _accent := Color(1.0, 0.25, 0.75)
var _layers: Array[Label] = []
var _face: Label
var _t := 0.0


static func make(text: String, font_size := 64, accent := Color(1.0, 0.25, 0.75)) -> ArcadeTitle:
	var t := ArcadeTitle.new()
	t._text = text
	t._size = font_size
	t._accent = accent
	t._build()
	return t


func set_text(text: String) -> void:
	_text = text
	for l in _layers:
		l.text = text
	_face.text = text
	_fit()


func set_accent(color: Color) -> void:
	_accent = color
	_restyle()


func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, _size * 1.45)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pivot_offset = Vector2.ZERO
	# Glow + extrusion layers (back to front), then the chrome face.
	for i in DEPTH + 1:
		var l := _make_label()
		add_child(l)
		_layers.append(l)
	_face = _make_label()
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	_face.material = mat
	add_child(_face)
	_restyle()
	_fit()
	resized.connect(_layout)


## Minimum width = real text width, so the letters never overflow the box.
func _fit() -> void:
	var font := UiStyle.arcade_font()
	var w := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, _size).x
	var pad := _size * 0.1 * 2.0 + DEPTH * (_size / 40.0) + _size * 0.3
	custom_minimum_size = Vector2(w + pad, _size * 1.45)
	_layout()


## Every layer covers the whole box; extrusion layers are offset by depth.
func _layout() -> void:
	for i in _layers.size():
		var depth := 0.0 if i == 0 else float(_layers.size() - i)
		_layers[i].position = Vector2(depth, depth * 1.2) * (_size / 40.0)
		_layers[i].size = size
	_face.position = Vector2.ZERO
	_face.size = size


func _make_label() -> Label:
	var l := Label.new()
	l.text = _text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ls := LabelSettings.new()
	ls.font = UiStyle.arcade_font()
	ls.font_size = _size
	l.label_settings = ls
	return l


func _restyle() -> void:
	var outline := int(_size * 0.1)
	# Layer 0: soft outer glow.
	var glow := _layers[0].label_settings
	glow.font_color = Color(_accent, 0.0)
	glow.outline_size = outline + int(_size * 0.22)
	glow.outline_color = Color(_accent, 0.28)
	# Extrusion: solid, darkening toward the back.
	for i in range(1, _layers.size()):
		var ls := _layers[i].label_settings
		var depth := float(_layers.size() - i)
		var shade := _accent.darkened(0.35 + depth * 0.09)
		ls.font_color = shade
		ls.outline_size = outline
		ls.outline_color = shade
	var face := _face.label_settings
	face.font_color = Color(1, 1, 1)
	face.outline_size = outline
	face.outline_color = Color(0.1, 0.02, 0.2)
	var mat := _face.material as ShaderMaterial
	mat.set_shader_parameter("low", _accent.lightened(0.15))


func _process(delta: float) -> void:
	_t += delta
	var appear := ease(minf(1.0, _t / 0.45), 0.3)
	pivot_offset = size * 0.5
	# Pop in once, then stay at exactly 1:1 so the letters never resample.
	scale = Vector2.ONE * lerpf(1.35, 1.0, appear)
	modulate.a = appear
	var mat := _face.material as ShaderMaterial
	var font := UiStyle.arcade_font()
	var h := font.get_height(_size)
	mat.set_shader_parameter("height", h * 0.78)
	mat.set_shader_parameter("y_offset", (size.y - h) * 0.5 + h * 0.14)
	# Occasional neon flicker on the glow.
	var flicker := 0.28 if fmod(_t, 3.7) > 0.12 else 0.08
	_layers[0].label_settings.outline_color = Color(_accent, flicker)
