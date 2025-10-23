extends Node2D

@onready var navigation_region: NavigationRegion2D = $NavigationRegion2D

func _ready():
	# Ensure everything is properly loaded
	print("Level loaded")
	print("Player position: ", $Player.global_position)
	print("Camera enabled: ", $Player/Camera2D.enabled)

	setup_simple_navigation()

func setup_simple_navigation():
	if navigation_region:
		var navigation_polygon = NavigationPolygon.new()

		var outline = PackedVector2Array()
		outline.append(Vector2(-1000, -1000))
		outline.append(Vector2(1000, -1000))
		outline.append(Vector2(1000, 1000))
		outline.append(Vector2(-1000, 1000))

		navigation_polygon.add_outline(outline)
		navigation_polygon.make_polygons_from_outlines()

		navigation_region.navigation_polygon = navigation_polygon
		print("NavigationRegion2D configured with simple polygon")
	
	# Test that GameManager is working
	GameManager.game_won.connect(_on_game_won)
	GameManager.game_lost.connect(_on_game_lost)

func _on_game_won():
	print("Level: Victory detected!")

# There is no loss condition yet
func _on_game_lost():
	print("Level: Game over detected!")

# Debug function to draw vision cone
func _process(delta):
	queue_redraw()
