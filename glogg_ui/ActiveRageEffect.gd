class_name ActiveRageEffect
extends "res://ActiveStatusEffect.gd"

const SPEED_INCREASE = 0.5
var was_active: bool = false

func _on_apply() -> bool:
	_apply_modifier()
	_start_or_add_duration(false) 
	return true

func _on_level_change(_old_level: int):
	_apply_modifier() 
	_start_or_refresh_duration_timer() 

func _on_remove():
	_remove_modifier() 
	duration_timer.stop()

func _apply_modifier():
	target_enemy.speed_multipliers[effect_data.effect_id] = (1.0 + SPEED_INCREASE)
	was_active = true

func _remove_modifier():
	target_enemy.speed_multipliers.erase(effect_data.effect_id)
	was_active = false

func _start_or_refresh_duration_timer():
	var duration = effect_data.get_calculated_value(level, "base_duration", "level_bonus_duration", 0.0)
	if duration > 0:
		if not duration_timer: 
			duration_timer = Timer.new(); duration_timer.one_shot = true
			add_child(duration_timer); duration_timer.timeout.connect(queue_free)
		duration_timer.wait_time = duration
		duration_timer.start()
	elif duration_timer: 
		duration_timer.stop()
