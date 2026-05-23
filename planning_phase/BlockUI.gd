# File: res://planning_phase/BlockUI.gd
class_name BlockUI
extends Control

@onready var bg = $BG
@onready var label = $Label

func update_display(data: BlockData, cell_size: Vector2):
	# Size the UI to the block's grid dimensions
	custom_minimum_size = Vector2(data.width, data.height) * cell_size
	size = custom_minimum_size
	
	# Set colors and text
	bg.color = data.color
	bg.size = size
	
	label.text = data.display_name
	label.size = size
	
	# Visual flare: Add a slight border effect
	bg.modulate = Color(1.1, 1.1, 1.1) # Slight glow
