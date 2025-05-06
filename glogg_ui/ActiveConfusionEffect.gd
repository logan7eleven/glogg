# ActiveConfusionEffect.gd (Implement Movement Override)
class_name ActiveConfusionEffect
extends "res://ActiveStatusEffect.gd" # Extend using path

var is_confused_moving: bool = false
var confusion_move_direction: Vector2 = Vector2.ZERO

func _ready():
	# Disable physics process initially, only enable when actively confused
	set_physics_process(false)

func _on_apply() -> bool:
	if not target_enemy is EnemyBase: return false
	_start_or_add_duration(false)
	_start_confused_movement()
	return true

func _on_level_change(_old_level: int):
	# Just add duration when level increases. The confused movement state
	# is already active if the effect exists.
	_start_or_add_duration(true)

func _on_remove():
	# Cleanup when effect node is removed (e.g., duration ends or enemy dies)
	_stop_confused_movement() # Ensure inhibitors are removed if active


func _start_confused_movement():
	# This is now called directly from _on_apply
	if not is_instance_valid(target_enemy): return

	# Check if already moving (e.g., from a rapid re-apply before timer ends)
	# If so, just recalculate direction and ensure physics is on.
	if not is_confused_moving:
		is_confused_moving = true
		set_physics_process(true) # Enable physics process for movement

		# Inhibit normal orientation and movement logic in EnemyBase
		target_enemy.orientation_inhibitors[effect_data.effect_id] = true
		target_enemy.movement_inhibitors[effect_data.effect_id] = true
	else:
		# Already confused, just ensure physics process is enabled
		if not is_physics_processing():
			set_physics_process(true)

	# Calculate initial random direction (or new direction if re-applied)
	_calculate_new_confusion_direction()


func _stop_confused_movement():
	# This function is primarily called by _on_remove when the effect expires.
	if not is_confused_moving: return # Only run cleanup if currently confused
	is_confused_moving = false
	set_physics_process(false) # Disable physics process

	# Remove inhibitors if target is still valid
	if is_instance_valid(target_enemy):
		if target_enemy.orientation_inhibitors.has(effect_data.effect_id):
			target_enemy.orientation_inhibitors.erase(effect_data.effect_id)
		if target_enemy.movement_inhibitors.has(effect_data.effect_id):
			target_enemy.movement_inhibitors.erase(effect_data.effect_id)


func _calculate_new_confusion_direction():
	# Calculates a new random direction vector
	if not is_instance_valid(target_enemy) or not is_instance_valid(target_enemy.player):
		confusion_move_direction = Vector2.RIGHT.rotated(randf() * TAU) # Failsafe random direction
		return

	var angle_to_player = target_enemy.global_position.angle_to_point(target_enemy.player.global_position)
	# Ensure offset is between 30 and 330 degrees (avoiding straight towards/away)
	var random_angle_offset = randf_range(deg_to_rad(30.0), deg_to_rad(330.0))
	var random_direction_angle = wrapf(angle_to_player + random_angle_offset, 0, TAU)
	confusion_move_direction = Vector2.RIGHT.rotated(random_direction_angle)


func _physics_process(delta: float):
	# This runs ONLY when is_confused_moving is true
	if not is_confused_moving or not is_instance_valid(target_enemy):
		_stop_confused_movement() # Safety check if target becomes invalid
		return

	# Use the enemy's BASE speed for confusion movement.
	# Assumes the enemy script (e.g., crawler.gd) has exported 'base_speed'.
	var speed = 0.0
	# Use get() for safety, check if property exists and is numeric
	if "base_speed" in target_enemy:
		var base_speed_val = target_enemy.get("base_speed")
		if typeof(base_speed_val) == TYPE_FLOAT or typeof(base_speed_val) == TYPE_INT:
			speed = float(base_speed_val)
		else:
			printerr("Confusion Effect: Target enemy %s 'base_speed' is not a number!" % target_enemy.name)
			_stop_confused_movement()
			return
	else:
		printerr("Confusion Effect: Target enemy %s missing 'base_speed' property!" % target_enemy.name)
		_stop_confused_movement() # Stop if we can't get speed
		return

	var movement = confusion_move_direction * speed * delta
	# Use the target_enemy's move_and_collide method
	var collision_info = target_enemy.move_and_collide(movement)

	if collision_info:
		# On collision, pick a new random direction immediately and continue moving
		# print("Confusion collision! Recalculating direction.") # Debug
		_calculate_new_confusion_direction()

	# The effect stops when the main duration_timer (started in _on_apply/_on_level_change)
	# times out. This timer calls queue_free() on this effect node.
	# queue_free() triggers NOTIFICATION_PREDELETE, which calls _on_remove.
	# _on_remove calls _stop_confused_movement() to remove inhibitors and disable physics.
