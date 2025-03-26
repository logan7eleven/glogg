extends Area2D

@onready var gun = $cannon/gun
@export var pixels_per_step = 15

# Stage-based fire rates in frames (at 30 FPS)
var fire_rates = {
	1: 15,  # Stage 1: 2 shots per second (30/2 = 15 frames)
	2: 10,   # Stage 2: 3 shots per second (30/3 = 10 frames)
	3: 6    # Stage 3: 5 shots per second (30/5 = 6 frames)
}

var current_stage = 1
var current_fire_rate = 15  # Start with stage 1 fire rate (in frames)
var last_aim_direction = 0.0
var min_pos: Vector2
var max_pos: Vector2
var last_fire_frame = 0
var can_fire = true
var aim_direction = Vector2.ZERO
var target_angle = 0.0
var fire_queued = false
var cockpit_target_angle = 0.0
var movement_queued = false

const ROTATION_TOLERANCE = 0.03

func _ready():
	# Get viewport size and set constraints with margins that account for sprite size and scale
	var viewport_size = get_viewport_rect().size
	var sprite_radius = 23 * scale.x
	
	# Use sprite_radius to calculate bounds
	min_pos = Vector2(sprite_radius, sprite_radius)
	max_pos = Vector2(viewport_size.x - sprite_radius, viewport_size.y - sprite_radius)
	print("Stage ", current_stage, " - Fire Rate: ", 30/current_fire_rate, " shots per second")

func _process (_delta):
	# Aiming and Shooting
	var aim_x = Input.get_axis("aimL", "aimR")
	var aim_y = Input.get_axis("aimU", "aimD")
	aim_direction = Vector2(aim_x, aim_y)
	
	if aim_direction != Vector2.ZERO and not fire_queued:
		var frames_since_last_fire = Engine.get_physics_frames() - last_fire_frame
		if frames_since_last_fire >= current_fire_rate:
			fire_queued = true
			target_angle = round(aim_direction.angle() / (PI / 12)) * (PI / 12)
	
func advance_stage():
	current_stage = min(current_stage + 1, 3)  # Cap at stage 3
	current_fire_rate = fire_rates[current_stage]
	last_fire_frame = 0  # Reset frame counter on stage change
	print("Stage ", current_stage, " - Fire Rate: ", 30/current_fire_rate, " shots per second")

func try_fire(aim_angle: float):
	var bullet = get_parent().projectile_pool.get_bullet()
	if bullet:
		bullet.fire(gun.global_position, aim_angle)

func _physics_process(_delta):
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
		
		if not movement_queued:
			cockpit_target_angle = movement.angle()
			movement_queued = true
			
	if movement_queued:
		$cockpit.rotation = lerp_angle($cockpit.rotation, cockpit_target_angle, 0.65)
		
		var cockpit_angle_diff = abs(wrapf(cockpit_target_angle - $cockpit.rotation, -PI, PI))
		if cockpit_angle_diff <= ROTATION_TOLERANCE:
			movement_queued = false
		
		#$cockpit.rotation = movement.angle()
	
	# Aiming and Shooting
	if aim_direction != Vector2.ZERO or fire_queued:
		$cannon.rotation = lerp_angle($cannon.rotation, target_angle, 0.65)
		
		var angle_diff = abs(wrapf(target_angle - $cannon.rotation, -PI, PI))
				
		if fire_queued and angle_diff <= ROTATION_TOLERANCE:
			try_fire(target_angle)
			last_fire_frame = Engine.get_physics_frames()
			fire_queued = false

		last_aim_direction = rotation

# For testing - Bind this to event later
func _input(event):
	if event.is_action_pressed("ui_accept"):  # Space bar by default
		advance_stage()
