extends Area2D

#@export var color: Color = Color.GREEN

#@onready var visual: ColorRect = $ColorRect
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready():
	#setup_visual()
	body_entered.connect(_on_body_entered)

#func setup_visual():
	#visual.color = color
	#visual.size = Vector2(28, 28) 
	#visual.position = Vector2(-14, -14)

func _on_body_entered(body):
	if body.name == "Player":
		print("Objective collected! You win!")
		GameManager.win_game()
