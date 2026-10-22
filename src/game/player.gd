class_name Player
extends Node3D
## The ship. Weapon level and hull belong to the current sector only: a new
## Player is created for every sector, so nothing carries over.

signal nova_fired(s: float, th: float)

const H := 0.9
const BASE_SPEED := 34.0
const MAX_SPEED := 56.0
const MIN_SPEED := 16.0
const STEER := 2.6
const MAX_HULL := 4
const MAX_WEAPON := 5
const CHARGE_TIME := 0.85
const INVULN_TIME := 1.6
const FIRE_RATE := [0.0, 8.0, 9.0, 10.0, 12.0, 12.0]
const DAMAGE := [0.0, 1.0, 1.0, 1.0, 1.3, 1.3]
## [angle offset, angular velocity] per barrel.
const PATTERNS := [
	[],
	[[0.0, 0.0]],
	[[-0.05, 0.0], [0.05, 0.0]],
	[[-0.09, -0.25], [0.0, 0.0], [0.09, 0.25]],
	[[-0.09, -0.25], [0.0, 0.0], [0.09, 0.25]],
	[[-0.14, -0.45], [-0.06, -0.15], [0.0, 0.0], [0.06, 0.15], [0.14, 0.45]],
]

var s := 0.0
var th := 0.0
var speed := BASE_SPEED
var hull := MAX_HULL
var weapon := 1
var charge := 0.0
var invuln := 0.0
var alive := true
var min_speed_override := 0.0
var shield_t := 0.0
var rapid_t := 0.0

var _bank := 0.0
var _fire_cd := 0.0
var _charge_sound := false
var _model: Node3D
var _shield: Node3D


func _ready() -> void:
	_model = Meshes.ship()
	add_child(_model)
	_shield = Meshes.shield_bubble()
	_shield.visible = false
	add_child(_shield)
	var trail := Fx.make_trail(EnemyTypes.PLAYER_COLOR, 140, 0.28, 0.5)
	trail.position = Vector3(0, 0, 1.1)
	_model.add_child(trail)
	trail.emitting = true


## input: {x, y, fire, charge} — returns the shots fired this frame.
func step(dt: float, input: Dictionary) -> Array[Dictionary]:
	var shots: Array[Dictionary] = []
	invuln = maxf(0.0, invuln - dt)
	shield_t = maxf(0.0, shield_t - dt)
	rapid_t = maxf(0.0, rapid_t - dt)
	_shield.visible = shield_t > 0.0 and (shield_t > 1.5 or fmod(shield_t, 0.2) > 0.08)
	_shield.rotate_y(dt * 0.8)
	_shield.rotate_x(dt * 0.3)
	_fire_cd -= dt
	var y: float = input.y
	var target := BASE_SPEED + (y * (MAX_SPEED - BASE_SPEED) if y > 0.0 else y * (BASE_SPEED - MIN_SPEED))
	target = maxf(target, min_speed_override)
	speed = move_toward(speed, target, 45.0 * dt)
	s += speed * dt
	if not alive:
		return shots
	var x: float = input.x
	th = wrapf(th + x * STEER * dt, -PI, PI)
	_bank = lerpf(_bank, -x * 0.55, minf(1.0, 10.0 * dt))
	_model.rotation.z = _bank
	_model.visible = invuln <= 0.0 or fmod(invuln, 0.16) > 0.07
	if input.fire and _fire_cd <= 0.0:
		_fire_cd = 1.0 / (FIRE_RATE[weapon] * (1.9 if rapid_t > 0.0 else 1.0))
		shots = _make_shots()
		Sfx.play("shot", -16.0)
	_update_charge(dt, input.charge)
	return shots


func _make_shots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for barrel: Array in PATTERNS[weapon]:
		out.append({"s": s + 1.6, "ps": s + 1.6, "th": th + barrel[0], "h": H, "vs": speed + 150.0,
			"vth": barrel[1], "dmg": DAMAGE[weapon], "pierce": false, "size": 0.55, "life": 0.5})
	return out


func _update_charge(dt: float, held: bool) -> void:
	if held:
		charge = minf(1.0, charge + dt / CHARGE_TIME)
		if charge >= 1.0 and not _charge_sound:
			_charge_sound = true
			Sfx.play("charge", -6.0)
		return
	if charge >= 1.0:
		nova_fired.emit(s + 2.0, th)
	charge = 0.0
	_charge_sound = false


func nova_shot(at_s: float, at_th: float) -> Dictionary:
	return {"s": at_s, "ps": at_s, "th": at_th, "h": H, "vs": speed + 110.0, "vth": 0.0,
		"dmg": 12.0, "pierce": true, "size": 2.4, "life": 1.1}


## Returns true when the ship is destroyed.
func take_hit() -> bool:
	if invuln > 0.0 or not alive:
		return false
	if shield_t > 0.0:
		shield_t = 0.0
		invuln = 0.8
		return false
	hull -= 1
	weapon = maxi(1, weapon - 1)
	invuln = INVULN_TIME
	if hull <= 0:
		alive = false
		_model.visible = false
		return true
	return false


func upgrade_weapon() -> bool:
	if weapon >= MAX_WEAPON:
		return false
	weapon += 1
	return true


func repair() -> bool:
	if hull >= MAX_HULL:
		return false
	hull += 1
	return true
