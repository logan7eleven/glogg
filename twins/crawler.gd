extends CharacterBody2D

@export var amplitude = 150
@export var period = 0.75
@export var speed_up = 0.25    # Speed for upward sine movement (/)
@export var speed_down = 1.0 # Speed for downward sine movement (\)
@export var speed = 100    # Constant forward speed

var t = 0.0
var player
var direction: Vector2
var health = 3
var sprite: Sprite2D
var is_bouncing = false
var bounce_timer = 0.0
var bounce_movement = Vector2.ZERO
var bounce_speed_multiplier = 0.5
var collision_cooldown = 0.0

signal enemy_damaged(slot_index: int)
signal enemy_killed(slot_index: int)

func _ready():
	sprite = get_node_or_null("Sprite2D")
	t = randf() * PI * 2
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("players")
	look_at(player.position)
	if sprite:
		sprite.global_rotation = 0
	add_to_group("enemies")
	var hitbox = $HitBox
	hitbox.area_entered.connect(_on_area_entered)

func _physics_process(delta):	
	if !player:
		return
	
	if sprite:
		sprite.global_rotation = 0
	
	# Update collision cooldown
	if collision_cooldown > 0:
		collision_cooldown -= delta
	
	# Handle bounce state
	if is_bouncing:
		var collision = move_and_collide(bounce_movement)
		
		bounce_timer -= delta
		if bounce_timer <= 0:
			# End bounce and reset sine wave
			is_bouncing = false
			look_at(player.position)
			if sprite:
				sprite.global_rotation = 0
		elif collision and collision_cooldown <= 0:
			# On collision during bounce, reverse direction but maintain sine wave pattern
			bounce_movement = -bounce_movement
			bounce_timer = 0.2  # Reset timer for new bounce
			collision_cooldown = 0.05  # Add small cooldown to prevent immediate re-collision
		return
	
	# Normal movement
	# Check the next position first
	var going_up = (t < PI/2) or (t > 3*PI/2)
	var speed_multiplier = speed_up if going_up else speed_down
	
	# Update t with the appropriate speed
	t += delta * (2 * PI / period) 
	
	# Calculate movement with the updated t
	var forward_movement = transform.x * speed * delta
	var oscillation = transform.y * sin(t) * amplitude * delta * speed_multiplier 
	var global_movement = forward_movement + oscillation
	
	var collision = move_and_collide(global_movement)
	if collision and collision_cooldown <= 0:
		if collision.get_collider().is_in_group("bounds"):
			# For bounds, just zero out the component that would go beyond bounds
			# Don't enter bounce state or reverse direction
			var normal = collision.get_normal()
			var adjusted_movement = global_movement - (global_movement.dot(normal) * normal)
			move_and_collide(adjusted_movement)
		else:
			# Only enter bounce state for non-bounds collisions (like other enemies)
			is_bouncing = true
			bounce_timer = 0.2
			bounce_movement = -global_movement * bounce_speed_multiplier
		collision_cooldown = 0.05
		
	sprite.global_rotation = 0
	
	if t >= 2 * PI:
		t = 0.0
		if !is_bouncing:
			look_at(player.position)
			if sprite:
				sprite.global_rotation = 0

func take_damage(slot_index: int):
	health -= 1
	print("Crawler Health:", health)
	emit_signal("enemy_damaged", slot_index)
	if health <= 0:
		emit_signal("enemy_killed", slot_index)
		queue_free()  # Remove crawler when health reaches 0

func _on_area_entered(area: Area2D):
	if area.is_in_group("players"):
		_on_collision_with_player()
	elif area.is_in_group("bullets"):
		take_damage(area.slot_index)
		area.deactivate()  # Call deactivate on the bullet

func _on_collision_with_player():
	if player:
		var level = get_parent()
		level.game_over()
