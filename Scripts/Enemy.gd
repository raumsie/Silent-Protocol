extends CharacterBody2D

@export var color: Color = Color.BLUE
@export var vision_range: float = 200.0
@export var vision_angle: float = 45.0

@onready var visual: ColorRect = $ColorRect
@onready var vision_ray: RayCast2D = $RayCast2D
@onready var detection_area: Area2D = $DetectionArea
@onready var vision_cone: CollisionPolygon2D = $DetectionArea/CollisionPolygon2D

func _ready():
	setup_visual()
	setup_vision()
	setup_detection()

func setup_visual():
	if visual:
		visual.color = color
		visual.size = Vector2(24, 32)
		visual.position = Vector2(-12, -16)

func setup_vision():
	if vision_ray:
		vision_ray.target_position = Vector2(vision_range, 0)
		vision_ray.enabled = true

func setup_detection():
	if detection_area and vision_cone:
		# Connect the signal
		detection_area.body_entered.connect(_on_detection_area_body_entered)
		
		# Debug: Print to confirm setup
		print("Vision cone polygon points: ", vision_cone.polygon)
		print("Detection area ready")
	else:
		print("ERROR: Detection area or vision cone not found!")

func _on_detection_area_body_entered(body):
	print("Body entered detection area: ", body.name)
	if body.name == "Player" or body.is_in_group("player"):
		print("Player entered vision cone!")
		if can_see_player(body):
			print("Enemy detected player! Game Over.")
			GameManager.lose_game()

func can_see_player(player) -> bool:
	if not vision_ray or not player:
		return false
		
	var direction_to_player = (player.global_position - global_position).normalized()
	var forward = Vector2.RIGHT.rotated(rotation)
	
	# Angle check
	var angle = rad_to_deg(forward.angle_to(direction_to_player))
	if abs(angle) > vision_angle / 2.0:
		print("Player outside vision angle: ", angle)
		return false
	
	# Raycast check for obstacles
	vision_ray.target_position = direction_to_player * vision_range
	vision_ray.force_raycast_update()
	
	if vision_ray.is_colliding():
		var can_see = vision_ray.get_collider() == player
		print("Raycast hit: ", vision_ray.get_collider().name, ". Can see player: ", can_see)
		return can_see
	
	print("Raycast didn't hit anything")
	return false

# Add to Enemy.gd
func _draw():
	# Only draw in debug mode or when needed
	if not Engine.is_editor_hint():
		draw_vision_cone_debug()

func draw_vision_cone_debug():
	if not vision_cone or vision_cone.polygon.size() < 3:
		return
		
	# Convert polygon points to global coordinates for drawing
	var global_points = PackedVector2Array()
	for point in vision_cone.polygon:
		global_points.append(to_global(point))
	
	# Draw the vision cone outline
	draw_polyline(global_points, Color.YELLOW)
	# Close the polygon
	if global_points.size() > 0:
		draw_line(global_points[global_points.size()-1], global_points[0], Color.YELLOW, 2.0)

func _process(delta):
	# Redraw every frame to update the debug visualization
	queue_redraw()
