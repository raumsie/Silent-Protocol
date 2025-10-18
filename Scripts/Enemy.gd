extends CharacterBody2D

@export var vision_renderer: Polygon2D
@export var alert_color: Color

@export_group("Rotation")
@export var is_rotating = false
@export var rotation_speed = 0.1
@export var rotation_angle = 90

@export_group("Movement")
@export var move_on_path: PathFollow2D
@export var movement_speed = 0.1
@onready var pos_start = position.x

@onready var original_color = vision_renderer.color if vision_renderer else Color.WHITE
@onready var rot_start = rotation

func debug_vision_cone_setup():
	var vision_cone = $VisionCone2D
	if vision_cone:
		print("=== VisionCone2D Configuration ===")
		print("Write Polygon2D set: ", vision_cone.write_polygon2d != null)
		print("Write Collision Polygon set: ", vision_cone.write_collision_polygon != null)
		print("Angle: ", vision_cone.angle_deg)
		print("Max Distance: ", vision_cone.max_distance)
		print("Ray Count: ", vision_cone.ray_count)
		print("Collision Layer Mask: ", vision_cone.collision_layer_mask)
		
		# Check if the plugin is actually calculating points
		if vision_cone.has_method("calculate_vision_shape"):
			var points = vision_cone.calculate_vision_shape()
			print("Calculated points: ", points.size())
		else:
			print("ERROR: VisionCone2D doesn't have calculate_vision_shape method")

func setup_vision_renderer():
	if vision_renderer:
		# Ensure the vision renderer is visible and on top
		vision_renderer.visible = true
		vision_renderer.z_index = 100  # High value to be on top
		vision_renderer.show_behind_parent = false
		
		# Set a default color if not set
		if vision_renderer.color.a == 0:
			vision_renderer.color = Color(1, 1, 0, 0.3)  # Semi-transparent yellow

func _ready():
	setup_vision_renderer()
	await get_tree().create_timer(0.5).timeout
	var vision_cone = $VisionCone2D
	if vision_cone and vision_cone.has_method("recalculate_vision"):
		vision_cone.recalculate_vision(true) # force recaulculation
		print("Forced vision recalc")
	debug_vision_cone_setup()
# Debug the vision renderer setup
	print("=== Vision Renderer Debug ===")
	print("Vision Renderer Node: ", vision_renderer)
	if vision_renderer:
		print("Vision Renderer Visible: ", vision_renderer.visible)
		print("Vision Renderer Z Index: ", vision_renderer.z_index)
		print("Vision Renderer Polygon Points: ", vision_renderer.polygon.size())
		print("Current Color: ", vision_renderer.color)

# Uncomment to debug color change	
'''
	# Force a color change to test visibility
	await get_tree().create_timer(0.5).timeout
	if vision_renderer:
		vision_renderer.color = Color.GREEN
		print("Test: Changed to GREEN")
	
	await get_tree().create_timer(0.5).timeout
	if vision_renderer:
		vision_renderer.color = Color.BLUE
		print("Test: Changed to BLUE")
'''



func _physics_process(delta: float) -> void:
	if is_rotating:
		rotation = rot_start + sin(Time.get_ticks_msec()/1000. * rotation_speed) * deg_to_rad(rotation_angle/2.)
	if move_on_path:
		move_on_path.progress += movement_speed
		global_position = move_on_path.position
		rotation = move_on_path.rotation


func _on_vision_cone_area_2_body_entered(body: Node2D) -> void:
	if body == self:
		return
		
	if body.is_in_group("enemy") or body.get_parent() == self:
		return
		
	if body.name == "Player" or body.is_in_group("player"):
		print("%s is seeing %s" % [self, body])
		print("Alert color value: ", alert_color)
		print("Vision renderer exists: ", vision_renderer != null)
		
	if vision_renderer:
		vision_renderer.color = alert_color
		print("New color set: ", vision_renderer.color)
	else:
		print("ERROR: Vision renderer is null!")		
		# Uncomment to enable loss scenario 
		#GameManager.lose_game()


func _on_vision_cone_area_2_body_exited(body: Node2D) -> void:
	if body == self:
		return
	# Skip if the body is part of the enemy
	if body.is_in_group("enemy") or body.get_parent() == self:
		return
		
	if body.name == "Player" or body.is_in_group("player"):
		print("%s stopped seeing %s" % [self, body])
		vision_renderer.color = original_color
