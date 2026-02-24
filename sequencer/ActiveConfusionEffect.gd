class_name ActiveConfusionEffect
extends "res://ActiveStatusEffect.gd" 

var is_confused: bool = false
var confusion_direction: Vector2 = Vector2.ZERO
var confused_timer: Timer
var interval_timer: Timer

const CONFUSION_DURATION = 1.0
const CONFUSION_SPEED_MULTIPLIER = 1.5
const CHECK_INTERVAL = 3.0
const CHANCE_KEY = "chance" 
const CHANCE_BONUS_KEY = "level_bonus_chance"

func _get_target_sprite() -> Sprite2D:
	if is_instance_valid(target_enemy) and target_enemy.has_node("Sprite2D"):
		return target_enemy.get_node("Sprite2D")
	return null

func _on_apply() -> bool: 
	interval_timer = Timer.new()
	interval_timer.wait_time = CHECK_INTERVAL
	interval_timer.one_shot = false
	interval_timer.timeout.connect(_on_interval_timer_timeout)
	add_child(interval_timer)
	interval_timer.start()
	confused_timer = Timer.new()
	confused_timer.one_shot = true
	confused_timer.wait_time = CONFUSION_DURATION
	confused_timer.timeout.connect(_on_confused_timer_timeout)
	add_child(confused_timer)
	var sprite = _get_target_sprite()
	if is_instance_valid(sprite):
		sprite.flip_v = true
	set_physics_process(false)
	return true

func _on_level_change(_old_level: int):
	pass

func _on_interval_timer_timeout():
	if not is_instance_valid(target_enemy):
		queue_free()
		return
	var chance = effect_data.get_calculated_value(level, CHANCE_KEY, CHANCE_BONUS_KEY, 0.0)
	if randf() < chance:
		_start_confused_movement()

func _start_confused_movement():
	is_confused = true
	set_physics_process(true) 
	if is_instance_valid(target_enemy) and is_instance_valid(target_enemy.player):
		target_enemy.orientation_inhibitors[effect_data.effect_id] = true
		target_enemy.movement_inhibitors[effect_data.effect_id] = true
		var angle_to_player = target_enemy.global_position.angle_to_point(target_enemy.player.global_position)
		var random_angle_offset = randf_range(deg_to_rad(30.0), deg_to_rad(330.0))
		var random_direction_angle = wrapf(angle_to_player + random_angle_offset, 0, TAU)
		confusion_direction = Vector2.RIGHT.rotated(random_direction_angle)
		confused_timer.start()
	
func _on_confused_timer_timeout():
	_stop_confused_movement()

func _stop_confused_movement():
	is_confused = false
	set_physics_process(false)
	if is_instance_valid(target_enemy):
		target_enemy.orientation_inhibitors.erase(effect_data.effect_id)
		target_enemy.movement_inhibitors.erase(effect_data.effect_id)

func _on_remove():
	_stop_confused_movement()
	var sprite = _get_target_sprite()
	if is_instance_valid(sprite):
		sprite.flip_v = false

func _physics_process(delta: float):
	if not is_instance_valid(target_enemy):
		queue_free()
		return
		
	var base_speed = target_enemy.base_speed
	var confused_speed = base_speed * CONFUSION_SPEED_MULTIPLIER
	var movement = confusion_direction * confused_speed * delta
	var collision_info = target_enemy.move_and_collide(movement)
	if collision_info and is_instance_valid(target_enemy.player):
		var angle_to_player = target_enemy.global_position.angle_to_point(target_enemy.player.global_position)
		var random_angle_offset = randf_range(deg_to_rad(30.0), deg_to_rad(330.0))
		var random_direction_angle = wrapf(angle_to_player + random_angle_offset, 0, TAU)
		confusion_direction = Vector2.RIGHT.rotated(random_direction_angle)
