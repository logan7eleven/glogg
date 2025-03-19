extends CharacterBody2D

@onready var gun = $Sprite2D/gun

@export var speed = 1200.0

var direction = Vector2.ZERO
var last_shot_time = 0.0
var last_aim_direction = 0.0
var time_since_last_shot = 0
var sensitivity = 999999
var time_step = 1/24.0  # Fixed timestep for 24 FPS
var fire_rate = 4
var time_since_last_move = 0 

func _physics_process(delta):
	var move_x = Input.get_axis("moveL", "moveR")
	var move_y = Input.get_axis("moveU", "moveD")
	var aim_x = Input.get_axis("aimL", "aimR")
	var aim_y = Input.get_axis("aimU", "aimD")

	aim_x *= sensitivity
	aim_y *= sensitivity
	
	time_since_last_move += delta
	
		# Normalize the input vector to ensure minimum speed
	var input_vector = Vector2(move_x, move_y).normalized()
	if time_since_last_move >= time_step:
		# Calculate the desired movement in pixels based on time_step
		velocity = input_vector * speed

		# Update the position with sub-pixel precision
		move_and_slide()

		time_since_last_move -= time_step  # Reset the accumulator

	var aim_direction = Vector2(aim_x, aim_y)
	time_since_last_shot += delta
	
	if (aim_x != 0 or aim_y != 0) and time_since_last_shot >= fire_rate * time_step:
		var snapped_angle = round(aim_direction.angle() / (PI / 12)) * (PI / 12) + PI/2
		$Sprite2D.rotation = lerp_angle($Sprite2D.rotation, snapped_angle, 0.65)
		var bullet = get_parent().projectile_pool.get_bullet()  # Get bullet from the pool
		bullet.fire(gun.global_position, snapped_angle)  # Directly fire the bullet
		time_since_last_shot = 0
		last_aim_direction = rotation

	direction = last_aim_direction
