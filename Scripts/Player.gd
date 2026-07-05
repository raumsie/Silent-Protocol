extends CharacterBody2D

@export var speed: int = 200
@export var color: Color = Color.BLUE
@export var camera_zoom: float = 1.5

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var camera: Camera2D = $Camera2D
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

# Animation (sprite sheet: hframes = 10, vframes = 13)
const IDLE_FRAME: int = 0
const RUN_ROW_BASE: int = 30  # row 3
const RUN_FRAME_COUNT: int = 4
const RUN_FPS: float = 8.0
const SHOOT_MELEE_ROW_BASE: int = 40  # row 4
const SHOOT_MELEE_FRAME_COUNT: int = 4
const DEATH_ROW_BASE: int = 50  # row 5
const DEATH_FRAME_COUNT: int = 7
const ONESHOT_FPS: float = 10.0
const FACING_MIN_X: float = 0.05

var anim_time: float = 0.0
var is_playing_oneshot: bool = false
var oneshot_token: int = 0

func _ready():
	setup_camera()
	setup_reticle()
	print("Player initialized with ", health, "/", max_health, " health")

func setup_reticle():
	if reticle_scene:
		reticle = reticle_scene.instantiate()
		# Player._ready() runs while its own parent (Level) is still setting up its
		# child tree, so an immediate add_child() here fails ("Parent node is busy
		# setting up children") and silently never parents the reticle - it then never
		# renders and its _process() never runs, freezing reticle.global_position at
		# whatever it was last set to instead of tracking the mouse. Defer both the
		# reparenting and the initial position set until the parent is free.
		call_deferred("_finish_reticle_setup")


func _finish_reticle_setup():
	get_parent().add_child(reticle)  # Add to level, not player
	reticle.global_position = global_position
	print("Reticle created")

func shoot():
	if not can_shoot or is_reloading or not reticle:
		return

	play_oneshot_animation(SHOOT_MELEE_ROW_BASE, SHOOT_MELEE_FRAME_COUNT, ONESHOT_FPS)

	print("Player shooting!")

	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		global_position,
		reticle.global_position
	)
	query.collision_mask = 1  # Enemy collision layer

	var result = space_state.intersect_ray(query)

	if result:
		var collider = result["collider"]
		if collider and collider.is_in_group("enemies"):
			print("Hit enemy!")
			collider.take_damage(pistol_damage, global_position)

	# TODO: shooting effects (muzzle flash, sound, recoil)

func _on_reload_finished():
	is_reloading = false

func _input(event):
	if event is InputEventMouseMotion and reticle:
		var mouse_pos = get_global_mouse_position()
		reticle.set_target_position(mouse_pos)

	if event.is_action_pressed("aim"):
		is_aiming = true
	elif event.is_action_released("aim"):
		is_aiming = false

	if event.is_action_pressed("shoot") and is_aiming:
		shoot()

	if event.is_action_pressed("melee"):
		melee_attack()


func melee_attack():
	if not can_melee:
		return

	play_oneshot_animation(SHOOT_MELEE_ROW_BASE, SHOOT_MELEE_FRAME_COUNT, ONESHOT_FPS)

	print("Attempting melee attack")

	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = melee_range
	query.shape = circle_shape
	query.transform = global_transform
	query.collision_mask = 1  # Enemy layer

	var results = space_state.intersect_shape(query)

	for result in results:
		var enemy = result["collider"]
		if enemy and enemy.is_in_group("enemies"):
			if not enemy.has_spotted_player():
				print("Melee takedown successful!")
				enemy.takedown()
				break
			else:
				print("Melee failed: enemy has already spotted the player!")
				enemy.player_detected(self)

# Secondary/unused-by-default facing check, kept available but no longer the success gate
# (gate is now Enemy.has_spotted_player() - see Scripts/Enemy.gd)
func is_behind_enemy(enemy) -> bool:
	var direction_to_player = (global_position - enemy.global_position).normalized()
	var enemy_forward = Vector2.RIGHT.rotated(enemy.rotation)

	# Negative dot product means the player is behind the enemy
	return direction_to_player.dot(enemy_forward) < 0

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
		velocity = velocity.move_toward(Vector2.ZERO, friction)

	move_and_slide()

	update_idle_run_animation(delta, velocity.length() > 0.1)
	update_facing_towards_reticle()

func update_idle_run_animation(delta: float, is_moving: bool) -> void:
	if is_playing_oneshot:
		return
	if is_moving:
		anim_time += delta
		sprite.frame = RUN_ROW_BASE + int(fmod(anim_time * RUN_FPS, RUN_FRAME_COUNT))
	else:
		anim_time = 0.0
		sprite.frame = IDLE_FRAME

# Face towards the aim reticle rather than movement direction
func update_facing_towards_reticle() -> void:
	if not reticle:
		return
	var to_reticle = reticle.global_position - global_position
	if abs(to_reticle.x) > FACING_MIN_X:
		sprite.flip_h = to_reticle.x < 0

func play_oneshot_animation(row_base: int, frame_count: int, fps: float) -> void:
	oneshot_token += 1
	var my_token = oneshot_token
	is_playing_oneshot = true

	for i in range(frame_count):
		if my_token != oneshot_token:
			return  # superseded by a newer one-shot trigger
		sprite.frame = row_base + i
		await get_tree().create_timer(1.0 / fps).timeout

	if my_token == oneshot_token:
		is_playing_oneshot = false

func take_damage(amount: int):
	if not is_alive:
		return

	health -= amount
	print("Player took ", amount, " damage. Current health: ", health)

	GameManager.player_damaged.emit(health, max_health)
	damage_flash()

	if health <= 0:
		die()

func damage_flash():
	var original_modulate = modulate
	modulate = Color.RED
	await get_tree().create_timer(damage_flash_duration).timeout
	modulate = original_modulate

func die():
	if not is_alive:
		return

	print("Player has died.")
	is_alive = false

	# Play the death clip fully before calling lose_game()
	await play_oneshot_animation(DEATH_ROW_BASE, DEATH_FRAME_COUNT, ONESHOT_FPS)

	GameManager.lose_game()
