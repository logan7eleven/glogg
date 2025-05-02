# ActiveStatusEffect.gd
# Base Node class for ACTIVE status effects attached to enemies.
class_name ActiveStatusEffect
extends Node

var effect_data: StatusEffectData
var target_enemy: EnemyBase
var level: int = 1 # The CURRENT effective level on the enemy
var source_slot_index: int = -1

# Called by EnemyBase.apply_status_effect
func initialize(data: StatusEffectData, target: EnemyBase, effect_level: int, slot_index: int):
	# Basic validation is unavoidable here to prevent later crashes
	if not is_instance_valid(data) or not is_instance_valid(target):
		queue_free(); return

	self.effect_data = data
	self.target_enemy = target
	self.level = effect_level
	self.source_slot_index = slot_index
	self.name = data.effect_id # Use effect_id for node name

	if not _on_apply(): # Call specific apply logic
		queue_free(); return # Remove if apply fails

# Called by EnemyBase if the same effect type is applied again (stacking hit)
func increment_and_update_level(): # Renamed from update_level for clarity
	var new_level = level + 1
	# No arbitrary cap on level increase on the enemy
	var old_level = level
	level = new_level
	_on_level_change(old_level) # Trigger logic update based on the new level

# Called automatically by Godot just before the node is freed
func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		_on_remove() # Ensure cleanup logic runs

# --- Virtual Methods for Inheriting Scripts ---
func _on_apply() -> bool: return true # Initial setup, return false on failure
func _on_level_change(_old_level: int): pass # React to level increase
func _on_remove(): pass # Cleanup (restoring enemy state)
