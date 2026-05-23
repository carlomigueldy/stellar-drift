extends Node

signal score_changed(new_score: int)
signal wave_changed(new_wave: int)
signal player_hp_changed(new_hp: int)
signal game_over_requested

const SAVE_PATH := "user://highscore.cfg"

var score: int = 0
var wave: int = 0
var high_score: int = 0

func _ready() -> void:
	_load_high_score()

func reset_run() -> void:
	score = 0
	wave = 0
	score_changed.emit(score)
	wave_changed.emit(wave)

func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)

func set_wave(new_wave: int) -> void:
	wave = new_wave
	wave_changed.emit(wave)

func report_player_hp(hp: int) -> void:
	player_hp_changed.emit(hp)

func report_game_over() -> void:
	if score > high_score:
		high_score = score
		_save_high_score()
	game_over_requested.emit()

func _save_high_score() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("score", "high", high_score)
	cfg.save(SAVE_PATH)

func _load_high_score() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		high_score = int(cfg.get_value("score", "high", 0))
