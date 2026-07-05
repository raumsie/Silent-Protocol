extends Node2D

@onready var navigation_region: NavigationRegion2D = $NavigationRegion2D

func _ready():
	print("Level loaded")
	print("Player position: ", $Player.global_position)
	print("Camera enabled: ", $Player/Camera2D.enabled)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	setup_simple_navigation()

func setup_simple_navigation():
	if not navigation_region:
		GameManager.game_won.connect(_on_game_won)
		GameManager.game_lost.connect(_on_game_lost)
		return

	var nav_polygon = NavigationPolygon.new()
	nav_polygon.agent_radius = 12.0
	var margin: float = nav_polygon.agent_radius
	var source_geometry := NavigationMeshSourceGeometryData2D.new()

	# Outer walkable boundary (world space; region is at origin with scale 1)
	var boundary = PackedVector2Array([
		Vector2(-2000.0, -2000.0),
		Vector2( 2000.0, -2000.0),
		Vector2( 2000.0,  2000.0),
		Vector2(-2000.0,  2000.0),
	])
	source_geometry.add_traversable_outline(boundary)

	# Carve a hole per wall in group "walls"
	for wall in get_tree().get_nodes_in_group("walls"):
		for child in wall.get_children():
			if child is CollisionShape2D and child.shape is RectangleShape2D:
				var rect_shape := child.shape as RectangleShape2D
				var shape_center: Vector2 = child.global_position
				# Account for the wall's own scale (e.g. Vector2(2,6))
				var world_scale: Vector2 = wall.global_transform.get_scale()
				# Half-extents plus agent radius margin
				var half_ext: Vector2 = (rect_shape.size / 2.0) * world_scale + Vector2(margin, margin)
				var c: Vector2 = navigation_region.to_local(shape_center)
				# Clockwise winding (opposite the CCW outer boundary)
				var hole = PackedVector2Array([
					c + Vector2(-half_ext.x, -half_ext.y),
					c + Vector2(-half_ext.x,  half_ext.y),
					c + Vector2( half_ext.x,  half_ext.y),
					c + Vector2( half_ext.x, -half_ext.y),
				])
				source_geometry.add_obstruction_outline(hole)

	NavigationServer2D.bake_from_source_geometry_data(nav_polygon, source_geometry)
	navigation_region.navigation_polygon = nav_polygon
	print("NavMesh built. Walls carved: ", get_tree().get_nodes_in_group("walls").size())

	GameManager.game_won.connect(_on_game_won)
	GameManager.game_lost.connect(_on_game_lost)

func _on_game_won():
	print("Level: Victory detected!")

func _on_game_lost():
	print("Level: Game over detected!")

func _process(delta):
	queue_redraw()
