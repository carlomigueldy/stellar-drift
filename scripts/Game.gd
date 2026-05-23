extends Node2D

const ARENA_RECT := Rect2(80, 80, 1120, 560)
const ASTEROID_COUNT := 10

@export var asteroid_scene: PackedScene

@onready var arena: Node2D = $Arena
@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $Camera2D

var _shake_time: float = 0.0
var _shake_strength: float = 0.0
var _camera_home: Vector2

func _ready() -> void:
	GameState.reset_run()
	_camera_home = camera.position
	_scatter_asteroids()
	if player:
		if not player.died.is_connected(_on_player_died):
			player.died.connect(_on_player_died)
		if not player.damaged.is_connected(_on_player_damaged):
			player.damaged.connect(_on_player_damaged)

func _process(delta: float) -> void:
	if _shake_time > 0.0:
		_shake_time -= delta
		var offset := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_strength
		camera.position = _camera_home + offset
		if _shake_time <= 0.0:
			camera.position = _camera_home

func _on_player_damaged() -> void:
	_shake_time = 0.28
	_shake_strength = 10.0

func _scatter_asteroids() -> void:
	if asteroid_scene == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var placed: Array[Vector2] = []
	var attempts := 0
	while placed.size() < ASTEROID_COUNT and attempts < 200:
		attempts += 1
		var p := Vector2(
			rng.randf_range(ARENA_RECT.position.x, ARENA_RECT.end.x),
			rng.randf_range(ARENA_RECT.position.y, ARENA_RECT.end.y)
		)
		if p.distance_to(Vector2(640, 360)) < 140.0:
			continue
		var ok := true
		for q in placed:
			if p.distance_to(q) < 90.0:
				ok = false
				break
		if not ok:
			continue
		var a: Node2D = asteroid_scene.instantiate()
		a.position = p
		arena.add_child(a)
		placed.append(p)

func _on_player_died() -> void:
	GameState.report_game_over()
	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://scenes/menus/GameOver.tscn")
