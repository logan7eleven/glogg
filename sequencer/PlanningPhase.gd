# File: res://planning_phase/PlanningPhase.gd (Corrected and Final)
extends Control

# --- CONSTANTS ---
const GRID_COLS = 16
const GRID_ROWS = 12
const CELL_SIZE = Vector2(40, 8)

# --- UI REFERENCES ---
@onready var bar_container: ColorRect = %BarContainer
@onready var temp_container: ColorRect = %TempContainer
@onready var perm_container: ColorRect = %PermContainer
@onready var selector: Control = %Selector

# --- STATE MANAGEMENT ---
enum State { SELECTING_ELEMENT, MANIPULATING_BLOCK }
# Renamed to avoid conflict with Godot's native Container class
enum ContainerType { BAR, TEMP, PERM }

var current_state: State = State.SELECTING_ELEMENT
var focused_container: ContainerType = ContainerType.BAR
var focused_coords: Vector2i = Vector2i.ZERO
var focused_index: int = 0

# --- DATA MODEL ---
var bar_data: Array = []
var temp_data: Array = []
var perm_data: Array = [null]

# --- MANIPULATION STATE ---
var held_block_data: BlockData = null
var held_block_origin: Dictionary = {}
var action_history: Array = []

# --- UI INSTANCES ---
var block_ui_nodes: Dictionary = {}

# =============================================================================
# GODOT LIFECYCLE
# =============================================================================

func _ready():
	_initialize_data()
	_redraw_all_ui()

func _process(_delta):
	_update_selector_visuals()

func _unhandled_input(event: InputEvent):
	var handled = false
	match current_state:
		State.SELECTING_ELEMENT:
			handled = _handle_input_selecting(event)
		State.MANIPULATING_BLOCK:
			handled = _handle_input_manipulating(event)
	
	if handled:
		get_viewport().set_input_as_handled()
		_redraw_all_ui()

# =============================================================================
# INITIALIZATION & DRAWING
# =============================================================================

#func _initialize_data():
	#bar_data.resize(GRID_COLS)
	#for i in range(GRID_COLS):
		#bar_data[i] = []; bar_data[i].resize(GRID_ROWS); bar_data[i].fill(null)
	#var all_test_blocks = _load_blocks_from_folder("res://planning_phase/test_blocks")
	#all_test_blocks.shuffle()
	#_procedurally_place_blocks(all_test_blocks)
func _initialize_data():
	# 1. Initialize the empty 16x12 grid for the bar.
	bar_data.resize(GRID_COLS)
	for i in range(GRID_COLS):
		bar_data[i] = []; bar_data[i].resize(GRID_ROWS); bar_data[i].fill(null)

	# 2. Load the "master" copies of the resources you want to place.
	#    Make sure the file paths are correct!
	var full_shot_master = load("res://planning_phase/test_blocks/FullSingleShot.tres") as BlockData
	var half_shot_master = load("res://planning_phase/test_blocks/HalfSingleShot.tres") as BlockData
	var rtri_slime_master = load("res://planning_phase/test_blocks/RTriSlime.tres") as BlockData

	# Safety check in case a file is missing or renamed.
	if not full_shot_master or not half_shot_master or not rtri_slime_master:
		printerr("ERROR: Could not load one or more required block resources. Check file paths.")
		return

	# 3. Create a list of the unique block instances we want to place.
	#    We use .duplicate() to create independent copies. This is CRUCIAL.
	var blocks_to_place: Array[BlockData] = []
	
	# Add 5 copies of FullSingleShot
	for i in range(5):
		var new_block = full_shot_master.duplicate(true) as BlockData # Use deep duplicate
		new_block.initialize() # IMPORTANT: Initialize each copy
		blocks_to_place.append(new_block)

	# Add 2 copies of RTriSlime
	for i in range(2):
		var new_block = rtri_slime_master.duplicate(true) as BlockData
		new_block.initialize()
		blocks_to_place.append(new_block)
		
	# Add 1 copy of HalfSingleShot
	var half_shot_instance = half_shot_master.duplicate(true) as BlockData
	half_shot_instance.initialize()
	blocks_to_place.append(half_shot_instance)

	# 4. Place the blocks onto the bar in a predictable, non-overlapping layout.
	var current_x_cursor = 0
	for block in blocks_to_place:
		# Check if there's enough horizontal space left on the bar
		if current_x_cursor + block.width <= GRID_COLS:
			# Place the block at the current cursor position, at the top of the bar (y=0)
			_place_block_in_grid(block, Vector2i(current_x_cursor, 0), bar_data)
			# Move the cursor over by the width of the block we just placed
			current_x_cursor += block.width
		else:
			# If we run out of space, put the remaining blocks in temp storage
			print("Ran out of bar space. Placing remaining blocks in temp storage.")
			temp_data.append(block)

func _load_blocks_from_folder(path: String) -> Array[BlockData]:
	var loaded_blocks: Array[BlockData] = []
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var resource = load(path + "/" + file_name)
				if resource is BlockData:
					resource.initialize(); loaded_blocks.append(resource)
			file_name = dir.get_next()
	else:
		printerr("Could not open directory: " + path)
	return loaded_blocks

func _procedurally_place_blocks(blocks: Array[BlockData]):
	var blocks_to_place_count = min(8, blocks.size())
	var placed_count = 0; var placement_attempts = 0
	for i in range(blocks_to_place_count):
		var block = blocks[i]
		var placed = false
		while not placed and placement_attempts < 200:
			placement_attempts += 1
			var rand_x = randi_range(0, GRID_COLS - block.width)
			var num_lanes = GRID_ROWS / block.step_y if block.step_y > 0 else 1
			var rand_y = randi_range(0, num_lanes - 1) * block.step_y
			var pos = Vector2i(rand_x, rand_y)
			if _is_area_clear_for_placement(block, pos, bar_data):
				_place_block_in_grid(block, pos, bar_data); placed = true; placed_count += 1
		if placement_attempts >= 200:
			print("Warning: Could not place all blocks. Placed %d." % placed_count); break
	if blocks.size() > blocks_to_place_count:
		temp_data.append(blocks[blocks_to_place_count])

func _redraw_all_ui():
	var all_blocks_in_data = _get_all_blocks_from_data()
	for block_data in block_ui_nodes.keys():
		if not all_blocks_in_data.has(block_data):
			if is_instance_valid(block_ui_nodes[block_data]):
				block_ui_nodes[block_data].queue_free()
			block_ui_nodes.erase(block_data)

	var drawn_bar_blocks: Array[BlockData] = []
	for x in range(GRID_COLS):
		for y in range(GRID_ROWS):
			var block_data = bar_data[x][y]
			if block_data != null and not drawn_bar_blocks.has(block_data):
				drawn_bar_blocks.append(block_data)
				_create_or_update_block_ui(block_data, Vector2i(x, y), bar_container)

func _create_or_update_block_ui(block_data: BlockData, root_pos: Vector2i, parent_container: Control):
	var ui_node: BlockUI
	if not block_ui_nodes.has(block_data):
		ui_node = BlockUI.instantiate(); parent_container.add_child(ui_node)
		block_ui_nodes[block_data] = ui_node
	ui_node = block_ui_nodes[block_data]
	ui_node.update_display(block_data, CELL_SIZE)
	ui_node.position = Vector2(root_pos) * CELL_SIZE
	ui_node.set_held_visual(block_data == held_block_data)

func _update_selector_visuals():
	var target_pos: Vector2; var target_size: Vector2
	if focused_container == ContainerType.BAR:
		if selector.get_parent() != bar_container: selector.reparent(bar_container)
		var hovered_block = _get_block_at_coords(focused_coords, bar_data)
		if held_block_data:
			target_size = Vector2(held_block_data.width, held_block_data.height) * CELL_SIZE
			var step = held_block_data.step_y if held_block_data.step_y > 0 else GRID_ROWS
			var snapped_y = floor(float(focused_coords.y) / step) * step
			target_pos = Vector2(focused_coords.x, snapped_y) * CELL_SIZE
		elif hovered_block:
			var root_pos = _find_block_root(hovered_block, bar_data)
			target_pos = Vector2(root_pos) * CELL_SIZE
			target_size = Vector2(hovered_block.width, hovered_block.height) * CELL_SIZE
		else:
			target_pos = Vector2(focused_coords) * CELL_SIZE; target_size = CELL_SIZE
		selector.position = target_pos; selector.size = target_size

# =============================================================================
# INPUT HANDLING
# =============================================================================

func _handle_input_selecting(event: InputEvent) -> bool:
	if event.is_action_just_pressed("ui_accept"):
		var block_to_pick_up = _get_focused_element_data()
		if block_to_pick_up:
			var origin_coords = _get_focused_element_coords()
			held_block_data = block_to_pick_up
			held_block_origin = {"container": focused_container, "coords": origin_coords}
			action_history.clear()
			action_history.push_front({"type": "pickup", "block": held_block_data, "origin": held_block_origin})
			current_state = State.MANIPULATING_BLOCK
			return true

	var dpad_vector = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if dpad_vector.length_squared() > 0 and event.is_action_just_pressed(dpad_vector):
		if focused_container == ContainerType.BAR:
			return _slide_chain_2d(focused_coords, dpad_vector.round())

	var nav_vector = Input.get_vector("navigate_x_neg", "navigate_x_pos", "navigate_y_neg", "navigate_y_pos")
	if nav_vector.length_squared() > 0.5 and event is InputEventJoypadMotion:
		var move_dir = Vector2i.ZERO
		if abs(nav_vector.x) > abs(nav_vector.y): move_dir.x = sign(nav_vector.x)
		else: move_dir.y = sign(nav_vector.y)
		focused_coords += move_dir
		focused_coords.x = clamp(focused_coords.x, 0, GRID_COLS - 1)
		focused_coords.y = clamp(focused_coords.y, 0, GRID_ROWS - 1)
		return true

	return false

func _handle_input_manipulating(event: InputEvent) -> bool:
	if event.is_action_just_pressed("ui_accept"):
		var snapped_coords = _get_snapped_placement_coords()
		var target_block = _get_block_at_coords(snapped_coords, _get_container_data(focused_container))
		
		if target_block and target_block != held_block_data: # SWAP
			var origin_data = _get_container_data(held_block_origin.container)
			var target_data = _get_container_data(focused_container)
			if _remove_block_from_grid(held_block_data, origin_data) and _remove_block_from_grid(target_block, target_data):
				_place_block_in_grid(held_block_data, snapped_coords, target_data)
				_place_block_in_grid(target_block, held_block_origin.coords, origin_data)
				action_history.push_front({"type": "swap", "new_held": target_block, "old_held": held_block_data, "old_pos": held_block_origin})
				held_block_data = target_block; held_block_origin = {"container": focused_container, "coords": snapped_coords}
				return true
		else: # PLACE
			if _is_area_clear_for_placement(held_block_data, snapped_coords, _get_container_data(focused_container)):
				_remove_block_from_grid(held_block_data, _get_container_data(held_block_origin.container))
				_place_block_in_grid(held_block_data, snapped_coords, _get_container_data(focused_container))
				held_block_data = null; action_history.clear(); current_state = State.SELECTING_ELEMENT
				return true
	
	if event.is_action_just_pressed("ui_cancel"):
		_undo_action(); return true
		
	var nav_vector = Input.get_vector("navigate_x_neg", "navigate_x_pos", "navigate_y_neg", "navigate_y_pos")
	if nav_vector.length_squared() > 0.5 and event is InputEventJoypadMotion:
		var move_dir = Vector2i.ZERO
		if abs(nav_vector.x) > abs(nav_vector.y): move_dir.x = sign(nav_vector.x)
		else: move_dir.y = sign(nav_vector.y)
		focused_coords += move_dir; focused_coords.x = clamp(focused_coords.x, 0, GRID_COLS - 1); focused_coords.y = clamp(focused_coords.y, 0, GRID_ROWS - 1)
		return true

	return false

func _undo_action():
	if action_history.is_empty(): return
	var last_action = action_history.pop_front()
	
	if last_action.type == "pickup":
		held_block_data = null; current_state = State.SELECTING_ELEMENT
	elif last_action.type == "swap":
		var origin_data = _get_container_data(last_action.old_pos.container)
		var target_data = _get_container_data(focused_container)
		_remove_block_from_grid(last_action.new_held, target_data)
		_remove_block_from_grid(last_action.old_held, origin_data)
		_place_block_in_grid(last_action.new_held, last_action.old_pos.coords, origin_data)
		_place_block_in_grid(last_action.old_held, held_block_origin.coords, target_data)
		held_block_data = last_action.old_held; held_block_origin = last_action.old_pos

# =============================================================================
# CORE LOGIC & HELPERS
# =============================================================================

func _slide_chain_2d(start_coords: Vector2i, direction: Vector2i) -> bool:
	var block_to_push = _get_block_at_coords(start_coords, bar_data)
	if not block_to_push: return false
	
	var chain: Array[BlockData] = []; var visited_coords: Dictionary = {}
	var q: Array[BlockData] = [block_to_push]
	visited_coords[_find_block_root(block_to_push, bar_data)] = true
	
	var head = 0
	while head < q.size():
		var current_block = q[head]; head += 1
		chain.append(current_block)
		var root = _find_block_root(current_block, bar_data)
		
		for y in range(current_block.height):
			for x in range(current_block.width):
				if not current_block.is_cell_active(x, y): continue
				var check_coord = root + Vector2i(x, y) + direction
				var neighbor = _get_block_at_coords(check_coord, bar_data)
				if neighbor:
					var neighbor_root = _find_block_root(neighbor, bar_data)
					if not visited_coords.has(neighbor_root):
						q.append(neighbor); visited_coords[neighbor_root] = true
	
	for block in chain:
		var root = _find_block_root(block, bar_data)
		if not _is_area_clear_for_push(block, root + direction, chain): return false

	var sort_dir = 1 if (direction.x > 0 or direction.y > 0) else -1
	chain.sort_custom(func(a,b): 
		var root_a = _find_block_root(a, bar_data); var root_b = _find_block_root(b, bar_data)
		return (root_a.x + root_a.y) * sort_dir > (root_b.x + root_b.y) * sort_dir
	)

	for block in chain:
		var old_root = _find_block_root(block, bar_data)
		_place_block_in_grid(block, old_root + direction, bar_data)

	focused_coords += direction
	return true

func _is_area_clear_for_push(block: BlockData, new_root: Vector2i, chain: Array[BlockData]) -> bool:
	for y in range(block.height):
		for x in range(block.width):
			if block.is_cell_active(x, y):
				var grid_pos = new_root + Vector2i(x, y)
				if grid_pos.x < 0 or grid_pos.x >= GRID_COLS or grid_pos.y < 0 or grid_pos.y >= GRID_ROWS: return false
				var existing = _get_block_at_coords(grid_pos, bar_data)
				if existing and not chain.has(existing): return false
	return true

func _is_area_clear_for_placement(block: BlockData, root_pos: Vector2i, data_grid: Array) -> bool:
	for y in range(block.height):
		for x in range(block.width):
			if block.is_cell_active(x, y):
				var grid_pos = root_pos + Vector2i(x, y)
				if grid_pos.x < 0 or grid_pos.x >= GRID_COLS or grid_pos.y < 0 or grid_pos.y >= GRID_ROWS: return false
				if _get_block_at_coords(grid_pos, data_grid) != null: return false
	return true

func _get_all_blocks_from_data() -> Array[BlockData]:
	var all_blocks: Array[BlockData] = []; var seen: Dictionary = {}
	for x in range(GRID_COLS):
		for y in range(GRID_ROWS):
			var b = bar_data[x][y]
			if b and not seen.has(b): all_blocks.append(b); seen[b] = true
	return all_blocks

func _get_container_data(container_type: ContainerType) -> Array:
	match container_type:
		ContainerType.BAR: return bar_data
		ContainerType.TEMP: return temp_data
		ContainerType.PERM: return perm_data
	return []

func _get_block_at_coords(coords: Vector2i, data_grid: Array) -> BlockData:
	if not data_grid or coords.x < 0 or coords.x >= data_grid.size() or coords.y < 0 or coords.y >= data_grid[0].size(): return null
	var result = data_grid[coords.x][coords.y]
	return result as BlockData

func _find_block_root(block: BlockData, data_grid: Array) -> Vector2i:
	if not block: return Vector2i(-1, -1)
	for x in range(data_grid.size()):
		for y in range(data_grid[0].size()):
			if data_grid[x][y] == block: return Vector2i(x, y)
	return Vector2i(-1, -1)

func _remove_block_from_grid(block: BlockData, data_grid: Array) -> bool:
	if not block or not data_grid: return false
	var removed = false
	for x in range(data_grid.size()):
		for y in range(data_grid[0].size()):
			if data_grid[x][y] == block: data_grid[x][y] = null; removed = true
	return removed

func _place_block_in_grid(block: BlockData, root_pos: Vector2i, data_grid: Array):
	_remove_block_from_grid(block, data_grid)
	for y in range(block.height):
		for x in range(block.width):
			if block.is_cell_active(x, y):
				var grid_pos = root_pos + Vector2i(x, y)
				if grid_pos.x < GRID_COLS and grid_pos.y < GRID_ROWS: data_grid[grid_pos.x][grid_pos.y] = block

func _get_focused_element_data() -> BlockData:
	if focused_container == ContainerType.BAR: return _get_block_at_coords(focused_coords, bar_data)
	return null

func _get_focused_element_coords() -> Vector2i:
	if focused_container == ContainerType.BAR:
		var block = _get_block_at_coords(focused_coords, bar_data)
		return _find_block_root(block, bar_data) if block else focused_coords
	return Vector2i.ZERO
	
func _get_snapped_placement_coords() -> Vector2i:
	if not held_block_data: return focused_coords
	var step = held_block_data.step_y if held_block_data.step_y > 0 else GRID_ROWS
	var snapped_y = floor(float(focused_coords.y) / step) * step
	return Vector2i(focused_coords.x, snapped_y)
