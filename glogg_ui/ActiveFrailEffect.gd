# ActiveFrailEffect.gd (No Duration)
class_name ActiveFrailEffect
extends "res://ActiveStatusEffect.gd" # Extend using path

func _on_apply() -> bool:
	if not target_enemy is EnemyBase: return false
	_update_multiplier()
	_start_or_add_duration(false) # Call base helper to set initial duration
	return true

func _on_level_change(_old_level: int):
	_update_multiplier() # Recalculate multiplier on level up
	_start_or_add_duration(true) # Call base helper to add duration

func _on_remove():
	# Perform Frail-specific cleanup FIRST
	if is_instance_valid(target_enemy): # Check validity before accessing
		if target_enemy.damage_taken_multipliers.has(effect_data.effect_id):
			target_enemy.damage_taken_multipliers.erase(effect_data.effect_id)

# Calculates and applies the damage taken multiplier to the enemy
func _update_multiplier():
	if not target_enemy or not effect_data: return
	# Calculate final increase percentage directly using the helper
	var total_increase_percent = effect_data.get_calculated_value(level, "increase", "level_bonus_increase", 0.0)
	var damage_taken_multiplier = max(0.0, 1.0 + total_increase_percent) # Ensure >= 0
	# Update the enemy's modifier dictionary
	target_enemy.damage_taken_multipliers[effect_data.effect_id] = damage_taken_multiplier
