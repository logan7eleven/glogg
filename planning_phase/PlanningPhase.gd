# File: res://planning_phase/PlanningPhase.gd
extends Control

# --- CONSTANTS ---
const GRID_COLS = 16
const GRID_ROWS = 12
const CELL_SIZE = Vector2(40, 8)

# --- UI REFERENCES ---
@onready var bar_container: ColorRect = %BarContainer
@onready var temp_container: ColorRect = %TempContainer
@onready var perm_container: ColorRect = %PermContainer
@onready var staging_container: GridContainer = %StagingContainer
@onready var selector: Control = %Selector
@onready var effect_label: Label = %EffectLabel

# --- SCENE PRELOADS ---
const BLOCK_UI_SCENE = preload("res://planning_phase/BlockUI.tscn")

# --- STATE MANAGEMENT ---
enum State { 
	CONTAINER_SELECTION,  
	NOT_HOLDING,          
	HOLDING_BLOCK         
}

enum ContainerZone { SEQUENCER, PERM_STORAGE, TEMP_STORAGE, STAGING_AREA }

var current_state: State = State.CONTAINER_SELECTION
var active_zone: ContainerZone = ContainerZone.SEQUENCER

# --- DATA MODEL ---
var spatial_grid: Array = [] 
var sequencer_blocks: Array[BlockData] = []
var temp_storage: BlockData = null
var perm_storage: BlockData = null
var staging_area: Array[BlockData] = []

# --- NAVIGATION & HOLDING STATE ---
var held_block: BlockData = null
var held_origin_zone: ContainerZone
var held_origin_coords: Vector2i 

var grid_cursor: Vector2i = Vector2i.ZERO 
var staging_cursor: int = 0               

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
		_place_block_in_sequencer(entry["block"], entry["origin"])
		
	perm_storage = GlobalState.master_perm_storage
	temp_storage = GlobalState.master_temp_storage

func _save_and_exit():
	var layout_to_save: Array[Dictionary] = []
	for block in sequencer_blocks:
		var origin = _get_block_origin(block)
		layout_to_save.append({
			"block": block,
			"origin": origin
		})
	
	# Transition penalty: Clear staging and temp before saving
	temp_storage = null
	staging_area.clear()
	
	GlobalState.save_planning_phase_state(layout_to_save, perm_storage)
	get_tree().change_scene_to_file("res://level.tscn")

# =============================================================================
# INPUT ROUTING
# =============================================================================

func _unhandled_input(event: InputEvent):
	var handled = false
	
	if event.is_action_just_pressed("ui_ready"):
		_save_and_exit()
		get_viewport().set_input_as_handled()
		return
		
	if event.is_action_just_pressed("ui_send_all_staging"):
		_send_all_sequencer_to_staging()
		handled = true
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
	if dpad != Vector2.ZERO and event.is_action_just_pressed(dpad_to_action(dpad)):
		active_zone = (active_zone + 1) % 4 as ContainerZone
		return true
		
	if event.is_action_just_pressed("ui_accept"):
		if active_zone == ContainerZone.PERM_STORAGE and perm_storage != null:
			_pick_up_block(perm_storage, active_zone, Vector2i.ZERO)
		elif active_zone == ContainerZone.TEMP_STORAGE and temp_storage != null:
			_pick_up_block(temp_storage, active_zone, Vector2i.ZERO)
		else:
			current_state = State.NOT_HOLDING
		return true
		
	return false

func _handle_not_holding(event: InputEvent) -> bool:
	if event.is_action_just_pressed("ui_cancel"):
		current_state = State.CONTAINER_SELECTION
		return true
		
	var dpad = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down").round()
	if dpad != Vector2.ZERO and event.is_action_just_pressed(dpad_to_action(dpad)):
		_navigate_blocks_in_zone(dpad)
		return true

	var hovered = _get_hovered_block()
	
	if event.is_action_just_pressed("ui_accept") and hovered != null:
		_pick_up_block(hovered, active_zone, grid_cursor)
		return true
		
	if event.is_action_just_pressed("ui_send_to_staging") and hovered != null:
		_send_block_to_staging(hovered, active_zone)
		return true

	return false

func _handle_holding(event: InputEvent) -> bool:
	var dpad = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down").round()
	if dpad != Vector2.ZERO and event.is_action_just_pressed(dpad_to_action(dpad)):
		_navigate_grid_while_holding(dpad)
		return true

	if event.is_action_just_pressed("ui_accept"):
		_place_held_block()
		return true
		
	if event.is_action_just_pressed("ui_cancel") or event.is_action_just_pressed("ui_send_to_staging"):
		_send_block_to_staging(held_block, ContainerZone.STAGING_AREA) 
		held_block = null
		current_state = State.CONTAINER_SELECTION
		return true
		
	if event.is_action_just_pressed("ui_return_origin"):
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

func _place_held_block():
	if active_zone == ContainerZone.SEQUENCER:
		var covered_blocks = _get_covered_blocks(held_block, grid_cursor)
		for b in covered_blocks:
			_send_block_to_staging(b, ContainerZone.SEQUENCER)
		_place_block_in_sequencer(held_block, grid_cursor)
		
	elif active_zone == ContainerZone.PERM_STORAGE:
		if perm_storage != null: _send_block_to_staging(perm_storage, ContainerZone.PERM_STORAGE)
		perm_storage = held_block
		
	elif active_zone == ContainerZone.TEMP_STORAGE:
		if temp_storage != null: _send_block_to_staging(temp_storage, ContainerZone.TEMP_STORAGE)
		temp_storage = held_block
		
	elif active_zone == ContainerZone.STAGING_AREA:
		staging_area.append(held_block)

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
	elif zone == ContainerZone.TEMP_STORAGE: temp_storage = null
	elif zone == ContainerZone.STAGING_AREA: staging_area.erase(block)

func _place_block_in_sequencer(block: BlockData, coords: Vector2i):
	sequencer_blocks.append(block)
	for y in range(block.height):
		for x in range(block.width):
			if block.is_cell_active(x, y):
				var target_x = coords.x + x
				var target_y = coords.y + y
				if target_x < GRID_COLS and target_y < GRID_ROWS:
					spatial_grid[target_x][target_y] = block

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

func _send_block_to_staging(block: BlockData, origin_zone: ContainerZone):
	_remove_block_from_zone(block, origin_zone)
	staging_area.append(block)

func _send_all_sequencer_to_staging():
	var blocks = sequencer_blocks.duplicate()
	for b in blocks:
		_send_block_to_staging(b, ContainerZone.SEQUENCER)
	current_state = State.CONTAINER_SELECTION

# =============================================================================
# NAVIGATION MATH
# =============================================================================

func _navigate_grid_while_holding(dir: Vector2):
	if active_zone == ContainerZone.SEQUENCER:
		grid_cursor.x = clamp(grid_cursor.x + int(dir.x), 0, GRID_COLS - held_block.width)
		
		if dir.y != 0:
			var valid_ys = _get_valid_lanes(held_block.height)
			var current_index = valid_ys.find(grid_cursor.y)
			if current_index == -1: current_index = 0
			var next_index = clamp(current_index + int(dir.y), 0, valid_ys.size() - 1)
			grid_cursor.y = valid_ys[next_index]
	else:
		_handle_container_selection(InputEventAction.new()) 

func _get_valid_lanes(block_height: int) -> Array[int]:
	var lanes: Array[int] = []
	var safe_height = max(1, block_height) 
	var lane_count = max(1, GRID_ROWS / safe_height)
	for i in range(lane_count):
		lanes.append(i * safe_height)
	return lanes

func _navigate_blocks_in_zone(dir: Vector2):
	if active_zone == ContainerZone.SEQUENCER:
		grid_cursor.x = clamp(grid_cursor.x + int(dir.x), 0, GRID_COLS - 1)
		grid_cursor.y = clamp(grid_cursor.y + int(dir.y), 0, GRID_ROWS - 1)
	elif active_zone == ContainerZone.STAGING_AREA:
		staging_cursor = clamp(staging_cursor + int(dir.x), 0, max(0, staging_area.size() - 1))

func _get_hovered_block() -> BlockData:
	match active_zone:
		ContainerZone.SEQUENCER: return spatial_grid[grid_cursor.x][grid_cursor.y]
		ContainerZone.PERM_STORAGE: return perm_storage
		ContainerZone.TEMP_STORAGE: return temp_storage
		ContainerZone.STAGING_AREA: 
			if staging_area.size() > 0: return staging_area[staging_cursor]
	return null

func _get_block_origin(block: BlockData) -> Vector2i:
	for x in range(GRID_COLS):
		for y in range(GRID_ROWS):
			if spatial_grid[x][y] == block:
				return Vector2i(x, y)
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
		block_ui.position = Vector2.ZERO # Fills the container
		
	# 3. Draw Temporary Storage
	if temp_storage:
		var block_ui = _create_block_ui(temp_storage, temp_container)
		block_ui.position = Vector2.ZERO
		
	# 4. Draw Staging Area (GridContainer handles layout automatically)
	for block in staging_area:
		_create_block_ui(block, staging_container)

	# 5. Handle Held Block (Ghost Preview)
	if held_block:
		var block_ui = _create_block_ui(held_block, self)
		block_ui.modulate.a = 0.6 # Transparency
		
		match active_zone:
			ContainerZone.SEQUENCER:
				block_ui.position = bar_container.position + (Vector2(grid_cursor) * CELL_SIZE)
			ContainerZone.PERM_STORAGE:
				block_ui.position = perm_container.position
			ContainerZone.TEMP_STORAGE:
				block_ui.position = temp_container.position
			ContainerZone.STAGING_AREA:
				block_ui.position = staging_container.position

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
	for child in staging_container.get_children(): child.queue_free()
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
		ContainerZone.STAGING_AREA:
			selector.position = staging_container.position
			# Scale selector to roughly match a staging slot
			selector.size = Vector2(80, 80) 

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
				ContainerZone.STAGING_AREA: effect_label.text = "Staging Area"

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
