# ActiveSpikeEffect.gd
class_name ActiveSpikeEffect
extends "res://ActiveStatusEffect.gd" # Extend using path

var calculated_spike_damage: float = 0.0

func _on_apply() -> bool:
	if not target_enemy is EnemyBase: return false
	_update_spike_state() # Calculate initial damage and update enemy state
	return true

func _on_level_change(_old_level: int):
	_update_spike_state() # Recalculate damage on level up

func _on_remove():
	if not is_instance_valid(target_enemy): return
	# Clear this effect's contribution from enemy state
	target_enemy.collision_damage_effects.erase(effect_data.effect_id)
	# Tell enemy to re-evaluate its aggregate spike state
	target_enemy.check_collision_damage_state()

# Calculates damage based on level and updates enemy state dictionaries
func _update_spike_state():
	# Calculate final multiplier directly using the helper
	var total_mult = effect_data.get_calculated_value(level, "damage_mult", "level_bonus_damage", 0.0)
	calculated_spike_damage = max(0.0, GlobalState.BASE_DAMAGE * total_mult)
	# Update the enemy's modifier dictionary
	target_enemy.collision_damage_effects[effect_data.effect_id] = {"damage": calculated_spike_damage}
	# Tell the enemy to update its aggregate spike state
	target_enemy.update_collision_damage()
