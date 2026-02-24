class_name EnemyBase
extends CharacterBody2D

signal damaged(slot_index: int, damage_amount: float) 
signal bonus_damage_dealt(slot_index: int, damage_amount: float)
# --- NEW SIGNAL ---
signal procedural_damage_dealt(slot_index: int, damage_amount: float)
signal killed(slot_index: int, credit: float)
signal orientation_requested
signal just_hit_by_bullet(bullet_instance: Area2D)

var health: float 
var speed_multipliers: Dictionary = {}
var damage_taken_multipliers: Dictionary = {}
var orientation_modifiers: Dictionary = {}
var movement_inhibitors: Dictionary = {}
var orientation_inhibitors: Dictionary = {}
var collision_damage_providers: Dictionary = {} 
var orientation_target: Variant = null
var enemy_id: int = -1
var player: Node2D 
var can_move: bool = false 
var hitstop_timer: Timer
var is_hitstop: bool = false
var _active_timed_inhibitors: Dictionary = {}
var _dot_source_cooldowns: Dictionary = {}
var physics_interaction_cooldown_timer: float = 0.0
var visual_manager

const HIT_FREEZE_DURATION = 0.04
const HIT_FREEZE_INHIBITOR_KEY = "global_hit_freeze" 

func _get_log_id_str() -> String:
	if "crawler_id" in self:
		var specific_id = get("crawler_id")
		if specific_id != -1: 
			return "Crawler " + str(specific_id)
	if "enemy_id" in self and enemy_id != -1:
		return "Enemy " + str(enemy_id)
	else:
		return name

func _ready():
	add_to_group("enemies_physics")
	_setup_hitbox()
	visual_manager = EffectVisualManager.new()
	visual_manager.name = "EffectVisualManager"
	add_child(visual_manager)
	call_deferred("initialize_visual_manager")
	call_deferred("_find_player")
	hitstop_timer = Timer.new()
	hitstop_timer.one_shot = true
	hitstop_timer.wait_time = HIT_FREEZE_DURATION
	hitstop_timer.timeout.connect(_on_hit_freeze_timer_timeout)
	add_child(hitstop_timer)

func initialize_visual_manager():
	var sprite = get_node_or_null("Sprite2D")
	if is_instance_valid(sprite):
		visual_manager.initialize(sprite)

func _find_player():
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("players")

func _setup_hitbox():
	var hitbox = get_node("HitBox")
	hitbox.add_to_group("enemies")
	hitbox.monitorable = true
	hitbox.connect("area_entered", Callable(self, "_on_hitbox_area_entered"))

func _physics_process(delta):
	if physics_interaction_cooldown_timer > 0:
		physics_interaction_cooldown_timer -= delta
	if not can_move or is_hitstop:
		return
	if orientation_inhibitors.is_empty():
		orientation_target = null 
		emit_signal("orientation_requested")
		if orientation_target == null and is_instance_valid(player):
			orientation_target = player
		if orientation_target != null:
			_perform_orientation(delta) 
	if movement_inhibitors.is_empty():
		var final_speed_multiplier = 1.0
		for effect_id in speed_multipliers:
			final_speed_multiplier *= speed_multipliers[effect_id]
		_perform_movement(delta, final_speed_multiplier)

func is_on_physics_cooldown() -> bool:
	return physics_interaction_cooldown_timer > 0.0

func _perform_orientation(_delta: float): pass
func _perform_movement(_delta: float, _speed_multiplier: float): pass

func process_bullet_hit(bullet: Area2D, slot_idx: int, effect_res: StatusEffectData, _effect_lvl_from_slot: int):
	trigger_bullet_hit_stun()
	if is_instance_valid(effect_res):
		apply_status_effect(effect_res, 1, slot_idx)
	else:
		# A bullet hit with no effect is a direct hit. is_procedural = false.
		take_damage(GlobalState.BASE_DAMAGE, slot_idx, "", false)
	emit_signal("just_hit_by_bullet", bullet)

# --- REWRITTEN 'take_damage' with new 'is_procedural' flag ---
func take_damage(base_damage: float, source_slot_index: int, source_description: String = "", is_procedural: bool = false):
	if health <= 0 or base_damage <= 0: return

	visual_manager.trigger_flash()
	var health_before = health
	var id_str = _get_log_id_str()

	var total_damage = base_damage
	var bonus_damage_contributors: Dictionary = {}

	for effect_id in damage_taken_multipliers:
		var effect_info = damage_taken_multipliers[effect_id]
		var multiplier = effect_info.get("multiplier", 1.0)
		var effect_slot_index = effect_info.get("slot_index", -1)
		
		if multiplier > 1.0:
			var bonus_damage = base_damage * (multiplier - 1.0)
			total_damage += bonus_damage
			bonus_damage_contributors[effect_slot_index] = bonus_damage_contributors.get(effect_slot_index, 0.0) + bonus_damage

	var is_lethal = (health_before > 0 and health - total_damage <= 0)

	if is_lethal:
		var lethal_contributors: Dictionary = {}
		lethal_contributors[source_slot_index] = true
		for slot_index in bonus_damage_contributors:
			lethal_contributors[slot_index] = true
		var kill_credit = 1.0 / float(lethal_contributors.size())
		for slot_index in lethal_contributors:
			emit_signal("killed", slot_index, kill_credit)
	else:
		# --- NEW LOGIC TO SEPARATE HITS FROM OTHER DAMAGE ---
		if is_procedural:
			# For Slime, Shock, Spikes etc. No hit is recorded.
			emit_signal("procedural_damage_dealt", source_slot_index, base_damage)
		else:
			# For direct bullet hits. A hit is recorded.
			emit_signal("damaged", source_slot_index, base_damage)
		
		for slot_index in bonus_damage_contributors:
			emit_signal("bonus_damage_dealt", slot_index, bonus_damage_contributors[slot_index])
			
	health -= total_damage
	health = max(health, 0.0)

	var source_info = source_description
	if source_info.is_empty():
		source_info = "Slot %d" % (source_slot_index + 1) if source_slot_index >= 0 else "Unknown Effect"
	print("%s took %.2f total damage from %s (base %.2f). Health: %.2f -> %.2f" % [id_str, total_damage, source_info, base_damage, health_before, health])

	if is_lethal:
		print("%s died (killed by %s)." % [id_str, source_info])
		queue_free()
		GlobalState.increment_enemies_destroyed()


func apply_status_effect(effect_data_resource: StatusEffectData, stacks_to_apply: int, source_slot_index: int, source_description_for_log: String = ""):
	if not is_hitstop:
		_apply_hit_freeze()
	var effect_id = effect_data_resource.effect_id
	var existing_effect_node: ActiveStatusEffect = get_node_or_null(effect_id)
	var actual_stacks_to_apply = max(1, stacks_to_apply)
	var id_str = _get_log_id_str()
	var source_str = ""
	if not source_description_for_log.is_empty():
		source_str = source_description_for_log
	elif source_slot_index >= 0:
		source_str = "Slot %d" % (source_slot_index + 1)
	if is_instance_valid(existing_effect_node):
		var old_level = existing_effect_node.level
		var max_level = GlobalState.unlocked_slots
		var stacks_to_actually_add = min(actual_stacks_to_apply, max_level - old_level)
		if stacks_to_actually_add <= 0: return
		for _i in range(stacks_to_actually_add):
			existing_effect_node.increment_and_update_level(source_slot_index, "")
		if not source_str.is_empty():
			var new_level = old_level + stacks_to_actually_add
			print("%s increased %s (Lvl %d to Lvl %d) from %s." % [id_str, effect_data_resource.display_name, old_level, new_level, source_str])
	else:
		var script_path = effect_data_resource.active_effect_script_path
		var EffectNodeScript = load(script_path) 
		var effect_node = EffectNodeScript.new() as ActiveStatusEffect 
		add_child(effect_node)
		var initial_level = min(actual_stacks_to_apply, GlobalState.unlocked_slots)
		effect_node.initialize(effect_data_resource, self, initial_level, source_slot_index)
		if not source_str.is_empty():
			print("%s received new effect '%s' (Lvl %d) from %s." % [id_str, effect_data_resource.display_name, initial_level, source_str])
	
	# REMOVED: The zero-damage 'hit' for applying effects is gone.
	# The initial bullet impact already counted as the hit.

func handle_physics_collision(collision_info: KinematicCollision2D):
	var other_enemy = collision_info.get_collider()
	if not (other_enemy is EnemyBase and other_enemy != self): return
	if self.is_on_physics_cooldown() or other_enemy.is_on_physics_cooldown(): return
	self.physics_interaction_cooldown_timer = 0.1
	other_enemy.physics_interaction_cooldown_timer = 0.1
	var leader: EnemyBase = self if self.get_instance_id() > other_enemy.get_instance_id() else other_enemy
	var follower: EnemyBase = other_enemy if self.get_instance_id() > other_enemy.get_instance_id() else self

	if not leader.collision_damage_providers.is_empty():
		for effect_id in leader.collision_damage_providers:
			var damage_info = leader.collision_damage_providers[effect_id]
			var damage_to_deal = damage_info.get("damage", 0.0)
			if damage_to_deal > 0:
				var effect_level = damage_info.get("level", 1)
				var effect_name = damage_info.get("name", effect_id.capitalize())
				var effect_slot_index = damage_info.get("slot_index", -1)
				var source_str = "%s %s (Lvl %d)" % [leader._get_log_id_str(), effect_name, effect_level]
				# Spikes damage is procedural, not a direct hit.
				follower.take_damage(damage_to_deal, effect_slot_index, source_str, true)

	var contagious_effect: ActiveContagiousEffect = leader.get_node_or_null("contagious")
	if is_instance_valid(contagious_effect):
		contagious_effect.execute_contagious_spread(follower)

# ... (rest of EnemyBase.gd is unchanged) ...
func trigger_bullet_hit_stun():
	if not is_hitstop:
		_apply_hit_freeze()

func _apply_hit_freeze():
	is_hitstop = true
	movement_inhibitors[HIT_FREEZE_INHIBITOR_KEY] = true
	orientation_inhibitors[HIT_FREEZE_INHIBITOR_KEY] = true
	hitstop_timer.start()

func _on_hit_freeze_timer_timeout():
	is_hitstop = false
	movement_inhibitors.erase(HIT_FREEZE_INHIBITOR_KEY)
	orientation_inhibitors.erase(HIT_FREEZE_INHIBITOR_KEY)

func apply_timed_stun(duration: float, stun_key: String):
	if duration <= 0: return
	if _active_timed_inhibitors.has(stun_key):
		var existing_timer = _active_timed_inhibitors[stun_key]
		if is_instance_valid(existing_timer):
			existing_timer.wait_time = duration
			existing_timer.start()
			return
	movement_inhibitors[stun_key] = true
	orientation_inhibitors[stun_key] = true
	var stun_timer = Timer.new()
	stun_timer.name = "StunTimer_" + stun_key
	stun_timer.wait_time = duration
	stun_timer.one_shot = true
	stun_timer.timeout.connect(Callable(self, "_on_timed_stun_finished").bind(stun_key))
	add_child(stun_timer)
	stun_timer.start()
	_active_timed_inhibitors[stun_key] = stun_timer

func _on_timed_stun_finished(stun_key_to_remove: String):
	if movement_inhibitors.has(stun_key_to_remove):
		movement_inhibitors.erase(stun_key_to_remove)
	if orientation_inhibitors.has(stun_key_to_remove):
		orientation_inhibitors.erase(stun_key_to_remove)
	if _active_timed_inhibitors.has(stun_key_to_remove):
		var timer_node = _active_timed_inhibitors[stun_key_to_remove]
		if is_instance_valid(timer_node):
			timer_node.queue_free()
		_active_timed_inhibitors.erase(stun_key_to_remove)
	
func _on_hitbox_area_entered(area: Area2D): 
	if area.is_in_group("players"): 
		_on_collision_with_player()

func _on_collision_with_player():
	var id_str = _get_log_id_str()
	print("Enemy %s Collided with Player - GAME OVER" % id_str)
	var level = get_parent()
	level.game_over("GAME OVER - Player Hit!")
	
func can_take_dot_damage_from(source_id: int, cooldown: float) -> bool:
	var last_hit_time = _dot_source_cooldowns.get(source_id, 0.0)
	var current_time = Time.get_ticks_msec() / 1000.0
	return current_time >= last_hit_time + cooldown

func record_dot_damage_from(source_id: int):
	_dot_source_cooldowns[source_id] = Time.get_ticks_msec() / 1000.0
