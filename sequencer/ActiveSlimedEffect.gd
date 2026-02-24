class_name ActiveSlimedEffect
extends ActiveStatusEffect

var _visual_trail: Line2D
var _path_points: Array[Vector2] = []
var _path_timestamps: Array[float] = []
var _last_added_path_point: Vector2
var _trail_width: float
var _trail_damage_per_tick: float
var _trail_damage_tick_interval: float
var _trail_duration: float
var _path_point_min_distance_sq: float
var _max_path_points: int
var _damage_tick_timer: Timer
var _enemies_in_slime: Dictionary = {} 
var _source_enemy_id: int = 0

func _on_apply() -> bool:
	if not is_instance_valid(target_enemy): return false
	_source_enemy_id = target_enemy.get_instance_id()
	_visual_trail = Line2D.new()
	_visual_trail.name = "GeneratedSlimeTrail_" + str(self.get_instance_id())
	_visual_trail.default_color = Color(0.1, 0.8, 0.2, 0.5)
	_visual_trail.joint_mode = Line2D.LINE_JOINT_ROUND
	_visual_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_visual_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	var level_node = get_tree().current_scene
	if is_instance_valid(level_node):
		level_node.add_child(_visual_trail)
	else:
		printerr("ActiveSlimedEffect: Could not find level node.")
		return false
	_update_parameters_from_data()
	if _trail_damage_tick_interval <= 0:
		printerr("Slimed Error: Invalid damage_tick_interval.")
		return false
	_damage_tick_timer = Timer.new()
	_damage_tick_timer.wait_time = _trail_damage_tick_interval
	_damage_tick_timer.one_shot = false
	_damage_tick_timer.timeout.connect(_on_damage_tick)
	add_child(_damage_tick_timer)
	_damage_tick_timer.start()
	_last_added_path_point = target_enemy.global_position
	_add_path_point(target_enemy.global_position)
	set_physics_process(true)
	return true

func _update_parameters_from_data():
	_trail_width = effect_data.get_calculated_value(level, "trail_width", "", 20.0)
	_trail_damage_per_tick = effect_data.get_calculated_value(level, "trail_damage_per_tick", "", 0.5)
	_trail_damage_tick_interval = effect_data.get_calculated_value(level, "trail_damage_tick_interval", "", 0.25)
	_trail_duration = effect_data.get_calculated_value(level, "base_trail_duration", "level_bonus_duration", 1.0)
	var path_point_dist = effect_data.get_calculated_value(level, "path_point_distance", "", 10.0)
	_path_point_min_distance_sq = path_point_dist * path_point_dist
	_max_path_points = int(effect_data.get_calculated_value(level, "max_path_points", "", 50))
	if is_instance_valid(_visual_trail):
		_visual_trail.width = _trail_width

func _on_level_change(_old_level: int):
	_update_parameters_from_data()
	if is_instance_valid(_damage_tick_timer):
		if _trail_damage_tick_interval > 0:
			_damage_tick_timer.wait_time = _trail_damage_tick_interval
			if not _damage_tick_timer.is_stopped():
				_damage_tick_timer.start() 
		else:
			_damage_tick_timer.stop()

func _physics_process(_delta):
	if not is_instance_valid(target_enemy):
		_cleanup_and_stop_effect_nodes()
		queue_free()
		return
	var current_pos = target_enemy.global_position
	if current_pos.distance_squared_to(_last_added_path_point) >= _path_point_min_distance_sq:
		_add_path_point(current_pos)
		_last_added_path_point = current_pos
	_prune_old_path_points()
	if is_instance_valid(_visual_trail):
		_visual_trail.points = _path_points

func _add_path_point(position: Vector2):
	_path_points.append(position)
	_path_timestamps.append(Time.get_ticks_msec() / 1000.0)
	while _path_points.size() > _max_path_points:
		_path_points.pop_front()
		_path_timestamps.pop_front()

func _prune_old_path_points():
	var current_time = Time.get_ticks_msec() / 1000.0
	while not _path_timestamps.is_empty() and current_time > _path_timestamps[0] + _trail_duration:
		_path_timestamps.pop_front()
		_path_points.pop_front()

func _on_damage_tick():
	if _path_points.size() < 2:
		return
	var space_state = target_enemy.get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	query.collision_mask = 2 
	query.collide_with_areas = true
	var damaged_enemies_this_tick: Dictionary = {}
	for i in range(_path_points.size() - 1):
		var p1 = _path_points[i]
		var p2 = _path_points[i+1]
		var segment_length = p1.distance_to(p2)
		if segment_length < 1.0: continue
		var rect_shape = RectangleShape2D.new()
		rect_shape.size = Vector2(segment_length, _trail_width)
		query.shape = rect_shape
		query.transform = Transform2D((p2 - p1).angle(), (p1 + p2) / 2.0)
		var results = space_state.intersect_shape(query)
		for result in results:
			var collider = result.get("collider") 
			if not is_instance_valid(collider):
				continue
			var enemy: EnemyBase = null
			if is_instance_valid(collider.owner) and collider.owner is EnemyBase:
				enemy = collider.owner
			if is_instance_valid(enemy) and enemy.get_instance_id() != _source_enemy_id:
				if not damaged_enemies_this_tick.has(enemy.get_instance_id()):
					_apply_damage_to_enemy(enemy)
					damaged_enemies_this_tick[enemy.get_instance_id()] = true

func _apply_damage_to_enemy(enemy: EnemyBase):
	var damage_cooldown = _trail_damage_tick_interval
	if enemy.can_take_dot_damage_from(_source_enemy_id, damage_cooldown):
		var source_desc = "%s %s (Lvl %d)" % [target_enemy._get_log_id_str(), effect_data.display_name, level]
		# --- CHANGE IS HERE ---
		# We now call take_damage with the 'is_procedural' flag set to true.
		enemy.take_damage(_trail_damage_per_tick, self.source_slot_index, source_desc, true)
		enemy.record_dot_damage_from(_source_enemy_id)

func _cleanup_and_stop_effect_nodes():
	set_physics_process(false)
	if is_instance_valid(_damage_tick_timer):
		_damage_tick_timer.stop()
	if is_instance_valid(_visual_trail):
		_visual_trail.queue_free()
	_visual_trail = null
	_path_points.clear()
	_path_timestamps.clear()
	_enemies_in_slime.clear()

func _on_remove():
	_cleanup_and_stop_effect_nodes()
