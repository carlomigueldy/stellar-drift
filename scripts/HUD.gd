extends CanvasLayer

@onready var score_label: Label = $Root/TopLeft/Score
@onready var wave_label: Label = $Root/TopLeft/Wave
@onready var hearts: HBoxContainer = $Root/TopRight/Hearts

@export var heart_texture: Texture2D

func _ready() -> void:
	GameState.score_changed.connect(_on_score_changed)
	GameState.wave_changed.connect(_on_wave_changed)
	GameState.player_hp_changed.connect(_on_hp_changed)
	_on_score_changed(GameState.score)
	_on_wave_changed(GameState.wave)
	_on_hp_changed(3)

func _on_score_changed(s: int) -> void:
	score_label.text = "Score: %d" % s

func _on_wave_changed(w: int) -> void:
	wave_label.text = "Wave: %d" % w

func _on_hp_changed(hp: int) -> void:
	for c in hearts.get_children():
		c.queue_free()
	for i in hp:
		var heart_rect := TextureRect.new()
		heart_rect.texture = heart_texture
		heart_rect.custom_minimum_size = Vector2(36, 36)
		heart_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		heart_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hearts.add_child(heart_rect)
