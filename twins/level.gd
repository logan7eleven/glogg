extends Node2D

var ammo: PackedScene = preload("res://bullet.tscn")

#func
#last_shot_time += _delta
		#if last_shot_time >= 1 / fire_rate:
			#var bullet = ammo.instantiate()
			#bullet.global_position = global_position
			#bullet.rotation = rotation
			#bullet.linear_velocity = Vector2(0, -bullet_speed).rotated(rotation)
			#add_child(bullet)
			#last_shot_time = 0.0
	#
	#direction = last_aim_direction


func _on_glogg_shoot():
	#print("shoot signal")
	var bull = ammo.instantiate()
	bull.position = position
	#bullet.linear_velocity = Vector2(0, glogg.bullet_speed).rotated(rotation)
	$Projectiles.add_child(bull)
	print(position)
	#glogg.last_shot_time = 0.0
