extends Area2D  # Changed from CharacterBody2D

@onready var gun = $Sprite2D/gun
@export var pixels_per_step = 16  # This will be 120 pixels/second at 30fps

var last_aim_direction = 0.0

func _physics_process(_delta):
	# Movement
	var move_x = Input.get_axis("moveL", "moveR")
	var move_y = Input.get_axis("moveU", "moveD")
	var movement = Vector2(move_x, move_y)
	
	if movement != Vector2.ZERO:
		movement = movement.normalized()
		position += movement * pixels_per_step
	
	# Aiming and Shooting
	var aim_x = Input.get_axis("aimL", "aimR")
	var aim_y = Input.get_axis("aimU", "aimD")
	
	if aim_x != 0 or aim_y != 0:
		var aim_direction = Vector2(aim_x, aim_y)
		var snapped_angle = round(aim_direction.angle() / (PI / 12)) * (PI / 12) + PI/2
		$Sprite2D.rotation = lerp_angle($Sprite2D.rotation, snapped_angle, 0.65)
		
		# Fire bullet
		var bullet = get_parent().projectile_pool.get_bullet()
		if bullet:
			bullet.fire(gun.global_position, snapped_angle)
		
		last_aim_direction = rotation
