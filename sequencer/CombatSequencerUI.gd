# File: res://sequencer/CombatSequencerUI.gd
extends ColorRect

@export var sequencer_manager: Node

const GRID_COLS = 16
const GRID_ROWS = 12
const CELL_SIZE = Vector2(15, 3) # Smaller footprint for the combat HUD

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
		
		var block_rect = ColorRect.new()
		block_rect.color = block.color
		block_rect.position = Vector2(origin) * CELL_SIZE
		block_rect.size = Vector2(block.width, block.height) * CELL_SIZE
		add_child(block_rect)

func _process(_delta):
	if not is_instance_valid(sequencer_manager): return
	
	# Smoothly interpolate the playhead across the grid columns
	var step = sequencer_manager.current_step
	var progress = sequencer_manager.step_timer / sequencer_manager.SECONDS_PER_STEP
	playhead.position.x = (step + progress) * CELL_SIZE.x
