# File: res://planning_phase/BlockData.gd
@tool
class_name BlockData
extends Resource

# --- Firing Behavior ---
enum ShotType { SINGLE, CONTINUOUS, SHIELD }
@export var shot_type: ShotType = ShotType.SINGLE
@export var behavior: Resource 
@export var effects: Array[Resource] = []

# --- Grid Dimensions ---
@export var width: int = 1:
	set(value):
		width = max(1, value)
		notify_property_list_changed()
@export var height: int = 3:
	set(value):
		height = max(1, value)
		notify_property_list_changed()

# --- Display Properties ---
@export var display_name: String = "Block"
@export var color: Color = Color.WHITE

# --- Persistence & Integrity ---
var total_damage: float = 0.0
var total_hits: int = 0
var total_kills: float = 0.0
# The "Health" of the block. If this hits 0 while on the ground, it dissolves.
var remaining_integrity: float = 5.0 

# --- Shape Mask ---
var _shape_mask_data: Array[bool] = []

func record_damage(amount: float):
	total_damage += amount
	total_hits += 1

func record_kill(credit: float = 1.0):
	total_kills += credit

func _get_property_list() -> Array:
	var properties: Array = []
	properties.append({"name": "Shape Mask", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP})
	var total_cells = width * height
	if _shape_mask_data.size() != total_cells: _shape_mask_data.resize(total_cells)
	for y in range(height):
		for x in range(width):
			properties.append({"name": "h%d_w%d" % [y + 1, x + 1], "type": TYPE_BOOL})
	return properties

func _get(property: StringName):
	if property.begins_with("h") and property.contains("_w"):
		var parts = property.split("_")
		var y = int(parts[0].trim_prefix("h")) - 1
		var x = int(parts[1].trim_prefix("w")) - 1
		var index = y * width + x
		if index >= 0 and index < _shape_mask_data.size(): return _shape_mask_data[index]
	return null

func _set(property: StringName, value: Variant) -> bool:
	if property.begins_with("h") and property.contains("_w"):
		var parts = property.split("_")
		var y = int(parts[0].trim_prefix("h")) - 1
		var x = int(parts[1].trim_prefix("w")) - 1
		var index = y * width + x
		if index >= 0 and index < _shape_mask_data.size():
			_shape_mask_data[index] = value
			return true
	return false

func initialize():
	var total_cells = width * height
	if _shape_mask_data.size() != total_cells: _shape_mask_data.resize(total_cells)
	var has_any_data = false
	for val in _shape_mask_data:
		if val == true: has_any_data = true; break
	if not has_any_data: _shape_mask_data.fill(true)

func is_cell_active(local_x: int, local_y: int) -> bool:
	if local_x < 0 or local_x >= width or local_y < 0 or local_y >= height: return false
	var index = local_y * width + local_x
	return _shape_mask_data[index] if index < _shape_mask_data.size() else false

func rotate_clockwise():
	var new_mask: Array[bool] = []
	new_mask.resize(width * height)
	
	for y in range(height):
		for x in range(width):
			var new_x = height - 1 - y
			var new_y = x
			new_mask[new_y * height + new_x] = _shape_mask_data[y * width + x]
			
	var temp = width
	width = height
	height = temp
	
	_shape_mask_data = new_mask
	emit_changed() # Tells Godot the shape has updated
