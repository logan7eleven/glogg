extends Area2D

@onready var gun = $cannon/gun
@export var pixels_per_step = 500

# Stage-based fire rates in frames (at 30 FPS)
var fire_rates = {
	1: 0.25,   # Stage 1: 4 shots per second (250ms interval)
	2: 0.125,  # Stage 2: 8 shots per second (125ms interval)
	3: 0.083333  # Stage 3: 12 shots per second (83.3ms interval)
}
var time_since_last_fire: float = 0.0
var current_stage = 1
var current_fire_rate = 0.25  # Start with stage 1 fire rate (in frames)
var last_aim_direction = 0.0
var min_pos: Vector2
var max_pos: Vector2
var aim_direction = Vector2.ZERO
var target_angle = 0.0
var fire_queued = false
var cockpit_target_angle = 0.0
var movement_queued = false
var rotation_speed = 50.0

const ROTATION_TOLERANCE = 0.03

func _ready():
	# Get viewport size and set constraints with margins that account for sprite size and scale
	var viewport_size = get_viewport_rect().size
	var sprite_radius = 23 * scale.x
	add_to_group("players")
	
	# Use sprite_radius to calculate bounds
	min_pos = Vector2(sprite_radius, sprite_radius)
	max_pos = Vector2(viewport_size.x - sprite_radius, viewport_size.y - sprite_radius)
	
	print("Stage ", current_stage, " - Fire Rate: ", 1.0/current_fire_rate, " shots per second")
	
func _process (delta):
	# Aiming and Shooting
	var aim_x = Input.get_axis("aimL", "aimR")
	var aim_y = Input.get_axis("aimU", "aimD")
	aim_direction = Vector2(aim_x, aim_y)
	
	if aim_direction != Vector2.ZERO and not fire_queued:
		time_since_last_fire += delta
		if time_since_last_fire >= current_fire_rate:
			fire_queued = true
			target_angle = round(aim_direction.angle() / (PI / 12)) * (PI / 12)
	
func advance_stage():
	current_stage = min(current_stage + 1, 3)  # Cap at stage 3
	current_fire_rate = fire_rates[current_stage]
	time_since_last_fire = 0.0  # Reset ftimer on stage change
	print("Stage ", current_stage, " - Fire Rate: ", 1/current_fire_rate, " shots per second")

func try_fire(aim_angle: float):
	var bullet = get_parent().projectile_pool.get_bullet()
	if bullet:
		bullet.fire(gun.global_position, aim_angle)

func _physics_process(delta):
	# Movement
	var move_x = Input.get_axis("moveL", "moveR")
	var move_y = Input.get_axis("moveU", "moveD")
	var movement = Vector2(move_x, move_y)
	
	if movement != Vector2.ZERO:
		movement = movement.normalized()
		var target_pos = position + movement * pixels_per_step * delta
		
		# Clamp the target position within viewport bounds
		target_pos.x = clamp(target_pos.x, min_pos.x, max_pos.x)
		target_pos.y = clamp(target_pos.y, min_pos.y, max_pos.y)
		
		position = target_pos
		
		if not movement_queued:
			cockpit_target_angle = movement.angle()
			movement_queued = true
			
	if movement_queued:
		$cockpit.rotation = lerp_angle($cockpit.rotation, cockpit_target_angle, rotation_speed * delta)
		
		var cockpit_angle_diff = abs(wrapf(cockpit_target_angle - $cockpit.rotation, -PI, PI))
		if cockpit_angle_diff <= ROTATION_TOLERANCE:
			movement_queued = false
		
		#$cockpit.rotation = movement.angle()
	
	# Aiming and Shooting
	if aim_direction != Vector2.ZERO or fire_queued:
		$cannon.rotation = lerp_angle($cannon.rotation, target_angle, rotation_speed * delta)
		
		var angle_diff = abs(wrapf(target_angle - $cannon.rotation, -PI, PI))
				
		if fire_queued and angle_diff <= ROTATION_TOLERANCE:
			try_fire(target_angle)
			time_since_last_fire = 0.0
			fire_queued = false

		last_aim_direction = rotation

# For testing - Bind this to event later
func _input(event):
	if event.is_action_pressed("ui_accept"):  # Space bar by default
		advance_stage()
