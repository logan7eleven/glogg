# File: res://planning_phase/BlockData.gd (Updated with Custom Labels)
@tool
class_name BlockData
extends Resource

# --- Firing Behavior ---
enum ShotType { SINGLE, CONTINUOUS, SHIELD }
@export var shot_type: ShotType = ShotType.SINGLE

# --- Gameplay Effects ---
@export var effects: Array[EffectData] = []

# --- Grid Dimensions ---
@export var width: int = 1:
	set(value):
		width = max(1, value)
		notify_property_list_changed()
@export var height: int = 12:
	set(value):
		height = max(1, value)
		notify_property_list_changed()

# --- Display Properties ---
@export var display_name: String = "Block"
@export var color: Color = Color.WHITE

# --- Shape Mask ---
var _shape_mask_data: Array[bool] = []


func _get_property_list() -> Array:
	var properties: Array = []
	
	properties.append({
		"name": "Shape Mask",
		"type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP,
	})
	
	var total_cells = width * height
	if _shape_mask_data.size() != total_cells:
		_shape_mask_data.resize(total_cells)

	for y in range(height):
		for x in range(width):
			# --- CHANGE IS HERE ---
			# We now create a 1-based label for the Inspector.
			var y_label = y + 1
			var x_label = x + 1
			# The internal property name will be like "h1_w1", "h1_w2", etc.
			var property_name = "h%d_w%d" % [y_label, x_label]
			# ---------------------
			
			properties.append({
				"name": property_name,
				"type": TYPE_BOOL,
			})
	
	return properties

func _get(property: StringName):
	# --- CHANGE IS HERE ---
	# We check for our new naming convention.
	if property.begins_with("h") and property.contains("_w"):
		# ---------------------
		var parts = property.split("_")
		if parts.size() == 2:
			var y_str = parts[0].trim_prefix("h")
			var x_str = parts[1].trim_prefix("w")
			
			if y_str.is_valid_int() and x_str.is_valid_int():
				# --- CHANGE IS HERE ---
				# Convert the 1-based label back to a 0-based array index.
				var y = int(y_str) - 1
				var x = int(x_str) - 1
				# ---------------------
				
				var index = y * width + x
				if index >= 0 and index < _shape_mask_data.size():
					return _shape_mask_data[index]
	return null

func _set(property: StringName, value: Variant) -> bool:
	# --- CHANGE IS HERE ---
	# The logic is identical to the _get function.
	if property.begins_with("h") and property.contains("_w"):
		# ---------------------
		var parts = property.split("_")
		if parts.size() == 2:
			var y_str = parts[0].trim_prefix("h")
			var x_str = parts[1].trim_prefix("w")

			if y_str.is_valid_int() and x_str.is_valid_int():
				# --- CHANGE IS HERE ---
				# Convert the 1-based label back to a 0-based array index.
				var y = int(y_str) - 1
				var x = int(x_str) - 1
				# ---------------------

				var index = y * width + x
				if index >= 0 and index < _shape_mask_data.size():
					_shape_mask_data[index] = value
					return true
	return false

# --- The rest of the script is the same ---

func initialize():
	var total_cells = width * height
	if _shape_mask_data.size() != total_cells:
		_shape_mask_data.resize(total_cells)
	
	var has_any_data = false
	for val in _shape_mask_data:
		if val == true:
			has_any_data = true
			break
	if not has_any_data:
		_shape_mask_data.fill(true)

func is_cell_active(local_x: int, local_y: int) -> bool:
	if local_x < 0 or local_x >= width or local_y < 0 or local_y >= height:
		return false
	var index = local_y * width + local_x
	if index < _shape_mask_data.size():
		return _shape_mask_data[index]
	return false
