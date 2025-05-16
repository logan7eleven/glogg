extends Node
class_name ActiveStatusEffect 

var effect_data: StatusEffectData
var target_enemy: EnemyBase 
var level: int = 1
var source_slot_index: int = -1
var duration_timer: Timer

func initialize(data: StatusEffectData, target: EnemyBase, effect_level: int, slot_index: int):
	self.effect_data = data
	self.target_enemy = target
	self.level = effect_level
	self.source_slot_index = slot_index
	self.name = data.effect_id
	if not _on_apply(): 
		queue_free()

func increment_and_update_level(triggering_slot_index: int):
	var new_level = level + 1
	var old_level = level
	level = new_level
	var id_str = target_enemy._get_log_id_str()
	var source_str = "Slot %d" % triggering_slot_index if triggering_slot_index >= 0 else "Unknown Source"
	print("%s %s increased to level %d by %s" % [id_str, effect_data.display_name, level, source_str])
	_on_level_change(old_level)

func _notification(what):
	if what == NOTIFICATION_PREDELETE: _on_remove()

# --- Virtual Methods ---
func _on_apply(): 
	return true
	pass
func _on_level_change(_old_level: int): 
	pass

func _on_remove():
	duration_timer.stop()
	target_enemy.effect_node_removed(self.name)

func _start_or_add_duration(add_duration: bool = false):
	var duration = effect_data.get_calculated_value(level, "base_duration", "level_bonus_duration", 0.0)
	if duration <= 0:
		if is_instance_valid(duration_timer): 
			duration_timer.stop()
		return 
	if not is_instance_valid(duration_timer):
		duration_timer = Timer.new(); duration_timer.one_shot = true
		add_child(duration_timer); duration_timer.timeout.connect(queue_free)
	var time_to_set = duration
	if add_duration and duration_timer.time_left > 0:
		time_to_set = duration_timer.time_left + duration
	duration_timer.wait_time = time_to_set
	duration_timer.start()
