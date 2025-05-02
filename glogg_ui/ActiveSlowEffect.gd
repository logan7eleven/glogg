# ActiveSlowEffect.gd
class_name ActiveSlowEffect
extends ActiveStatusEffect

const SPEED_MODIFIER = 0.5 # 50% slow
var was_active: bool = false
# Duration timer managed internally now

func _on_apply() -> bool:
	if not target_enemy is EnemyBase: return false
	_apply_modifier()
	_start_duration_timer()
	return true

func _on_level_change(_old_level: int):
	_apply_modifier()
	_start_duration_timer()

func _on_remove():
	_remove_modifier()
	if is_instance_valid(duration_timer): duration_timer.stop()

func _apply_modifier():
	if not is_instance_valid(target_enemy): return
	var multiplier = 1.0 - SPEED_MODIFIER
	target_enemy.speed_multipliers[effect_data.effect_id] = multiplier
	was_active = true

func _remove_modifier():
	if not is_instance_valid(target_enemy): return
	if target_enemy.speed_multipliers.has(effect_data.effect_id):
		target_enemy.speed_multipliers.erase(effect_data.effect_id)
	was_active = false

func _start_duration_timer():
	var duration = effect_data.get_value_for_level(level, "duration", 0.0)
	if duration > 0:
		if not is_instance_valid(duration_timer):
			duration_timer = Timer.new()
			duration_timer.one_shot = true
			add_child(duration_timer)
			duration_timer.timeout.connect(queue_free)
		duration_timer.wait_time = duration
		duration_timer.start()
	elif is_instance_valid(duration_timer):
		duration_timer.stop()
