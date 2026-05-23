extends Control

@onready var final_score_label: Label = $VBox/FinalScore
@onready var high_score_label: Label = $VBox/HighScore
@onready var retry_button: Button = $VBox/RetryButton
@onready var menu_button: Button = $VBox/MenuButton

func _ready() -> void:
	final_score_label.text = "Final Score: %d" % GameState.score
	high_score_label.text = "High Score: %d" % GameState.high_score
	retry_button.pressed.connect(_on_retry)
	menu_button.pressed.connect(_on_menu)
	retry_button.grab_focus()

func _on_retry() -> void:
	GameState.reset_run()
	get_tree().change_scene_to_file("res://scenes/game/Game.tscn")

func _on_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/MainMenu.tscn")
