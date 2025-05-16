class_name ActiveConfusionEffect
extends "res://ActiveStatusEffect.gd" 

var is_confused_moving: bool = false
var confusion_move_direction: Vector2 = Vector2.ZERO

func _ready():
	set_physics_process(false)

func _on_apply() -> bool:
	_start_or_add_duration(false)
	_start_confused_movement()
	return true

func _on_level_change(_old_level: int):
	_start_or_add_duration(true)

func _on_remove():
	_stop_confused_movement() 

func _start_confused_movement():
	if not is_confused_moving:
		is_confused_moving = true
		set_physics_process(true) 
		target_enemy.orientation_inhibitors[effect_data.effect_id] = true
		target_enemy.movement_inhibitors[effect_data.effect_id] = true
	else:
		if not is_physics_processing():
			set_physics_process(true)
	_calculate_new_confusion_direction()

func _stop_confused_movement():
	is_confused_moving = false
	set_physics_process(false) 
	target_enemy.orientation_inhibitors.erase(effect_data.effect_id)
	target_enemy.movement_inhibitors.erase(effect_data.effect_id)

func _calculate_new_confusion_direction():
	confusion_move_direction = Vector2.RIGHT.rotated(randf() * TAU)
	var angle_to_player = target_enemy.global_position.angle_to_point(target_enemy.player.global_position)
	var random_angle_offset = randf_range(deg_to_rad(30.0), deg_to_rad(330.0))
	var random_direction_angle = wrapf(angle_to_player + random_angle_offset, 0, TAU)
	confusion_move_direction = Vector2.RIGHT.rotated(random_direction_angle)

func _physics_process(delta: float):
	if not is_confused_moving: 
		_stop_confused_movement() 
		return
	var speed = 0.0
	var base_speed_val = target_enemy.get("base_speed")
	speed = float(base_speed_val)
	var movement = confusion_move_direction * speed * delta
	var collision_info = target_enemy.move_and_collide(movement)
	if collision_info:
		_calculate_new_confusion_direction()
