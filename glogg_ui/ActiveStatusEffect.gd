# ActiveStatusEffect.gd (Base Node - No Level Capping)
class_name ActiveStatusEffect
extends Node

var effect_data: StatusEffectData
var target_enemy: EnemyBase
var level: int = 1 # The CURRENT effective level on the enemy
var source_slot_index: int = -1
var duration_timer: Timer

func initialize(data: StatusEffectData, target: EnemyBase, initial_level: int, slot_index: int):
	if not is_instance_valid(data) or not is_instance_valid(target):
		printerr("ActiveStatusEffect: Invalid data or target during initialization for %s." % data.effect_id if is_instance_valid(data) else "UNKNOWN")
		queue_free(); return

	self.effect_data = data
	self.target_enemy = target
	self.level = initial_level # Start at level from hit (usually 1)
	self.source_slot_index = slot_index
	self.name = data.effect_id

	if not _on_apply(): # Call specific apply logic
		printerr("ActiveStatusEffect: _on_apply failed for %s. Removing." % self.name)
		queue_free(); return

# Called by EnemyBase when the same effect type is applied again
func update_level(new_level: int):
	# --- REMOVED CLAMPING ---
	# var clamped_new_level = clampi(new_level, 1, effect_data.max_enemy_stacks) # Removed
	if new_level == level: return # Still avoid redundant updates

	var old_level = level
	level = new_level # Assign the new, potentially very high, level
	print("Stacked effect '%s' on %s to Lvl %d" % [name, target_enemy.crawler_id, level])
	_on_level_change(old_level) # Trigger logic update based on the new level
	_start_duration_timer_if_needed() # Refresh duration based on NEW level

func _notification(what):
	if what == NOTIFICATION_PREDELETE: _on_remove()

# --- Virtual Methods ---
func _on_apply() -> bool: return true
func _on_level_change(_old_level: int): pass
func _on_remove(): pass

# --- Internal Helper ---
# Moved from specific effects to base, called by inheriting scripts if needed
func _start_duration_timer_if_needed():
	# Calculate duration using CURRENT node level and resource data
	var duration = effect_data.get_calculated_value(level, "base_duration", "level_bonus_duration")
	if duration > 0:
		if not is_instance_valid(duration_timer):
			duration_timer = Timer.new(); duration_timer.one_shot = true
			add_child(duration_timer); duration_timer.timeout.connect(queue_free)
		duration_timer.wait_time = duration
		duration_timer.start()
	elif is_instance_valid(duration_timer): # Stop timer if duration becomes 0 or negative
		duration_timer.stop()
