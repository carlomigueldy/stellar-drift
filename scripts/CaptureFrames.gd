extends Node

# One-shot capture sequencer for README screenshots.
# Loads each scene in turn, waits for it to render, saves a PNG, then quits.
# Run with: godot res://scenes/capture/Capture.tscn

const TARGETS := [
	{"scene": "res://scenes/menus/MainMenu.tscn", "out": "user://capture_menu.png"},
	{"scene": "res://scenes/menus/GameOver.tscn", "out": "user://capture_gameover.png"},
]

var _idx: int = 0

func _ready() -> void:
	GameState.score = 1240
	GameState.high_score = 1240
	# Reparent to the root window so we survive scene swaps.
	var parent := get_parent()
	parent.call_deferred("remove_child", self)
	get_tree().root.call_deferred("add_child", self)
	call_deferred("_run")

func _run() -> void:
	await get_tree().process_frame
	_next()

func _next() -> void:
	if _idx >= TARGETS.size():
		print("[capture] done")
		get_tree().quit()
		return
	var t: Dictionary = TARGETS[_idx]
	get_tree().change_scene_to_file(t["scene"])
	for i in range(6):
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(t["out"])
	print("[capture] saved ", t["out"])
	_idx += 1
	await get_tree().process_frame
	_next()
