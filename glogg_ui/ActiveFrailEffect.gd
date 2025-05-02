# ActiveFrailEffect.gd
class_name ActiveFrailEffect
extends ActiveStatusEffect

func _on_apply() -> bool:
	if not target_enemy is EnemyBase: return false
	_update_multiplier()
	return true

func _on_level_change(_old_level: int):
	_update_multiplier() # Recalculate on level up

func _on_remove():
	if not is_instance_valid(target_enemy): return
	if target_enemy.damage_taken_multipliers.has(effect_data.effect_id):
		target_enemy.damage_taken_multipliers.erase(effect_data.effect_id)

func _update_multiplier():
	if not is_instance_valid(target_enemy): return
	var base_increase = effect_data.get_value_for_level(level, "increase", 0.0)
	var bonus = effect_data.get_value_for_level(level, "level_bonus", 0.0)
	var total_increase_percent = base_increase + (bonus * (level - 1))
	var damage_taken_multiplier = 1.0 + total_increase_percent
	target_enemy.damage_taken_multipliers[effect_data.effect_id] = damage_taken_multiplier
