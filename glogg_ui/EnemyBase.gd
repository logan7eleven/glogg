# EnemyBase.gd (Corrected - Includes handle_physics_collision and can_move)
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

var can_move: bool = false # Flag to control movement start

# --- Constants ---
const SPIKE_LAYER = 7 # Assign in Project Settings -> Layer Names -> 2D Physics

func _get_log_id_str() -> String:
	# Check for specific known ID variables using 'in' and get()
	if "crawler_id" in self:
		var specific_id = get("crawler_id") # Use get() to access child variable
		if specific_id != -1: # Check if it was assigned
			return "Crawler " + str(specific_id)
	elif "scooter_id" in self: # Example for another type
		var specific_id = get("scooter_id")
		if specific_id != -1:
			return "Scooter " + str(specific_id)

	# Fallback to generic enemy_id if specific ID not found or not set
	if "enemy_id" in self and enemy_id != -1:
		return "Enemy " + str(enemy_id)
	else: # Fallback to node name if no IDs are set
		print("No Enemy ID found.")
		return name

# --- Engine Methods ---
func _ready():
	# Base setup needed for all enemies
	add_to_group("enemies_physics") # Use this group to enable movement later
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
	#Check if movement is allowed yet
	if not can_move:
		return

	# --- Orientation ---
	var final_can_orient = orientation_inhibitors.is_empty()
	if final_can_orient:
		orientation_target = null # Reset target before requesting
		emit_signal("orientation_requested") # Allow effects (like confusion) to potentially set target
		# If no effect set a target, default to player
		if orientation_target == null and is_instance_valid(player):
			orientation_target = player
		# Only call _perform_orientation if we have a valid target (Node or Vector2)
		if orientation_target != null:
			_perform_orientation(delta) # Call subclass implementation
	# else: Orientation inhibited (e.g., by confusion)

	# --- Movement ---
	var final_can_move = movement_inhibitors.is_empty()
	if final_can_move:
		var final_speed_multiplier = 1.0
		for effect_id in speed_multipliers:
			final_speed_multiplier *= speed_multipliers[effect_id]
		_perform_movement(delta, final_speed_multiplier) # Call subclass implementation
	# else: Movement inhibited (e.g., by confusion or fear)


# --- Virtual Methods for Subclasses ---
func _perform_orientation(_delta: float): pass # Implemented by subclasses
func _perform_movement(_delta: float, _speed_multiplier: float): pass # Implemented by subclasses

# --- Damage Taking ---
func take_damage(amount: float, slot_index: int, source_description: String = ""):
	if health <= 0: return
	var final_damage_taken_multiplier = 1.0
	for effect_id in damage_taken_multipliers: # Apply frail etc.
		final_damage_taken_multiplier *= damage_taken_multipliers[effect_id]
	var final_damage = amount * final_damage_taken_multiplier
	var health_before = health
	health -= final_damage
	health = max(health, 0.0)

	# Use specific ID if available (set by child), otherwise generic name
	var id_str = _get_log_id_str()
	var source_info: String
	if slot_index >= 0:
		source_info = "Slot %d" % slot_index
	elif not source_description.is_empty():
		source_info = source_description # Use the provided description
	else:
		source_info = "Unknown Effect" # Fallback if slot is -1 and no description given
	print("%s took %.2f damage from %s. Health: %.2f -> %.2f" % [id_str, final_damage, source_info, health_before, health])
	emit_signal("damaged", slot_index, final_damage) # Emit float damage

	if health <= 0:
		print("%s died (killed by %s)." % [id_str, source_info])
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
		existing_effect_node.increment_and_update_level(source_slot_index)
	else:
		# Effect not active: Create and add it at level 1
		var EffectNodeScript = load(effect_data_resource.active_effect_script_path)
		if EffectNodeScript == null: return
		var effect_node = EffectNodeScript.new() as ActiveStatusEffect
		if effect_node:
			add_child(effect_node)
			var id_str = _get_log_id_str()
			# Initialize at level 1, pass resource and source slot
			effect_node.initialize(effect_data_resource, self, 1, source_slot_index)
			print("%s received new effect '%s' (Lvl 1) from Slot %d." % [id_str, effect_id, source_slot_index]) # Use id_str

	# --- Emit damaged signal AFTER applying/stacking effect to record the HIT ---
	emit_signal("damaged", source_slot_index, 0.0) # Pass 0.0 damage

func handle_physics_collision(collision_info: KinematicCollision2D):
	if not collision_info: return
	var collider = collision_info.get_collider()

	# Check if WE hit something that has spikes active
	if collider is EnemyBase and collider != self and collider.apply_collision_damage:
		if collider.collision_damage_amount > 0:
			var source_str = "%s spikes" % collider._get_log_id_str()
			take_damage(collider.collision_damage_amount, -1, source_str)


# --- Called by ActiveStatusEffect node when it is removed ---
func effect_node_removed(effect_id: String):
	# Example: If spikes effect is removed, recheck collision state
	if effect_id == "spikes": check_collision_damage_state()
	# Add other checks if needed for specific effect cleanup coordination

# --- Collision Damage Logic ---
# This is the generic handler called by the physics signal (if using body_entered)
# Note: move_and_collide is often preferred for CharacterBody2D
func _on_body_entered_base(body: Node): # Renamed to avoid conflicts
	# Check if WE have spikes active and hit another EnemyBase
	if apply_collision_damage and collision_damage_amount > 0 and body is EnemyBase and body != self:
		var source_str = "%s spikes" % self._get_log_id_str()
		body.take_damage(collision_damage_amount, -1, source_str)

	# Check if WE hit something that has spikes active
	if body is EnemyBase and body != self and body.apply_collision_damage:
		if body.collision_damage_amount > 0:
			var source_str = "%s spikes" % body._get_log_id_str()
			take_damage(body.collision_damage_amount, -1, source_str)

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
	var id_str = _get_log_id_str()
	print("Enemy %s Collided with Player - GAME OVER" % id_str)
	var level = get_parent()
	if level and level.has_method("game_over"):
		level.game_over("GAME OVER - Player Hit!")
	else:
		var player_node = get_tree().get_first_node_in_group("players")
		if player_node: player_node.queue_free()
