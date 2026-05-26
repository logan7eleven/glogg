class_name Behavior_ShootProjectile
extends BlockBehavior

# ADDED 'damage: float' TO THE SIGNATURE
func execute(spawn_pos: Vector2, aim_angle: float, damage: float, effects_payload: Array, block_ref: BlockData):
	var level = Engine.get_main_loop().current_scene
	var bullet_pool = level.get_node_or_null("BulletPool")
	
	if not bullet_pool:
		printerr("Shoot Behavior: BulletPool not found in scene.")
		return
		
	var bullet = bullet_pool.get_bullet()
	
	# Pass the damage into the bullet!
	bullet.fire(spawn_pos, aim_angle, damage, effects_payload, block_ref)
