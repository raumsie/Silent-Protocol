extends Node2D

func _ready():
	# Ensure everything is properly loaded
	print("Level loaded")
	print("Player position: ", $Player.global_position)
	print("Camera enabled: ", $Player/Camera2D.enabled)
	
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
