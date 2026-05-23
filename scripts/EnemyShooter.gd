extends CharacterBody2D

const EXPLOSION_SCENE := preload("res://scenes/actors/Explosion.tscn")

@export var speed: float = 110.0
@export var preferred_distance: float = 320.0
@export var distance_tolerance: float = 40.0
@export var max_hp: int = 2
@export var contact_damage: int = 1
@export var score_value: int = 25
@export var fire_interval: float = 1.5
@export var bullet_scene: PackedScene

var hp: int
var _fire_cooldown: float = 0.0

func _ready() -> void:
	hp = max_hp
	add_to_group("enemies")
	_fire_cooldown = randf_range(0.4, fire_interval)

func _physics_process(delta: float) -> void:
	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	var player := _find_player()
	if player == null:
		return
	var to_player := player.global_position - global_position
	var dist := to_player.length()
	var dir := to_player.normalized()
	look_at(player.global_position)

	if dist > preferred_distance + distance_tolerance:
		velocity = dir * speed
	elif dist < preferred_distance - distance_tolerance:
		velocity = -dir * speed
	else:
		velocity = velocity.move_toward(Vector2.ZERO, speed * 2.0 * delta)
	move_and_slide()

	if _fire_cooldown <= 0.0 and bullet_scene != null:
		_fire(dir)
		_fire_cooldown = fire_interval

func _fire(dir: Vector2) -> void:
	var b: Node2D = bullet_scene.instantiate()
	b.global_position = global_position + dir * 32.0
	b.rotation = dir.angle()
	get_parent().add_child(b)

func _find_player() -> Node2D:
	var nodes := get_tree().get_nodes_in_group("player")
	return nodes[0] if nodes.size() > 0 else null

func take_damage(amount: int = 1) -> void:
	hp -= amount
	if hp <= 0:
		GameState.add_score(score_value)
		_spawn_explosion()
		queue_free()

func _spawn_explosion() -> void:
	var e: Node2D = EXPLOSION_SCENE.instantiate()
	e.global_position = global_position
	get_parent().add_child(e)
