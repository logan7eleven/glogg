# ActiveConfusionEffect.gd (No Duration)
class_name ActiveConfusionEffect
extends "res://ActiveStatusEffect.gd" # Extend using path

func _on_apply() -> bool:
	if not target_enemy is EnemyBase: return false
	if not target_enemy.is_connected("orientation_requested", Callable(self, "_on_target_orientation_requested")):
		target_enemy.connect("orientation_requested", Callable(self, "_on_target_orientation_requested"))
	_start_or_add_duration(false) # Set initial duration
	return true

func _on_level_change(_old_level: int):
	_start_or_add_duration(true) 
	
func _on_remove():
	if is_instance_valid(target_enemy):
		if target_enemy.is_connected("orientation_requested", Callable(self, "_on_target_orientation_requested")):
			target_enemy.disconnect("orientation_requested", Callable(self, "_on_target_orientation_requested"))
	if is_instance_valid(duration_timer): duration_timer.stop() # Stop internal timer

# Called by signal from EnemyBase before it tries to orient
func _on_target_orientation_requested():
	if not target_enemy or not target_enemy.player: return

	# Calculate chance based on CURRENT level of this node
	var total_chance = effect_data.get_calculated_value(level, "chance", "level_bonus_chance", 0.0)

	if randf() < total_chance:
		# Calculate random target angle away from player
		var angle_to_player = target_enemy.global_position.angle_to_point(target_enemy.player.global_position)
		var random_angle_offset = randf_range(deg_to_rad(30.0), deg_to_rad(330.0))
		var random_direction_angle = wrapf(angle_to_player + random_angle_offset, 0, TAU)
		var random_direction = Vector2.RIGHT.rotated(random_direction_angle)
		# Set the enemy's target to a point far away
		target_enemy.orientation_target = target_enemy.global_position + random_direction * 1000
