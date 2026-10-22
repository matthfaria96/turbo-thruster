class_name MenuBackdrop
extends Node3D
## Slow fly-through of the tunnel behind the menus.

var _track: Track
var _tunnel: Tunnel
var _camera: Camera3D
var _ship: Node3D
var _space: SpaceBackdrop
var _s := 40.0
var _t := 0.0


func _ready() -> void:
	add_child(WorldEnv.new())
	_space = SpaceBackdrop.new()
	add_child(_space)
	_space.setup(Color(0.35, 0.5, 1.0))
	_track = Track.new(0.7, 7)
	_tunnel = Tunnel.new()
	_tunnel.setup(_track, Color(0.35, 0.5, 1.0))
	_tunnel.set_brightness(0.8)
	add_child(_tunnel)
	_ship = Meshes.ship()
	add_child(_ship)
	var trail := Fx.make_trail(EnemyTypes.PLAYER_COLOR)
	trail.position = Vector3(0, 0, 1.1)
	_ship.add_child(trail)
	trail.emitting = true
	_camera = Camera3D.new()
	_camera.fov = 70.0
	_camera.far = 420.0
	add_child(_camera)
	_camera.current = true
	_process(0.0)


func _process(delta: float) -> void:
	_t += delta
	_s += 22.0 * delta
	var th := sin(_t * 0.35) * 0.8
	_ship.global_transform = _track.pose(_s + 10.0, th, Player.H + 0.4)
	_ship.rotation.z += sin(_t * 0.7) * 0.25
	var eye := _track.point(_s, th * 0.6, Track.RADIUS - 3.4)
	var target := _track.point(_s + 30.0, th * 0.6, Track.RADIUS - 2.0)
	_camera.look_at_from_position(eye, target, -Track.radial(_track.frame(_s), th * 0.6))
	_tunnel.update_view(_s)
	_space.follow(_camera, delta)
