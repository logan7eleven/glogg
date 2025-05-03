# StatusEffectData.gd
# Resource holding configuration DATA for a status effect.
extends Resource
class_name StatusEffectData # Keep class_name for Resource type recognition

@export var effect_id: String = "unknown"
@export var display_name: String = "Unknown Effect"
@export_multiline var description_template: String = "Applies effect. Use {key}."
@export var values_per_level: Array = [] # Single Dictionary: { "base_key": val, "bonus_key": val }
@export var active_effect_script_path: String = "" # e.g., "res://ActiveSlowEffect.gd"

func get_level_data_dict() -> Dictionary:
	if not values_per_level.is_empty() and typeof(values_per_level[0]) == TYPE_DICTIONARY:
		return values_per_level[0]
	return {}

func get_calculated_value(level: int, base_key: String, bonus_key: String, default_base = 0.0) -> Variant:
	var data_dict = get_level_data_dict()
	var base_value = data_dict.get(base_key, default_base)
	var level_bonus = data_dict.get(bonus_key, 0.0)
	var effective_level = max(1, level)
	if typeof(base_value) == TYPE_FLOAT or typeof(level_bonus) == TYPE_FLOAT:
		return float(base_value) + (float(level_bonus) * (effective_level - 1))
	elif typeof(base_value) == TYPE_INT and typeof(level_bonus) == TYPE_INT:
		return int(base_value) + (int(level_bonus) * (effective_level - 1))
	else: return base_value

func get_description(_level: int) -> String: # Level param currently unused here
	var data_dict = get_level_data_dict()
	if data_dict.is_empty(): return description_template
	var formatted_desc = description_template
	for key in data_dict:
		var placeholder = "{%s}" % key
		formatted_desc = formatted_desc.replace(placeholder, str(data_dict[key]))
	return formatted_desc
