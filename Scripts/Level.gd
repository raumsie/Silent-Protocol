extends Node2D

func _ready():
	# Ensure everything is properly set up
	print("Level loaded")
	print("Player position: ", $Player.global_position)
	print("Camera enabled: ", $Player/Camera2D.enabled)
	
	# Test that GameManager is working
	GameManager.game_won.connect(_on_game_won)
	GameManager.game_lost.connect(_on_game_lost)

func _on_game_won():
	print("Level: Victory detected!")

func _on_game_lost():
	print("Level: Game over detected!")

# Debug function to draw vision cone (call in _draw() if needed)
func _process(delta):
	# This is optional - for debugging vision cone
	queue_redraw()

func _draw():
	# Draw enemy vision cone for debugging
	var enemy = $Enemy
	if enemy:
		var vision_range = enemy.vision_range
		var vision_angle = deg_to_rad(enemy.vision_angle)
		
		var left_angle = enemy.rotation - vision_angle/2
		var right_angle = enemy.rotation + vision_angle/2
		
		var left_point = enemy.global_position + Vector2.RIGHT.rotated(left_angle) * vision_range
		var right_point = enemy.global_position + Vector2.RIGHT.rotated(right_angle) * vision_range
		
		draw_line(enemy.global_position, left_point, Color.YELLOW, 1.0)
		draw_line(enemy.global_position, right_point, Color.YELLOW, 1.0)
		draw_line(left_point, right_point, Color.YELLOW, 1.0)
