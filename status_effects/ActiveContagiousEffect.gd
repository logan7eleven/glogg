class_name ActiveContagiousEffect
extends ActiveStatusEffect

var visual_ring: Polygon2D

const BASE_EFFECTS_KEY = "base_effects_to_pass"
const BONUS_FRACTION_KEY = "bonus_effects_to_pass" 
const RING_COLOR = Color(0.3, 0.15, 0.05, 0.5)

func _on_apply() -> bool:
	_create_or_update_ring()
	return true

func _on_remove():
	if is_instance_valid(visual_ring):
		visual_ring.queue_free()

func _on_level_change(_old_level: int):
	_create_or_update_ring()

func _create_or_update_ring():
	if not is_instance_valid(target_enemy): return

	if is_instance_valid(visual_ring):
		visual_ring.queue_free()
	
	visual_ring = Polygon2D.new()
	visual_ring.color = RING_COLOR
	
	var base_radius = _get_sprite_radius(target_enemy)
	var spikes_radius = base_radius * 1.05
	var contagious_radius = spikes_radius * 1.15
	
	# Check if the Spikes effect node exists on the same enemy.
	var spikes_effect = target_enemy.get_node_or_null("spikes")
	
	if is_instance_valid(spikes_effect):
		# If spikes are active, draw a donut shape to create a "cutout".
		visual_ring.polygon = _generate_donut_points(contagious_radius, spikes_radius, 32)
	else:
		# Otherwise, draw a normal, full circle.
		visual_ring.polygon = _generate_circle_points(contagious_radius, 32)
	
	target_enemy.add_child(visual_ring)
	# Move the ring behind the sprite so it doesn't cover it.
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

func _generate_donut_points(outer_radius: float, inner_radius: float, num_segments: int) -> PackedVector2Array:
	# This function creates a "donut" shape.
	# It works by first defining the outer edge clockwise...
	var outer_points = _generate_circle_points(outer_radius, num_segments)
	
	# ...and then defining the inner hole counter-clockwise.
	var inner_points = PackedVector2Array()
	var step = TAU / num_segments
	# We iterate backwards to get the opposite winding order for the hole.
	for i in range(num_segments, -1, -1):
		inner_points.append(Vector2(cos(i * step), sin(i * step)) * inner_radius)
		
	# Combining them creates a single polygon with a hole.
	return outer_points + inner_points

func execute_contagious_spread(target_enemy_to_infect: EnemyBase):
	var base_guaranteed_draws = effect_data.get_calculated_value(level, BASE_EFFECTS_KEY, "", 1)
	var bonus_fraction_from_data = effect_data.get_level_data_dict().get(BONUS_FRACTION_KEY, 0.0)	
	var total_bonus_potential = float(level - 1) * bonus_fraction_from_data
	var guaranteed_bonus_draws = floor(total_bonus_potential)
	var chance_for_one_more_draw = total_bonus_potential - guaranteed_bonus_draws
	var num_draws_to_attempt = int(base_guaranteed_draws + guaranteed_bonus_draws)
	if randf() < chance_for_one_more_draw:
		num_draws_to_attempt += 1
	if num_draws_to_attempt <= 0:
		return
	var available_effect_stacks_to_pass: Array = []
	for child_node in self.target_enemy.get_children():
		if child_node is ActiveStatusEffect:
			var effect_node_on_source := child_node as ActiveStatusEffect
			for _i in range(effect_node_on_source.level): 
				available_effect_stacks_to_pass.append(effect_node_on_source.effect_data)
	if available_effect_stacks_to_pass.is_empty():
		return
	available_effect_stacks_to_pass.shuffle()
	var effects_to_pass: Dictionary = {}
	var num_to_draw = min(num_draws_to_attempt, available_effect_stacks_to_pass.size())
	for i in range(num_to_draw):
		var effect_data_to_pass = available_effect_stacks_to_pass[i]
		effects_to_pass[effect_data_to_pass] = effects_to_pass.get(effect_data_to_pass, 0) + 1
	if effects_to_pass.is_empty():
		return
	for effect_data_to_apply in effects_to_pass:
		var stacks_to_add = effects_to_pass[effect_data_to_apply]
		var contagious_source_desc = "%s Contagious (Lvl %d)" % [self.target_enemy._get_log_id_str(), level]
		target_enemy_to_infect.apply_status_effect(effect_data_to_apply, stacks_to_add, -2, contagious_source_desc)
