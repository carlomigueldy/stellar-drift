extends Node2D

const ARENA_RECT := Rect2(80, 80, 1120, 560)

func _ready() -> void:
	GameState.reset_run()
