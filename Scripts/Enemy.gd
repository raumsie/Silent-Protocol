extends CharacterBody2D

# State enumeration
enum State { PATROL, COMBAT, SEARCH }

@export var vision_renderer: Polygon2D
@export var alert_color: Color = Color.RED
@export var search_color: Color = Color.ORANGE
@export var patrol_color: Color = Color(1, 1, 0, 0.3)

@export_group("State Settings")
@export var search_duration: float = 5.0
@export var combat_speed: float = 150.0
@export var patrol_speed: float = 50.0
@export var search_speed: float = 75.0

@export_group("Patrol Configuration")
@export var patrol_path: Path2D
@export var patrol_points: Array[Vector2] = []
@export var use_patrol_path: bool = false

@export_group("Rotation")
@export var is_rotating: bool = false
@export var rotation_speed: float = 0.1
@export var rotation_angle: float = 90

@export_group("Combat")
@export var health: int = 2
@export var can_be_meleed: bool = true
@export var damage_amount: int = 25
@export var attack_cooldown: float = 0.50

# Combat variables
var current_state: State = State.PATROL
var player_ref: Node2D = null
var can_attack: bool = true
var last_attack_time: float = 0.0

# State variables
var player_last_known_position: Vector2
var search_timer: float = 0.0
var patrol_index: int = 0
var path_follow: PathFollow2D

# Search variables
var search_center: Vector2
var search_radius: float = 100.0
var current_search_target: Vector2

# Combat variables
var combat_timer: float = 0.0
var max_combat_time: float = 10.0
var has_player_in_sight: bool = false

# Rotation variables
var rot_start: float = 0.0
var time_since_state_change: float = 0.0


# References
@onready var vision_cone = $VisionCone2D
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D

func _ready():
	rot_start = rotation
	can_attack = true

	setup_vision_renderer()
	setup_navigation()
	setup_patrol_path()
	
	# Wait for plugin to initialize
	await get_tree().create_timer(0.5).timeout
	force_vision_cone_update()
	
	set_state(State.PATROL)

func setup_navigation():
	if not navigation_agent:
		push_error("NavigationAgent2D not found")
		#navigation_agent = $NavigationAgent2D
	

	navigation_agent.path_desired_distance = 4.0
	navigation_agent.target_desired_distance = 4.0
	navigation_agent.path_max_distance = 1000.0
		
	if not navigation_agent.navigation_finished.is_connected(_on_navigation_finished):
		navigation_agent.navigation_finished.connect(_on_navigation_finished)
		# Wait for navigation to be ready
		#await get_tree().process_frame
		
	print("Navigation configured successfully")


func setup_patrol_path():
	if use_patrol_path and patrol_path:
		if patrol_path.get_child_count() > 0 and patrol_path.get_child(0) is PathFollow2D:
			path_follow = patrol_path.get_child(0) as PathFollow2D
			print("Using existing PathFollow2D for patrol path")
		else:
			path_follow = PathFollow2D.new()
			patrol_path.add_child(path_follow)
			print("Patrol path configured with new PathFollow2D")
		#path_follow = PathFollow2D.new()
		#patrol_path.add_child(path_follow)
		#print("Patrol path configured with Path2D")
	elif patrol_points.size() > 0:
		print("Manual patrol points configured: ", patrol_points.size())
	else:
		print("No patrol path - enemy will be stationary")

# State management
func set_state(new_state: State):
	if current_state == new_state:
		return
			
	print("Enemy state: ", State.keys()[current_state], " → ", State.keys()[new_state])

	match current_state:
		State.COMBAT:
			combat_timer = 0.0
			has_player_in_sight = false
			print("Exiting COMBAT state")

	current_state = new_state
	
	# State entry logic
	match current_state:
		State.PATROL:
			vision_renderer.color = patrol_color
			start_patrol()
		State.COMBAT:
			vision_renderer.color = alert_color
			GameManager.player_spotted.emit(self, player_last_known_position)
			start_combat()
		State.SEARCH:
			vision_renderer.color = search_color
			GameManager.player_lost.emit(self, player_last_known_position)
			start_search()


func setup_vision_renderer():
	if vision_renderer:
		vision_renderer.visible = true
		vision_renderer.z_index = 100
		vision_renderer.color = patrol_color

func force_vision_cone_update():
	if vision_cone and vision_cone.has_method("_update_render_polygon"):
		vision_cone._update_render_polygon()

# PATROL BEHAVIOR

func start_patrol():
	print("Starting patrol")
	if use_patrol_path and patrol_path and path_follow:
		path_follow.progress = 0.0
		global_position = path_follow.global_position
		print("Using Path2D for patrol")
	elif patrol_points.size() > 0:
		print("Using manual patrol points")
		find_closest_patrol_point()
	else:
		print("No patrol configured, enemy will remain stationary")

'''
func find_closest_point_on_path() -> Vector2:
	if not patrol_path or not path_follow:
		return global_position

	var curve = patrol_path.curve
	if curve.get_point_count() == 0:
		return global_position

	# Convert enemy position to local path coordinates
	var local_pos = patrol_path.to_local(global_position)

	# Find closest point on curve
	var closest_offset = curve.get_closest_offset(local_pos)

	# Get position of offset
	var closest_position = curve.sample_baked(closest_offset)

	return patrol_path.to_global(closest_position)
'''

func find_closest_patrol_point():
	if patrol_points.size() == 0:
		return

	var min_distance = INF
	var closest_index = 0

	for i in range(patrol_points.size()):
		var distance = global_position.distance_to(patrol_points[i])
		if distance < min_distance:
			min_distance = distance
			closest_index = i


	patrol_index = closest_index
	print("Resuming patrol at point index: ", patrol_index, " (distance: ", min_distance, ")")			



func start_combat():
	# Put combat logic here
	print("Starting combat")
	combat_timer = 0.0
	has_player_in_sight = true

func start_search():
	print("Starting search")
	search_timer = search_duration
	search_center = player_last_known_position
	pick_new_search_target()

func pick_new_search_target():
	var random_angle = randf() * 2 * PI
	var random_distance = randf() * search_radius
	current_search_target = search_center + Vector2(cos(random_angle), sin(random_angle)) * random_distance


func update_patrol(delta):
	if use_patrol_path and path_follow:
		# Direct path following
		path_follow.progress += patrol_speed * delta
		global_position = path_follow.global_position

		if path_follow.rotates:
			rotation = path_follow.rotation
		elif is_rotating:
			rotation = rot_start + sin(Time.get_ticks_msec()/1000.0 * rotation_speed) * deg_to_rad(rotation_angle/2.0)
					
	elif patrol_points.size() > 0:
		# Use navigation for manual patrol points
		if patrol_index < patrol_points.size():
			var target_point = patrol_points[patrol_index]
			move_towards_target(target_point, patrol_speed)
			
			if global_position.distance_to(target_point) < 15.0:
				patrol_index = (patrol_index + 1) % patrol_points.size()
				print("Moving to next patrol point: ", patrol_index)
				
			# Update rotation based on movement
			update_rotation_based_on_movement(delta)
	else:
		# Stationary patrol with rotation
		if is_rotating:
			rotation = rot_start + sin(Time.get_ticks_msec()/1000.0 * rotation_speed) * deg_to_rad(rotation_angle/2.0)


# COMBAT BEHAVIOR
func update_combat(delta):
	if current_state != State.COMBAT:
		return

	combat_timer += delta
	
	if combat_timer > max_combat_time and not has_player_in_sight:
		print("Max combat time exceeded, switching to SEARCH state")
		set_state(State.SEARCH)
		return
	
	if player_ref and is_instance_valid(player_ref) and has_player_in_sight:
		# Update last known position
		var distance_to_player = global_position.distance_to(player_ref.global_position)
		
		# Attack if player is in range and cooldown is ready
		if distance_to_player < 40.0 and can_attack:
			attack_player()
		
		# Move toward player if not in attack range
		elif distance_to_player > 45.0:
			move_towards_target(player_ref.global_position, combat_speed)
			
			# Face the player
			var direction_to_player = (player_ref.global_position - global_position).normalized()
			if direction_to_player.length() > 0.1:
				rotation = direction_to_player.angle()

	else:
		# Player not in sight 
		# Go to last known position
		move_towards_target(player_last_known_position, combat_speed)

		# Update rotation based on movement
		update_rotation_based_on_movement(delta)

		# If reached last known position, switch to SEARCH
		if global_position.distance_to(player_last_known_position) < 25.0:
			print("Reached last known player position, switching to SEARCH state")
			set_state(State.SEARCH)		

func attack_player():
	if not can_attack or not player_ref:
		return
	
	print("Enemy attacking player!")
	player_ref.take_damage(damage_amount)
	
	# Attack cooldown
	can_attack = false
	last_attack_time = Time.get_ticks_msec()
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true


func update_search(delta):
	search_timer -= delta

	# Return to patrol after search duration ends
	if search_timer <= 0:
		print("Search duration ended, returning to PATROL state")
		set_state(State.PATROL)
		return

	move_towards_target(current_search_target, search_speed)

	update_rotation_based_on_movement(delta)

	if global_position.distance_to(current_search_target) < 20.0 or randf() < 0.01:
		pick_new_search_target()

func update_rotation_based_on_movement(delta):
	# Only update rotation if moving
	if velocity.length() > 0.1:
		rotation = velocity.angle()
	elif is_rotating:
		rotation = rot_start + sin(Time.get_ticks_msec()/1000.0 * rotation_speed) * deg_to_rad(rotation_angle/2.0)


func move_towards_target(target_position: Vector2, movement_speed: float):
	if not navigation_agent:
		return
		
	navigation_agent.target_position = target_position
	
	if navigation_agent.is_navigation_finished():
		return
		
	var next_pos = navigation_agent.get_next_path_position()
	var direction = (next_pos - global_position).normalized()
	velocity = direction * movement_speed


func _on_navigation_finished():
	# Navigation target reached
	pass

func _physics_process(delta):
	# Reset velocity
	velocity = Vector2.ZERO

	# Update state behavior
	match current_state:
		State.PATROL:
			update_patrol(delta)
		State.COMBAT:
			update_combat(delta)
		State.SEARCH:
			update_search(delta)
	
	# Apply movement
	if velocity.length() > 0:
		move_and_slide()


func _on_vision_cone_area_2_body_entered(body: Node2D):
	if body == self or body.get_parent() == self:
		return
	  
	if body.name == "Player" or body.is_in_group("player"):
		print("Player detected by enemy")
		player_ref = body
		player_last_known_position = body.global_position
		has_player_in_sight = true

		# Always switch to COMBAT on detection
		if current_state != State.COMBAT:
			set_state(State.COMBAT)
			print("Enemy state: PATROL > COMBAT")


func _on_vision_cone_area_2_body_exited(body: Node2D):
	if body == self or body.get_parent() == self:
		return
		
	if body.name == "Player" or body.is_in_group("player"):
		print("Player lost by enemy")

		# Player lost, keep reference
		has_player_in_sight = false

		
		if current_state == State.COMBAT:
			current_state = State.SEARCH
			print("Enemy state: COMBAT > SEARCH")


func take_damage(damage: int, shot_from_position: Vector2):
	health -= damage
	print("Enemy took damage! Health: ", health)
	
	# Set last known position to where shot came from
	player_last_known_position = shot_from_position
	
	# Always go to combat when shot
	if current_state != State.COMBAT:
		set_state(State.COMBAT)
	
	# Check for death
	if health <= 0:
		die()

func takedown():
	if not can_be_meleed:
		return
	
	print("Enemy taken down by melee!")
	die()

func die():
	print("Enemy died!")
	# Disable the enemy
	set_physics_process(false)
	set_process(false)
	# Optional: Play death animation
	# Then remove from scene
	queue_free()

func player_detected(player):
	# Called when melee attack fails
	player_last_known_position = player.global_position
	if current_state != State.COMBAT:
		set_state(State.COMBAT)
