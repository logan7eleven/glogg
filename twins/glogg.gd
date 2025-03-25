extends Area2D

@onready var gun = $cannon/gun
@export var pixels_per_step = 16

# Stage-based fire rates in frames (at 30 FPS)
var fire_rates = {
	1: 10,  # Stage 1: 3 shots per second (30/3 = 10 frames)
	2: 6,   # Stage 2: 5 shots per second (30/5 = 6 frames)
	3: 3    # Stage 3: 10 shots per second (30/10 = 3 frames)
}

var current_stage = 1
var current_fire_rate = 10  # Start with stage 1 fire rate (in frames)
var last_aim_direction = 0.0
var min_pos: Vector2
var max_pos: Vector2
var frame_counter = 0
var debug_shot_count = 0
var debug_time = 0.0

func _ready():
	# Get viewport size and set constraints with margins that account for sprite size and scale
	var viewport_size = get_viewport_rect().size
	var sprite_radius = 23 * scale.x
	
	# Use sprite_radius to calculate bounds
	min_pos = Vector2(sprite_radius, sprite_radius)
	max_pos = Vector2(viewport_size.x - sprite_radius, viewport_size.y - sprite_radius)
	print("Starting at Stage 1 - Fire Rate: 3 shots per second (every 10 frames)")

func advance_stage():
	current_stage = min(current_stage + 1, 3)  # Cap at stage 3
	current_fire_rate = fire_rates[current_stage]
	frame_counter = 0  # Reset frame counter on stage change
	debug_shot_count = 0
	debug_time = 0.0
	print("Advanced to Stage ", current_stage, " - Fire Rate: ", 30.0/current_fire_rate, " shots per second (every ", current_fire_rate, " frames)")

func try_fire(aim_angle: float):
	var bullet = get_parent().projectile_pool.get_bullet()
	if bullet:
		bullet.fire(gun.global_position, aim_angle)
		debug_shot_count += 1

func _physics_process(delta):
	frame_counter = (frame_counter + 1) % current_fire_rate
	
	debug_time += delta
	if debug_time >= 1.0:
		print("Shots in last second: ", debug_shot_count)
		debug_shot_count = 0
		debug_time = 0.0
	
	# Movement
	var move_x = Input.get_axis("moveL", "moveR")
	var move_y = Input.get_axis("moveU", "moveD")
	var movement = Vector2(move_x, move_y)
	
	if movement != Vector2.ZERO:
		movement = movement.normalized()
		var target_pos = position + movement * pixels_per_step
		
		# Clamp the target position within viewport bounds
		target_pos.x = clamp(target_pos.x, min_pos.x, max_pos.x)
		target_pos.y = clamp(target_pos.y, min_pos.y, max_pos.y)
		
		position = target_pos
		$cockpit.rotation = movement.angle()
	
	# Aiming and Shooting
	var aim_x = Input.get_axis("aimL", "aimR")
	var aim_y = Input.get_axis("aimU", "aimD")
	
	if aim_x != 0 or aim_y != 0:
		var aim_direction = Vector2(aim_x, aim_y)
		var snapped_angle = round(aim_direction.angle() / (PI / 12)) * (PI / 12)
		$cannon.rotation = lerp_angle($cannon.rotation, snapped_angle, 0.65)
		
		# Fire bullet if frame counter is 0
		if frame_counter == 0:
			try_fire(snapped_angle)
		
		last_aim_direction = rotation

# For testing - you can bind this to a key or event
func _input(event):
	if event.is_action_pressed("ui_accept"):  # Space bar by default
		advance_stage()
