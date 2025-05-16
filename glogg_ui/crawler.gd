extends "res://EnemyBase.gd" 
class_name Crawler

@onready var sprite: Sprite2D = $Sprite2D

# --- Crawler Specific Base Stats ---
@export var base_health: float = 6.0
@export var base_speed: float = 75.0
@export var amplitude = 100
@export var period = 0.75
@export var speed_up = 0.25
@export var speed_down = 1.0

var t = 0.0
var is_bouncing = false
var bounce_timer = 0.0
var bounce_movement = Vector2.ZERO
var bounce_speed_multiplier = 0.5
var collision_cooldown = 0.0
var crawler_id: int = -1 

func _ready():
	super._ready() 
	health = base_health 
	t = randf() * PI * 2

func _physics_process(delta):
	sprite.global_rotation = 0
	collision_cooldown -= delta
	if is_bouncing:
		var bounce_collision = move_and_collide(bounce_movement * delta)
		bounce_timer -= delta
		if bounce_timer <= 0: is_bouncing = false
		elif bounce_collision and collision_cooldown <= 0:
			bounce_movement = bounce_movement.bounce(bounce_collision.get_normal())
			collision_cooldown = 0.05
		return 
	super._physics_process(delta)

func _perform_orientation(_delta: float):
	if orientation_target is Node: 
		look_at(orientation_target.global_position)
	elif orientation_target is Vector2: 
		look_at(orientation_target)

func _perform_movement(delta: float, speed_multiplier_from_base: float):
	var effective_speed = base_speed * speed_multiplier_from_base
	var going_up = (t < PI / 2) or (t > 3 * PI / 2)
	var oscillation_speed_multiplier = speed_up if going_up else speed_down
	t += delta * (2 * PI / period)
	var oscillation = transform.y * sin(t) * amplitude * delta * oscillation_speed_multiplier
	var forward_movement = transform.x * effective_speed * delta
	var global_movement = forward_movement + oscillation
	var collision_info = move_and_collide(global_movement)
	if collision_info and apply_collision_damage and collision_damage_amount > 0:
		var collider = collision_info.get_collider()
		if collider is EnemyBase and collider != self:
			var source_str = "%s spikes" % self._get_log_id_str()
			collider.take_damage(collision_damage_amount, -1, source_str)
	if collision_info and collision_cooldown <= 0:
		var collider = collision_info.get_collider()
		if collider != self and collider is CharacterBody2D: 
			is_bouncing = true
			bounce_timer = 0.2
			bounce_movement = global_movement.bounce(collision_info.get_normal()) * bounce_speed_multiplier / delta
			collision_cooldown = 0.05
	if sprite: sprite.global_rotation = 0
	if t >= 2 * PI:
		t = fmod(t, 2 * PI) 
