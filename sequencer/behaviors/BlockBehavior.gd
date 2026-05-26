class_name BlockBehavior
extends Resource

@export var behavior_id: String = "base_behavior"

# ADDED 'damage: float' TO THE SIGNATURE
func execute(spawn_pos: Vector2, aim_angle: float, damage: float, effects_payload: Array, block_ref: BlockData):
	pass
