# File: res://planning_phase/PlanningPhase.gd
extends Control

# --- CONSTANTS ---
const GRID_COLS = 16
const GRID_ROWS = 3
const CELL_SIZE = Vector2(32, 32)

# --- UI REFERENCES ---
@onready var bar_container: ColorRect = %BarContainer
@onready var temp_container: ColorRect = %TempContainer
@onready var perm_container: ColorRect = %PermContainer
@onready var selector: Control = %Selector
@onready var effect_label: Label = %EffectLabel

# --- SCENE PRELOADS ---
const BLOCK_UI_SCENE = preload("res://blocks/BlockUI.tscn")

# --- STATE MANAGEMENT ---
enum State { 
	CONTAINER_SELECTION,  
	NOT_HOLDING,          
	HOLDING_BLOCK         
}

enum ContainerZone { SEQUENCER, PERM_STORAGE, TEMP_STORAGE }

var current_state: State = State.CONTAINER_SELECTION
var active_zone: ContainerZone = ContainerZone.SEQUENCER

# --- DATA MODEL ---
var spatial_grid: Array = [] 
var sequencer_blocks: Array[BlockData] = []
var temp_storage: Array[BlockData] = []
var perm_storage: BlockData = null

# --- NAVIGATION & HOLDING STATE ---
var held_block: BlockData = null
var held_origin_zone: ContainerZone
var held_origin_coords: Vector2i 

var grid_cursor: Vector2i = Vector2i.ZERO 

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready():
	spatial_grid.resize(GRID_COLS)
	for i in range(GRID_COLS):
		spatial_grid[i] = []
		spatial_grid[i].resize(GRID_ROWS)
		spatial_grid[i].fill(null)
	
	_load_from_global_state()
	_redraw_all_ui()

func _load_from_global_state():
	for entry in GlobalState.master_sequencer_blocks:
		# Temporarily "hold" the block to trick the placement function into working perfectly
		held_block = entry["block"]
		grid_cursor = entry["origin"]
		_place_block_in_sequencer()
		
	# Now that everything is placed, empty your hands and reset the cursor!
	held_block = null
	grid_cursor = Vector2i.ZERO
	
	perm_storage = GlobalState.master_perm_storage
	
	# VERY IMPORTANT: Use .duplicate() so the Planning Phase array and the Global array don't get permanently tangled in memory!
	temp_storage = GlobalState.master_temp_storage.duplicate()

func _save_and_exit():
	var layout_to_save: Array[Dictionary] = []
	for block in sequencer_blocks:
		var origin = _get_block_origin(block)
		layout_to_save.append({
			"block": block,
			"origin": origin
		})
	
	# Transition penalty: Clear temp/scrap storage before saving
	temp_storage.clear() # <--- Changed from "temp_storage = null"
	
	GlobalState.save_planning_phase_state(layout_to_save, perm_storage)
	get_tree().change_scene_to_file("res://level.tscn")

# =============================================================================
# INPUT ROUTING
# =============================================================================

func _unhandled_input(event: InputEvent):
	if not is_visible_in_tree():
		return
		
	var handled = false
	
	if event.is_action_pressed("ui_ready"):
		get_viewport().set_input_as_handled()
		_save_and_exit()
		return
		
	# --- NEW ROTATION LOGIC ---
	elif current_state == State.HOLDING_BLOCK and event.is_action_pressed("ui_rotate"):
		# 1. Rotate the data
		held_block.rotate_clockwise()
		
		# 2. Re-clamp the cursor so you don't break out of bounds
		grid_cursor.x = clamp(grid_cursor.x, 0, max(0, GRID_COLS - held_block.width))
		grid_cursor.y = clamp(grid_cursor.y, 0, max(0, GRID_ROWS - held_block.height))
		
		# 3. FORCE THE SELECTOR BOX TO RESIZE INSTANTLY
		selector.size = Vector2(held_block.width, held_block.height) * CELL_SIZE
		
		# Debug check: This will prove the math is working!
		print("Rotated! New physical size: ", held_block.width, "x", held_block.height)
		
		handled = true
	# --------------------------
	
	else:
		match current_state:
			State.CONTAINER_SELECTION:
				handled = _handle_container_selection(event)
			State.NOT_HOLDING:
				handled = _handle_not_holding(event)
			State.HOLDING_BLOCK:
				handled = _handle_holding(event)
				
	if handled:
		get_viewport().set_input_as_handled()
		_redraw_all_ui()

# =============================================================================
# STATE HANDLERS
# =============================================================================

func _handle_container_selection(event: InputEvent) -> bool:
	var dpad = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down").round()
	if dpad != Vector2.ZERO and event.is_action_pressed(dpad_to_action(dpad)):
		active_zone = (active_zone + 1) % 3 as ContainerZone
		return true
		
	if event.is_action_pressed("ui_accept"):
		if active_zone == ContainerZone.PERM_STORAGE and perm_storage != null:
			_pick_up_block(perm_storage, active_zone, Vector2i.ZERO)
		elif active_zone == ContainerZone.TEMP_STORAGE and temp_storage.size() > 0:
			# Pop the top item off the array!
			_pick_up_block(temp_storage.pop_back(), active_zone, Vector2i.ZERO)
		else:
			current_state = State.NOT_HOLDING
		return true
		
	return false

func _handle_not_holding(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_cancel"):
		# Circle Button: Back out to container selection
		current_state = State.CONTAINER_SELECTION
		return true
		
	var dpad = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down").round()
	if dpad != Vector2.ZERO and event.is_action_pressed(dpad_to_action(dpad)):
		_navigate_blocks_in_zone(dpad)
		return true

	var hovered = _get_hovered_block()
	
	if event.is_action_pressed("ui_accept") and hovered != null:
		_pick_up_block(hovered, active_zone, grid_cursor)
		return true

	return false

func _handle_holding(event: InputEvent) -> bool:
	var dpad = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down").round()
	if dpad != Vector2.ZERO and event.is_action_pressed(dpad_to_action(dpad)):
		_navigate_grid_while_holding(dpad)
		return true

	if event.is_action_pressed("ui_accept"):
		_place_held_block()
		return true
		
	if event.is_action_pressed("ui_cancel"):
		# Circle Button: Return held block to origin
		_return_held_to_origin()
		return true

	return false

# =============================================================================
# SPATIAL MATH & PLACEMENT LOGIC
# =============================================================================

func _pick_up_block(block: BlockData, origin_zone: ContainerZone, coords: Vector2i):
	held_block = block
	held_origin_zone = origin_zone
	held_origin_coords = coords
	_remove_block_from_zone(block, origin_zone)
	current_state = State.HOLDING_BLOCK
	
	# Instantly warp the cursor to the sequencer grid
	active_zone = ContainerZone.SEQUENCER
	
	# Clean bounds-checking so the block can't hang outside the grid
	grid_cursor.x = clamp(grid_cursor.x, 0, max(0, GRID_COLS - block.width))
	grid_cursor.y = clamp(grid_cursor.y, 0, max(0, GRID_ROWS - block.height))

func _place_held_block():
	if active_zone == ContainerZone.SEQUENCER:
		_place_block_in_sequencer()
	elif active_zone == ContainerZone.PERM_STORAGE:
		if perm_storage != null: _scrap_block(perm_storage, ContainerZone.PERM_STORAGE)
		perm_storage = held_block
	elif active_zone == ContainerZone.TEMP_STORAGE:
		temp_storage.append(held_block) # Append to array

	held_block = null
	current_state = State.CONTAINER_SELECTION

func _return_held_to_origin():
	active_zone = held_origin_zone
	grid_cursor = held_origin_coords
	_place_held_block()

func _remove_block_from_zone(block: BlockData, zone: ContainerZone):
	if zone == ContainerZone.SEQUENCER:
		sequencer_blocks.erase(block)
		for x in range(GRID_COLS):
			for y in range(GRID_ROWS):
				if spatial_grid[x][y] == block:
					spatial_grid[x][y] = null
	elif zone == ContainerZone.PERM_STORAGE: perm_storage = null
	elif zone == ContainerZone.TEMP_STORAGE: temp_storage.erase(block)

func _place_block_in_sequencer():
	# THE HARD WALL: If width or height spills over the grid, abort the drop entirely!
	if grid_cursor.x + held_block.width > GRID_COLS or grid_cursor.y + held_block.height > GRID_ROWS:
		effect_label.text = "ERROR: Block is out of bounds!"
		return 
		
	# Displace covered blocks to temp storage
	var covered = _get_covered_blocks(held_block, grid_cursor)
	for block in covered:
		_scrap_block(block, ContainerZone.SEQUENCER)

	# Actually map the block into the grid math
	for y in range(held_block.height):
		for x in range(held_block.width):
			if held_block.is_cell_active(x, y):
				var target_x = grid_cursor.x + x
				var target_y = grid_cursor.y + y
				if target_x < GRID_COLS and target_y < GRID_ROWS:
					spatial_grid[target_x][target_y] = held_block
					
	sequencer_blocks.append(held_block)

func _get_covered_blocks(block: BlockData, coords: Vector2i) -> Array[BlockData]:
	var covered: Array[BlockData] = []
	for y in range(block.height):
		for x in range(block.width):
			if block.is_cell_active(x, y):
				var target_x = coords.x + x
				var target_y = coords.y + y
				if target_x < GRID_COLS and target_y < GRID_ROWS:
					var existing = spatial_grid[target_x][target_y]
					if existing != null and not covered.has(existing):
						covered.append(existing)
	return covered

func _scrap_block(block: BlockData, origin_zone: ContainerZone):
	_remove_block_from_zone(block, origin_zone)
	temp_storage.append(block) # Append to array

func _empty_sequencer():
	var blocks = sequencer_blocks.duplicate()
	for b in blocks:
		_remove_block_from_zone(b, ContainerZone.SEQUENCER)
	current_state = State.CONTAINER_SELECTION

# =============================================================================
# NAVIGATION MATH
# =============================================================================

func _navigate_grid_while_holding(dir: Vector2):
	if active_zone == ContainerZone.SEQUENCER:
		grid_cursor.x = clamp(grid_cursor.x + int(dir.x), 0, max(0, GRID_COLS - held_block.width))
		grid_cursor.y = clamp(grid_cursor.y + int(dir.y), 0, max(0, GRID_ROWS - held_block.height))
	else:
		_handle_container_selection(InputEventAction.new())

func _navigate_blocks_in_zone(dir: Vector2):
	if active_zone == ContainerZone.SEQUENCER:
		grid_cursor.x = clamp(grid_cursor.x + int(dir.x), 0, GRID_COLS - 1)
		grid_cursor.y = clamp(grid_cursor.y + int(dir.y), 0, GRID_ROWS - 1)

func _get_hovered_block() -> BlockData:
	match active_zone:
		ContainerZone.SEQUENCER: return spatial_grid[grid_cursor.x][grid_cursor.y]
		ContainerZone.PERM_STORAGE: return perm_storage
		ContainerZone.TEMP_STORAGE: return temp_storage.back() if temp_storage.size() > 0 else null
	return null

func _get_block_origin(block: BlockData) -> Vector2i:
	var min_x = GRID_COLS
	var min_y = GRID_ROWS
	var found = false

	# Scan the ENTIRE grid to find the absolute minimum X and Y
	for x in range(GRID_COLS):
		for y in range(GRID_ROWS):
			if spatial_grid[x][y] == block:
				min_x = min(min_x, x)
				min_y = min(min_y, y)
				found = true
				
	if found:
		return Vector2i(min_x, min_y)
		
	return Vector2i.ZERO

func dpad_to_action(dpad: Vector2) -> String:
	if dpad.x > 0: return "ui_right"
	if dpad.x < 0: return "ui_left"
	if dpad.y > 0: return "ui_down"
	return "ui_up"

# =============================================================================
# UI VISUALS & DYNAMIC INSTANTIATION
# =============================================================================

func _redraw_all_ui():
	_clear_all_containers()
	
	# 1. Draw Sequencer Blocks
	for block in sequencer_blocks:
		var origin = _get_block_origin(block)
		var block_ui = _create_block_ui(block, bar_container)
		block_ui.position = Vector2(origin) * CELL_SIZE
	
	# 2. Draw Permanent Storage
	if perm_storage:
		var block_ui = _create_block_ui(perm_storage, perm_container)
		block_ui.position = Vector2.ZERO 
		
	# 3. Draw Temporary Storage Array (Side-by-side)
	var x_offset = 10.0
	for block in temp_storage:
		var block_ui = _create_block_ui(block, temp_container)
		block_ui.position = Vector2(x_offset, 10.0)
		x_offset += (block.width * CELL_SIZE.x) + 10.0

	# 4. Handle Held Block (Ghost Preview)
	if held_block:
		var block_ui = _create_block_ui(held_block, self)
		block_ui.modulate.a = 0.6 
		
		match active_zone:
			ContainerZone.SEQUENCER:
				block_ui.position = bar_container.position + (Vector2(grid_cursor) * CELL_SIZE)
			ContainerZone.PERM_STORAGE:
				block_ui.position = perm_container.position
			ContainerZone.TEMP_STORAGE:
				block_ui.position = temp_container.position

	_update_selector_position()
	_update_effect_label()

func _create_block_ui(data: BlockData, parent: Node) -> BlockUI:
	var ui = BLOCK_UI_SCENE.instantiate()
	parent.add_child(ui)
	ui.update_display(data, CELL_SIZE)
	return ui

func _clear_all_containers():
	for child in bar_container.get_children(): child.queue_free()
	for child in perm_container.get_children(): child.queue_free()
	for child in temp_container.get_children(): child.queue_free()
	# Clear any ghost blocks on root
	for child in get_children():
		if child is BlockUI: child.queue_free()

func _update_selector_position():
	selector.visible = (current_state != State.HOLDING_BLOCK)
	
	match active_zone:
		ContainerZone.SEQUENCER:
			selector.position = bar_container.position + (Vector2(grid_cursor) * CELL_SIZE)
			selector.size = CELL_SIZE
		ContainerZone.PERM_STORAGE:
			selector.position = perm_container.position
			selector.size = perm_container.size
		ContainerZone.TEMP_STORAGE:
			selector.position = temp_container.position
			selector.size = temp_container.size

func _update_effect_label():
	if effect_label == null: return
	
	if current_state == State.HOLDING_BLOCK and active_zone == ContainerZone.SEQUENCER:
		var covered = _get_covered_blocks(held_block, grid_cursor)
		var text = _get_block_effect_text(held_block)
		if covered.size() > 0:
			text += " -> REPLACES: "
			for i in range(covered.size()):
				text += _get_block_effect_text(covered[i])
				if i < covered.size() - 1: text += ", "
		effect_label.text = text
	else:
		var hovered = _get_hovered_block()
		if hovered: effect_label.text = _get_block_effect_text(hovered)
		else: 
			match active_zone:
				ContainerZone.SEQUENCER: effect_label.text = "Sequencer Zone"
				ContainerZone.PERM_STORAGE: effect_label.text = "Permanent Storage"
				ContainerZone.TEMP_STORAGE: effect_label.text = "Temporary Storage"

func _get_block_effect_text(block: BlockData) -> String:
	if block == null: return "Empty"
	var text = block.display_name
	
	# Show Integrity/Life left
	if block.remaining_integrity < 5.0:
		text += " (" + str(snapped(block.remaining_integrity, 0.1)) + "s left)"
		
	if block.effects.is_empty():
		return text + " [No Effect]"
		
	var effect_strings = []
	for effect_data in block.effects:
		if effect_data and "display_name" in effect_data:
			effect_strings.append(effect_data.display_name)
	return text + " [" + ", ".join(effect_strings) + "]"
