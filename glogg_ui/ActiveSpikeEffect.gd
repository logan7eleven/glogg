class_name ActiveSpikeEffect
extends "res://ActiveStatusEffect.gd"

var calculated_spike_damage: float = 0.0

func _on_apply() -> bool:
	_update_spike_state()
	return true

func _on_level_change(_old_level: int):
	_update_spike_state() 

func _on_remove():
	target_enemy.collision_damage_effects.erase(effect_data.effect_id)
	target_enemy.check_collision_damage_state()

func _update_spike_state():
	var total_mult = effect_data.get_calculated_value(level, "damage_mult", "level_bonus_damage", 0.0)
	calculated_spike_damage = GlobalState.BASE_DAMAGE * total_mult
	target_enemy.collision_damage_effects[effect_data.effect_id] = {"damage": calculated_spike_damage}
	target_enemy.update_collision_damage()
