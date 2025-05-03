# ActiveStatusEffect.gd
# Base Node class for ACTIVE status effects attached to enemies.
extends Node
class_name ActiveStatusEffect # Keep class_name for type hints if needed elsewhere

var effect_data: StatusEffectData
var target_enemy: EnemyBase # Requires EnemyBase.gd to have class_name EnemyBase
var level: int = 1
var source_slot_index: int = -1
var duration_timer: Timer

func initialize(data: StatusEffectData, target: EnemyBase, effect_level: int, slot_index: int):
	if not is_instance_valid(data) or not is_instance_valid(target): queue_free(); return
	self.effect_data = data
	self.target_enemy = target
	self.level = effect_level
	self.source_slot_index = slot_index
	self.name = data.effect_id
	if not _on_apply(): queue_free()

func increment_and_update_level():
	var new_level = level + 1
	var old_level = level
	level = new_level
	print("Stacked effect '%s' on %s to Lvl %d" % [name, target_enemy.enemy_id, level])
	_on_level_change(old_level)

func _notification(what):
	if what == NOTIFICATION_PREDELETE: _on_remove()

# --- Virtual Methods ---
func _on_apply() -> bool: return true
func _on_level_change(_old_level: int): pass

func _on_remove():
	if is_instance_valid(duration_timer):
		duration_timer.stop()
	# Inform EnemyBase (optional)
	if is_instance_valid(target_enemy) and target_enemy.has_method("effect_node_removed"):
		target_enemy.effect_node_removed(self.name)

func _start_or_add_duration(add_duration: bool = false):
	# Calculate duration using CURRENT node level and resource data
	var duration = effect_data.get_calculated_value(level, "base_duration", "level_bonus_duration", 0.0)

	if duration <= 0: # Effect has no duration or invalid duration
		if is_instance_valid(duration_timer): duration_timer.stop() # Stop if running
		return # Do nothing further

	# Create timer if it doesn't exist
	if not is_instance_valid(duration_timer):
		duration_timer = Timer.new(); duration_timer.one_shot = true
		# Timer is child of this effect node, connects timeout to free this node
		add_child(duration_timer); duration_timer.timeout.connect(queue_free)

	var time_to_set = duration
	# If stacking duration, add new duration to remaining time
	if add_duration and duration_timer.time_left > 0:
		time_to_set = duration_timer.time_left + duration

	duration_timer.wait_time = time_to_set
	duration_timer.start() # Start or restart the timer
