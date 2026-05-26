# File: res://sequencer/SequencerManager.gd
extends Node

const GRID_COLS = 16
const GRID_ROWS = 3

# 112.5 BPM = 1.875 beats per second = 2.133 seconds per 16-step loop
# 2.133 / 16 = 0.1333 seconds per step
const SECONDS_PER_STEP: float = 0.133333 

var spatial_grid: Array = []
var current_step: int = 0
var step_timer: float = 0.0
var is_active: bool = false

@onready var player: Node2D

func _ready():
	_build_lookup_grid()
	
	# Wait for player to spawn, then start sequencer
	player = get_tree().get_first_node_in_group("players")
	is_active = true

func _build_lookup_grid():
	spatial_grid.resize(GRID_COLS)
	for i in range(GRID_COLS):
		spatial_grid[i] = []
		spatial_grid[i].resize(GRID_ROWS)
		spatial_grid[i].fill(null)
		
	# Populate local grid from GlobalState master list
	for entry in GlobalState.master_sequencer_blocks:
		var block: BlockData = entry["block"]
		var origin: Vector2i = entry["origin"]
		
		for y in range(block.height):
			for x in range(block.width):
				if block.is_cell_active(x, y):
					var target_x = origin.x + x
					var target_y = origin.y + y
					if target_x < GRID_COLS and target_y < GRID_ROWS:
						# Store dictionary with block reference AND its root origin
						spatial_grid[target_x][target_y] = {
							"block": block,
							"origin": origin
						}

func _process(delta):
	# DYNAMIC FETCH: Find the player if we don't have them yet
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("players")
		return # Wait until next frame
		
	if not is_active: return
	
	# The Aiming Gate: only progress if aiming or finishing a mid-column fraction
	var is_aiming = player.aim_direction != Vector2.ZERO
	
	if is_aiming or step_timer > 0.0:
		step_timer += delta
		
		if step_timer >= SECONDS_PER_STEP:
			_execute_current_step()
			current_step = (current_step + 1) % GRID_COLS
			
			if not is_aiming:
				step_timer = 0.0 
			else:
				step_timer -= SECONDS_PER_STEP

func _execute_current_step():
	var unique_blocks_this_step: Dictionary = {}
	var column_total_height: int = 0
	
	var primary_behavior: Resource = null 
	var primary_block: BlockData = null 
	
	for y in range(GRID_ROWS):
		var cell_data = spatial_grid[current_step][y]
		if cell_data == null: 
			continue
		
		var block: BlockData = cell_data["block"]
		var origin: Vector2i = cell_data["origin"]
		
		if unique_blocks_this_step.has(block): 
			continue
			
		unique_blocks_this_step[block] = origin

	for block in unique_blocks_this_step.keys():
		var origin = unique_blocks_this_step[block]
		column_total_height += block.height
		
		if primary_behavior == null and block.behavior != null:
			primary_behavior = block.behavior
			primary_block = block

	if column_total_height > 0:
		var cumulative_damage = (float(column_total_height) / 12.0) * 2.0
		
		if primary_behavior and primary_behavior.has_method("execute"):
			# PULL EXACTLY WHAT THE BEHAVIOR ASKS FOR
			var gun_pos = player.get_gun_position()
			var aim_angle = player.get_aim_angle()
			
			# We will add cumulative_damage to this signature in the next step!
			primary_behavior.execute(gun_pos, aim_angle, cumulative_damage, primary_block.effects, primary_block)
