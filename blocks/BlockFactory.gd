# File: res://sequencer/BlockFactory.gd
class_name BlockFactory
extends RefCounted

enum Shape { LINE_FULL, LINE_HALF, SQUARE, L_SHAPE, T_SHAPE, DOT, LONG_4, LONG_5, LONG_6, LONG_7, LONG_8 }

static func create_random_block(available_status_effects: Array) -> BlockData:
	var shape = Shape.values().pick_random()
	var block = BlockData.new()
	block.remaining_integrity = 5.0 # Initialize cumulative timer
	block.shot_type = BlockData.ShotType.SINGLE
	
	block.behavior = GlobalState.BASIC_SHOOT_BEHAVIOR
	
	match shape:
		# Original Shapes
		Shape.LINE_FULL: _apply_shape(block, 1, 3, [true, true, true])
		Shape.LINE_HALF: _apply_shape(block, 1, 2, [true, true])
		Shape.SQUARE: _apply_shape(block, 2, 2, [true, true, true, true])
		Shape.L_SHAPE: _apply_shape(block, 2, 2, [true, false, true, true])
		Shape.T_SHAPE: _apply_shape(block, 3, 2, [true, true, true, false, true, false])
		Shape.DOT: _apply_shape(block, 1, 1, [true])
		
		# The new extra-long pieces (Spawn vertical, forcing the player to rotate!)
		Shape.LONG_4: _apply_shape(block, 1, 4, [true, true, true, true])
		Shape.LONG_5: _apply_shape(block, 1, 5, [true, true, true, true, true])
		Shape.LONG_6: _apply_shape(block, 1, 6, [true, true, true, true, true, true])
		Shape.LONG_7: _apply_shape(block, 1, 7, [true, true, true, true, true, true, true])
		Shape.LONG_8: _apply_shape(block, 1, 8, [true, true, true, true, true, true, true, true])

	if available_status_effects.size() > 0:
		var effect_wrapper = EffectData.new()
		effect_wrapper.status_effect = available_status_effects.pick_random()
		block.effects.append(effect_wrapper)
		block.display_name = effect_wrapper.get_display_name()
		block.color = Color(randf_range(0.3, 1.0), randf_range(0.3, 1.0), randf_range(0.3, 1.0)) 
	else:
		block.display_name = "Raw Geometry"
		block.color = Color.DIM_GRAY

	return block

static func _apply_shape(block: BlockData, w: int, h: int, mask: Array):
	block.width = w
	block.height = h
	var typed_mask: Array[bool] = []
	typed_mask.assign(mask)
	block._shape_mask_data = typed_mask
