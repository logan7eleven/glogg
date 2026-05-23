# File: res://sequencer/behaviors/BlockBehavior.gd
class_name BlockBehavior
extends Resource

@export var behavior_id: String = "base_behavior"

# The parent signature MUST have these 4 arguments
func execute(spawn_pos: Vector2, aim_angle: float, effects_payload: Array, block_ref: BlockData):
	pass
