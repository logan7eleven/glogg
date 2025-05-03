# SceneLoader.gd (Correct Upgrade Offering Logic - Full Script)
extends Node

var is_game_paused := false

var upgrade_ui_scene := preload("res://UpgradeUI.tscn")
var upgrade_ui_instance: Control = null

# --- Preload ALL Effect Data Resources ---
# Ensure these paths are correct and the .tres files exist
const SPIKE_EFFECT_DATA = preload("res://SpikeData.tres")
const CONFUSION_EFFECT_DATA = preload("res://ConfusionData.tres")
const FRAIL_EFFECT_DATA = preload("res://FrailData.tres")
const SLOW_EFFECT_DATA = preload("res://SlowData.tres")
const FEAR_EFFECT_DATA = preload("res://FearData.tres")
const RAGE_EFFECT_DATA = preload("res://RageData.tres")

# Array of all possible effect resources to choose from
const ALL_EFFECTS = [
	SPIKE_EFFECT_DATA, CONFUSION_EFFECT_DATA, FRAIL_EFFECT_DATA,
	SLOW_EFFECT_DATA, FEAR_EFFECT_DATA, RAGE_EFFECT_DATA
]

# Store offered choices for the current UI instance
# Array of Dictionaries: [{"slot": idx, "resource": res}, ...]
var current_offered_choices: Array = []

# --- Engine Methods ---

func _ready() -> void:
	# Connect to the signal from GlobalState when kill threshold is met
	GlobalState.connect("upgrades_ready", Callable(self, "_on_upgrades_ready"))
	print("SceneLoader Ready.") # Optional: Confirm ready state

# --- Pause/Resume Control ---

func pause_game():
	# Directly set pause state
	get_tree().paused = true
	is_game_paused = true
	print("⏸ Game paused (set by SceneLoader)")

func resume_game():
	# Directly set resume state
	get_tree().paused = false
	is_game_paused = false
	print("▶️ Game resumed (set by SceneLoader)")

# --- Upgrade/Wave Logic ---

# Called when GlobalState signals enough enemies killed
func _on_upgrades_ready() -> void:
	# Prevent duplicate UI if already showing
	if is_instance_valid(upgrade_ui_instance) and upgrade_ui_instance.is_inside_tree():
		printerr("SceneLoader: Upgrade UI already visible.")
		return

	# Get reference to the current level scene
	var level_node = get_tree().current_scene
	if not is_instance_valid(level_node) or not level_node.has_method("get_current_wave"):
		printerr("SceneLoader: Cannot find Level or get_current_wave method.")
		return

	# Get wave number and calculate the index of the wave just completed
	var current_wave_num = level_node.get_current_wave()
	var completed_wave_index = current_wave_num - 1 # Wave index just finished (0 to 11)

	print("SceneLoader: Completed Wave Index: %d" % completed_wave_index)

	# --- 1. CHECK FOR WIN CONDITION ---
	# Win after completing Wave 12 (index 11) - Skip Upgrade UI on Win
	if completed_wave_index >= 11:
		print("SceneLoader: Wave 12 Completed - Triggering WIN!")
		if level_node.has_method("game_over"):
			level_node.game_over("YOU WIN!") # Call level's game over function with win message
		return # Stop processing here if game is won

	# --- 2. CHECK FOR BOSS FIGHT TRIGGER ---
	# Trigger boss after waves 4, 8 (indices 3, 7)
	var boss_num = 0
	if completed_wave_index == 3: boss_num = 1
	elif completed_wave_index == 7: boss_num = 2
	# No boss trigger after wave 11, handled by win condition above

	if boss_num > 0:
		print("SceneLoader: Triggering Boss Fight %d after wave %d." % [boss_num, completed_wave_index + 1])
		if level_node.has_method("start_boss_fight"):
			level_node.start_boss_fight(boss_num) # Tell level to handle boss setup
		else:
			printerr("SceneLoader: Level node missing start_boss_fight method!")
		return # Stop processing here for boss fight

	# --- 3. PRINT SLOT STATS (If not boss/win wave) ---
	var slot_manager = level_node.get_node_or_null("SlotManager")
	if is_instance_valid(slot_manager) and slot_manager.has_method("get_slot_stats"):
		print("\n--- Slot Stats for Completed Wave ---")
		var num_slots = GlobalState.unlocked_slots # Use unlocked count
		for i in range(num_slots):
			var stats = slot_manager.get_slot_stats(i) # Gets {damage: float, kills: int, hits: int}
			var upgrade_data = GlobalState.get_slot_upgrade_data(i)
			var effect_name = upgrade_data["resource"].effect_id if is_instance_valid(upgrade_data["resource"]) else "Damage" # Show "Damage" if no effect
			var effect_level = upgrade_data["level"] if is_instance_valid(upgrade_data["resource"]) else 0 # Level is 0 if no effect resource
			# Print with specific formatting
			print("  Slot %d: Hits: %d, Damage Dealt: %.2f, Kills: %d | Effect: %s (Lvl %d)" % [i, stats.hits, stats.damage, stats.kills, effect_name, effect_level])
		print("-----------------------------------\n")
	# Continue even if manager invalid

	# --- 4. GENERATE UPGRADE CHOICES ---
	current_offered_choices = _generate_upgrade_choices(slot_manager)

	# Check if we have enough choices (ideally 3)
	if current_offered_choices.size() < 1: # Need at least 1 valid choice
		printerr("SceneLoader: Could not generate any valid upgrade choices. Skipping.")
		_proceed_without_upgrade(level_node, slot_manager); return
	# Pad with random choices if less than 3 generated
	while current_offered_choices.size() < 3:
		print("SceneLoader: Padding upgrade choices.")
		var random_slot = randi_range(0, GlobalState.unlocked_slots - 1)
		var random_effect = ALL_EFFECTS.pick_random()
		var padded_choice = {"slot": random_slot, "resource": random_effect}
		# Basic check to avoid exact duplicate padding immediately after adding
		var is_duplicate = false
		for existing_choice in current_offered_choices:
			if existing_choice.slot == padded_choice.slot and existing_choice.resource == padded_choice.resource:
				is_duplicate = true; break
		if not is_duplicate:
			current_offered_choices.append(padded_choice)
		else:
			# If duplicate, just break padding loop to avoid infinite loop if pool is small
			break

	# --- 5. SHOW UPGRADE UI ---
	upgrade_ui_instance = upgrade_ui_scene.instantiate()
	get_tree().root.add_child(upgrade_ui_instance)
	upgrade_ui_instance.process_mode = Node.PROCESS_MODE_ALWAYS # Process when paused

	var vbox = upgrade_ui_instance.get_node_or_null("Panel/VBoxContainer")
	# Safety checks for UI structure
	if not vbox or vbox.get_child_count() < 3:
		printerr("SceneLoader: UpgradeUI structure incorrect (needs Panel/VBoxContainer with >= 3 children).")
		_cleanup_and_proceed(level_node, slot_manager); return
	var buttons = [vbox.get_child(0), vbox.get_child(1), vbox.get_child(2)]
	if not buttons[0] or not buttons[1] or not buttons[2]:
		printerr("SceneLoader: Could not find all three buttons in UpgradeUI VBoxContainer.")
		_cleanup_and_proceed(level_node, slot_manager); return

	# Configure buttons using current_offered_choices array
	for i in range(buttons.size()):
		if i >= current_offered_choices.size(): # Handle case where fewer than 3 choices generated
			buttons[i].visible = false # Hide unused buttons
			continue
		else:
			buttons[i].visible = true

		var button = buttons[i]
		var choice_data = current_offered_choices[i]
		var target_slot = choice_data["slot"]
		var effect_res = choice_data["resource"] as StatusEffectData # Type hint
		var current_upgrade_data = GlobalState.get_slot_upgrade_data(target_slot)
		var current_level = current_upgrade_data["level"]
		var current_res = current_upgrade_data["resource"]

		# Determine display text based on whether it's a new effect or level up
		var display_level_text = "(Apply Lvl 1)"
		if is_instance_valid(current_res) and current_res == effect_res:
			display_level_text = "(L%d -> L%d)" % [current_level, current_level + 1]

		button.text = "[S%d] %s %s" % [target_slot, effect_res.display_name, display_level_text]
		# Tooltip shows description based on base values in resource for now
		button.tooltip_text = effect_res.get_description(1) # Show Lvl 1 description

		# Connect signal, passing button index (0, 1, or 2)
		var args = [i]
		# Ensure only one connection exists
		for conn in button.get_signal_connection_list("pressed"):
			if conn.callable == Callable(self, "_on_upgrade_button_pressed"):
				button.disconnect("pressed", Callable(self, "_on_upgrade_button_pressed"))
		button.connect("pressed", Callable(self, "_on_upgrade_button_pressed").bindv(args))

	buttons[0].grab_focus() # Focus first available button
	pause_game() # Pause game after UI is set up
	print("🚀 Upgrade UI shown — player will choose upgrade...")


# --- Helper Functions for Upgrade Choice Logic ---

# Generates the 3 upgrade choices based on rules
func _generate_upgrade_choices(slot_manager) -> Array:
	var choices = []
	var available_effects = ALL_EFFECTS.duplicate() # Pool of effects to pick from
	var rng = RandomNumberGenerator.new(); rng.randomize()
	var level_node = get_tree().current_scene
	var completed_wave_index = level_node.get_current_wave() - 1 if is_instance_valid(level_node) else -1

	# --- Choice 1 ---
	var choice1 = _get_choice_1(available_effects, rng)
	if choice1:
		choices.append(choice1)
		if choice1.get("was_random", false) and choice1.resource in available_effects:
			available_effects.erase(choice1.resource)

	# --- Choice 2 ---
	var choice2 = _get_choice_2(slot_manager, available_effects, rng)
	if choice2:
		var attempts = 0
		while attempts < 10 and choices.size() > 0 and _is_duplicate_offer(choice2, choices):
			if available_effects.is_empty(): break # Stop if no more effects
			choice2["resource"] = available_effects.pick_random() # Re-roll effect only
			attempts += 1
		if attempts < 10:
			choices.append(choice2)
			if choice2.resource in available_effects: available_effects.erase(choice2.resource)
		# else: print("Warning: Could not make Choice 2 unique.")

	# --- Choice 3 ---
	var choice3 = null
	if completed_wave_index == 0: # Is it the first upgrade (after wave 1)?
		print("SceneLoader: First upgrade - Choice 3 is random slot + random effect.")
		choice3 = _get_choice_3_random_slot(available_effects, rng) # Use special helper for first time
	else:
		# Normal logic: Lowest free slot, random effect
		choice3 = _get_choice_3_lowest_free(available_effects, rng)

	if choice3:
		# Ensure unique from choice 1 and 2
		var attempts = 0
		while attempts < 10 and _is_duplicate_offer(choice3, choices):
			if available_effects.is_empty(): break
			# Re-roll effect, keep target slot determined by logic above
			choice3["resource"] = available_effects.pick_random()
			attempts += 1
		if attempts < 10:
			choices.append(choice3)
		# else: print("Warning: Could not make Choice 3 unique.")

	return choices

func _get_choice_3_lowest_free(available_effects, rng):
	var target_slot = _find_lowest_free_slot()
	if target_slot == -1: target_slot = 0 # Fallback
	if available_effects.is_empty(): return null
	var random_effect = available_effects.pick_random()
	return {"slot": target_slot, "resource": random_effect}

# --- Choice 3 Helper (First Time: Random Slot) ---
func _get_choice_3_random_slot(available_effects, rng):
	# Pick a random *currently unlocked* slot
	var target_slot = rng.randi_range(0, GlobalState.unlocked_slots - 1)
	if available_effects.is_empty(): return null
	var random_effect = available_effects.pick_random()
	return {"slot": target_slot, "resource": random_effect}

# Helper to check if a new offer duplicates an existing one
func _is_duplicate_offer(new_offer: Dictionary, existing_offers: Array) -> bool:
	for offer in existing_offers:
		if new_offer.slot == offer.slot and new_offer.resource == offer.resource:
			return true
	return false

# Choice 1 Helper: Level up existing or random new on free slot
func _get_choice_1(available_effects, rng):
	var upgraded_slots_data = []
	for i in range(GlobalState.unlocked_slots):
		var data = GlobalState.get_slot_upgrade_data(i)
		if data["resource"] != null:
			upgraded_slots_data.append({"slot": i, "resource": data["resource"]})

	if upgraded_slots_data.size() >= 3:
		# Randomly pick an already upgraded slot and offer level up
		return upgraded_slots_data[rng.randi_range(0, upgraded_slots_data.size() - 1)]
	else:
		# Pick lowest free slot
		var target_slot = _find_lowest_free_slot()
		if target_slot == -1: target_slot = 0 # Fallback
		# Offer random NEW effect
		if available_effects.is_empty(): return null
		var random_effect = available_effects.pick_random()
		return {"slot": target_slot, "resource": random_effect, "was_random": true}

# Choice 2 Helper: Most Hits slot, random effect
func _get_choice_2(slot_manager, available_effects, rng):
	if not slot_manager: return null
	var target_slot = slot_manager.get_most_hits_slot()
	if target_slot < 0: target_slot = 0 # Fallback
	if available_effects.is_empty(): return null
	var random_effect = available_effects.pick_random()
	return {"slot": target_slot, "resource": random_effect}

# Choice 3 Helper: Lowest Free Slot, random effect
func _get_choice_3(available_effects, rng):
	var target_slot = _find_lowest_free_slot()
	if target_slot == -1: target_slot = 0 # Fallback
	if available_effects.is_empty(): return null
	var random_effect = available_effects.pick_random()
	return {"slot": target_slot, "resource": random_effect}

# Finds lowest index slot with no assigned effect resource
func _find_lowest_free_slot() -> int:
	for i in range(GlobalState.unlocked_slots):
		if not GlobalState.get_slot_upgrade_data(i)["resource"]: return i
	return -1 # Return -1 if no free slots found

# Helper to proceed if UI fails or is skipped
func _proceed_without_upgrade(level_node, slot_manager):
	if slot_manager: slot_manager.reset_slot_stats()
	GlobalState.reset_enemies_destroyed()
	if level_node and level_node.has_method("start_next_wave"):
		level_node.call("start_next_wave")

# Helper to cleanup UI and proceed if setup fails
func _cleanup_and_proceed(level_node, slot_manager):
	if upgrade_ui_instance: upgrade_ui_instance.queue_free(); upgrade_ui_instance = null
	if get_tree().paused: resume_game()
	_proceed_without_upgrade(level_node, slot_manager)

# --- Called when upgrade button pressed ---
func _on_upgrade_button_pressed(button_index: int) -> void:
	if button_index < 0 or button_index >= current_offered_choices.size():
		printerr("SceneLoader: Invalid button index received: %d" % button_index); return

	# Get the choice data associated with the pressed button index
	var chosen_data = current_offered_choices[button_index]
	var target_slot_index = chosen_data["slot"]
	var chosen_resource = chosen_data["resource"]

	if is_instance_valid(chosen_resource) and target_slot_index != -1:
		GlobalState.apply_slot_upgrade(target_slot_index, chosen_resource)
	else: printerr("SceneLoader: Invalid resource/slot for button index %d." % button_index)

	# Reset counters and stats
	GlobalState.reset_enemies_destroyed()
	var level_node = get_tree().current_scene
	var slot_manager = level_node.get_node_or_null("SlotManager") if level_node else null
	if slot_manager: slot_manager.reset_slot_stats()

	# Clean up UI
	if upgrade_ui_instance: upgrade_ui_instance.queue_free(); upgrade_ui_instance = null

	# Resume game
	resume_game()

	# Reset Player Position
	var player = get_tree().get_first_node_in_group("players") as Node2D
	if player: player.global_position = Vector2(600, 400)

	# Start the next wave
	if level_node and level_node.has_method("start_next_wave"):
		level_node.call("start_next_wave")
	else: printerr("SceneLoader: Cannot start next wave.")


# --- Function to handle post-boss logic ---
# Called by Level after boss placeholder is "defeated"
func post_boss_victory(boss_num: int):
	print("SceneLoader: Post Boss %d Logic." % boss_num)
	GlobalState.unlock_next_slots(boss_num) # Unlock Slots
	var player = get_tree().get_first_node_in_group("players")
	if player and player.has_method("advance_stage"): player.advance_stage() # Advance Player Stage

	if boss_num >= 3: # Check for Game Win
		var level_node = get_tree().current_scene
		if level_node and level_node.has_method("game_over"):
			level_node.game_over("YOU WIN!") # Trigger win screen
	else: # Proceed to next wave
		var level_node = get_tree().current_scene
		if level_node and level_node.has_method("start_next_wave"):
			var slot_manager = level_node.get_node_or_null("SlotManager")
			if slot_manager: slot_manager.reset_slot_stats()
			GlobalState.reset_enemies_destroyed()
			if player: player.global_position = Vector2(600, 400) # Reset player pos
			# Start next wave via countdown
			if level_node.has_method("start_level_countdown"):
				level_node.start_level_countdown()
			else: # Fallback if countdown missing
				level_node.call("start_next_wave")
		else:
			printerr("SceneLoader: Cannot start next wave after boss %d." % boss_num)
# Called by Level script during game over / win sequence
func print_final_slot_stats():
	var level_node = get_tree().current_scene
	var slot_manager = level_node.get_node_or_null("SlotManager") if is_instance_valid(level_node) else null

	if is_instance_valid(slot_manager) and slot_manager.has_method("get_slot_stats"):
		print("\n--- FINAL SLOT STATS ---")
		var num_slots = GlobalState.unlocked_slots
		for i in range(num_slots):
			var stats = slot_manager.get_slot_stats(i)
			var upgrade_data = GlobalState.get_slot_upgrade_data(i)
			var effect_name = upgrade_data["resource"].effect_id if is_instance_valid(upgrade_data["resource"]) else "Damage"
			var effect_level = upgrade_data["level"] if is_instance_valid(upgrade_data["resource"]) else 0
			print("  Slot %d: Hits: %d, Damage Dealt: %.2f, Kills: %d | Effect: %s (Lvl %d)" % [i, stats.hits, stats.damage, stats.kills, effect_name, effect_level])
		print("------------------------\n")
	else:
		print("Could not retrieve final slot stats (Level or SlotManager invalid).")
