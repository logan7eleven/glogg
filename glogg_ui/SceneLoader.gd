# SceneLoader.gd (Revised for Boss Trigger & New Upgrades - Cleaned)
extends Node

var is_game_paused := false

var upgrade_ui_scene := preload("res://UpgradeUI.tscn")
var upgrade_ui_instance: Control = null

# --- Preload Effect Data Resources ---
const SPIKE_EFFECT_DATA = preload("res://SpikeData.tres") # Assuming .tres files exist
const CONFUSION_EFFECT_DATA = preload("res://ConfusionData.tres")
const FRAIL_EFFECT_DATA = preload("res://FrailData.tres")
const SLOW_EFFECT_DATA = preload("res://SlowData.tres")
const FEAR_EFFECT_DATA = preload("res://FearData.tres")
const RAGE_EFFECT_DATA = preload("res://RageData.tres")

var upgrade_set_odd = { "spikes": SPIKE_EFFECT_DATA, "confusion": CONFUSION_EFFECT_DATA, "frail": FRAIL_EFFECT_DATA }
var upgrade_set_even = { "slow": SLOW_EFFECT_DATA, "fear": FEAR_EFFECT_DATA, "rage": RAGE_EFFECT_DATA }

var performance_criteria_odd = { "spikes": "most_hits", "confusion": "least_hits", "frail": "lowest_free_slot" }
var performance_criteria_even = { "slow": "most_hits", "fear": "least_hits", "rage": "lowest_free_slot" }

var current_offered_resources: Dictionary = {} # { "button1": Res, "button2": Res, "button3": Res }
var current_target_slots: Dictionary = {} # { "button1": slot_idx, "button2": slot_idx, "button3": slot_idx }

func _ready() -> void:
	GlobalState.connect("upgrades_ready", Callable(self, "_on_upgrades_ready"))

func pause_game(): get_tree().paused = true; is_game_paused = true
func resume_game(): get_tree().paused = false; is_game_paused = false

func _on_upgrades_ready() -> void:
	if upgrade_ui_instance and upgrade_ui_instance.is_inside_tree(): return

	var level_node = get_tree().current_scene
	if not is_instance_valid(level_node) or not level_node.has_method("get_current_wave"): return

	var current_wave_num = level_node.get_current_wave()
	var completed_wave_index = current_wave_num - 1

	# --- 1. CHECK FOR BOSS FIGHT TRIGGER ---
	var boss_num = 0
	if completed_wave_index == 3: boss_num = 1
	elif completed_wave_index == 7: boss_num = 2
	elif completed_wave_index == 11: boss_num = 3

	if boss_num > 0:
		if level_node.has_method("start_boss_fight"): level_node.start_boss_fight(boss_num)
		else: printerr("SceneLoader: Level missing start_boss_fight method!")
		return

	# --- 2. PRINT SLOT STATS ---
	var slot_manager = level_node.get_node_or_null("SlotManager")
	if is_instance_valid(slot_manager) and slot_manager.has_method("get_slot_stats"):
		print("\n--- Slot Stats for Completed Wave ---")
		var num_slots = GlobalState.unlocked_slots
		for i in range(num_slots):
			var stats = slot_manager.get_slot_stats(i)
			var upgrade_data = GlobalState.get_slot_upgrade_data(i)
			var effect_name = upgrade_data["resource"].effect_id if is_instance_valid(upgrade_data["resource"]) else "None"
			var effect_level = upgrade_data["level"]
			print("  Slot %d: Hits: %d, Damage: %d, Kills: %d | Effect: %s (Lvl %d)" % [i, stats.hits, stats.damage, stats.kills, effect_name, effect_level])
		print("-----------------------------------\n")

	# --- 3. DETERMINE UPGRADE SET & TARGET SLOTS ---
	var is_odd_wave = (completed_wave_index + 1) % 2 != 0
	var upgrade_set_to_use = upgrade_set_odd if is_odd_wave else upgrade_set_even
	var performance_criteria = performance_criteria_odd if is_odd_wave else performance_criteria_even
	var target_slots = {}

	if is_instance_valid(slot_manager) and slot_manager.has_method("get_performance_slots"):
		var performance_slots = slot_manager.get_performance_slots()
		for effect_key in performance_criteria:
			var criteria = performance_criteria[effect_key]
			if criteria == "most_hits": target_slots[effect_key] = performance_slots.spikes
			elif criteria == "least_hits": target_slots[effect_key] = performance_slots.confusion
			elif criteria == "most_kills": target_slots[effect_key] = performance_slots.frail # Only used on odd waves
			elif criteria == "lowest_free_slot": target_slots[effect_key] = _find_lowest_free_slot()
			else: target_slots[effect_key] = -1

		var slots_valid = true
		for effect_key in target_slots:
			if target_slots[effect_key] < 0: slots_valid = false; break
		if not slots_valid:
			printerr("SceneLoader: Failed to determine target slots. Skipping upgrade.")
			_proceed_without_upgrade(level_node, slot_manager); return
	else:
		printerr("SceneLoader: Cannot get performance slots. Skipping upgrade.")
		_proceed_without_upgrade(level_node, slot_manager); return

	# --- 4. SHOW UPGRADE UI ---
	upgrade_ui_instance = upgrade_ui_scene.instantiate()
	get_tree().root.add_child(upgrade_ui_instance)
	upgrade_ui_instance.process_mode = Node.PROCESS_MODE_ALWAYS

	var vbox = upgrade_ui_instance.get_node_or_null("Panel/VBoxContainer")
	if not vbox or vbox.get_child_count() < 3: _cleanup_and_proceed(level_node, slot_manager); return
	var button1 = vbox.get_child(0) as Button
	var button2 = vbox.get_child(1) as Button
	var button3 = vbox.get_child(2) as Button
	if not button1 or not button2 or not button3: _cleanup_and_proceed(level_node, slot_manager); return

	current_offered_resources.clear(); current_target_slots.clear()
	var button_index = 1
	for effect_key in upgrade_set_to_use:
		var button_name = "Button" + str(button_index)
		var button = vbox.get_node_or_null(button_name) as Button
		if not is_instance_valid(button): continue
		var effect_res = upgrade_set_to_use[effect_key]
		var target_slot_idx = target_slots[effect_key]
		var current_upgrade_data = GlobalState.get_slot_upgrade_data(target_slot_idx)
		var current_level = current_upgrade_data["level"]
		var current_resource = current_upgrade_data["resource"]
		var display_level_text = ""
		if is_instance_valid(current_resource) and current_resource == effect_res:
			display_level_text = "(L%d -> L%d)" % [current_level, current_level + 1]
		else:
			display_level_text = "(Apply Lvl 1)"
		button.text = "[Slot %d] %s %s" % [target_slot_idx, effect_res.display_name, display_level_text]
		button.tooltip_text = effect_res.get_description(1)
		var button_id = "button" + str(button_index)
		current_offered_resources[button_id] = effect_res
		current_target_slots[button_id] = target_slot_idx
		var args = [button_id, target_slot_idx]
		for conn in button.get_signal_connection_list("pressed"):
			if conn.callable == Callable(self, "_on_upgrade_button_pressed"): button.disconnect("pressed", Callable(self, "_on_upgrade_button_pressed"))
		button.connect("pressed", Callable(self, "_on_upgrade_button_pressed").bindv(args))
		button_index += 1

	if is_instance_valid(button1): button1.grab_focus()
	pause_game()

func _find_lowest_free_slot() -> int:
	for i in range(GlobalState.unlocked_slots):
		if not is_instance_valid(GlobalState.get_slot_upgrade_data(i)["resource"]): return i
	return 0 # Fallback if all slots have upgrades

func _proceed_without_upgrade(level_node, slot_manager):
	if is_instance_valid(slot_manager): slot_manager.reset_slot_stats()
	GlobalState.reset_enemies_destroyed()
	if is_instance_valid(level_node) and level_node.has_method("start_next_wave"):
		level_node.call("start_next_wave")

func _cleanup_and_proceed(level_node, slot_manager):
	if is_instance_valid(upgrade_ui_instance): upgrade_ui_instance.queue_free(); upgrade_ui_instance = null
	if get_tree().paused: resume_game()
	_proceed_without_upgrade(level_node, slot_manager)

func _on_upgrade_button_pressed(button_id: String, target_slot_index: int):
	var chosen_resource = current_offered_resources.get(button_id)
	if is_instance_valid(chosen_resource):
		GlobalState.apply_slot_upgrade(target_slot_index, chosen_resource)
	else: printerr("SceneLoader: Invalid resource for button '%s'." % button_id)

	GlobalState.reset_enemies_destroyed()
	var level_node = get_tree().current_scene
	var slot_manager = level_node.get_node_or_null("SlotManager") if is_instance_valid(level_node) else null
	if is_instance_valid(slot_manager): slot_manager.reset_slot_stats()

	if is_instance_valid(upgrade_ui_instance): upgrade_ui_instance.queue_free(); upgrade_ui_instance = null
	resume_game()

	var player = get_tree().get_first_node_in_group("players") as Node2D
	if is_instance_valid(player): player.global_position = Vector2(600, 400)

	if is_instance_valid(level_node) and level_node.has_method("start_next_wave"):
		level_node.call("start_next_wave")
	else: printerr("SceneLoader: Cannot start next wave.")

func post_boss_victory(boss_num: int):
	print("SceneLoader: Post Boss %d Logic." % boss_num)
	GlobalState.unlock_next_slots(boss_num)
	var player = get_tree().get_first_node_in_group("players")
	if is_instance_valid(player) and player.has_method("advance_stage"): player.advance_stage()

	if boss_num >= 3: # Check for Win
		var level_node = get_tree().current_scene
		if is_instance_valid(level_node) and level_node.has_method("game_over"):
			level_node.game_over("YOU WIN!")
	else: # Proceed to next wave
		var level_node = get_tree().current_scene
		if is_instance_valid(level_node) and level_node.has_method("start_next_wave"):
			var slot_manager = level_node.get_node_or_null("SlotManager")
			if is_instance_valid(slot_manager): slot_manager.reset_slot_stats()
			GlobalState.reset_enemies_destroyed()
			if is_instance_valid(player): player.global_position = Vector2(600, 400)
			if level_node.has_method("start_level_countdown"): level_node.start_level_countdown()
			else: level_node.call("start_next_wave") # Fallback
		else: printerr("SceneLoader: Cannot start next wave after boss %d." % boss_num)
