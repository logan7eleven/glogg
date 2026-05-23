class_name ActiveSpikeEffect
extends "res://ActiveStatusEffect.gd"

var visual_ring: Polygon2D

func _on_apply() -> bool:
	_update_spike_state()
	_create_or_update_ring()

	var contagious_effect = target_enemy.get_node_or_null("contagious")
	if is_instance_valid(contagious_effect) and contagious_effect.has_method("_create_or_update_ring"):
		contagious_effect._create_or_update_ring()
		
	return true
	
func _on_remove():
	if is_instance_valid(target_enemy):
		target_enemy.collision_damage_providers.erase(effect_data.effect_id)
	if is_instance_valid(visual_ring):
		visual_ring.queue_free()
		
	var contagious_effect = target_enemy.get_node_or_null("contagious")
	if is_instance_valid(contagious_effect) and contagious_effect.has_method("_create_or_update_ring"):
		contagious_effect._create_or_update_ring()

func _on_level_change(_old_level: int):
	_update_spike_state()
	_create_or_update_ring()

func _update_spike_state():
	if not is_instance_valid(target_enemy): return
	var total_mult = effect_data.get_calculated_value(level, "damage_mult", "level_bonus_damage", 0.0)
	var calculated_spike_damage = GlobalState.BASE_DAMAGE * total_mult

	# --- CHANGE IS HERE ---
	# We now store the source slot index along with the other data.
	target_enemy.collision_damage_providers[effect_data.effect_id] = {
		"damage": calculated_spike_damage,
		"level": level,
		"name": "Spikes",
		"slot_index": self.source_slot_index
	}

func _create_or_update_ring():
	if not is_instance_valid(target_enemy): return

	if is_instance_valid(visual_ring):
		visual_ring.queue_free()
	
	visual_ring = Polygon2D.new()
	visual_ring.color = Color(0.0, 0.0, 0.0, 0.5) 
	
	var base_radius = _get_sprite_radius(target_enemy)
	var spikes_radius = base_radius * 1.05
	
	visual_ring.polygon = _generate_circle_points(spikes_radius, 32)
	
	target_enemy.add_child(visual_ring)
	target_enemy.move_child(visual_ring, 0)

func _get_sprite_radius(enemy: EnemyBase) -> float:
	var sprite = enemy.get_node_or_null("Sprite2D")
	if is_instance_valid(sprite) and is_instance_valid(sprite.texture):
		var size = sprite.texture.get_size() * sprite.scale
		return size.length() / 2.0
	return 20.0

func _generate_circle_points(radius: float, num_segments: int) -> PackedVector2Array:
	var points = PackedVector2Array()
	var step = TAU / num_segments
	for i in range(num_segments + 1):
		points.append(Vector2(cos(i * step), sin(i * step)) * radius)
	return points
