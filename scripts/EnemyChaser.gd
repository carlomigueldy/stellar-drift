extends CharacterBody2D

@export var speed: float = 130.0
@export var max_hp: int = 1
@export var contact_damage: int = 1
@export var score_value: int = 10

var hp: int

func _ready() -> void:
	hp = max_hp
	add_to_group("enemies")

func _physics_process(delta: float) -> void:
	var player := _find_player()
	if player == null:
		return
	var dir := (player.global_position - global_position).normalized()
	velocity = dir * speed
	look_at(player.global_position)
	var col := move_and_collide(velocity * delta)
	if col:
		var other := col.get_collider()
		if other and other.is_in_group("player") and other.has_method("take_damage"):
			other.take_damage(contact_damage)
			queue_free()

func _find_player() -> Node2D:
	var nodes := get_tree().get_nodes_in_group("player")
	return nodes[0] if nodes.size() > 0 else null

func take_damage(amount: int = 1) -> void:
	hp -= amount
	if hp <= 0:
		GameState.add_score(score_value)
		queue_free()
