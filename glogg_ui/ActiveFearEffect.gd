class_name ActiveFearEffect
extends "res://ActiveStatusEffect.gd" 

const PLAYER_PROXIMITY_THRESHOLD = 100.0
const FEAR_DURATION_BASE_KEY = "fear_duration"
const FEAR_DURATION_BONUS_KEY = "level_bonus_fear" 

var fear_timer: Timer 
var is_feared: bool = false 

func _on_apply() -> bool:
	if not fear_timer: 
		fear_timer = Timer.new(); fear_timer.one_shot = true
		add_child(fear_timer); fear_timer.timeout.connect(_on_fear_timer_timeout)
	set_physics_process(true) 
	return true

func _physics_process(_delta):
	if not is_feared and target_enemy and target_enemy.player:
		if target_enemy.global_position.distance_to(target_enemy.player.global_position) < PLAYER_PROXIMITY_THRESHOLD:
			_apply_fear()

func _apply_fear():
	is_feared = true
	target_enemy.movement_inhibitors[effect_data.effect_id] = true 
	var total_fear_duration = effect_data.get_calculated_value(level, FEAR_DURATION_BASE_KEY, FEAR_DURATION_BONUS_KEY, 1.0)
	fear_timer.start(total_fear_duration)

func _on_fear_timer_timeout():
	is_feared = false
	if target_enemy and target_enemy.movement_inhibitors.has(effect_data.effect_id):
		target_enemy.movement_inhibitors.erase(effect_data.effect_id)

func _on_remove():
	if fear_timer: 
		fear_timer.stop()
	if target_enemy and is_feared and target_enemy.movement_inhibitors.has(effect_data.effect_id):
		target_enemy.movement_inhibitors.erase(effect_data.effect_id)
	set_physics_process(false)
