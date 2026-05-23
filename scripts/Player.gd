extends CharacterBody2D

signal died

@export var speed: float = 320.0
@export var accel: float = 1800.0
@export var friction: float = 1500.0
@export var fire_rate: float = 0.18
@export var bullet_scene: PackedScene
@export var max_hp: int = 3
@export var invuln_time: float = 0.6

@onready var sprite: Sprite2D = $Sprite
@onready var muzzle: Marker2D = $Muzzle

var hp: int = 3
var _invuln: float = 0.0
var _shoot_cooldown: float = 0.0

func _ready() -> void:
	hp = max_hp
	add_to_group("player")
	GameState.report_player_hp(hp)

func _physics_process(delta: float) -> void:
	_invuln = maxf(0.0, _invuln - delta)
	_shoot_cooldown = maxf(0.0, _shoot_cooldown - delta)

	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir.length() > 0.0:
		velocity = velocity.move_toward(input_dir * speed, accel * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	move_and_slide()

	look_at(get_global_mouse_position())

	if Input.is_action_pressed("shoot") and _shoot_cooldown <= 0.0:
		_shoot()
		_shoot_cooldown = fire_rate

func _shoot() -> void:
	if bullet_scene == null:
		return
	var b: Node2D = bullet_scene.instantiate()
	b.global_position = muzzle.global_position
	b.rotation = rotation
	get_parent().add_child(b)

func take_damage(amount: int = 1) -> void:
	if _invuln > 0.0:
		return
	hp = max(0, hp - amount)
	GameState.report_player_hp(hp)
	_invuln = invuln_time
	if hp <= 0:
		died.emit()
		queue_free()

func is_invulnerable() -> bool:
	return _invuln > 0.0
