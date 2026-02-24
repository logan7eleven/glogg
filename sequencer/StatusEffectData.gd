# Resource holding configuration DATA for a status effect.
extends Resource
class_name StatusEffectData

@export var effect_id: String = "unknown"
@export var display_name: String = "Unknown Effect"
@export var values_per_level: Array = [] # Single Dictionary: { "base_key": val, "bonus_key": val }
@export var active_effect_script_path: String = "" # e.g., "res://ActiveSlowEffect.gd"

func get_level_data_dict() -> Dictionary:
	return values_per_level[0]

func get_calculated_value(level: int, base_key: String, bonus_key: String, default_base = 0.0) -> Variant:
	var data_dict = get_level_data_dict()
	var base_value = data_dict.get(base_key, default_base)
	var level_bonus = data_dict.get(bonus_key, 0.0)
	var effective_level = level
	return base_value + (level_bonus * (effective_level - 1))
