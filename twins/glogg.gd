extends CharacterBody2D

@export var speed = 600.0
@export var rotation_speed = .02
@export var bullet_speed = 500.0
@export var fire_rate = 10.0
@export var can_shoot: bool = false

var direction = 0
#var ammo: PackedScene = preload("res://bullet.tscn")

var last_shot_time = 0.0
var last_aim_direction = 0.0

signal shoot

func _physics_process(_delta):

	var move_x = Input.get_axis("moveL", "moveR")
	var move_y = Input.get_axis("moveU", "moveD")
	var aim_x = Input.get_axis("aimL", "aimR")
	var aim_y = Input.get_axis("aimU", "aimD")
	
	#print(aim_x)
	#print(aim_y)

	velocity = Vector2(move_x, move_y).normalized() * speed
	
	move_and_slide()
	
	var aim_direction = Vector2(aim_x, aim_y) 
	

	if aim_x != 0 or aim_y != 0:
		#print ('aim')
		#print (aim_direction.length())
		shoot.emit()
		
		rotation = aim_direction.angle()
		var target_angle = Vector2(aim_x, aim_y)
		last_aim_direction = target_angle.angle()
	
		#last_shot_time += _delta
		#if last_shot_time >= 1 / fire_rate:
			#var bullet = ammo.instantiate()
			#bullet.global_position = global_position
			#bullet.rotation = rotation
			#bullet.linear_velocity = Vector2(0, -bullet_speed).rotated(rotation)
			#add_child(bullet)
			#last_shot_time = 0.0
	#
	direction = last_aim_direction
