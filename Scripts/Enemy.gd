extends CharacterBody2D

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

# Combat
var current_state: State = State.PATROL
var player_ref: Node2D = null
var can_attack: bool = true
var last_attack_time: float = 0.0

# State
var player_last_known_position: Vector2
var search_timer: float = 0.0
var patrol_index: int = 0
var path_follow: PathFollow2D

# Search
var search_center: Vector2
var search_radius: float = 100.0
var current_search_target: Vector2

# Combat
var combat_timer: float = 0.0
var max_combat_time: float = 10.0
var has_player_in_sight: bool = false

# Global alert / A* pathfinding
var is_alerted: bool = false
var path_waypoints: PackedVector2Array = PackedVector2Array()
var current_waypoint_index: int = 0
var astar_target_position: Vector2 = Vector2.ZERO

# Periodic re-broadcast interval while actively chasing
var alert_rebroadcast_timer: float = 0.0
const ALERT_REBROADCAST_INTERVAL: float = 0.75

# Rotation
var time_since_state_change: float = 0.0

const VISION_CONE_REST_OFFSET: float = -PI / 2.0
const FACING_MIN_X: float = 0.05

# Animation
# sprite sheet: hframes = 10, rows 12-15 used by this enemy
const ENEMY_IDLE_FRAMES: Array[int] = [120, 122, 123]  # row 12, cols 0, 2, 3
const ENEMY_IDLE_FPS: float = 3.0
const ENEMY_RUN_ROW_BASE: int = 130  # row 13
const ENEMY_RUN_FRAME_COUNT: int = 4
const ENEMY_RUN_FPS: float = 8.0
const ENEMY_SHOOT_ROW_BASE: int = 140  # row 14
const ENEMY_SHOOT_FRAME_COUNT: int = 4
const ENEMY_DEATH_ROW_BASE: int = 150  # row 15
const ENEMY_DEATH_FRAME_COUNT: int = 8
const ONESHOT_FPS: float = 10.0

var anim_time: float = 0.0
var is_playing_oneshot: bool = false
var oneshot_token: int = 0


@onready var vision_cone = $VisionCone2D
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var sprite: Sprite2D = $Sprite2D

# Raycast LOS check against walls (layer 2)
func has_line_of_sight_to(target: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, target, 2)
	var result = space_state.intersect_ray(query)
	return result.is_empty()

func _ready():
	can_attack = true

	setup_vision_renderer()
	setup_navigation()
	setup_patrol_path()

	if not is_in_group("enemies"):
		add_to_group("enemies")

	if not GameManager.player_spotted.is_connected(_on_global_alert):
		GameManager.player_spotted.connect(_on_global_alert)

	# Wait for plugin to initialize
	await get_tree().create_timer(0.5).timeout
	force_vision_cone_update()

	set_state(State.PATROL)

func setup_navigation():
	if not navigation_agent:
		push_error("NavigationAgent2D not found")

	navigation_agent.path_desired_distance = 4.0
	navigation_agent.target_desired_distance = 4.0
	navigation_agent.path_max_distance = 1000.0

	if not navigation_agent.navigation_finished.is_connected(_on_navigation_finished):
		navigation_agent.navigation_finished.connect(_on_navigation_finished)

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
	elif patrol_points.size() > 0:
		print("Manual patrol points configured: ", patrol_points.size())
	else:
		print("No patrol path - enemy will be stationary")

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


# Radio alert from another enemy that spotted the player
func _on_global_alert(spotted_enemy: Node, player_pos: Vector2):
	if spotted_enemy == self:
		return

	# Already engaged — just refresh the target, no delay needed
	if current_state == State.COMBAT:
		print(name, ": already in COMBAT, refreshing last known player position from ", spotted_enemy.name, " (", player_last_known_position, " -> ", player_pos, ")")
		player_last_known_position = player_pos
		return

	if is_alerted:
		print(name, " ignoring global alert (radio delay already in progress)")
		return

	is_alerted = true

	print("Global alert received by ", name, " from ", spotted_enemy.name, ". Waiting 1s for radio animation...")
	await get_tree().create_timer(1.0).timeout
	print(name, " radio delay finished. Engaging COMBAT toward ", player_pos)

	# Re-check in case state changed during the wait
	if not is_instance_valid(self) or current_state == State.COMBAT:
		is_alerted = false
		return

	player_last_known_position = player_pos
	path_waypoints = PackedVector2Array()
	current_waypoint_index = 0

	set_state(State.COMBAT)
	is_alerted = false


func setup_vision_renderer():
	if vision_renderer:
		vision_renderer.visible = true
		vision_renderer.z_index = 100
		vision_renderer.color = patrol_color

func force_vision_cone_update():
	if vision_cone and vision_cone.has_method("_update_render_polygon"):
		vision_cone._update_render_polygon()

# Patrol

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
	print("Starting combat")
	combat_timer = 0.0
	alert_rebroadcast_timer = 0.0

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
		path_follow.progress += patrol_speed * delta
		global_position = path_follow.global_position

		if path_follow.rotates:
			update_facing(Vector2.RIGHT.rotated(path_follow.rotation))
		elif is_rotating:
			update_idle_vision_sway()

	elif patrol_points.size() > 0:
		if patrol_index < patrol_points.size():
			var target_point = patrol_points[patrol_index]
			move_towards_target(target_point, patrol_speed)

			if global_position.distance_to(target_point) < 15.0:
				patrol_index = (patrol_index + 1) % patrol_points.size()
				print("Moving to next patrol point: ", patrol_index)

			update_rotation_based_on_movement(delta)
	else:
		# Stationary patrol with rotation
		if is_rotating:
			update_idle_vision_sway()


# Combat
func update_combat(delta):
	if current_state != State.COMBAT:
		return

	combat_timer += delta

	if combat_timer > max_combat_time and not has_player_in_sight:
		print("Max combat time exceeded, switching to SEARCH state")
		set_state(State.SEARCH)
		return

	if player_ref and is_instance_valid(player_ref) and has_player_in_sight:
		# Direct LOS — clear stale A* path
		path_waypoints = PackedVector2Array()
		current_waypoint_index = 0

		# Periodic re-broadcast so allies' target stays fresh during the chase
		alert_rebroadcast_timer += delta
		if alert_rebroadcast_timer >= ALERT_REBROADCAST_INTERVAL:
			alert_rebroadcast_timer = 0.0
			print(name, ": periodic re-broadcast - still have LOS on player, re-emitting player_spotted at ", player_ref.global_position)
			GameManager.player_spotted.emit(self, player_ref.global_position)

		var distance_to_player = global_position.distance_to(player_ref.global_position)

		if distance_to_player < 40.0 and can_attack:
			attack_player()

		elif distance_to_player > 45.0:
			move_towards_target(player_ref.global_position, combat_speed)

			var direction_to_player = (player_ref.global_position - global_position).normalized()
			update_facing(direction_to_player)

	else:
		# Player not in sight - pursue last known position
		if has_line_of_sight_to(player_last_known_position):
			path_waypoints = PackedVector2Array()
			current_waypoint_index = 0
			move_towards_target(player_last_known_position, combat_speed)
		else:
			move_towards_target_with_astar(player_last_known_position, combat_speed)

		update_rotation_based_on_movement(delta)

		# Reached last-known position without LOS — check if an ally still sees the player
		if global_position.distance_to(player_last_known_position) < 25.0:
			var ally_with_eyes_on_player: Node = find_ally_with_eyes_on_player()
			if ally_with_eyes_on_player:
				print(name, ": reached last known position with no LOS, but ", ally_with_eyes_on_player.name, " still has eyes on the player - refreshing pursuit target instead of giving up to SEARCH")
				player_last_known_position = ally_with_eyes_on_player.player_ref.global_position
				path_waypoints = PackedVector2Array()
				current_waypoint_index = 0
			else:
				print("Reached last known player position, switching to SEARCH state")
				path_waypoints = PackedVector2Array()
				current_waypoint_index = 0
				set_state(State.SEARCH)

# Finds an ally in COMBAT with active LOS on the player
func find_ally_with_eyes_on_player() -> Node:
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if enemy_node == self or not is_instance_valid(enemy_node):
			continue
		if enemy_node.current_state == State.COMBAT and enemy_node.has_player_in_sight \
				and enemy_node.player_ref and is_instance_valid(enemy_node.player_ref):
			return enemy_node
	return null

# Stateless, per-tick idle/run frame calculation
func update_idle_run_animation(delta: float, is_moving: bool) -> void:
	if is_playing_oneshot:
		return
	anim_time += delta
	if is_moving:
		sprite.frame = ENEMY_RUN_ROW_BASE + int(fmod(anim_time * ENEMY_RUN_FPS, ENEMY_RUN_FRAME_COUNT))
	else:
		var idle_index = int(fmod(anim_time * ENEMY_IDLE_FPS, ENEMY_IDLE_FRAMES.size()))
		sprite.frame = ENEMY_IDLE_FRAMES[idle_index]


func play_oneshot_animation(row_base: int, frame_count: int, fps: float, on_frame: Callable = Callable()) -> void:
	oneshot_token += 1
	var my_token = oneshot_token
	is_playing_oneshot = true

	for i in range(frame_count):
		if my_token != oneshot_token:
			return  # superseded by a newer one-shot trigger
		sprite.frame = row_base + i
		if on_frame.is_valid():
			on_frame.call(i)
		await get_tree().create_timer(1.0 / fps).timeout

	if my_token == oneshot_token:
		is_playing_oneshot = false

func attack_player():
	if not can_attack or not player_ref:
		return

	print("Enemy attacking player!")
	player_ref.take_damage(damage_amount)
	play_oneshot_animation(ENEMY_SHOOT_ROW_BASE, ENEMY_SHOOT_FRAME_COUNT, ONESHOT_FPS)

	can_attack = false
	last_attack_time = Time.get_ticks_msec()
	await get_tree().create_timer(attack_cooldown).timeout
	# Guard against resuming on a freed instance (killed mid-cooldown)
	if not is_instance_valid(self):
		return
	can_attack = true


func update_search(delta):
	search_timer -= delta

	if search_timer <= 0:
		print("Search duration ended, returning to PATROL state")
		set_state(State.PATROL)
		return

	move_towards_target(current_search_target, search_speed)

	update_rotation_based_on_movement(delta)

	if global_position.distance_to(current_search_target) < 20.0 or randf() < 0.01:
		pick_new_search_target()

func update_rotation_based_on_movement(delta):
	if velocity.length() > 0.1:
		update_facing(velocity)
	elif is_rotating:
		update_idle_vision_sway()

# Sets left/right sprite facing (flip_h) and re-orients the vision cone
# (independent ofthe body) so LOS detection keeps tracking the same direction
# that used to drive the whole body's rotation.
func update_facing(direction: Vector2) -> void:
	if direction.length() < 0.1:
		return  # don't flip/re-aim on near-zero movement noise (keep last facing)
	if abs(direction.x) > FACING_MIN_X:
		sprite.flip_h = direction.x < 0
	vision_cone.rotation = direction.angle() + VISION_CONE_REST_OFFSET

# is_rotating/rotation_speed/rotation_angle previously oscillated the whole body's
# rotation while idle. Now will only oscillate the vision cone's rotation,
# preserving the scanning behavior without spinning the sprite.
func update_idle_vision_sway() -> void:
	vision_cone.rotation = VISION_CONE_REST_OFFSET + sin(Time.get_ticks_msec()/1000.0 * rotation_speed) * deg_to_rad(rotation_angle/2.0)


# A* pursuit when no direct LOS; falls back to NavigationAgent2D if no path found
func move_towards_target_with_astar(target_position: Vector2, movement_speed: float):
	# Recompute the path if missing, exhausted, or target moved
	var need_new_path: bool = path_waypoints.is_empty() or current_waypoint_index >= path_waypoints.size()
	if astar_target_position.distance_to(target_position) > 16.0:
		need_new_path = true

	if need_new_path:
		astar_target_position = target_position
		var path: PackedVector2Array = PathfindingManager.get_world_path(global_position, target_position)

		if path.is_empty():
			print(name, ": A* path empty/not found, falling back to NavigationAgent2D")
			path_waypoints = PackedVector2Array()
			current_waypoint_index = 0
			move_towards_target(target_position, movement_speed)
			return

		print(name, ": A* path found with ", path.size(), " waypoints")
		path_waypoints = path
		current_waypoint_index = 0

	if path_waypoints.is_empty():
		move_towards_target(target_position, movement_speed)
		return

	# Skip waypoints already reached
	while current_waypoint_index < path_waypoints.size() - 1 and global_position.distance_to(path_waypoints[current_waypoint_index]) < 10.0:
		current_waypoint_index += 1
		print(name, ": Moving to waypoint ", current_waypoint_index, " at position ", path_waypoints[current_waypoint_index])

	var waypoint_target: Vector2 = path_waypoints[current_waypoint_index]
	var direction = (waypoint_target - global_position).normalized()
	velocity = direction * movement_speed

	# Clear path after reaching the final waypoint so it recomputes next time
	if current_waypoint_index >= path_waypoints.size() - 1 and global_position.distance_to(waypoint_target) < 10.0:
		print(name, ": Reached final A* waypoint")
		path_waypoints = PackedVector2Array()
		current_waypoint_index = 0


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
	pass

func _physics_process(delta):
	velocity = Vector2.ZERO

	match current_state:
		State.PATROL:
			update_patrol(delta)
		State.COMBAT:
			update_combat(delta)
		State.SEARCH:
			update_search(delta)

	# velocity is final for this tick now
	update_idle_run_animation(delta, velocity.length() > 0.1)

	if player_ref and is_instance_valid(player_ref):
		var los = has_line_of_sight_to(player_ref.global_position)
		if los != has_player_in_sight:
			has_player_in_sight = los
			if los and current_state != State.COMBAT:
				set_state(State.COMBAT)
			elif not los and current_state == State.COMBAT:
				set_state(State.SEARCH)

	if velocity.length() > 0:
		move_and_slide()


func _on_vision_cone_area_2_body_entered(body: Node2D):
	if body == self or body.get_parent() == self:
		return

	if body.name == "Player" or body.is_in_group("player"):
		print("Player entered vision cone")
		player_ref = body
		player_last_known_position = body.global_position
		# Line of sight will be checked in _physics_process


func _on_vision_cone_area_2_body_exited(body: Node2D):
	if body == self or body.get_parent() == self:
		return

	if body.name == "Player" or body.is_in_group("player"):
		print("Player exited vision cone")
		has_player_in_sight = false
		player_ref = null

		if current_state == State.COMBAT:
			set_state(State.SEARCH)
			print("Enemy state: COMBAT > SEARCH")


func take_damage(damage: int, shot_from_position: Vector2):
	health -= damage
	print("Enemy took damage! Health: ", health)

	player_last_known_position = shot_from_position

	if current_state != State.COMBAT:
		set_state(State.COMBAT)

	if health <= 0:
		die()


# current_state == COMBAT covers alertness from LOS, being shot, a failed melee, 
# or a radio alert from an ally (even without direct LOS) 
func has_spotted_player() -> bool:
	return current_state == State.COMBAT or has_player_in_sight

func takedown():
	if not can_be_meleed:
		return

	print("Enemy taken down by melee! ", name, " at ", global_position)
	die()

func die():
	print("Enemy died!")
	set_physics_process(false)
	set_process(false)
	await play_oneshot_animation(ENEMY_DEATH_ROW_BASE, ENEMY_DEATH_FRAME_COUNT, ONESHOT_FPS, func(frame_index):
		if frame_index == 1:
			vision_renderer.visible = false
	)
	queue_free()

# Called when a failed (non-stealth) melee attempt alerts this enemy
func player_detected(player):
	player_last_known_position = player.global_position
	if current_state != State.COMBAT:
		set_state(State.COMBAT)
