class_name ActiveFrailEffect
extends "res://ActiveStatusEffect.gd" 

func _on_apply() -> bool:
	if is_instance_valid(target_enemy.visual_manager):
		target_enemy.visual_manager.set_effect_active("frail", true)
	_update_multiplier()
	return true

func _on_level_change(_old_level: int):
	_update_multiplier()

func _on_remove():
	if is_instance_valid(target_enemy):
		target_enemy.damage_taken_multipliers.erase(effect_data.effect_id)
		if is_instance_valid(target_enemy.visual_manager):
			target_enemy.visual_manager.set_effect_active("frail", false)

func _update_multiplier():
	if not is_instance_valid(target_enemy): return
	var total_increase_percent = effect_data.get_calculated_value(level, "increase", "level_bonus_increase", 0.0)
	var damage_taken_multiplier = 1.0 + total_increase_percent
	
	# --- CHANGE IS HERE ---
	# We now store a dictionary with both the multiplier and the source slot index.
	target_enemy.damage_taken_multipliers[effect_data.effect_id] = {
		"multiplier": damage_taken_multiplier,
		"slot_index": self.source_slot_index 
	}
