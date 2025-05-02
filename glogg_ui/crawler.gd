# crawler.gd (Extends EnemyBase - Cleaned)
extends EnemyBase

# --- Crawler Specific Movement Vars ---
@export var amplitude = 150
@export var period = 0.75
@export var speed_up = 0.25
@export var speed_down = 1.0

# --- Internal State ---
var t = 0.0 # For sine wave
# Inherited: health, speed_multiplier, can_move, can_orient, active_effects, crawler_id, player, sprite
# Inherited Signals: damaged, killed

@onready var sprite: Sprite2D = $Sprite2D

# --- Bouncing State (Specific to Crawler) ---
var is_bouncing = false
var bounce_timer = 0.0
var bounce_movement = Vector2.ZERO
var bounce_speed_multiplier = 0.5
var collision_cooldown = 0.0

func _ready():
	super()._ready() # Call parent's ready function first!
	sprite = get_node_or_null("Sprite2D")
	t = randf() * PI * 2
	# _find_player is called by base class _ready->call_deferred

func _physics_process(delta):
	if not is_instance_valid(player): return
	if is_instance_valid(sprite): sprite.global_rotation = 0
	if collision_cooldown > 0: collision_cooldown -= delta

	if is_bouncing:
		var bounce_collision = move_and_collide(bounce_movement * delta)
		bounce_timer -= delta
		if bounce_timer <= 0: is_bouncing = false
		elif bounce_collision and collision_cooldown <= 0:
			bounce_movement = bounce_movement.bounce(bounce_collision.get_normal())
			collision_cooldown = 0.05
		return # Skip base processing while bouncing

	super._physics_process(delta) # Call base class physics

# Implement Orientation Logic (Called by EnemyBase)
func _perform_orientation(_delta: float):
	# orientation_target is set by base class or Confusion effect
	if is_instance_valid(orientation_target): # Check if target is a Node
		look_at(orientation_target.global_position)
	elif orientation_target is Vector2: # Check if target is a position
		look_at(orientation_target)
	# If null, do nothing (or maybe default orientation?)

# Implement Movement Logic (Called by EnemyBase)
func _perform_movement(delta: float, effective_speed: float):
	# Sine Wave Movement
	var going_up = (t < PI / 2) or (t > 3 * PI / 2)
	var speed_factor = speed_up if going_up else speed_down
	var effective_period = period / speed_factor if speed_factor > 0 else period
	if effective_period > 0 : t += delta * (2 * PI / effective_period)
	else: t += delta

	var forward_movement = transform.x * effective_speed * delta
	var oscillation = transform.y * sin(t) * amplitude * delta
	var global_movement = forward_movement + oscillation

	var collision = move_and_collide(global_movement)
	if collision and collision_cooldown <= 0:
		var collider = collision.get_collider()
		# Bounce off other physics bodies (not static bounds)
		if is_instance_valid(collider) and collider != self and collider is CharacterBody2D:
			is_bouncing = true
			bounce_timer = 0.2
			# Adjust bounce calculation if needed
			bounce_movement = global_movement.bounce(collision.get_normal()) * bounce_speed_multiplier / delta
			collision_cooldown = 0.05

	if is_instance_valid(sprite): sprite.global_rotation = 0
	if t >= 2 * PI: t = fmod(t, 2 * PI)
