# File: res://sequencer/CombatSequencerUI.gd
extends ColorRect

@export var sequencer_manager: Node

const GRID_COLS = 16
const GRID_ROWS = 3
const CELL_SIZE = Vector2(16, 16) # Smaller footprint for the combat HUD

@onready var playhead = ColorRect.new()

func _ready():
	# Configure the background
	custom_minimum_size = Vector2(GRID_COLS * CELL_SIZE.x, GRID_ROWS * CELL_SIZE.y)
	size = custom_minimum_size
	color = Color(0.1, 0.1, 0.1, 0.8) # Semi-transparent dark background
	
	_draw_blocks()
	
	# Configure the playhead
	playhead.color = Color(1, 1, 1, 0.5) # Semi-transparent white bar
	playhead.size = Vector2(CELL_SIZE.x, size.y)
	add_child(playhead)

func _draw_blocks():
	for entry in GlobalState.master_sequencer_blocks:
		var block: BlockData = entry["block"]
		var origin: Vector2i = entry["origin"]
		
		# Draw each active cell individually
		for y in range(block.height):
			for x in range(block.width):
				if block.is_cell_active(x, y):
					var cell_rect = ColorRect.new()
					cell_rect.color = block.color
					
					# Offset by both the block's origin AND the cell's local position
					var cell_x = origin.x + x
					var cell_y = origin.y + y
					cell_rect.position = Vector2(cell_x, cell_y) * CELL_SIZE
					cell_rect.size = CELL_SIZE
					
					add_child(cell_rect)

func _process(_delta):
	if not is_instance_valid(sequencer_manager): return
	
	# Smoothly interpolate the playhead across the grid columns
	var step = sequencer_manager.current_step
	var progress = sequencer_manager.step_timer / sequencer_manager.SECONDS_PER_STEP
	playhead.position.x = (step + progress) * CELL_SIZE.x
