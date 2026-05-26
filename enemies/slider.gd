# File: res://enemies/slider.gd
extends EnemyBase

# --- Stats ---
@export var base_health: float = 8.0
@export var acceleration_rate: float = 0.1 # Adds 10% to its speed every second

# --- Internal State ---
var slider_base_speed: float = 0.0
var internal_speed_multiplier: float = 1.0

func _ready():
	# Call EnemyBase _ready to initialize health, hitbox, and find the player
	super._ready()
	
	health = base_health
	add_to_group("enemies")
	
	# Wait one frame for the player to fully load before checking their speed
	call_deferred("_initialize_speed")

func _initialize_speed():
	if is_instance_valid(player):
		# Assumes your player script has a variable literally named 'speed'. 
		# Change this if your player uses 'base_speed' or 'movement_speed'!
		var player_current_speed = 150.0 
		if "speed" in player:
			player_current_speed = player.speed
			
		# Start at exactly 50% of the player's current speed
		slider_base_speed = player_current_speed * 0.5
	else:
		slider_base_speed = 75.0 
		
func _perform_orientation(_delta: float):
	# The Slider constantly stares down the player
	if is_instance_valid(player):
		look_at(player.global_position)

func _perform_movement(delta: float, external_speed_multiplier: float):
	if not is_instance_valid(player): 
		return

	# Accelerate infinitely
	internal_speed_multiplier += acceleration_rate * delta
	
	# Calculate direction to the player
	var direction = (player.global_position - global_position).normalized()
	
	# Combine base speed, our infinite acceleration, and any freeze/slow effects from EnemyBase
	var current_speed = slider_base_speed * internal_speed_multiplier * external_speed_multiplier
	
	var movement = direction * current_speed * delta
	var collision_info = move_and_collide(movement)
	
	if collision_info:
		# Standard EnemyBase bounce/collision handling
		handle_physics_collision(collision_info)
