class_name ActiveFrailEffect
extends "res://ActiveStatusEffect.gd" 

func _on_apply() -> bool:
	_update_multiplier()
	_start_or_add_duration(false) 
	return true

func _on_level_change(_old_level: int):
	_update_multiplier() 
	_start_or_add_duration(true) 

func _on_remove():
	target_enemy.damage_taken_multipliers.erase(effect_data.effect_id)

func _update_multiplier():
	var total_increase_percent = effect_data.get_calculated_value(level, "increase", "level_bonus_increase", 0.0)
	var damage_taken_multiplier = 1.0 + total_increase_percent 
	target_enemy.damage_taken_multipliers[effect_data.effect_id] = damage_taken_multiplier
