# ActiveSpikeEffect.gd
class_name ActiveSpikeEffect
extends ActiveStatusEffect

var calculated_spike_damage: float = 0.0

func _on_apply() -> bool:
	if not target_enemy is EnemyBase: return false
	_update_spike_state()
	if not target_enemy.is_connected("body_entered", Callable(self, "_on_target_body_entered")):
		target_enemy.connect("body_entered", Callable(self, "_on_target_body_entered"))
	return true

func _on_level_change(_old_level: int):
	_update_spike_state() # Recalculate damage on level up

func _on_remove():
	if not is_instance_valid(target_enemy): return
	target_enemy.collision_damage_effects.erase(effect_data.effect_id) # Remove modifier
	target_enemy.check_collision_damage_state() # Tell enemy to re-evaluate
	if target_enemy.is_connected("body_entered", Callable(self, "_on_target_body_entered")):
		target_enemy.disconnect("body_entered", Callable(self, "_on_target_body_entered"))

func _update_spike_state():
	var base_mult = effect_data.get_value_for_level(level, "damage_mult", 0.0)
	var bonus = effect_data.get_value_for_level(level, "level_bonus", 0.0)
	var total_mult = base_mult + (bonus * (level - 1))
	calculated_spike_damage = max(0.0, GlobalState.BASE_DAMAGE * total_mult)
	target_enemy.collision_damage_effects[effect_data.effect_id] = {"damage": calculated_spike_damage}
	target_enemy.update_collision_damage() # Tell enemy to re-evaluate aggregate

func _on_target_body_entered(body: Node):
	if calculated_spike_damage > 0 and body is EnemyBase and body != target_enemy:
		body.take_damage(calculated_spike_damage, -1)
