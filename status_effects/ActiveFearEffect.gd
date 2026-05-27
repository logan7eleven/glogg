class_name ActiveFearEffect
extends "res://ActiveStatusEffect.gd" 

var fear_timer: Timer 
var is_feared: bool = false 

const PLAYER_PROXIMITY_THRESHOLD = 100.0
const FEAR_DURATION_BASE_KEY = "fear_duration"
const FEAR_DURATION_BONUS_KEY = "level_bonus_fear"
const IDLE_COLOR = Color(0.8, 0.7, 1.0, 1)   # Light purple tint
const FEARED_COLOR = Color(0.8, 0.2, 1.0, 1) # Vibrant purple tint

func _on_apply() -> bool:
	if not fear_timer: 
		fear_timer = Timer.new(); fear_timer.one_shot = true
		add_child(fear_timer); fear_timer.timeout.connect(_on_fear_timer_timeout)
	if is_instance_valid(target_enemy.visual_manager):
		target_enemy.visual_manager.set_effect_active("fear", true)
	_update_fear_color()
	set_physics_process(true)
	return true

func _on_level_change(_old_level: int):
	pass

func _physics_process(_delta):
	if not is_feared and target_enemy and is_instance_valid(target_enemy.player):
		if target_enemy.global_position.distance_to(target_enemy.player.global_position) < PLAYER_PROXIMITY_THRESHOLD:
			_apply_fear()

func _apply_fear():
	is_feared = true
	if is_instance_valid(target_enemy):
		target_enemy.movement_inhibitors[effect_data.effect_id] = true 
	var total_fear_duration = effect_data.get_calculated_value(level, FEAR_DURATION_BASE_KEY, FEAR_DURATION_BONUS_KEY, 1.0)
	fear_timer.start(total_fear_duration)
	_update_fear_color()

func _on_fear_timer_timeout():
	is_feared = false
	if is_instance_valid(target_enemy) and target_enemy.movement_inhibitors.has(effect_data.effect_id):
		target_enemy.movement_inhibitors.erase(effect_data.effect_id)
	_update_fear_color()

func _update_fear_color():
	var color = IDLE_COLOR if not is_feared else FEARED_COLOR
	if is_instance_valid(target_enemy.visual_manager):
		target_enemy.visual_manager.set_fear_color(color)

func _on_remove():
	if fear_timer: 
		fear_timer.stop()
	if is_instance_valid(target_enemy):
		if is_feared and target_enemy.movement_inhibitors.has(effect_data.effect_id):
			target_enemy.movement_inhibitors.erase(effect_data.effect_id)
		if is_instance_valid(target_enemy.visual_manager):
			target_enemy.visual_manager.set_effect_active("fear", false)
	set_physics_process(false)
