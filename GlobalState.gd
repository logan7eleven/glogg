# File: res://GlobalState.gd
extends Node

signal upgrades_ready

# --- V2 DATA STRUCTURES ---
var master_sequencer_blocks: Array[Dictionary] = [] 
var master_perm_storage: BlockData = null
var master_temp_storage: Array[BlockData] = []

# Used for your rhythm grid obstacles
var obstacle_origins: Array[Vector2i] = [] 

# --- RESOURCE PRELOADS ---
const BASIC_SHOOT_BEHAVIOR = preload("res://sequencer/behaviors/BasicShootBehavior.tres")

func _ready():
	reset_for_new_game()

func reset_for_new_game():
	master_sequencer_blocks.clear()
	master_perm_storage = null
	master_temp_storage.clear()
	obstacle_origins.clear()
	
	# Setting up initial obstacles based on your UI layout
	obstacle_origins.append(Vector2i(2, 0))
	obstacle_origins.append(Vector2i(6, 0))
	obstacle_origins.append(Vector2i(10, 0))
	obstacle_origins.append(Vector2i(14, 0))
	
	# Add the 4 starting blocks
	_add_default_shot(Vector2i(0, 0))
	_add_default_shot(Vector2i(4, 0))
	_add_default_shot(Vector2i(8, 0))
	_add_default_shot(Vector2i(12, 0))

func _add_default_shot(origin: Vector2i):
	var block = BlockData.new()
	block.display_name = "Basic Shot"
	block.color = Color.WHITE
	block.width = 1
	block.height = 3 # <--- Changed from 12 to 3!
	block.shot_type = BlockData.ShotType.SINGLE
	block.remaining_integrity = 5.0 
	
	# Link the execution behavior
	block.behavior = BASIC_SHOOT_BEHAVIOR
	
	block.initialize() 
	
	master_sequencer_blocks.append({
		"block": block,
		"origin": origin
	})

func save_planning_phase_state(sequencer_layout: Array[Dictionary], perm: BlockData):
	master_sequencer_blocks = sequencer_layout
	master_perm_storage = perm
	
	# Penalty: Clear temporary and staging storage on exit
	master_temp_storage.clear()
