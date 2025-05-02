# ActiveConfusionEffect.gd
class_name ActiveConfusionEffect
extends ActiveStatusEffect

func _on_apply() -> bool:
	if not target_enemy is EnemyBase: return false
	# Connect to signal emitted by EnemyBase before it decides orientation target
	if not target_enemy.is_connected("orientation_requested", Callable(self, "_on_target_orientation_requested")):
		target_enemy.connect("orientation_requested", Callable(self, "_on_target_orientation_requested"))
	return true

func _on_remove():
	if not is_instance_valid(target_enemy): return
	if target_enemy.is_connected("orientation_requested", Callable(self, "_on_target_orientation_requested")):
		target_enemy.disconnect("orientation_requested", Callable(self, "_on_target_orientation_requested"))
	# No persistent state on enemy to clean up directly

# Called by signal from EnemyBase before it tries to orient
func _on_target_orientation_requested():
	if not is_instance_valid(target_enemy) or not is_instance_valid(target_enemy.player): return

	var base_chance = effect_data.get_value_for_level(level, "chance", 0.0)
	var bonus = effect_data.get_value_for_level(level, "level_bonus", 0.0)
	var total_chance = base_chance + (bonus * (level - 1))

	if randf() < total_chance:
		var angle_to_player = target_enemy.global_position.angle_to_point(target_enemy.player.global_position)
		var random_angle_offset = randf_range(deg_to_rad(30.0), deg_to_rad(330.0))
		var random_direction_angle = wrapf(angle_to_player + random_angle_offset, 0, TAU)
		var random_direction = Vector2.RIGHT.rotated(random_direction_angle)
		# Set the enemy's target to a point far away
		target_enemy.orientation_target = target_enemy.global_position + random_direction * 1000
