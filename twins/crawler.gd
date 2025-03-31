extends Area2D

@export var amplitude = 50
@export var period = 1
@export var speed_up = 2
@export var speed_down = 4
@export var player_path = NodePath("../Player") # Path to the player node

var t = 0.0
var viewport_bounds
var player
var direction = Vector2(1, 0) # Initial direction
var movement_speed = 0

func _ready():
	# Get the viewport size and set constraints with margins that account for sprite size and scale
	viewport_bounds = get_viewport_rect().size - Vector2(23, 23) # Assuming sprite_radius is 23
	player = get_node(player_path)
	randomize()

func _process(delta):
	# Calculate the sine wave position and velocity
	t += delta
	var sine_pos = amplitude * sin(2 * PI * t / period)
	var sine_vel = amplitude * 2 * PI / period * cos(2 * PI * t / period)
	
	# Determine the movement speed based on the slope of the sine wave
	if sine_vel>= 0:
		movement_speed = speed_up
	else:
		movement_speed = speed_down
		 #movement_speed = sine_vel >= 0 ? speed_up : speed_down

	# Calculate the movement direction and update position
	var movement = direction * movement_speed
	movement.y += sine_pos * delta

	# Ensure the crawler stays within the viewport
	var new_position = position + movement
	new_position.x = clamp(new_position.x, 0, viewport_bounds.x)
	new_position.y = clamp(new_position.y, 0, viewport_bounds.y)
	position = new_position

	# Redirect towards the player after each full wave
	if t >= period:
		t = 0.0
		direction = (player.position - position).normalized()

	# Detect collision with the player
	if position.distance_to(player.position) < 20: # Adjust collision distance as needed
		_on_collision_with_player()

func _on_collision_with_player():
	# Handle collision with the player
	print("Collision with player detected!")
	# Implement player damage or other collision effects here
