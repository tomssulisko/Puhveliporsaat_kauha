extends Sprite2D

const TEXTURES: Array[String] = [
	"res://Effects/darksumu1.png",
	"res://Effects/darksumu2.png",
	"res://Effects/darksumu3.png",
]

@export var base_speed: float = 0.18
@export var speed_variation: float = 0.12

var _angular_velocity: float = 0.0


func setup(clockwise: bool) -> void:
	texture = load(TEXTURES[randi() % TEXTURES.size()]) as Texture2D
	var speed := base_speed + randf_range(-speed_variation, speed_variation)
	_angular_velocity = speed if clockwise else -speed
	rotation = randf() * TAU


func _process(delta: float) -> void:
	rotation += _angular_velocity * delta
