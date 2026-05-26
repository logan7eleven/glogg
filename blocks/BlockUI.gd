# File: res://planning_phase/BlockUI.gd
class_name BlockUI
extends Control

@onready var bg = $BG
@onready var label = $Label

func update_display(data: BlockData, cell_size: Vector2):
	custom_minimum_size = Vector2(data.width, data.height) * cell_size
	size = custom_minimum_size
	
	# Make the main background invisible so it just acts as an anchor
	bg.color = Color(0, 0, 0, 0)
	bg.size = size
	
	# Clear out any old cells (important for when you rotate!)
	for child in bg.get_children():
		child.queue_free()
		
	# Draw the actual Tefunc update_display(data: BlockData, cell_size: Vector2):
	custom_minimum_size = Vector2(data.width, data.height) * cell_size
	size = custom_minimum_size
	
	bg.color = Color(0, 0, 0, 0)
	bg.size = size
	
	for child in bg.get_children():
		child.queue_free()
		bg.remove_child(child) # Ensures clean removal
		
	for y in range(data.height):
		for x in range(data.width):
			if data.is_cell_active(x, y):
				var cell = ColorRect.new()
				cell.color = data.color
				cell.position = Vector2(x, y) * cell_size
				cell.size = cell_size
				bg.add_child(cell)
