class_name Pickup
extends Node3D
## Power-up dropped by enemies: "weapon" (+1 weapon level) or "repair" (+1 hull).

const COLLECT_RADIUS := 2.0
const MAGNET_RADIUS := 7.0

var kind := "weapon"
var s := 0.0
var th := 0.0
var h := 1.0
var age := 0.0
var _spin: Node3D
var _halo: Node3D


func setup(p_kind: String, p_s: float, p_th: float) -> void:
	kind = p_kind
	s = p_s
	th = p_th
	var model := Meshes.pickup(kind)
	add_child(model)
	_spin = model.get_node("Spin")
	_halo = model.get_node("Halo")


func step(dt: float, player: Player) -> void:
	age += dt
	_spin.rotation.y += dt * 3.0
	_halo.rotation.z += dt * 1.5
	_halo.scale = Vector3.ONE * (1.0 + sin(age * 6.0) * 0.12)
	h = 1.0 + sin(age * 4.0) * 0.2
	var dist := Track.distance(s, th, h, player.s, player.th, Player.H)
	if dist < MAGNET_RADIUS:
		th = lerp_angle(th, player.th, minf(1.0, dt * 5.0))
		s = lerpf(s, player.s, minf(1.0, dt * 4.0))


func color() -> Color:
	return EnemyTypes.WEAPON_COLOR if kind == "weapon" else EnemyTypes.REPAIR_COLOR
