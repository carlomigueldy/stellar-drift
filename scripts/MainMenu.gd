extends Control

@onready var high_score_label: Label = $VBox/HighScore
@onready var start_button: Button = $VBox/StartButton
@onready var quit_button: Button = $VBox/QuitButton

func _ready() -> void:
	high_score_label.text = "High Score: %d" % GameState.high_score
	start_button.pressed.connect(_on_start)
	quit_button.pressed.connect(_on_quit)
	start_button.grab_focus()

func _on_start() -> void:
	GameState.reset_run()
	get_tree().change_scene_to_file("res://scenes/game/Game.tscn")

func _on_quit() -> void:
	get_tree().quit()
