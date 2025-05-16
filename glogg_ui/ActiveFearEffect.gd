class_name ActiveFearEffect
extends "res://ActiveStatusEffect.gd" 

const PLAYER_PROXIMITY_THRESHOLD = 100.0
const FREEZE_DURATION_BASE_KEY = "freeze_duration"
const FREEZE_DURATION_BONUS_KEY = "level_bonus_freeze" 

var freeze_timer: Timer 
var is_frozen: bool = false 

func _on_apply() -> bool:
	if not freeze_timer: 
		freeze_timer = Timer.new(); freeze_timer.one_shot = true
		add_child(freeze_timer); freeze_timer.timeout.connect(_on_freeze_timer_timeout)
	set_physics_process(true) 
	return true

func _physics_process(_delta):
	if not is_frozen and target_enemy and target_enemy.player:
		if target_enemy.global_position.distance_to(target_enemy.player.global_position) < PLAYER_PROXIMITY_THRESHOLD:
			_apply_freeze()

func _apply_freeze():
	is_frozen = true
	target_enemy.movement_inhibitors[effect_data.effect_id] = true 
	var total_freeze_duration = effect_data.get_calculated_value(level, FREEZE_DURATION_BASE_KEY, FREEZE_DURATION_BONUS_KEY, 1.0)
	freeze_timer.start(total_freeze_duration)

func _on_freeze_timer_timeout():
	is_frozen = false
	if target_enemy and target_enemy.movement_inhibitors.has(effect_data.effect_id):
		target_enemy.movement_inhibitors.erase(effect_data.effect_id)

func _on_remove():
	if freeze_timer: 
		freeze_timer.stop()
	if target_enemy and is_frozen and target_enemy.movement_inhibitors.has(effect_data.effect_id):
		target_enemy.movement_inhibitors.erase(effect_data.effect_id)
	set_physics_process(false)
