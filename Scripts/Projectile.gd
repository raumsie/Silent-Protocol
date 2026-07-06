extends Area2D

# Traveling projectile shared by Player.gd::shoot() (pistol) and
# Enemy.gd::attack_player() (ranged attack). Straight-line travel, no physics
# response needed - hence Area2D, not CharacterBody2D/RigidBody2D.
#
# Sprite sheet: res://Assets/v7/Projectiles/projectiles x3.png (hframes=5, vframes=9).
# Row 0 (frames 0-3) = enemy projectile animation, Row 1 (frames 5-8) = player's.
const ENEMY_PROJECTILE_ROW_BASE: int = 0   # row 0, cols 0-3
const PLAYER_PROJECTILE_ROW_BASE: int = 5  # row 1 * hframes 5 + col
const PROJECTILE_FRAME_COUNT: int = 4
const PROJECTILE_ANIM_FPS: float = 12.0  # continuous loop, not a one-shot - a bit livelier than the shooters' own 10fps

# Set via launch() by the shooter, before add_child().
var direction: Vector2 = Vector2.RIGHT
var speed: float = 1000.0
var damage: int = 0
var max_travel_distance: float = 400.0
var faction: String = "enemy"  # "player" or "enemy" - selects animation row + hit-target filter

var distance_traveled: float = 0.0
var anim_time: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D


func launch(p_direction: Vector2, p_speed: float, p_damage: int, p_faction: String, p_max_travel_distance: float) -> void:
	direction = p_direction.normalized() if p_direction.length() > 0.0 else Vector2.RIGHT
	speed = p_speed
	damage = p_damage
	faction = p_faction
	max_travel_distance = p_max_travel_distance


func _ready() -> void:
	rotation = direction.angle()
	sprite.frame = _row_base()
	body_entered.connect(_on_body_entered)


func _row_base() -> int:
	return PLAYER_PROJECTILE_ROW_BASE if faction == "player" else ENEMY_PROJECTILE_ROW_BASE


func _physics_process(delta: float) -> void:
	var step: Vector2 = direction * speed * delta
	global_position += step
	distance_traveled += step.length()

	anim_time += delta
	sprite.frame = _row_base() + int(fmod(anim_time * PROJECTILE_ANIM_FPS, PROJECTILE_FRAME_COUNT))

	if distance_traveled >= max_travel_distance:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("walls"):
		queue_free()
		return

	if faction == "player":
		# Player-fired: mirrors Player.gd::shoot()/melee_attack()'s existing "enemies" group check.
		if body.is_in_group("enemies"):
			body.take_damage(damage, global_position)
			queue_free()
	else:
		# Enemy-fired: mirrors Enemy.gd's vision-cone body_entered checks (name fallback
		# because the "player" group is never actually populated - see Known Issues #3).
		if body.name == "Player" or body.is_in_group("player"):
			body.take_damage(damage)
			queue_free()
	# Anything else (e.g. the projectile overlapping its own shooter at spawn, or an
	# enemy's projectile passing another enemy) is ignored - it keeps flying past it.
