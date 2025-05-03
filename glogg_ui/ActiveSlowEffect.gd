# ActiveSlowEffect.gd (Cleaned - Internal Timer)
class_name ActiveSlowEffect
extends "res://ActiveStatusEffect.gd" # Extend using path

const SPEED_MODIFIER = 0.5 # 50% slow
var was_active: bool = false

func _on_apply() -> bool:
	if not target_enemy is EnemyBase: return false
	_apply_modifier()
	_start_or_add_duration(false)
	return true

func _on_level_change(_old_level: int):
	_apply_modifier()
	_start_or_add_duration(true)

func _on_remove():
	_remove_modifier()
	if duration_timer: duration_timer.stop()

func _apply_modifier():
	if not target_enemy: return
	target_enemy.speed_multipliers[effect_data.effect_id] = (1.0 - SPEED_MODIFIER)
	was_active = true

func _remove_modifier():
	if not target_enemy: return
	if target_enemy.speed_multipliers.has(effect_data.effect_id): # .has() on Dictionary is OK
		target_enemy.speed_multipliers.erase(effect_data.effect_id)
	was_active = false
