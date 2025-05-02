# EnemyBase.gd (Revised for Node Effects - Cleaned)
@tool
class_name EnemyBase
extends CharacterBody2D

# --- Signals ---
# Emitted when direct damage is taken (after multipliers)
signal damaged(slot_index: int, damage_amount: int)
# Emitted when health reaches zero
signal killed(slot_index: int)
# Emitted by _physics_process just before _perform_orientation is called
signal orientation_requested

# --- Exportable Base Stats ---
@export var base_health: float = 3.0
@export var base_speed: float = 100.0

# --- Internal State ---
var health: float
# State variables modified by ActiveStatusEffect nodes
var speed_multipliers: Dictionary = {} # { effect_id: float_multiplier }
var damage_taken_multipliers: Dictionary = {} # { effect_id: float_multiplier }
var orientation_modifiers: Dictionary = {} # { effect_id: effect_specific_data }
var collision_damage_effects: Dictionary = {} # { effect_id: {"damage": float} }
var movement_inhibitors: Dictionary = {} # { effect_id: true }
var orientation_inhibitors: Dictionary = {} # { effect_id: true }
var orientation_target: Variant = null # Target Node or Vector2
var apply_collision_damage: bool = false # Aggregate flag for spikes
var collision_damage_amount: float = 0.0 # Aggregate damage for spikes

var crawler_id: int = -1 # Set by Level
var player: Node2D # Set in _find_player

# --- Engine Methods ---
func _ready():
	health = base_health
	add_to_group("enemies_physics") # Group for physics interactions like Spikes
	_setup_hitbox()
	connect("body_entered", Callable(self, "_on_body_entered")) #, CONNECT_REFERENCE_COUNTED) 
	call_deferred("_find_player") # Find player safely after tree is ready

func _find_player():
	# Wait one frame ensures nodes are ready in the scene tree
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("players")
	if not is_instance_valid(player):
		printerr("EnemyBase ID %d: Could not find player node!" % crawler_id)

func _setup_hitbox():
	var hitbox = get_node_or_null("HitBox") # Expect Area2D child named HitBox
	if hitbox is Area2D:
		# Ensure bullets can detect this hitbox
		if not hitbox.is_in_group("enemies"): hitbox.add_to_group("enemies")
		if not hitbox.monitorable: hitbox.monitorable = true
		# Connect hitbox signal for detecting player collision
		if not hitbox.is_connected("area_entered", Callable(self, "_on_hitbox_area_entered")):
			hitbox.connect("area_entered", Callable(self, "_on_hitbox_area_entered"))
	else:
		printerr("EnemyBase ID %d: HitBox node missing or invalid!" % crawler_id)

func _physics_process(delta):
	# Effects update themselves via their own _process/_physics_process if needed

	# --- Orientation ---
	var final_can_orient = orientation_inhibitors.is_empty() # Check inhibitors
	if final_can_orient:
		orientation_target = null # Reset target, allow effects/subclass to set it
		emit_signal("orientation_requested") # Effects like Confusion connect to this
		# If target wasn't overridden by an effect, default to player
		if orientation_target == null and is_instance_valid(player):
			orientation_target = player
		# Call subclass orientation logic (e.g., crawler's look_at)
		_perform_orientation(delta)

	# --- Movement ---
	var final_can_move = movement_inhibitors.is_empty() # Check inhibitors (e.g., Fear freeze)
	if final_can_move:
		# Calculate final speed multiplier from all active effects (Slow, Rage)
		var final_speed_multiplier = 1.0
		for effect_id in speed_multipliers:
			final_speed_multiplier *= speed_multipliers[effect_id]
		var effective_speed = base_speed * final_speed_multiplier
		# Call subclass movement logic (e.g., crawler's sine wave)
		_perform_movement(delta, effective_speed)

# --- Virtual Methods for Subclasses ---
# Subclasses MUST implement these to define their specific behavior
func _perform_orientation(_delta: float):
	printerr("EnemyBase: _perform_orientation must be implemented by subclass!")
	pass
func _perform_movement(_delta: float, _effective_speed: float):
	printerr("EnemyBase: _perform_movement must be implemented by subclass!")
	pass

# --- Damage Taking ---
func take_damage(amount: float, slot_index: int):
	if health <= 0: return # Already dead

	var final_damage_taken_multiplier = 1.0
	# Apply multipliers from active effects (like Frail)
	for effect_id in damage_taken_multipliers:
		final_damage_taken_multiplier *= damage_taken_multipliers[effect_id]

	var final_damage = amount * final_damage_taken_multiplier
	health -= final_damage
	health = max(health, 0.0) # Prevent negative health

	print("Crawler %d dealt %.2f damage from slot %d." % [crawler_id, final_damage, slot_index])
	# Emit signal with integer damage amount (rounded up) for SlotManager
	emit_signal("damaged", slot_index, int(ceil(final_damage)))

	# Check for death
	if health <= 0:
		print("Crawler %d died." % crawler_id)
		emit_signal("killed", slot_index) # Signal kill to SlotManager
		# Effect nodes are children, will be freed automatically when parent (this node) is freed
		queue_free() # Remove self from scene
		GlobalState.increment_enemies_destroyed() # Notify GlobalState

# --- Status Effect Application ---
# Called by bullet script
func apply_status_effect(effect_data_resource: StatusEffectData, level_from_hit: int, source_slot_index: int):
	if not is_instance_valid(effect_data_resource):
		printerr("EnemyBase ID %d: apply_status_effect called with invalid resource." % crawler_id)
		return
	var effect_id = effect_data_resource.effect_id
	var script_path = effect_data_resource.active_effect_script_path
	if script_path.is_empty() or not ResourceLoader.exists(script_path):
		printerr("EnemyBase: No valid script path for effect '%s' in resource." % effect_id)
		return

	var EffectNodeScript = load(script_path)
	if EffectNodeScript == null:
		printerr("EnemyBase: Failed to load script '%s' for effect '%s'." % [script_path, effect_id])
		return

	var existing_effect_node = get_node_or_null(effect_id) as ActiveStatusEffect

	if is_instance_valid(existing_effect_node):
		# Effect already active: Increment its level (stacking hit)
		existing_effect_node.increment_and_update_level()
	else:
		# Effect not active: Create and add it at level 1
		var effect_node = EffectNodeScript.new() as ActiveStatusEffect
		if not is_instance_valid(effect_node):
			printerr("EnemyBase ID %d: Failed to instantiate effect node for '%s'." % [crawler_id, effect_id])
			return
		add_child(effect_node) # Add node to the enemy
		# Initialize the new effect node at level 1
		effect_node.initialize(effect_data_resource, self, 1, source_slot_index)

# --- Called by ActiveStatusEffect node when it is removed ---
func effect_node_removed(effect_id: String):
	# Re-evaluate aggregate states that might depend on this effect
	if effect_id == "spikes": check_collision_damage_state()
	# Add checks for other effects if needed (e.g., recalculate speed multiplier)

# --- Collision Damage (Spikes) ---
# Called by physics signal connection
func _on_body_entered(body: Node):
	# Check flag set by ActiveSpikeEffect._apply/_remove via update_collision_damage
	if apply_collision_damage and body is EnemyBase and body != self:
		if collision_damage_amount > 0:
			body.take_damage(collision_damage_amount, -1) # Slot -1 for effect damage

# --- Update aggregate collision damage state (called by SpikeEffect) ---
func update_collision_damage():
	var max_damage = 0.0
	var spikes_active = false
	for node in get_children(): # Check all children for spike effects
		if node is ActiveSpikeEffect:
			spikes_active = true
			# Use the damage calculated and stored by the effect node
			max_damage = max(max_damage, node.calculated_spike_damage)
	apply_collision_damage = spikes_active
	collision_damage_amount = max_damage

# Called by SpikeEffect._on_remove to re-check aggregate state
func check_collision_damage_state():
	call_deferred("update_collision_damage") # Use deferred for safety

# --- Hitbox Area Entered (For Player Collision) ---
# Called by HitBox Area2D signal connection
func _on_hitbox_area_entered(area: Area2D):
	if area.is_in_group("players"):
		_on_collision_with_player()

# --- Player Collision ---
func _on_collision_with_player():
	print("[EnemyBase ID %d] Collided with Player - GAME OVER" % crawler_id)
	var level = get_parent() # Assumes direct child
	if is_instance_valid(level) and level.has_method("game_over"):
		level.game_over("GAME OVER - Player Hit!")
	else:
		printerr("EnemyBase ID %d: Cannot find Level node for game over." % crawler_id)
		var player_node = get_tree().get_first_node_in_group("players")
		if is_instance_valid(player_node): player_node.queue_free()
