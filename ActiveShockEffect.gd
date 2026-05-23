class_name ActiveShockEffect
extends ActiveStatusEffect

const PULSE_AREA_SCENE = preload("res://ShockArea.tscn")
const INTERVAL_KEY = "pulse_interval"
const DIAMETER_BASE_KEY = "base_aoe_diameter"
const DIAMETER_BONUS_KEY = "level_bonus_aoe_diameter"
const ACTIVE_DURATION_KEY = "pulse_active_duration"
const DAMAGE_KEY = "shock_damage"
const STUN_DURATION_KEY = "shock_stun_duration"

var _pulse_interval_timer: Timer
var _source_enemy_id: int = 0
var _active_pulses: Array[Node] = []

func _on_apply() -> bool:
	if not is_instance_valid(target_enemy): return false
	_source_enemy_id = target_enemy.get_instance_id()
	var interval = effect_data.get_calculated_value(level, INTERVAL_KEY, "", 1.0)
	_pulse_interval_timer = Timer.new()
	_pulse_interval_timer.wait_time = interval
	_pulse_interval_timer.one_shot = false
	_pulse_interval_timer.timeout.connect(Callable(self, "_on_pulse_interval_timeout"))
	add_child(_pulse_interval_timer)
	_pulse_interval_timer.start()
	return true

func _on_level_change(_old_level: int):
	if is_instance_valid(_pulse_interval_timer):
		var interval = effect_data.get_calculated_value(level, INTERVAL_KEY, "", 1.0)
		if interval > 0:
			_pulse_interval_timer.wait_time = interval
			if not _pulse_interval_timer.is_stopped():
				_pulse_interval_timer.start()
		else:
			_pulse_interval_timer.stop()

func _on_pulse_interval_timeout():
	if not is_instance_valid(target_enemy):
		_cleanup_timers_and_remove_self()
		return
	var diameter = effect_data.get_calculated_value(level, DIAMETER_BASE_KEY, DIAMETER_BONUS_KEY, 50.0)
	var active_duration = effect_data.get_calculated_value(level, ACTIVE_DURATION_KEY, "", 0.25)
	var damage = effect_data.get_calculated_value(level, DAMAGE_KEY, "", 0.5)
	var stun_duration = effect_data.get_calculated_value(level, STUN_DURATION_KEY, "", 0.5)
	target_enemy.apply_timed_stun(stun_duration, "shock_stun")
	_active_pulses = _active_pulses.filter(func(p): return is_instance_valid(p))
	var pulse_area_instance = PULSE_AREA_SCENE.instantiate()
	var level_node = get_tree().current_scene
	if is_instance_valid(level_node) and level_node is Node2D:
		level_node.add_child(pulse_area_instance)
	elif is_instance_valid(target_enemy.get_parent()):
		target_enemy.get_parent().add_child(pulse_area_instance)
	else:
		add_child(pulse_area_instance)
	pulse_area_instance.global_position = target_enemy.global_position
	if pulse_area_instance.has_method("setup_pulse"):
		var source_name = target_enemy._get_log_id_str()
		# --- MODIFIED LINE ---
		# We now pass `self.source_slot_index` as the last argument.
		pulse_area_instance.setup_pulse(diameter, active_duration, damage, stun_duration, _source_enemy_id, source_name, level, self.source_slot_index)

func _cleanup_timers_and_remove_self():
	if is_instance_valid(_pulse_interval_timer):
		_pulse_interval_timer.stop()
	if not is_inside_tree(): return
	queue_free()

func _on_remove():
	if is_instance_valid(_pulse_interval_timer):
		_pulse_interval_timer.stop()
	for pulse in _active_pulses:
		if is_instance_valid(pulse):
			pulse.queue_free()
	_active_pulses.clear()
