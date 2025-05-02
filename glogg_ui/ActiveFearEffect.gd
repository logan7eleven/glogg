# ActiveFearEffect.gd (Persistent Proximity Freeze - Cleaned)
class_name ActiveFearEffect
extends "res://ActiveStatusEffect.gd" # Extend using path

const PLAYER_PROXIMITY_THRESHOLD = 100.0
const FREEZE_DURATION_BASE_KEY = "freeze_duration"
const FREEZE_DURATION_BONUS_KEY = "level_bonus_freeze" # Use consistent bonus key naming

var freeze_timer: Timer # Timer for the duration of a single freeze instance
var is_frozen: bool = false # Is the enemy currently frozen by this effect?

func _on_apply() -> bool:
	if not target_enemy is EnemyBase: return false
	# Initialize freeze timer (but don't start)
	if not freeze_timer: # Use simpler check
		freeze_timer = Timer.new(); freeze_timer.one_shot = true
		add_child(freeze_timer); freeze_timer.timeout.connect(_on_freeze_timer_timeout)
	set_physics_process(true) # Need to check distance continuously
	return true

func _on_level_change(_old_level: int):
	# Level change affects future freeze durations, no immediate action needed
	pass

func _physics_process(_delta):
	# Continuously check proximity if the effect is active and target is valid
	if not is_frozen and target_enemy and target_enemy.player:
		if target_enemy.global_position.distance_to(target_enemy.player.global_position) < PLAYER_PROXIMITY_THRESHOLD:
			_apply_freeze()

func _apply_freeze():
	is_frozen = true
	target_enemy.movement_inhibitors[effect_data.effect_id] = true # Inhibit movement
	# Calculate freeze duration based on current level from resource data
	var total_freeze_duration = effect_data.get_calculated_value(level, FREEZE_DURATION_BASE_KEY, FREEZE_DURATION_BONUS_KEY, 1.0)
	freeze_timer.start(total_freeze_duration) # Start freeze timer

func _on_freeze_timer_timeout():
	is_frozen = false
	# Remove freeze inhibitor if target still valid
	if target_enemy and target_enemy.movement_inhibitors.has(effect_data.effect_id):
		target_enemy.movement_inhibitors.erase(effect_data.effect_id)

func _on_remove():
	# Stop timer if running
	if freeze_timer: freeze_timer.stop()
	# Ensure inhibitor is removed if effect removed mid-freeze
	if target_enemy and is_frozen and target_enemy.movement_inhibitors.has(effect_data.effect_id):
		target_enemy.movement_inhibitors.erase(effect_data.effect_id)
	set_physics_process(false) # Stop checking distance
