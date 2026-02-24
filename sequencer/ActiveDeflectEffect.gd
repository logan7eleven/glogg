class_name ActiveDeflectEffect
extends ActiveStatusEffect

const ANGLE_INCREMENT = TAU / 16.0
const BASE_CHANCE_KEY = "base_chance"
const BONUS_CHANCE_KEY = "level_bonus_chance"

func _on_apply() -> bool:
	if not is_instance_valid(target_enemy): 
		return false
		
	if not target_enemy.is_connected("just_hit_by_bullet", Callable(self, "_on_enemy_hit_by_bullet")):
		target_enemy.connect("just_hit_by_bullet", Callable(self, "_on_enemy_hit_by_bullet"))
		
	if is_instance_valid(target_enemy) and is_instance_valid(target_enemy.visual_manager):
		target_enemy.visual_manager.set_effect_active("deflect", true)
		
	return true

func _on_level_change(_old_level: int):
	pass

func _on_enemy_hit_by_bullet(bullet: Area2D):
	if not is_instance_valid(bullet):
		return
	var deflect_chance = effect_data.get_calculated_value(level, BASE_CHANCE_KEY, BONUS_CHANCE_KEY, 0.0)
	if randf() < deflect_chance:
		var random_direction_index = randi_range(0, 15)
		var new_angle = random_direction_index * ANGLE_INCREMENT
		var new_direction = Vector2.RIGHT.rotated(new_angle)   
		if bullet.has_method("execute_deflection"):
			bullet.execute_deflection(new_direction)
			# --- CHANGE IS HERE ---
			# Take ownership of the deflected bullet's damage.
			if bullet.has_method("set_owner_slot"):
				bullet.set_owner_slot(self.source_slot_index)
			print("%s deflected a bullet with Lvl %d %s (%.1f%% chance)" % [target_enemy._get_log_id_str(), level, effect_data.display_name, deflect_chance * 100])
	else:
		if bullet.has_method("finalize_impact"):
			bullet.finalize_impact()

func _on_remove():
	if is_instance_valid(target_enemy):
		if target_enemy.is_connected("just_hit_by_bullet", Callable(self, "_on_enemy_hit_by_bullet")):
			target_enemy.disconnect("just_hit_by_bullet", Callable(self, "_on_enemy_hit_by_bullet"))
		
		if is_instance_valid(target_enemy.visual_manager):
			target_enemy.visual_manager.set_effect_active("deflect", false)
