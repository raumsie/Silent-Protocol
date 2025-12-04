extends Node

signal game_won
signal game_lost

# Enemy signals
signal player_spotted(enemy, player_position)
signal player_lost(enemy, last_known_position)
signal enemy_died(enemy)

signal player_damaged(current_health, max_health)
signal player_died()
signal player_takedown_performed(enemy)

# Game state signals
signal game_over(reason)
signal objective_completed()

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
		await get_tree().create_timer(1.0).timeout
		get_tree().paused = false
		get_tree().reload_current_scene()
