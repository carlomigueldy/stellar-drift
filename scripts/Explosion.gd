extends Node2D

@export var lifetime: float = 0.9

@onready var particles: CPUParticles2D = $Particles
@onready var sfx: AudioStreamPlayer2D = $SFX

func _ready() -> void:
	particles.emitting = true
	_load_and_play_sfx()
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _load_and_play_sfx() -> void:
	var candidates := ["res://assets/audio/explosion.ogg", "res://assets/audio/explosion.wav"]
	for p in candidates:
		if ResourceLoader.exists(p):
			sfx.stream = load(p)
			sfx.play()
			return
