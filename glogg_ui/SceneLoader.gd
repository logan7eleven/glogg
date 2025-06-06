extends Node

var is_game_paused := false
var upgrade_ui_scene := preload("res://UpgradeUI.tscn")
var upgrade_ui_instance: Control = null
var current_offered_choices: Array = []

const SPIKE_EFFECT_DATA = preload("res://SpikeData.tres")
const CONFUSION_EFFECT_DATA = preload("res://ConfusionData.tres")
const FRAIL_EFFECT_DATA = preload("res://FrailData.tres")
const SLOW_EFFECT_DATA = preload("res://SlowData.tres")
const FEAR_EFFECT_DATA = preload("res://FearData.tres")
const RAGE_EFFECT_DATA = preload("res://RageData.tres")
const ALL_EFFECTS = [SPIKE_EFFECT_DATA, CONFUSION_EFFECT_DATA, FRAIL_EFFECT_DATA, SLOW_EFFECT_DATA, FEAR_EFFECT_DATA, RAGE_EFFECT_DATA]

signal upgrade_ui_displayed

func _ready() -> void:
	GlobalState.connect("upgrades_ready", Callable(self, "_on_upgrades_ready"))

func pause_game():
	get_tree().paused = true
	is_game_paused = true

func resume_game():
	get_tree().paused = false
	is_game_paused = false

func _handle_upgrades_ready_deferred():
	call_deferred("_on_upgrades_ready")

func _on_upgrades_ready() -> void:
	var level_node = get_tree().current_scene
	if level_node.game_is_over: 
		return
	var completed_wave_index = level_node.get_current_wave() - 1
	print("Completed Wave %d" % (completed_wave_index + 1)) 
	if completed_wave_index >= 11:
		print("Wave 12 Completed - Triggering WIN!")
		level_node.game_over("YOU WIN!") 
		return
	var slot_manager = level_node.get_node("SlotManager")
	print("\n--- Slot Stats for Completed Wave ---")
	var num_slots = GlobalState.unlocked_slots 
	for i in range(num_slots):
		var stats = slot_manager.get_slot_stats(i) 
		var upgrade_data = GlobalState.get_slot_upgrade_data(i)
		var effect_name = upgrade_data["resource"].effect_id if is_instance_valid(upgrade_data["resource"]) else "Damage" 
		var effect_level = upgrade_data["level"] if is_instance_valid(upgrade_data["resource"]) else 0 
		print("  Slot %d: Hits: %d, Damage Dealt: %.2f, Kills: %d | Effect: %s (Lvl %d)" % [i, stats.hits, stats.damage, stats.kills, effect_name, effect_level])
	print("-----------------------------------\n")
	emit_signal("upgrade_ui_displayed")
	current_offered_choices = _generate_upgrade_choices(slot_manager, completed_wave_index)
	upgrade_ui_instance = upgrade_ui_scene.instantiate()
	get_tree().root.add_child(upgrade_ui_instance)
	upgrade_ui_instance.process_mode = Node.PROCESS_MODE_ALWAYS 
	var vbox = upgrade_ui_instance.get_node("Panel/VBoxContainer")
	var buttons = [vbox.get_child(0), vbox.get_child(1), vbox.get_child(2)]
	for i in range(buttons.size()):
		buttons[i].visible = true
		var button = buttons[i]
		var choice_data = current_offered_choices[i]
		var target_slot = choice_data["slot"]
		var effect_res = choice_data["resource"] as StatusEffectData 
		var current_upgrade_data = GlobalState.get_slot_upgrade_data(target_slot)
		var current_level = current_upgrade_data["level"]
		var current_res = current_upgrade_data["resource"]
		var display_level_text = "(Apply Lvl 1)"
		if is_instance_valid(current_res) and current_res == effect_res:
			display_level_text = "(L%d -> L%d)" % [current_level, current_level + 1]
		button.text = "[S%d] %s %s" % [target_slot, effect_res.display_name, display_level_text]
		var args = [i, completed_wave_index] 
		for conn in button.get_signal_connection_list("pressed"):
			if conn.callable == Callable(self, "_on_upgrade_button_pressed"):
				button.disconnect("pressed", Callable(self, "_on_upgrade_button_pressed"))
		button.connect("pressed", Callable(self, "_on_upgrade_button_pressed").bindv(args))
	buttons[0].grab_focus()
	pause_game() 

func _generate_upgrade_choices(slot_manager, completed_wave_index: int) -> Array:
	var choices = []
	var available_effects = ALL_EFFECTS.duplicate()
	var rng = RandomNumberGenerator.new(); rng.randomize()
	var choice1 = _get_choice_1(available_effects, completed_wave_index)
	if choice1:
		choices.append(choice1)
		if choice1.get("was_random", false) and choice1.resource in available_effects:
			available_effects.erase(choice1.resource)
	var choice2 = _get_choice_2(slot_manager, available_effects)
	if choice2:
		var attempts = 0
		while attempts < 10 and choices.size() > 0 and _is_duplicate_offer(choice2, choices):
			if available_effects.is_empty(): 
				break
			choice2["resource"] = available_effects.pick_random() 
			attempts += 1
		if attempts < 10:
			choices.append(choice2)
			if choice2.resource in available_effects: available_effects.erase(choice2.resource)
	var choice3 = null
	if completed_wave_index == 0: 
		choice3 = _get_choice_3_random_slot(available_effects) 
	else:
		choice3 = _get_choice_3_lowest_free(available_effects)
	if choice3:
		var attempts = 0
		while attempts < 10 and _is_duplicate_offer(choice3, choices):
			if available_effects.is_empty(): 
				break
			choice3["resource"] = available_effects.pick_random()
			attempts += 1
		if attempts < 10:
			choices.append(choice3)
	return choices

func _get_choice_3_lowest_free(available_effects):
	var target_slot = _find_lowest_free_slot()
	if target_slot == -1: 
		target_slot = 0 
	if available_effects.is_empty(): 
		return null
	var random_effect = available_effects.pick_random()
	return {"slot": target_slot, "resource": random_effect}

func _get_choice_3_random_slot(available_effects): 
	var target_slot = randi_range(0, GlobalState.unlocked_slots - 1) 
	if available_effects.is_empty(): 
		return null
	var random_effect = available_effects.pick_random() 
	return {"slot": target_slot, "resource": random_effect}

func _is_duplicate_offer(new_offer: Dictionary, existing_offers: Array) -> bool:
	for offer in existing_offers:
		if new_offer.slot == offer.slot and new_offer.resource == offer.resource:
			return true
	return false

func _get_choice_1(available_effects, completed_wave_index: int): 
	var upgraded_slots_data = []
	for i in range(GlobalState.unlocked_slots):
		var data = GlobalState.get_slot_upgrade_data(i)
		if data["resource"] != null:
			upgraded_slots_data.append({"slot": i, "resource": data["resource"]})
	if completed_wave_index < 2:
		if available_effects.is_empty(): 
			return null
		var target_slot = randi_range(0, GlobalState.unlocked_slots - 1)
		var random_effect = available_effects.pick_random()
		return {"slot": target_slot, "resource": random_effect, "was_random": true}
	else:
		if not upgraded_slots_data.is_empty():
			var choice = upgraded_slots_data.pick_random() 
			return choice
		else:
			if available_effects.is_empty(): 
				return null
			var target_slot = randi_range(0, GlobalState.unlocked_slots - 1) 
			var random_effect = available_effects.pick_random()
			return {"slot": target_slot, "resource": random_effect, "was_random": true}

func _get_choice_2(slot_manager, available_effects):
	if not slot_manager: 
		return null
	var target_slot = slot_manager.get_most_hits_slot()
	if target_slot < 0: 
		target_slot = 0
	if available_effects.is_empty(): 
		return null
	var random_effect = available_effects.pick_random()
	return {"slot": target_slot, "resource": random_effect}

func _find_lowest_free_slot() -> int:
	for i in range(GlobalState.unlocked_slots):
		if not GlobalState.get_slot_upgrade_data(i)["resource"]: 
			return i
	return -1 

func _proceed_without_upgrade(level_node, slot_manager, is_boss_trigger_wave: bool, completed_wave_index: int):
	slot_manager.reset_slot_stats()
	GlobalState.reset_enemies_destroyed()
	level_node.cleanup_active_bullets()
	var player = get_tree().get_first_node_in_group("players") as Node2D
	player.global_position = Vector2(600, 400)
	if is_boss_trigger_wave:
		var boss_num = 1 if completed_wave_index == 3 else 2
		if level_node and level_node.has_method("start_boss_fight"):
			level_node.start_boss_fight(boss_num)
	elif level_node and level_node.has_method("start_level_countdown"):
		level_node.start_level_countdown()
	elif level_node and level_node.has_method("start_next_wave"): # Fallback
		level_node.call("start_next_wave")

func _cleanup_and_proceed(level_node, slot_manager, is_boss_trigger_wave: bool, completed_wave_index: int):
	if upgrade_ui_instance: 
		upgrade_ui_instance.queue_free() 
		upgrade_ui_instance = null
	if get_tree().paused: 
		resume_game()
	_proceed_without_upgrade(level_node, slot_manager, is_boss_trigger_wave, completed_wave_index)

func _on_upgrade_button_pressed(button_index: int, completed_wave_index: int) -> void: 
	var level_node = get_tree().current_scene
	var chosen_data = current_offered_choices[button_index]
	var target_slot_index = chosen_data["slot"]
	var chosen_resource = chosen_data["resource"]
	var current_slot_data = GlobalState.get_slot_upgrade_data(target_slot_index)
	var current_resource = current_slot_data["resource"] 
	GlobalState.apply_slot_upgrade(target_slot_index, chosen_resource)
	if current_resource == chosen_resource:
		pass
	elif current_resource == null:
		print("Added '%s' to slot %d" % [chosen_resource.display_name, target_slot_index])
	else:
		print("Overwrote '%s' on slot %d, added '%s'" % [current_resource.display_name, target_slot_index, chosen_resource.display_name])
	GlobalState.reset_enemies_destroyed()
	var slot_manager = level_node.get_node("SlotManager") if level_node else null
	if slot_manager: slot_manager.reset_slot_stats()
	if upgrade_ui_instance: upgrade_ui_instance.queue_free(); upgrade_ui_instance = null
	resume_game()
	level_node.cleanup_active_bullets()
	var player = get_tree().get_first_node_in_group("players") as Node2D
	if player: player.global_position = Vector2(600, 400)
	var boss_num = 0
	if completed_wave_index == 3: boss_num = 1 # Boss after Wave 4 upgrade
	elif completed_wave_index == 7: boss_num = 2 # Boss after Wave 8 upgrade
	if boss_num > 0:
		level_node.start_boss_fight(boss_num)
	else:
		level_node.start_next_wave()

func post_boss_victory(boss_num: int):
	GlobalState.unlock_next_slots(boss_num) 
	var player = get_tree().get_first_node_in_group("players")
	player.advance_stage() 
	if boss_num >= 3: 
		var level_node = get_tree().current_scene
		level_node.game_over("YOU WIN!") 
	else:
		var level_node = get_tree().current_scene
		if level_node and level_node.has_method("start_next_wave"):
			var slot_manager = level_node.get_node("SlotManager")
			slot_manager.reset_slot_stats()
			GlobalState.reset_enemies_destroyed()
			level_node.cleanup_active_bullets()
			player.global_position = Vector2(600, 400) 
			level_node.start_next_wave()

func print_final_slot_stats():
	var level_node = get_tree().current_scene
	var slot_manager = level_node.get_node("SlotManager") if is_instance_valid(level_node) else null
	print("\n--- FINAL SLOT STATS ---")
	var num_slots = GlobalState.unlocked_slots
	for i in range(num_slots):
		var stats = slot_manager.get_slot_stats(i)
		var upgrade_data = GlobalState.get_slot_upgrade_data(i)
		var effect_name = upgrade_data["resource"].effect_id if is_instance_valid(upgrade_data["resource"]) else "Damage"
		var effect_level = upgrade_data["level"] if is_instance_valid(upgrade_data["resource"]) else 0
		print("  Slot %d: Hits: %d, Damage Dealt: %.2f, Kills: %d | Effect: %s (Lvl %d)" % [i, stats.hits, stats.damage, stats.kills, effect_name, effect_level])
	print("------------------------\n")
