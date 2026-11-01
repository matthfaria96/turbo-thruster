extends Node
## Touch play in the browser (phones, tablets). The page (web/shell.html)
## draws the on-screen controls under the game during a run and sends them
## here as input actions; the game tells the page when a run starts and ends
## and what the buttons should show (bombs, nitro, charge).
## Run with `-- --mobile` on desktop to preview the touch layout.

## Smaller design size so menus and HUD stay readable on a phone screen:
## the short side of the screen maps to 720 units instead of 720 × (1280 wide).
const DESIGN_SIZE := Vector2i(720, 720)
const HUD_PUSH_SECONDS := 0.1

var enabled := false
var _web := false
var _input_cb: JavaScriptObject
var _in_match := false
var _hud_t := 0.0
var _last_hud := ""


func _ready() -> void:
	_web = OS.has_feature("web")
	# A finger as the main pointer (phones, tablets), not a laptop that also has a touch screen.
	enabled = "--mobile" in OS.get_cmdline_user_args() \
		or (_web and bool(JavaScriptBridge.eval("window.matchMedia('(pointer: coarse)').matches", true)))
	if not enabled:
		return
	get_window().min_size = Vector2i.ZERO
	get_window().content_scale_size = DESIGN_SIZE
	if _web:
		_input_cb = JavaScriptBridge.create_callback(_on_page_input)
		JavaScriptBridge.get_interface("window").ttInput = _input_cb
		_eval("window.ttReady && window.ttReady()")


## Called by the page: [action, pressed, strength].
func _on_page_input(args: Array) -> void:
	var ev := InputEventAction.new()
	ev.action = String(args[0])
	ev.pressed = bool(args[1])
	ev.strength = float(args[2]) if args.size() > 2 else 1.0
	Input.parse_input_event(ev)


## A run is on screen: the page shows the controls under the game.
func set_match(active: bool) -> void:
	if not enabled or active == _in_match:
		return
	_in_match = active
	_last_hud = ""
	_eval("window.ttMatch && window.ttMatch(%s)" % ("true" if active else "false"))


## Button state shown by the page: bombs left, nitro 0..1, charge 0..1.
func push_hud(bombs: int, nitro: float, charge: float, dt: float) -> void:
	if not _in_match:
		return
	_hud_t -= dt
	if _hud_t > 0.0:
		return
	_hud_t = HUD_PUSH_SECONDS
	var payload := "%d,%.2f,%.2f" % [bombs, nitro, charge]
	if payload != _last_hud:
		_last_hud = payload
		_eval("window.ttHud && window.ttHud(%s)" % payload)


func _eval(code: String) -> void:
	if _web:
		JavaScriptBridge.eval(code, true)
