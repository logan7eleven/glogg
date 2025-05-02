# ActiveSpikeEffect.gd
class_name ActiveSpikeEffect
extends "res://ActiveStatusEffect.gd" # Extend using path

var calculated_spike_damage: float = 0.0

func _on_apply() -> bool:
	_update_spike_state() # Calculate initial damage and update enemy state
	# Connect to physics collision signal on the enemy
	if not target_enemy.is_connected("body_entered", Callable(self, "_on_target_body_entered")):
		target_enemy.connect("body_entered", Callable(self, "_on_target_body_entered"))
	return true

func _on_level_change(_old_level: int):
	_update_spike_state() # Recalculate damage on level up

func _on_remove():
	# Clear this effect's contribution from enemy state
	target_enemy.collision_damage_effects.erase(effect_data.effect_id)
	# Tell enemy to re-evaluate its aggregate spike state
	target_enemy.check_collision_damage_state()
	# Disconnect signal
	if target_enemy.is_connected("body_entered", Callable(self, "_on_target_body_entered")):
		target_enemy.disconnect("body_entered", Callable(self, "_on_target_body_entered"))

# Calculates damage based on level and updates enemy state dictionaries
func _update_spike_state():
	# Calculate final multiplier directly using the helper
	var total_mult = effect_data.get_calculated_value(level, "damage_mult", "level_bonus_damage", 0.0)
	calculated_spike_damage = max(0.0, GlobalState.BASE_DAMAGE * total_mult)
	# Update the enemy's modifier dictionary
	target_enemy.collision_damage_effects[effect_data.effect_id] = {"damage": calculated_spike_damage}
	# Tell the enemy to update its aggregate spike state
	target_enemy.update_collision_damage()

# Handles the signal emitted by the target enemy when it collides
func _on_target_body_entered(body: Node):
	# Apply damage if colliding with another valid enemy
	if calculated_spike_damage > 0 and body is EnemyBase and body != target_enemy:
		body.take_damage(calculated_spike_damage, -1) # Slot -1 for effect damage
