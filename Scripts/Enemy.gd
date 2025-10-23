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

# State variables
var current_state: State = State.PATROL
var player_last_known_position: Vector2
var search_timer: float = 0.0
var patrol_index: int = 0
var path_follow: PathFollow2D

# References
@onready var vision_cone = $VisionCone2D
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D

func _ready():
	setup_vision_renderer()
	setup_navigation()
	setup_patrol_path()
    
    # Wait for plugin to initialize
	await get_tree().create_timer(0.5).timeout
	force_vision_cone_update()
    
	set_state(State.PATROL)

func setup_navigation():
	if not navigation_agent:
		navigation_agent = $NavigationAgent2D
    
	if navigation_agent:
		navigation_agent.path_desired_distance = 4.0
		navigation_agent.target_desired_distance = 4.0
		navigation_agent.path_max_distance = 1000.0
        
        # Wait for navigation to be ready
		await get_tree().process_frame
        
		print("NavigationAgent2D configured successfully")
	else:
		push_error("NavigationAgent2D node not found in Enemy scene")


func setup_patrol_path():
	if use_patrol_path and patrol_path:
		path_follow = PathFollow2D.new()
		patrol_path.add_child(path_follow)
		print("Patrol path configured with Path2D")
	elif patrol_points.size() > 0:
		print("Manual patrol points configured: ", patrol_points.size())
	else:
		print("No patrol path - enemy will be stationary")

func set_state(new_state: State):
	if current_state == new_state:
		return
        
	print("Enemy state: ", State.keys()[current_state], " → ", State.keys()[new_state])
	current_state = new_state

	# Update vision cone color and emit signals
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
			#GameManager.player_lost.emit(self, player_last_known_position)
			start_search()

func setup_vision_renderer():
	if vision_renderer:
		vision_renderer.visible = true
		vision_renderer.z_index = 100
		vision_renderer.color = patrol_color

func force_vision_cone_update():
	if vision_cone and vision_cone.has_method("_update_render_polygon"):
		vision_cone._update_render_polygon()

func start_patrol():
	patrol_index = 0

func start_combat():
	# Put combat logic here
	pass

func start_search():
	search_timer = search_duration

func update_patrol(delta):
	if use_patrol_path and path_follow:
		# Use Path2D for patrol
		path_follow.progress += patrol_speed * delta
		global_position = path_follow.global_position
		rotation = path_follow.rotation
	elif patrol_points.size() > 0:
        # Navigate between manual points
		if patrol_index < patrol_points.size():
			var target = patrol_points[patrol_index]
			move_towards_target(target, patrol_speed)
            
            # Check if reached point
			if global_position.distance_to(target) < 10.0:
				patrol_index = (patrol_index + 1) % patrol_points.size()
	else:
		if is_rotating:
			rotation = rotation + rotation_speed * delta

func update_combat(delta):
	if player_last_known_position:
		move_towards_target(player_last_known_position, combat_speed)
        
		# If close to target and player not re-spotted, switch to search
		if global_position.distance_to(player_last_known_position) < 20.0:
			set_state(State.SEARCH)

func update_search(delta):
	search_timer -= delta
    # Return to patrol after search duration ends
	if search_timer <= 0:
		set_state(State.PATROL)
		return
    # Continue moving towards last known player position
	if player_last_known_position:
		move_towards_target(player_last_known_position, search_speed)

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
		player_last_known_position = body.global_position
		if current_state != State.COMBAT:
			set_state(State.COMBAT)


func _on_vision_cone_area_2_body_exited(body: Node2D):
	if body == self or body.get_parent() == self:
		return
        
	if body.name == "Player" or body.is_in_group("player"):
		if current_state == State.COMBAT:
			set_state(State.SEARCH)