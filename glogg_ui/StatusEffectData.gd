# StatusEffectData.gd (NO Max Level for Slots OR Enemy Stacks)
class_name StatusEffectData
extends Resource

@export var effect_id: String = "unknown"
@export var display_name: String = "Unknown Effect"
@export_multiline var description_template: String = "Applies effect. Use {key}."
@export var values_per_level: Array = [] # Single Dictionary: { "base_key": val, "bonus_key": val }
@export var active_effect_script_path: String = ""

# --- Helper Functions ---
func get_level_data_dict() -> Dictionary:
	if not values_per_level.is_empty() and typeof(values_per_level[0]) == TYPE_DICTIONARY:
		return values_per_level[0]
	# Return empty dict if data is missing or invalid
	return {}

# Calculates value for a specific level using base + bonus
func get_calculated_value(level: int, base_key: String, bonus_key: String, default_base = 0.0) -> Variant:
	var data_dict = get_level_data_dict()
	var base_value = data_dict.get(base_key, default_base)
	var level_bonus = data_dict.get(bonus_key, 0.0)
	var effective_level = max(1, level)
	# Calculation: base + bonus * (level - 1)
	if typeof(base_value) == TYPE_FLOAT or typeof(level_bonus) == TYPE_FLOAT:
		return float(base_value) + (float(level_bonus) * (effective_level - 1))
	elif typeof(base_value) == TYPE_INT and typeof(level_bonus) == TYPE_INT:
		return int(base_value) + (int(level_bonus) * (effective_level - 1))
	else: return base_value # Fallback for non-numeric types

# Gets description - Shows base values from resource data
func get_description(_level: int) -> String: # Level param ignored for now
	var data_dict = get_level_data_dict()
	if data_dict.is_empty(): return description_template

	var formatted_desc = description_template
	# Simple replacement using base values stored in the resource
	for key in data_dict:
		var placeholder = "{%s}" % key
		formatted_desc = formatted_desc.replace(placeholder, str(data_dict[key]))
	# UI can add "(Current Lvl: X)" separately if needed
	return formatted_desc
