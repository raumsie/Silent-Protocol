extends CharacterBody2D

@export var speed: int = 200
@export var color: Color = Color.BLUE
@export var camera_zoom: float = 1.5 

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
#@onready var visual: ColorRect = $ColorRect
@onready var camera: Camera2D = $Camera2D

@export var acceleration: float = 15.0
@export var friction: float = 10.0

func _ready():
	#setup_visual()
	setup_camera()

#func setup_visual():
	#visual.color = color
	#visual.size = Vector2(24, 32)
	#visual.position = Vector2(-12, -16)

func setup_camera():
	camera.zoom = Vector2(camera_zoom, camera_zoom)
	camera.enabled = true
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0

func get_input() -> Vector2:
	var input_direction = Vector2.ZERO
	input_direction.x = Input.get_axis("ui_left", "ui_right")
	input_direction.y = Input.get_axis("ui_up", "ui_down")
	return input_direction.normalized() if input_direction.length() > 0 else Vector2.ZERO

func _physics_process(delta):
	var direction = get_input()
	
	if direction != Vector2.ZERO:
		
		velocity = velocity.move_toward(direction * speed, acceleration)
	else:
		# Apply friction when not using movement keys
		velocity = velocity.move_toward(Vector2.ZERO, friction)
	
	move_and_slide()
