# File: res://sequencer/behaviors/Behavior_ShootProjectile.gd
class_name Behavior_ShootProjectile
extends BlockBehavior

func execute(spawn_pos: Vector2, aim_angle: float, effects_payload: Array, block_ref: BlockData):
	var level = Engine.get_main_loop().current_scene
	var bullet_pool = level.get_node_or_null("BulletPool")
	
	if not bullet_pool:
		printerr("Shoot Behavior: BulletPool not found in scene.")
		return
		
	var bullet = bullet_pool.get_bullet()
	
	# Pass the 4th argument (block_ref) to the bullet for stat tracking
	# This matches the new fire() signature in your bullet.gd
	bullet.fire(spawn_pos, aim_angle, effects_payload, block_ref)
