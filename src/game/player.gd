class_name Player
extends Node3D
## The ship. Weapon level and hull belong to the current sector only: a new
## Player is created for every sector, so nothing carries over.

signal nova_fired(s: float, th: float)
signal lane_bump

const H := 0.9
const BASE_SPEED := 34.0
const MAX_SPEED := 56.0
const MIN_SPEED := 16.0
const NITRO_SPEED := 82.0
const NITRO_TIME := 4.0
const NITRO_COLOR := Color(1.0, 0.55, 0.15)
const STEER := 2.6
const MAX_HULL := 4
const MAX_WEAPON := 5
const CHARGE_TIME := 0.5
const NOVA_COLOR := Color(0.55, 0.85, 1.0)
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
## Cruise speed set by the game: rises on its own during the run.
var cruise := 30.0
## Nitro gauge 0..1 (filled by kills/geoms) and active boost time left.
var nitro := 0.0
var nitro_t := 0.0
var hull := MAX_HULL
var weapon := 1
var charge := 0.0
var invuln := 0.0
var alive := true
var min_speed_override := 0.0
var frozen := false
var external_drift := 0.0
var invert_x := false
var lane_center := 0.0
var lane_half := PI
var shield_t := 0.0
var rapid_t := 0.0

var _bank := 0.0
var _fire_cd := 0.0
var _charge_sound := false
var _model: Node3D
var _flares: Array[Node3D] = []
var _muzzle: Node3D
var _orb: Node3D
var _suction: GPUParticles3D
var _muzzle_t := 0.0
var specials := 2
const MAX_SPECIALS := 4
var _shield: Node3D


func _ready() -> void:
	_model = Meshes.ship()
	add_child(_model)
	_flares = [_model.get_node("FlareL"), _model.get_node("FlareR")]
	_muzzle = _model.get_node("Muzzle")
	_orb = Meshes.aura(NOVA_COLOR, 1.0, 1.1)
	_orb.position = Vector3(0, 0.1, -1.6)
	_orb.visible = false
	_model.add_child(_orb)
	_suction = Fx.make_suction(NOVA_COLOR)
	_suction.position = _orb.position
	_model.add_child(_suction)
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
	nitro_t = maxf(0.0, nitro_t - dt)
	var target := maxf(cruise, NITRO_SPEED if nitro_t > 0.0 else 0.0)
	target = maxf(target, min_speed_override)
	speed = 0.0 if frozen else move_toward(speed, target, (90.0 if nitro_t > 0.0 else 30.0) * dt)
	s += speed * dt
	if not alive:
		return shots
	var x: float = -float(input.x) if invert_x else float(input.x)
	th = wrapf(th + (x * STEER + external_drift) * dt, -PI, PI)
	_clamp_to_lane()
	_bank = lerpf(_bank, -x * 0.55, minf(1.0, 10.0 * dt))
	_model.rotation.z = _bank
	_model.visible = invuln <= 0.0 or fmod(invuln, 0.16) > 0.07
	var thrust := clampf((speed - MIN_SPEED) / (MAX_SPEED - MIN_SPEED), 0.0, 1.0)
	var flicker := 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.05)
	for f in _flares:
		f.scale = Vector3.ONE * (0.45 + thrust * 0.7) * flicker
	_muzzle_t = maxf(0.0, _muzzle_t - dt * 30.0)
	_muzzle.visible = _muzzle_t > 0.0
	_muzzle.scale = Vector3.ONE * (0.3 + _muzzle_t * 0.6) * (1.0 + weapon * 0.1)
	_muzzle.rotation.z += dt * 20.0
	if input.fire and _fire_cd <= 0.0:
		_fire_cd = 1.0 / (FIRE_RATE[weapon] * (1.9 if rapid_t > 0.0 else 1.0))
		shots = _make_shots()
		_muzzle_t = 1.0
		Sfx.play("shot", -16.0)
	_update_charge(dt, input.charge)
	_animate_charge()
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


## Energy ball growing at the nose while charging, particles sucked inward.
func _animate_charge() -> void:
	_orb.visible = charge > 0.02 and alive
	var flick := 0.9 + 0.1 * sin(Time.get_ticks_msec() * (0.04 if charge >= 1.0 else 0.02))
	_orb.scale = Vector3.ONE * (0.2 + charge * 0.6) * flick
	Meshes.set_param(_orb, "tint", NOVA_COLOR.lerp(Color(1, 1, 1), charge * charge))
	_suction.emitting = charge > 0.05 and alive
	_suction.amount_ratio = clampf(charge, 0.2, 1.0)


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


func add_nitro(amount: float) -> bool:
	var was_full := nitro >= 1.0
	nitro = minf(1.0, nitro + amount)
	return nitro >= 1.0 and not was_full


## Q: spend a full gauge on a burst of speed.
func fire_nitro() -> bool:
	if nitro < 1.0 or nitro_t > 0.0 or not alive:
		return false
	nitro = 0.0
	nitro_t = NITRO_TIME
	return true


func bank_amount() -> float:
	return _bank


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


## Keeps the ship inside the open part of the tunnel (lane modifier).
func _clamp_to_lane() -> void:
	if lane_half >= PI - 0.01:
		return
	var rel := Track.angle_diff(th, lane_center)
	if absf(rel) > lane_half:
		th = wrapf(lane_center + signf(rel) * lane_half, -PI, PI)
		lane_bump.emit()
