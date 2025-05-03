# crawler.gd (Defines own base stats, extends path, calls super)
extends "res://EnemyBase.gd" # Extend using path

# --- Crawler Specific Base Stats ---
@export var base_health: float = 3.0
@export var base_speed: float = 75.0

# --- Crawler Specific Movement Vars ---
@export var amplitude = 150
@export var period = 0.75
@export var speed_up = 0.25
@export var speed_down = 1.0

# --- Internal State ---
var t = 0.0
@onready var sprite: Sprite2D = $Sprite2D
var is_bouncing = false
var bounce_timer = 0.0
var bounce_movement = Vector2.ZERO
var bounce_speed_multiplier = 0.5
var collision_cooldown = 0.0
# Inherited: health, speed_multipliers, etc., player

# --- ADD CRAWLER ID ---
var crawler_id: int = -1 # Specific ID for this type

func _ready():
	# --- CALL SUPER FIRST ---
	super._ready() # Call parent's ready function first!
	# --- SET HEALTH ---
	health = base_health # Initialize health using own exported value
	# --- END INIT ---

	# Crawler-specific setup
	t = randf() * PI * 2
	# _find_player is called by base class _ready->call_deferred

# --- Override Physics Process ---
func _physics_process(delta):
	# Use base class player variable, check validity if needed before use
	if not player: return
	if sprite: sprite.global_rotation = 0
	if collision_cooldown > 0: collision_cooldown -= delta

	if is_bouncing:
		var bounce_collision = move_and_collide(bounce_movement * delta)
		bounce_timer -= delta
		if bounce_timer <= 0: is_bouncing = false
		elif bounce_collision and collision_cooldown <= 0:
			bounce_movement = bounce_movement.bounce(bounce_collision.get_normal())
			collision_cooldown = 0.05
		return # Skip base processing while bouncing

	# Call base class physics process which calculates multipliers and calls _perform_movement
	super._physics_process(delta)

# --- Implement Orientation ---
func _perform_orientation(_delta: float):
	# Uses orientation_target set by base class or Confusion effect
	if orientation_target is Node: # Check if target is a Node (Player)
		look_at(orientation_target.global_position)
	elif orientation_target is Vector2: # Check if target is a position
		look_at(orientation_target)

# --- Implement Movement ---
func _perform_movement(delta: float, speed_multiplier_from_base: float):
	var effective_speed = base_speed * speed_multiplier_from_base

	# Sine Wave Movement using calculated effective_speed
	var going_up = (t < PI / 2) or (t > 3 * PI / 2)
	var oscillation_speed_multiplier = speed_up if going_up else speed_down

	# Increment t based on the CONSTANT period
	t += delta * (2 * PI / period)

	# Calculate oscillation, applying the multiplier to its magnitude
	var oscillation = transform.y * sin(t) * amplitude * delta * oscillation_speed_multiplier
	var forward_movement = transform.x * effective_speed * delta
	var global_movement = forward_movement + oscillation

	# Perform collision and movement
	var collision_info = move_and_collide(global_movement)

	handle_physics_collision(collision_info)
	
	if collision_info and apply_collision_damage and collision_damage_amount > 0:
		var collider = collision_info.get_collider()
		if collider is EnemyBase and collider != self:
			# print("[Crawler %d Spikes] Hit Crawler %d! Dealing %.2f damage." % [crawler_id, collider.crawler_id, collision_damage_amount])
			collider.take_damage(collision_damage_amount, -1) # Apply OUR damage to the one hit

	# Handle bouncing based on the collision result
	if collision_info and collision_cooldown <= 0:
		var collider = collision_info.get_collider()
		if collider != self and collider is CharacterBody2D: # Check if it's another physics body
			is_bouncing = true
			bounce_timer = 0.2
			bounce_movement = global_movement.bounce(collision_info.get_normal()) * bounce_speed_multiplier / delta
			collision_cooldown = 0.05

	if sprite: sprite.global_rotation = 0
	# Reset t cycle correctly
	if t >= 2 * PI:
		t = fmod(t, 2 * PI) # Use fmod for smooth wrap-around

# --- Override take_damage for specific logging ---
func take_damage(amount: float, slot_index: int):
	super(amount, slot_index) # Pass arguments to super
