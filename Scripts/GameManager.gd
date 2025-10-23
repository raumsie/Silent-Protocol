extends Node

signal game_won
signal game_lost

# Enemy signals
signal player_spotted(enemy, player_position)
signal player_lost(enemy, last_known_position)

var current_state = "playing"

func win_game():
	if current_state == "playing":
		current_state = "won"
		game_won.emit()
		print("VICTORY! Mission accomplished!")
		get_tree().paused = true
		await get_tree().create_timer(2.0).timeout
		get_tree().paused = false
		get_tree().reload_current_scene()

func lose_game():
	if current_state == "playing":
		current_state = "lost"
		game_lost.emit()
		print("GAME OVER! Detected by enemy!")
		get_tree().paused = true
		await get_tree().create_timer(2.0).timeout
		get_tree().paused = false
		get_tree().reload_current_scene()
