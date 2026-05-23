extends Node

# Auto-pilots the player for demo recording.
# Add as a child of the Game scene; it finds the Player by group on _ready.
#
# Behavior: orbits the arena center, faces the nearest enemy (or screen center
# if none), and fires periodically. Also takes screenshots at scripted moments.

@export var orbit_radius: float = 220.0
@export var orbit_speed: float = 1.1  # radians per second
@export var fire_interval: float = 0.18
@export var screenshot_times: Array[float] = []
@export var screenshot_prefix: String = "user://screenshot_"

var _player: Node2D
var _t: float = 0.0
var _fire_timer: float = 0.0
var _screenshots_taken: int = 0

func _ready() -> void:
	await get_tree().process_frame
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]

func _process(delta: float) -> void:
	_t += delta
	if _player == null or not is_instance_valid(_player):
		_maybe_screenshot()
		return

	# Drive position: orbit around arena center
	var center := Vector2(640, 360)
	var target := center + Vector2(cos(_t * orbit_speed), sin(_t * orbit_speed)) * orbit_radius
	_player.global_position = _player.global_position.lerp(target, 0.12)

	# Drive rotation: face nearest enemy, else face forward (right)
	var target_pos := _find_nearest_enemy_position()
	if target_pos == Vector2.ZERO:
		# face away from center for visual variety
		target_pos = _player.global_position + (_player.global_position - center).normalized() * 100
	_player.look_at(target_pos)

	# Drive shooting
	_fire_timer = maxf(0.0, _fire_timer - delta)
	if _fire_timer <= 0.0 and _player.has_method("_shoot"):
		_player._shoot()
		_fire_timer = fire_interval

	_maybe_screenshot()

func _find_nearest_enemy_position() -> Vector2:
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return Vector2.ZERO
	var best: Node2D = null
	var best_d := INF
	for e in enemies:
		var n: Node2D = e
		var d := n.global_position.distance_to(_player.global_position)
		if d < best_d:
			best_d = d
			best = n
	return best.global_position if best else Vector2.ZERO

func _maybe_screenshot() -> void:
	if _screenshots_taken >= screenshot_times.size():
		return
	var due_at: float = screenshot_times[_screenshots_taken]
	if _t < due_at:
		return
	_screenshots_taken += 1
	var img := get_viewport().get_texture().get_image()
	var path := "%s%02d.png" % [screenshot_prefix, _screenshots_taken]
	img.save_png(path)
	print("[demo] screenshot ", _screenshots_taken, " -> ", path, " at t=", "%.2f" % _t)
