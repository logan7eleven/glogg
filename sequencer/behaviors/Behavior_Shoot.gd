class_name Behavior_Shoot extends BlockBehavior

func execute(spawn_pos: Vector2, aim_angle: float, effects_payload: Array, block_ref: BlockData):
	# We pull your old glogg.gd logic here
	var level = Engine.get_main_loop().current_scene
	var bullet_pool = level.get_node("BulletPool")
	var bullet = bullet_pool.get_bullet()
	
	# We pass the effects_payload and block_ref to the bullet, so it knows what to apply on impact
	bullet.fire(spawn_pos, aim_angle, effects_payload, block_ref)
