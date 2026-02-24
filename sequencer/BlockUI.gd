# File: res://planning_phase/BlockUI.gd
class_name BlockUI
extends Control

# --- Node References ---
# The '%' syntax requires you to set "Access as Unique Name" in the editor's Scene dock.
@onready var background: ColorRect = %Background
@onready var label: Label = %Label

# --- Properties ---
var block_data: BlockData # A reference to the data this UI represents.

# This is the main function to configure the UI element's appearance.
func update_display(data: BlockData, cell_size: Vector2):
	block_data = data
	
	# If there's no data, this UI element should be invisible.
	if block_data == null:
		visible = false
		return
		
	# Make sure it's visible if it has data.
	visible = true
	
	# Set the text and color from the data blueprint.
	label.text = block_data.display_name
	background.color = block_data.color
	
	# Calculate and set the visual size based on the block's grid dimensions
	# and the visual size of a single grid cell.
	var visual_width = block_data.width * cell_size.x
	var visual_height = block_data.height * cell_size.y
	custom_minimum_size = Vector2(visual_width, visual_height)

# This function will be used later to show that a block is "held".
func set_held_visual(is_held: bool):
	# Make the block semi-transparent if it's being held.
	modulate = Color(1, 1, 1, 0.4) if is_held else Color(1, 1, 1, 1)
