extends Area2D

@export var amplitude = 2
@export var period = 2
@export var speed_up = 10
@export var speed_down = 5

var t = 0.0
var viewport_bounds
var player
var direction = Vector2.ZERO
var movement_speed = 0
var health = 3

func _ready():
	viewport_bounds = get_viewport_rect().size - Vector2(46, 46) # Assuming sprite_radius is 23
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("players")
	direction = (player.position - position).normalized()
	if not player:
		push_warning("Crawler: Could not find player node!")
	add_to_group("enemies")

func _process(delta):
	# Calculate the sine wave position and velocity
	t += delta
	var sine_pos = amplitude * sin(2 * PI * t / period)
	var sine_vel = amplitude * 2 * PI / period * cos(2 * PI * t / period)
	
	movement_speed = speed_up if sine_vel >= 0 else speed_down

	# Calculate the movement direction and update position
	var movement = direction * movement_speed
	movement.y += sine_pos * delta

 # Check for crawler collisions before moving
	var potential_position = position + movement
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		position,
		potential_position,
		collision_mask,
		[self]  # Exclude self from collision check
	)
	
	var collision = space_state.intersect_ray(query)
	if !collision or !collision.collider.is_in_group("enemies"):
		# Only move if no collision with other crawlers
		var new_position = potential_position
		new_position.x = clamp(new_position.x, 0, viewport_bounds.x)
		new_position.y = clamp(new_position.y, 0, viewport_bounds.y)
		position = new_position


	## Ensure the crawler stays within the viewport
	#var new_position = position + movement
	#new_position.x = clamp(new_position.x, 0, viewport_bounds.x)
	#new_position.y = clamp(new_position.y, 0, viewport_bounds.y)
	#position = new_position

	# Redirect towards the player after each full wave
	if t >= period:
		t = 0.0
		direction = (player.position - position).normalized()

func take_damage():
	health -= 1
	if health <= 0:
		queue_free()  # Remove crawler when health reaches 0


func _on_area_entered(area: Area2D):
	if area.is_in_group("players"):
		_on_collision_with_player()
	elif area.is_in_group("bounds"):
		# Bounce off bounds by reflecting the direction
		direction = direction.reflect(Vector2.RIGHT if abs(direction.x) > abs(direction.y) else Vector2.UP)
	elif area.is_in_group("bullets"):
		take_damage()
		area.deactivate()  # Call deactivate on the bullet

func _on_collision_with_player():
	print("Collision with player detected!")
	if player:
		var level = get_parent()
		level.game_over()
		print("game over!")
