extends Area2D

@export var speed: float = 900.0
@export var lifetime: float = 1.2
@export var damage: int = 1

var _time_alive: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	position += Vector2.RIGHT.rotated(rotation) * speed * delta
	_time_alive += delta
	if _time_alive >= lifetime:
		queue_free()

func _on_body_entered(body: Node) -> void:
	_try_hit(body)
	queue_free()

func _on_area_entered(area: Area2D) -> void:
	_try_hit(area)
	queue_free()

func _try_hit(node: Node) -> void:
	if node.has_method("take_damage"):
		node.take_damage(damage)
