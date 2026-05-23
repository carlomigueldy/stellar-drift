extends Node2D

const ARENA_RECT := Rect2(80, 80, 1120, 560)
const ASTEROID_COUNT := 10

@export var asteroid_scene: PackedScene

@onready var arena: Node2D = $Arena

func _ready() -> void:
	GameState.reset_run()
	_scatter_asteroids()

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
