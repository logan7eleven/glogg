# ActiveSlowEffect.gd (Cleaned - Internal Timer)
class_name ActiveSlowEffect
extends "res://ActiveStatusEffect.gd" # Extend using path

const SPEED_MODIFIER = 0.5 # 50% slow
var was_active: bool = false
var duration_timer: Timer # Internal timer variable

func _on_apply() -> bool:
	if not target_enemy is EnemyBase: return false
	_apply_modifier()
	_start_or_refresh_duration_timer()
	return true

func _on_level_change(_old_level: int):
	_apply_modifier()
	_start_or_refresh_duration_timer()

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

func _start_or_refresh_duration_timer():
	var duration = effect_data.get_calculated_value(level, "base_duration", "level_bonus_duration", 0.0)
	if duration > 0:
		if not duration_timer: # Check if timer exists before using
			duration_timer = Timer.new(); duration_timer.one_shot = true
			add_child(duration_timer); duration_timer.timeout.connect(queue_free)
		duration_timer.wait_time = duration
		duration_timer.start()
	elif duration_timer: # Stop if duration is 0 or less
		duration_timer.stop()
