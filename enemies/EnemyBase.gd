# File: res://EnemyBase.gd
class_name EnemyBase
extends CharacterBody2D

# --- V2 SIGNALS ---
# We now pass the BlockData directly so the Enemy can tell it to record stats
signal damaged(source_block: BlockData, damage_amount: float) 
signal bonus_damage_dealt(source_block: BlockData, damage_amount: float)
signal procedural_damage_dealt(source_block: BlockData, damage_amount: float)
signal killed(source_block: BlockData, credit: float)

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

# Optional visual manager (Make sure your EffectVisualManager is updated too!)
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
	
	# Assuming EffectVisualManager exists and works with the old structure
	if ResourceLoader.exists("res://EffectVisualManager.gd"):
		var VisualManagerClass = load("res://EffectVisualManager.gd")
		visual_manager = VisualManagerClass.new()
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
	if is_instance_valid(sprite) and is_instance_valid(visual_manager):
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
				
				# V2 Update: Look for source_block instead of slot_index
				var effect_source_block = damage_info.get("source_block", null)
				var source_str = "%s %s (Lvl %d)" % [leader._get_log_id_str(), effect_name, effect_level]
				
				follower.take_damage(damage_to_deal, effect_source_block, source_str, true)

	# Keep your contagious spread logic
	if ResourceLoader.exists("res://ActiveContagiousEffect.gd"): # Safe check
		var contagious_effect = leader.get_node_or_null("contagious")
		if is_instance_valid(contagious_effect) and contagious_effect.has_method("execute_contagious_spread"):
			contagious_effect.execute_contagious_spread(follower)

# --- V2 HIT RESOLUTION ---
# This is called directly from the bullet when it hits an enemy.
# The `effect_res` array contains all EffectData resources attached to the BlockData.
func process_bullet_hit(bullet: Area2D, source_block: BlockData, effects: Array):
	trigger_bullet_hit_stun()
	emit_signal("just_hit_by_bullet", bullet)
	
	# Always take base bullet damage first
	take_damage(1.0, source_block, "Direct Hit", false)
	
	# Apply all status effects stacked on the block
	for effect_wrapper in effects:
		var actual_effect = effect_wrapper.status_effect
		if is_instance_valid(actual_effect):
			apply_status_effect(actual_effect, 1, source_block)

func take_damage(base_damage: float, source_block: BlockData, source_description: String = "", is_procedural: bool = false):
	if health <= 0 or base_damage <= 0: return

	if is_instance_valid(visual_manager) and visual_manager.has_method("trigger_flash"):
		visual_manager.trigger_flash()
		
	var health_before = health
	var total_damage = base_damage
	var bonus_damage_contributors: Dictionary = {}

	# Calculate bonus damage from status effects already on the enemy
	for effect_id in damage_taken_multipliers:
		var effect_info = damage_taken_multipliers[effect_id]
		var multiplier = effect_info.get("multiplier", 1.0)
		var effect_block = effect_info.get("source_block", null)
		
		if multiplier > 1.0:
			var bonus_damage = base_damage * (multiplier - 1.0)
			total_damage += bonus_damage
			if effect_block != null:
				bonus_damage_contributors[effect_block] = bonus_damage_contributors.get(effect_block, 0.0) + bonus_damage

	var is_lethal = (health_before > 0 and health - total_damage <= 0)

	if is_lethal:
		var lethal_contributors: Dictionary = {}
		if source_block != null: lethal_contributors[source_block] = true
		
		for block in bonus_damage_contributors:
			lethal_contributors[block] = true
			
		var kill_credit = 1.0 / float(max(1, lethal_contributors.size()))
		
		# Record kill credit directly to the block(s)
		for block in lethal_contributors:
			if is_instance_valid(block) and block.has_method("record_kill"):
				block.record_kill(kill_credit)
				
		# Emit signal for level progression
		emit_signal("killed", source_block, kill_credit)
	else:
		if is_procedural:
			emit_signal("procedural_damage_dealt", source_block, base_damage)
		else:
			emit_signal("damaged", source_block, base_damage)
		
		for block in bonus_damage_contributors:
			emit_signal("bonus_damage_dealt", block, bonus_damage_contributors[block])
			if is_instance_valid(block) and block.has_method("record_damage"):
				block.record_damage(bonus_damage_contributors[block])
			
	health -= total_damage
	health = max(health, 0.0)

	if is_lethal:
		GameManager.record_enemy_death()
		queue_free()

func apply_status_effect(effect_data_resource: Resource, stacks_to_apply: int, source_block: BlockData):
	if not is_hitstop:
		_apply_hit_freeze()
		
	var effect_id = effect_data_resource.effect_id
	var existing_effect_node = get_node_or_null(effect_id)
	var actual_stacks_to_apply = max(1, stacks_to_apply)
	
	if is_instance_valid(existing_effect_node):
		# V2 System: Effects no longer have a "level limit" based on unlocked slots. 
		# You can stack them infinitely based on your Sequencer layout.
		for _i in range(actual_stacks_to_apply):
			existing_effect_node.increment_and_update_level(source_block, "")
	else:
		var script_path = effect_data_resource.active_effect_script_path
		if not script_path.is_empty() and ResourceLoader.exists(script_path):
			var EffectNodeScript = load(script_path) 
			var effect_node = EffectNodeScript.new() 
			add_child(effect_node)
			effect_node.initialize(effect_data_resource, self, actual_stacks_to_apply, source_block)

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
	var level = get_parent()
	if level.has_method("game_over"):
		level.game_over("GAME OVER - Player Hit!")
	
func can_take_dot_damage_from(source_id: int, cooldown: float) -> bool:
	var last_hit_time = _dot_source_cooldowns.get(source_id, 0.0)
	var current_time = Time.get_ticks_msec() / 1000.0
	return current_time >= last_hit_time + cooldown

func record_dot_damage_from(source_id: int):
	_dot_source_cooldowns[source_id] = Time.get_ticks_msec() / 1000.0
