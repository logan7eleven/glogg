class_name EnemyBase
extends CharacterBody2D

signal damaged(slot_index: int, damage_amount: float) 
signal killed(slot_index: int)
signal orientation_requested

var health: float 
var speed_multipliers: Dictionary = {}
var damage_taken_multipliers: Dictionary = {}
var orientation_modifiers: Dictionary = {}
var collision_damage_effects: Dictionary = {} 
var movement_inhibitors: Dictionary = {}
var orientation_inhibitors: Dictionary = {}
var orientation_target: Variant = null
var apply_collision_damage: bool = false 
var collision_damage_amount: float = 0.0 
var enemy_id: int = -1
var player: Node2D 
var can_move: bool = false 
var hitstop_timer: Timer
var is_hitstop: bool = false

const HIT_FREEZE_DURATION = 0.04
const HIT_FREEZE_INHIBITOR_KEY = "global_hit_freeze" 

func _get_log_id_str() -> String:
	if "crawler_id" in self:
		var specific_id = get("crawler_id")
		if specific_id != -1: 
			return "Crawler " + str(specific_id)
	#elif "scooter_id" in self: # Example for another type
		#var specific_id = get("scooter_id")
		#if specific_id != -1:
			#return "Scooter " + str(specific_id)
	if "enemy_id" in self and enemy_id != -1:
		return "Enemy " + str(enemy_id)
	else:
		print("No Enemy ID found.")
		return name

func _ready():
	add_to_group("enemies_physics")
	_setup_hitbox()
	call_deferred("_find_player")
	hitstop_timer = Timer.new()
	hitstop_timer.one_shot = true
	hitstop_timer.wait_time = HIT_FREEZE_DURATION
	hitstop_timer.timeout.connect(_on_hit_freeze_timer_timeout)
	add_child(hitstop_timer)

func _find_player():
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("players")

func _setup_hitbox():
	var hitbox = get_node("HitBox")
	hitbox.add_to_group("enemies")
	hitbox.monitorable = true
	hitbox.connect("area_entered", Callable(self, "_on_hitbox_area_entered"))

func _physics_process(delta):
	if not can_move:
		return
	if is_hitstop:
		return
	# --- Orientation ---
	var final_can_orient = orientation_inhibitors.is_empty()
	if final_can_orient:
		orientation_target = null 
		emit_signal("orientation_requested")
		if orientation_target == null and is_instance_valid(player):
			orientation_target = player
		if orientation_target != null:
			_perform_orientation(delta) 
	# --- Movement ---
	var final_can_move = movement_inhibitors.is_empty()
	if final_can_move:
		var final_speed_multiplier = 1.0
		for effect_id in speed_multipliers:
			final_speed_multiplier *= speed_multipliers[effect_id]
		_perform_movement(delta, final_speed_multiplier)

func _perform_orientation(_delta: float): pass # Implemented by subclasses
func _perform_movement(_delta: float, _speed_multiplier: float): pass # Implemented by subclasses

func take_damage(amount: float, slot_index: int, source_description: String = ""):
	if health <= 0: 
		return
	var final_damage_taken_multiplier = 1.0
	for effect_id in damage_taken_multipliers:
		final_damage_taken_multiplier *= damage_taken_multipliers[effect_id]
	var final_damage = amount * final_damage_taken_multiplier
	var health_before = health
	health -= final_damage
	health = max(health, 0.0)
	var id_str = _get_log_id_str()
	var source_info: String
	if slot_index >= 0:
		source_info = "Slot %d" % slot_index
	elif not source_description.is_empty():
		source_info = source_description 
	else:
		source_info = "Unknown Effect" 
	print("%s took %.2f damage from %s. Health: %.2f -> %.2f" % [id_str, final_damage, source_info, health_before, health])
	emit_signal("damaged", slot_index, final_damage) 
	if health <= 0:
		print("%s died (killed by %s)." % [id_str, source_info])
		emit_signal("killed", slot_index)
		queue_free()
		GlobalState.increment_enemies_destroyed()

func apply_status_effect(effect_data_resource: StatusEffectData, _level_from_hit: int, source_slot_index: int):
	if not is_hitstop:
		_apply_hit_freeze()
	var effect_id = effect_data_resource.effect_id
	var existing_effect_node = get_node(effect_id) as ActiveStatusEffect
	if existing_effect_node:
		existing_effect_node.increment_and_update_level(source_slot_index)
	else:
		var EffectNodeScript = load(effect_data_resource.active_effect_script_path)
		var effect_node = EffectNodeScript.new() as ActiveStatusEffect
		add_child(effect_node)
		var id_str = _get_log_id_str()
		effect_node.initialize(effect_data_resource, self, 1, source_slot_index)
		print("%s received new effect '%s' (Lvl 1) from Slot %d." % [id_str, effect_id, source_slot_index]) 
	emit_signal("damaged", source_slot_index, 0.0) 

func handle_physics_collision(collision_info: KinematicCollision2D):
	var collider = collision_info.get_collider()
	if collider is EnemyBase and collider != self and collider.apply_collision_damage:
		var source_str = "%s spikes" % collider._get_log_id_str()
		take_damage(collider.collision_damage_amount, -1, source_str)

func _apply_hit_freeze():
	is_hitstop = true
	movement_inhibitors[HIT_FREEZE_INHIBITOR_KEY] = true
	orientation_inhibitors[HIT_FREEZE_INHIBITOR_KEY] = true
	hitstop_timer.start()

func _on_hit_freeze_timer_timeout():
	is_hitstop = false
	movement_inhibitors.erase(HIT_FREEZE_INHIBITOR_KEY)
	orientation_inhibitors.erase(HIT_FREEZE_INHIBITOR_KEY)

func _on_body_entered_base(body: Node): 
	if apply_collision_damage and body is EnemyBase and body != self:
		var source_str = "%s spikes" % self._get_log_id_str()
		body.take_damage(collision_damage_amount, -1, source_str)
	if body is EnemyBase and body != self and body.apply_collision_damage:
		var source_str = "%s spikes" % body._get_log_id_str()
		take_damage(body.collision_damage_amount, -1, source_str)

func update_collision_damage():
	var damage = 0.0
	var spikes_active = false
	for node in get_children():
		if node is ActiveSpikeEffect:
			spikes_active = true
			damage = node.calculated_spike_damage
	apply_collision_damage = spikes_active
	collision_damage_amount = damage

func check_collision_damage_state(): 
	call_deferred("update_collision_damage")

func _on_hitbox_area_entered(area: Area2D): 
	if area.is_in_group("players"): 
		_on_collision_with_player()

func _on_collision_with_player():
	var id_str = _get_log_id_str()
	print("Enemy %s Collided with Player - GAME OVER" % id_str)
	var level = get_parent()
	level.game_over("GAME OVER - Player Hit!")
