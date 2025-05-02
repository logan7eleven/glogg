# ActiveFearEffect.gd (Persistent Proximity Freeze)
class_name ActiveFearEffect
extends ActiveStatusEffect

const PLAYER_PROXIMITY_THRESHOLD = 100.0
const FREEZE_DURATION_BASE_KEY = "freeze_duration" # Key in resource data
const FREEZE_DURATION_BONUS_KEY = "duration_bonus" # Key in resource data

var freeze_timer: Timer
var is_frozen: bool = false

func _on_apply() -> bool:
	if not target_enemy is EnemyBase: return false
	if not is_instance_valid(freeze_timer):
		freeze_timer = Timer.new()
		freeze_timer.one_shot = true
		add_child(freeze_timer) # Child of this node
		freeze_timer.timeout.connect(_on_freeze_timer_timeout)
	set_physics_process(true) # Need to check distance
	return true

func _on_level_change(_old_level: int):
	# Level change affects future freeze durations, no immediate action needed
	pass

func _physics_process(_delta):
	# Continuously check proximity if the effect is active and target is valid
	if not is_frozen and is_instance_valid(target_enemy) and is_instance_valid(target_enemy.player):
		if target_enemy.global_position.distance_to(target_enemy.player.global_position) < PLAYER_PROXIMITY_THRESHOLD:
			_apply_freeze()

func _apply_freeze():
	is_frozen = true
	target_enemy.movement_inhibitors[effect_data.effect_id] = true # Inhibit movement

	# Calculate freeze duration based on current level from resource data
	var base_duration = effect_data.get_value_for_level(level, FREEZE_DURATION_BASE_KEY, 1.0)
	var bonus = effect_data.get_value_for_level(level, FREEZE_DURATION_BONUS_KEY, 0.0)
	var total_freeze_duration = base_duration + (bonus * (level - 1))

	freeze_timer.start(total_freeze_duration) # Start freeze timer

func _on_freeze_timer_timeout():
	is_frozen = false
	# Remove freeze inhibitor if target still valid
	if is_instance_valid(target_enemy) and target_enemy.movement_inhibitors.has(effect_data.effect_id):
		target_enemy.movement_inhibitors.erase(effect_data.effect_id)

func _on_remove():
	# Stop timer if running
	if is_instance_valid(freeze_timer): freeze_timer.stop()
	# Ensure inhibitor is removed if effect removed mid-freeze
	if is_instance_valid(target_enemy) and is_frozen and target_enemy.movement_inhibitors.has(effect_data.effect_id):
		target_enemy.movement_inhibitors.erase(effect_data.effect_id)
	set_physics_process(false)
