extends StaticBody2D

@export var max_hp: int = 2
@export var score_value: int = 5

var hp: int

func _ready() -> void:
	hp = max_hp

func take_damage(amount: int = 1) -> void:
	hp -= amount
	if hp <= 0:
		GameState.add_score(score_value)
		queue_free()
