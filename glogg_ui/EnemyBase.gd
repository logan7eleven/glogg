# EnemyBase.gd (Corrected - Includes handle_physics_collision)
class_name EnemyBase
extends CharacterBody2D

# --- Signals ---
signal damaged(slot_index: int, damage_amount: float) # Emit float damage
signal killed(slot_index: int)
signal orientation_requested

# --- Internal State (No Base Stat Exports Here) ---
var health: float # Initialized by inheriting script's _ready AFTER super()._ready()
var speed_multipliers: Dictionary = {}
var damage_taken_multipliers: Dictionary = {}
var orientation_modifiers: Dictionary = {}
var collision_damage_effects: Dictionary = {} # Stores data from ActiveSpikeEffect
var movement_inhibitors: Dictionary = {}
var orientation_inhibitors: Dictionary = {}
var orientation_target: Variant = null
var apply_collision_damage: bool = false # Aggregate flag set by update_collision_damage
var collision_damage_amount: float = 0.0 # Aggregate damage set by update_collision_damage

var enemy_id: int = -1 # Generic ID set by Level (if needed by base logic)
var player: Node2D # Set in _find_player

# --- Constants ---
const SPIKE_LAYER = 7 # Assign in Project Settings -> Layer Names -> 2D Physics

# --- Engine Methods ---
func _ready():
	# Base setup needed for all enemies
	add_to_group("enemies_physics")
	_setup_hitbox()
	call_deferred("_find_player")

func _find_player():
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("players")
	# No error needed here, child scripts should handle player validity

func _setup_hitbox():
	var hitbox = get_node_or_null("HitBox")
	if hitbox is Area2D:
		if not hitbox.is_in_group("enemies"): hitbox.add_to_group("enemies")
		if not hitbox.monitorable: hitbox.monitorable = true
		if not hitbox.is_connected("area_entered", Callable(self, "_on_hitbox_area_entered")):
			hitbox.connect("area_entered", Callable(self, "_on_hitbox_area_entered"))

func _physics_process(delta):
	# --- Orientation ---
	var final_can_orient = orientation_inhibitors.is_empty()
	if final_can_orient:
		orientation_target = null
		emit_signal("orientation_requested")
		if orientation_target == null and player: orientation_target = player
		_perform_orientation(delta) # Call subclass implementation

	# --- Movement ---
	var final_can_move = movement_inhibitors.is_empty()
	if final_can_move:
		var final_speed_multiplier = 1.0
		for effect_id in speed_multipliers:
			final_speed_multiplier *= speed_multipliers[effect_id]
		_perform_movement(delta, final_speed_multiplier)

# --- Virtual Methods for Subclasses ---
func _perform_orientation(_delta: float): pass # Implemented by subclasses
func _perform_movement(_delta: float, _speed_multiplier: float): pass # Implemented by subclasses

# --- Damage Taking ---
func take_damage(amount: float, slot_index: int):
	if health <= 0: return
	var final_damage_taken_multiplier = 1.0
	for effect_id in damage_taken_multipliers: # Apply frail etc.
		final_damage_taken_multiplier *= damage_taken_multipliers[effect_id]
	var final_damage = amount * final_damage_taken_multiplier
	var health_before = health
	health -= final_damage
	health = max(health, 0.0)

	# Use specific ID if available (set by child), otherwise generic name
	var id_str = str(get("crawler_id"))
	var source_info = "Slot %d" % slot_index if slot_index >= 0 else "Effect"
	print("Enemy %s took %.2f damage from %s. Health: %.2f -> %.2f" % [id_str, final_damage, source_info, health_before, health])
	emit_signal("damaged", slot_index, final_damage) # Emit float damage

	if health <= 0:
		print("Enemy %s died." % id_str)
		emit_signal("killed", slot_index)
		queue_free()
		GlobalState.increment_enemies_destroyed()

# --- Status Effect Application ---
func apply_status_effect(effect_data_resource: StatusEffectData, _level_from_hit: int, source_slot_index: int):
	if not effect_data_resource is StatusEffectData: return
	var effect_id = effect_data_resource.effect_id
	var script_path = effect_data_resource.active_effect_script_path
	if script_path.is_empty() or not ResourceLoader.exists(script_path): return

	var existing_effect_node = get_node_or_null(effect_id) as ActiveStatusEffect

	if existing_effect_node:
		# Effect already active: Increment its level
		existing_effect_node.increment_and_update_level()
	else:
		# Effect not active: Create and add it at level 1
		var EffectNodeScript = load(effect_data_resource.active_effect_script_path)
		if EffectNodeScript == null: return
		var effect_node = EffectNodeScript.new() as ActiveStatusEffect
		if effect_node:
			add_child(effect_node)
			# Initialize at level 1, pass resource and source slot
			effect_node.initialize(effect_data_resource, self, 1, source_slot_index)
			
	# --- Emit damaged signal AFTER applying/stacking effect to record the HIT ---
	emit_signal("damaged", source_slot_index, 0.0) # Pass 0.0 damage

func handle_physics_collision(collision_info: KinematicCollision2D):
	if not collision_info: return
	var collider = collision_info.get_collider()

	# Check if WE hit something that has spikes active
	if collider is EnemyBase and collider != self and collider.apply_collision_damage:
		if collider.collision_damage_amount > 0:
			take_damage(collider.collision_damage_amount, -1) # Take damage from THEIR spikes


# --- Called by ActiveStatusEffect node when it is removed ---
func effect_node_removed(effect_id: String):
	if effect_id == "spikes": check_collision_damage_state()

# --- Collision Damage Logic ---
# This is the generic handler called by the physics signal
func _on_body_entered_base(body: Node): # Renamed to avoid conflicts
	# Check if WE have spikes active and hit another EnemyBase
	if apply_collision_damage and collision_damage_amount > 0 and body is EnemyBase and body != self:
		# print("[EnemyBase %s] My Spikes hit %s! Dealing %.2f damage." % [name, body.name, collision_damage_amount])
		body.take_damage(collision_damage_amount, -1) # Apply OUR damage to THEM

	# Check if WE hit something that has spikes active
	if body is EnemyBase and body != self and body.apply_collision_damage:
		if body.collision_damage_amount > 0:
			# print("[EnemyBase %s] Hit Spikes on %s! Taking %.2f damage." % [name, body.name, body.collision_damage_amount])
			take_damage(body.collision_damage_amount, -1) # Take damage from THEIR spikes

# --- Update aggregate collision damage state (called by SpikeEffect) ---
func update_collision_damage():
	var max_damage = 0.0; var spikes_active = false
	for node in get_children():
		if node is ActiveSpikeEffect:
			spikes_active = true
			max_damage = max(max_damage, node.calculated_spike_damage)
	apply_collision_damage = spikes_active
	collision_damage_amount = max_damage
	# Update physics layer based on state - KEEPING this layer logic for now
	set_collision_layer_value(SPIKE_LAYER, spikes_active)
	set_collision_mask_value(SPIKE_LAYER, spikes_active) # Detect other spikes

func check_collision_damage_state(): call_deferred("update_collision_damage")

# --- Hitbox/Player Collision ---
func _on_hitbox_area_entered(area: Area2D): # Called by HitBox Area2D signal
	if area.is_in_group("players"): _on_collision_with_player()

func _on_collision_with_player():
	var id_str = str(get("crawler_id"))
	print("Enemy %s Collided with Player - GAME OVER" % id_str)
	var level = get_parent()
	if level and level.has_method("game_over"):
		level.game_over("GAME OVER - Player Hit!")
	else:
		var player_node = get_tree().get_first_node_in_group("players")
		if player_node: player_node.queue_free()
