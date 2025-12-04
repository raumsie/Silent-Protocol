extends CharacterBody2D

@export var speed: int = 200
@export var color: Color = Color.BLUE
@export var camera_zoom: float = 1.5 

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
#@onready var visual: ColorRect = $ColorRect
@onready var camera: Camera2D = $Camera2D

# Sprite
@onready var sprite: Sprite2D = $Sprite2D
var is_alive: bool = true

@export var max_health: int = 100
@export var health: int = 100
@export var damage_flash_duration: float = 0.1

@export var acceleration: float = 15.0
@export var friction: float = 10.0

@export_group("Combat")
@export var pistol_damage: int = 1
@export var melee_range: float = 50.0
@export var melee_damage: int = 999  # Instant kill
@export var can_shoot: bool = true
@export var can_melee: bool = true

var current_weapon: String = "pistol"
var is_reloading: bool = false

@export var reticle_scene: PackedScene
var reticle: Node2D
var is_aiming: bool = false

func _ready():
	#setup_visual()
	setup_camera()
	setup_reticle()
	print("Player initialized with ", health, "/", max_health, " health")

func setup_reticle():
	if reticle_scene:
		reticle = reticle_scene.instantiate()
		get_parent().add_child(reticle)  # Add to level, not player
		print("Reticle created")

func shoot():
	if not can_shoot or is_reloading or not reticle:
		return
	
	print("Player shooting!")
	
	# Raycast from player to reticle
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		global_position,
		reticle.global_position
	)
	query.collision_mask = 2  # Enemy collision layer
	
	var result = space_state.intersect_ray(query)
	
	if result:
		var collider = result["collider"]
		if collider and collider.is_in_group("enemy"):
			print("Hit enemy!")
			collider.take_damage(pistol_damage, global_position)
	
	# Optional: Add shooting effects
	# - Muzzle flash
	# - Sound
	# - Recoil animation

func _on_reload_finished():
	is_reloading = false

func _input(event):
	# Mouse movement for reticle
	if event is InputEventMouseMotion and reticle:
		var mouse_pos = get_global_mouse_position()
		reticle.set_target_position(mouse_pos)
	
	# Aim toggle (right mouse button)
	if event.is_action_pressed("aim"):
		is_aiming = true
		# Optional: Slow player movement while aiming
	elif event.is_action_released("aim"):
		is_aiming = false
	
	# Shooting (left mouse button)
	if event.is_action_pressed("shoot") and is_aiming:
		shoot()
	
	# Melee (F key)
	if event.is_action_pressed("melee"):
		melee_attack()


func melee_attack():
	if not can_melee:
		return
	
	print("Attempting melee attack")
	
	# Check for enemies in melee range
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = melee_range
	query.shape = circle_shape
	query.transform = global_transform
	query.collision_mask = 2  # Enemy layer
	
	var results = space_state.intersect_shape(query)
	
	for result in results:
		var enemy = result["collider"]
		if enemy and enemy.is_in_group("enemy"):
			# Check if player is behind enemy (out of vision)
			if is_behind_enemy(enemy):
				print("Melee takedown successful!")
				enemy.takedown()
				break
			else:
				print("Melee failed: enemy can see you!")
				# Alert the enemy
				enemy.player_detected(self)

func is_behind_enemy(enemy) -> bool:
	var direction_to_player = (global_position - enemy.global_position).normalized()
	var enemy_forward = Vector2.RIGHT.rotated(enemy.rotation)
	
	# If dot product is negative, player is behind enemy
	return direction_to_player.dot(enemy_forward) < 0

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

func take_damage(amount: int):
	if not is_alive:
		return
	
	health -= amount
	print("Player took ", amount, " damage. Current health: ", health)
	
	# Emit signal for UI/other systems
	GameManager.player_damaged.emit(health, max_health)
	
	# Red flash effect
	damage_flash()
	
	if health <= 0:
		die()

func damage_flash():
	# Store original modulate
	var original_modulate = modulate
	
	# Flash red
	modulate = Color.RED
	await get_tree().create_timer(damage_flash_duration).timeout
	
	# Return to normal
	modulate = original_modulate

func die():
	if not is_alive:
		return
	
	print("Player has died.")
	is_alive = false
	GameManager.lose_game()
	
	
