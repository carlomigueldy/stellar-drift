extends Node

signal wave_cleared

@export var chaser_scene: PackedScene
@export var shooter_scene: PackedScene
@export var arena_rect: Rect2 = Rect2(80, 80, 1120, 560)
@export var wave_break_seconds: float = 2.0
@export var spawn_stagger_seconds: float = 0.35

var _current_wave: int = 0
var _alive_enemies: int = 0
var _spawning: bool = false

func _ready() -> void:
	await get_tree().process_frame
	_start_next_wave()

func _start_next_wave() -> void:
	_current_wave += 1
	GameState.set_wave(_current_wave)
	var count := _current_wave + 2
	var shooter_chance: float = clampf(float(_current_wave - 1) * 0.10, 0.0, 0.60)
	_spawning = true
	for i in count:
		_spawn_one(shooter_chance)
		await get_tree().create_timer(spawn_stagger_seconds).timeout
	_spawning = false
	_check_wave_clear()

func _spawn_one(shooter_chance: float) -> void:
	var use_shooter := shooter_scene != null and randf() < shooter_chance
	var scene := shooter_scene if use_shooter else chaser_scene
	if scene == null:
		return
	var e: Node2D = scene.instantiate()
	e.position = _random_edge_position()
	e.tree_exited.connect(_on_enemy_freed)
	get_parent().get_node("Arena").add_child(e)
	_alive_enemies += 1

func _random_edge_position() -> Vector2:
	var edge := randi() % 4
	match edge:
		0: return Vector2(arena_rect.position.x + randf() * arena_rect.size.x, arena_rect.position.y - 20)
		1: return Vector2(arena_rect.position.x + randf() * arena_rect.size.x, arena_rect.end.y + 20)
		2: return Vector2(arena_rect.position.x - 20, arena_rect.position.y + randf() * arena_rect.size.y)
		_: return Vector2(arena_rect.end.x + 20, arena_rect.position.y + randf() * arena_rect.size.y)

func _on_enemy_freed() -> void:
	_alive_enemies -= 1
	_check_wave_clear()

func _check_wave_clear() -> void:
	if _spawning or _alive_enemies > 0:
		return
	wave_cleared.emit()
	await get_tree().create_timer(wave_break_seconds).timeout
	_start_next_wave()
