# File: res://loot/DroppedBlock.gd
extends Area2D

const MAX_INTEGRITY: float = 5.0 # Total possible life
var stored_block: BlockData = null

@onready var visual_rect = $ColorRect

func setup(block: BlockData):
	stored_block = block
	if is_inside_tree() and stored_block:
		# Hide the solid bounding box so we don't see it
		visual_rect.hide() 
		# Tell Godot to run the _draw() function!
		queue_redraw()

func _ready():
	add_to_group("drops")
	if stored_block: setup(stored_block)

func _draw():
	if not stored_block: return
	
	# Keep the physical drops mathematically square
	var cell_w = 16.0
	var cell_h = 16.0
	var top_left = Vector2(-stored_block.width * cell_w / 2.0, -stored_block.height * cell_h / 2.0)
	
	for y in range(stored_block.height):
		for x in range(stored_block.width):
			if stored_block.is_cell_active(x, y):
				var cell_pos = top_left + Vector2(x * cell_w, y * cell_h)
				var rect = Rect2(cell_pos, Vector2(cell_w, cell_h))
				draw_rect(rect, stored_block.color)

func _process(delta):
	if not stored_block: return
	
	stored_block.remaining_integrity -= delta
	var life_ratio = max(0.0, stored_block.remaining_integrity / MAX_INTEGRITY)
	
	# Apply the fade to the entire object instead of visual_rect
	modulate.a = max(0.3, life_ratio)
	
	if stored_block.remaining_integrity < 1.5:
		visible = int(Time.get_ticks_msec() / 100.0) % 2 == 0
		
	if stored_block.remaining_integrity <= 0:
		queue_free()
