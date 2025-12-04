extends Node2D

@export var reticle_speed: float = 10.0
var target_position: Vector2 = Vector2.ZERO

func _ready():
    # Start at player position
    global_position = get_parent().global_position

func _process(delta):
    # Smoothly move towards target position (mouse position)
    global_position = global_position.lerp(target_position, reticle_speed * delta)

func set_target_position(position: Vector2):
    target_position = position