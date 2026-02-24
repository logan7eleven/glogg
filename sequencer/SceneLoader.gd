extends Node

signal upgrade_ui_displayed

var is_game_paused := false
var upgrade_ui_scene := preload("res://UpgradeUI.tscn")
var upgrade_ui_instance: Control = null
var ALL_EFFECTS: Array[StatusEffectData] = []
var current_offered_choices: Array = []

const EFFECT_DATA_PATH = "res://status_effects/"
const STAGE_1_WAVES = 4
const STAGE_2_WAVES = 8
const STAGE_3_WAVES = 12
const BOSS_WAVE_1 = STAGE_1_WAVES 
const BOSS_WAVE_2 = STAGE_1_WAVES + STAGE_2_WAVES
const MAX_WAVE = STAGE_1_WAVES + STAGE_2_WAVES + STAGE_3_WAVES

# --- NEW CONSTANTS FOR THE CORRECT NAMING SCHEME ---
const BASE_SLOT_COUNT = 4
const SLOT_NAMES_BASE = ["1", "2", "3", "4"]         # For slots 0-3
const SLOT_NAMES_EXP1 = ["A", "B", "C", "D"]         # For slots 4-7
const SLOT_NAMES_EXP2 = ["i", "ii", "iii", "iv"]     # For slots 8-11

func _ready() -> void:
	_load_all_effects()
	GlobalState.connect("upgrades_ready", Callable(self, "_on_upgrades_ready"))

# ... (the rest of the script down to the helper functions is unchanged) ...

func _load_all_effects():
	ALL_EFFECTS.clear()
	var dir = DirAccess.open(EFFECT_DATA_PATH)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var resource = load(EFFECT_DATA_PATH + file_name)
				if resource is StatusEffectData:
					assert(not resource.effect_id.is_empty() and resource.effect_id != "unknown", "Effect %s has an invalid effect_id." % file_name)
					assert(not resource.active_effect_script_path.is_empty(), "Effect %s is missing its active_effect_script_path." % file_name)
					ALL_EFFECTS.append(resource)
			file_name = dir.get_next()
	else:
		printerr("SceneLoader Error: Could not open directory: %s" % EFFECT_DATA_PATH)
	assert(not ALL_EFFECTS.is_empty(), "SceneLoader: No StatusEffectData resources found in %s. Upgrades will not work." % EFFECT_DATA_PATH)

func pause_game():
	get_tree().paused = true
	is_game_paused = true

func resume_game():
	get_tree().paused = false
	is_game_paused = false

func _on_upgrades_ready() -> void:
	var level_node = get_tree().current_scene
	
	if level_node.game_is_over: return
	var completed_wave_num = level_node.get_current_wave()
	
	if completed_wave_num >= MAX_WAVE:
		level_node.game_over("YOU WIN!")
		return
		
	var is_boss_trigger_wave = (completed_wave_num == BOSS_WAVE_1 or completed_wave_num == BOSS_WAVE_2)
	current_offered_choices = _generate_upgrade_choices(level_node)
	_display_upgrade_ui(is_boss_trigger_wave)

func _display_upgrade_ui(is_boss_trigger_wave: bool):
	emit_signal("upgrade_ui_displayed")
	pause_game()
	upgrade_ui_instance = upgrade_ui_scene.instantiate()
	get_tree().root.add_child(upgrade_ui_instance)
	
	_populate_upgrade_choices(is_boss_trigger_wave)
	_populate_stats_panel()

func _populate_upgrade_choices(is_boss_trigger_wave: bool):
	var choice_buttons = [
		upgrade_ui_instance.get_node("Panel/MarginContainer/HBoxContainer/UpgradeChoices/ChoiceButton1"),
		upgrade_ui_instance.get_node("Panel/MarginContainer/HBoxContainer/UpgradeChoices/ChoiceButton2"),
		upgrade_ui_instance.get_node("Panel/MarginContainer/HBoxContainer/UpgradeChoices/ChoiceButton3")
	]
	
	for i in range(choice_buttons.size()):
		var button = choice_buttons[i]
		if i < current_offered_choices.size():
			button.visible = true
			var choice_data = current_offered_choices[i]
			var description_parts = _generate_choice_description(choice_data)
			
			var vbox = button.get_node("MarginContainer/VBoxContainer")
			vbox.get_node("TitleLabel").text = description_parts[0]
			vbox.get_node("DescLabel").text = description_parts[1]
				
			button.pressed.connect(Callable(self, "_on_upgrade_button_pressed").bind(i, is_boss_trigger_wave))
		else:
			button.visible = false
			
	if not choice_buttons.is_empty() and choice_buttons[0].visible:
		choice_buttons[0].grab_focus()

# --- REWRITTEN HELPER FUNCTION ---
# This now correctly maps the slot index to its name (e.g., 5 -> "B").
func _get_slot_display_name(slot_index: int) -> String:
	if slot_index < 0: return "?"

	# The "group" determines the character (1/A/i, 2/B/ii, etc.).
	var group_index = slot_index % BASE_SLOT_COUNT
	# The "set" determines which naming convention to use.
	var expansion_set = slot_index / BASE_SLOT_COUNT

	match expansion_set:
		0: # Base slots (0-3)
			return SLOT_NAMES_BASE[group_index]
		1: # First expansion slots (4-7)
			return SLOT_NAMES_EXP1[group_index]
		2: # Second expansion slots (8-11)
			return SLOT_NAMES_EXP2[group_index]
		_: # Fallback for any future slots beyond 12
			return str(slot_index + 1)

# --- REWRITTEN FUNCTION TO USE FIRING ORDER AND NEW NAMES ---
func _populate_stats_panel():
	var level_node = get_tree().current_scene
	var slot_manager = level_node.get_node("SlotManager")
	var stats_panel = upgrade_ui_instance.get_node("Panel/MarginContainer/HBoxContainer/StatsPanel")
	
	var title_label = stats_panel.get_node("MarginContainer/StatsVBox/Title")
	title_label.text = "Finished Wave %d" % level_node.get_current_wave()

	var stats_container = stats_panel.get_node("MarginContainer/StatsVBox/StatsContainer")
	for child in stats_container.get_children():
		child.queue_free()
	
	var firing_order = slot_manager.firing_order
	
	# Create a temporary array to hold the generated stat lines.
	var stat_lines: Array[String] = []
	
	# First, generate all the stat lines based on the *numerical* order.
	for i in range(GlobalState.unlocked_slots):
		var stats = slot_manager.get_slot_stats(i)
		var upgrade_data = GlobalState.get_slot_upgrade_data(i)
		var display_name = _get_slot_display_name(i)
		
		var effect_name = upgrade_data.resource.display_name if is_instance_valid(upgrade_data.resource) else "Damage"
		var effect_level = upgrade_data.level
		
		var stat_line = ""
		if effect_name == "Damage":
			stat_line = "Slot %s (Damage): Hits: %d, Damage: %.1f, Kills: %.1f" % [
				display_name, stats.hits, stats.damage, stats.kills
			]
		else:
			stat_line = "Slot %s (%s Lvl %d): Hits: %d, Damage: %.1f, Kills: %.1f" % [
				display_name, effect_name, effect_level, stats.hits, stats.damage, stats.kills
			]
		# Store the generated line at its numerical index.
		stat_lines.resize(max(stat_lines.size(), i + 1))
		stat_lines[i] = stat_line

	# Now, iterate through the *firing_order* to add the labels in the correct sequence.
	for slot_index in firing_order:
		if slot_index < stat_lines.size():
			var label = Label.new()
			label.text = stat_lines[slot_index]
			stats_container.add_child(label)


# --- UPDATED TO USE NEW NAMING SCHEME ---
func _generate_choice_description(choice_data: Dictionary) -> Array:
	var target_slot = choice_data["slot"]
	var effect_res = choice_data["resource"] as StatusEffectData
	var current_upgrade_data = GlobalState.get_slot_upgrade_data(target_slot)
	var current_level = current_upgrade_data["level"]
	var current_res = current_upgrade_data["resource"]
	
	# Get the correct display name for the target slot
	var slot_display_name = _get_slot_display_name(target_slot)
	
	var title = ""
	var next_level = 1
	
	if is_instance_valid(current_res) and current_res == effect_res:
		next_level = current_level + 1
		title = "Upgrade Slot %s: %s Lvl %d -> Lvl %d" % [slot_display_name, effect_res.display_name, current_level, next_level]
	else:
		var replaced_name = "Damage"
		if is_instance_valid(current_res):
			replaced_name = "%s Lvl %d" % [current_res.display_name, current_level]
		title = "Replace Slot %s (%s) with %s Lvl 1" % [slot_display_name, replaced_name, effect_res.display_name]

	var format_dict: Dictionary = {}
	var level_data_dict = effect_res.get_level_data_dict()

	for key in level_data_dict:
		var placeholder_name = key.trim_prefix("base_").trim_prefix("level_bonus_")
		var value = level_data_dict[key]
		
		var calculated_value
		if key.begins_with("level_bonus_"):
			calculated_value = value
		else:
			var bonus_key = "level_bonus_" + placeholder_name
			calculated_value = effect_res.get_calculated_value(next_level, key, bonus_key, value)
		
		var is_percent = "chance" in key or "increase" in key or "mult" in key
		if is_percent:
			format_dict[placeholder_name] = calculated_value * 100.0
		else:
			format_dict[placeholder_name] = calculated_value
			
	var description = effect_res.description_template.format(format_dict)

	return [title, description]

# ... (rest of the script is unchanged) ...

func _on_upgrade_button_pressed(choice_index: int, is_boss_trigger_wave: bool):
	var chosen_data = current_offered_choices[choice_index]
	var target_slot = chosen_data["slot"]
	var effect_res = chosen_data["resource"] as StatusEffectData
	var current_upgrade_data = GlobalState.get_slot_upgrade_data(target_slot)
	
	var is_replacement = not (is_instance_valid(current_upgrade_data.resource) and current_upgrade_data.resource == effect_res)
	if is_replacement:
		var damage_slot_count = 0
		for i in range(GlobalState.unlocked_slots):
			if GlobalState.get_slot_upgrade_data(i).resource == null:
				damage_slot_count += 1
		if damage_slot_count == 1 and current_upgrade_data.resource == null:
			var dialog = upgrade_ui_instance.get_node("ConfirmationDialog")
			dialog.popup_centered()
			if dialog.is_connected("confirmed", Callable(self, "_commit_upgrade")):
				dialog.disconnect("confirmed", Callable(self, "_commit_upgrade"))
			dialog.confirmed.connect(Callable(self, "_commit_upgrade").bind(choice_index, is_boss_trigger_wave), CONNECT_ONE_SHOT)
			return

	_commit_upgrade(choice_index, is_boss_trigger_wave)

func _commit_upgrade(choice_index: int, is_boss_trigger_wave: bool):
	var chosen_data = current_offered_choices[choice_index]
	GlobalState.apply_slot_upgrade(chosen_data["slot"], chosen_data["resource"])
	
	var level_node = get_tree().current_scene
	_cleanup_ui_and_proceed(level_node, is_boss_trigger_wave)

func _cleanup_ui_and_proceed(level_node: Node, is_boss_trigger_wave: bool):
	if is_instance_valid(upgrade_ui_instance):
		upgrade_ui_instance.queue_free()
		upgrade_ui_instance = null
	resume_game()
	_proceed_to_next_stage(level_node, is_boss_trigger_wave)

func _proceed_to_next_stage(level_node: Node, is_boss_trigger_wave: bool):
	if not is_instance_valid(level_node): return
	var slot_manager = level_node.get_node("SlotManager")
	if is_instance_valid(slot_manager):
		slot_manager.reset_slot_stats()
	GlobalState.reset_enemies_destroyed()
	level_node.cleanup_active_bullets()
	var player = get_tree().get_first_node_in_group("players")
	if is_instance_valid(player):
		player.global_position = level_node.player_spawn_position
	if is_boss_trigger_wave:
		var boss_num = 1 if level_node.get_current_wave() == BOSS_WAVE_1 else 2
		level_node.start_boss_fight(boss_num)
	else:
		level_node.start_next_wave()

func trigger_post_boss_upgrade(boss_num: int):
	pause_game()
	upgrade_ui_instance = upgrade_ui_scene.instantiate()
	get_tree().root.add_child(upgrade_ui_instance)
	
	_populate_stats_panel() 
	
	upgrade_ui_instance.get_node("Panel/MarginContainer/HBoxContainer/UpgradeChoices/ChoiceButton2").hide()
	upgrade_ui_instance.get_node("Panel/MarginContainer/HBoxContainer/UpgradeChoices/ChoiceButton3").hide()
	
	var boss_button = upgrade_ui_instance.get_node("Panel/MarginContainer/HBoxContainer/UpgradeChoices/ChoiceButton1")
	var vbox = boss_button.get_node("MarginContainer/VBoxContainer")
	vbox.get_node("TitleLabel").text = "Victory!"
	vbox.get_node("DescLabel").text = "+4 Slots | +4 Shots Per Second"
	
	boss_button.pressed.connect(Callable(self, "_on_post_boss_button_pressed").bind(boss_num))
	boss_button.grab_focus()

func _on_post_boss_button_pressed(boss_num: int):
	post_boss_victory(boss_num)

func post_boss_victory(boss_num: int):
	GlobalState.unlock_next_slots(boss_num)
	var player = get_tree().get_first_node_in_group("players")
	if is_instance_valid(player):
		player.advance_stage()
	var level_node = get_tree().get_current_scene
	if is_instance_valid(level_node):
		_cleanup_ui_and_proceed(level_node, false)

func _generate_upgrade_choices(level_node: Node) -> Array:
	var choices: Array[Dictionary] = []
	var available_effects = ALL_EFFECTS.duplicate()
	var slot_manager = level_node.get_node("SlotManager")
	var completed_wave = level_node.get_current_wave()

	# --- Choice 1 Logic ---
	var choice1 = null
	if completed_wave <= 2:
		var random_slot = randi_range(0, GlobalState.unlocked_slots - 1)
		var random_effect = available_effects.pick_random()
		choice1 = {"slot": random_slot, "resource": random_effect}
	else:
		var applied_effects: Array[Dictionary] = []
		for i in range(GlobalState.unlocked_slots):
			var data = GlobalState.get_slot_upgrade_data(i)
			if data.resource != null:
				applied_effects.append({"slot": i, "resource": data.resource})
		if not applied_effects.is_empty():
			choice1 = applied_effects.pick_random()

	if choice1:
		choices.append(choice1)

	# --- Choice 2 Logic ---
	var empty_slots: Array[int] = []
	for i in range(GlobalState.unlocked_slots):
		if GlobalState.get_slot_upgrade_data(i).resource == null:
			empty_slots.append(i)
	if not empty_slots.is_empty():
		var target_slot = empty_slots.pick_random()
		var random_effect = available_effects.pick_random()
		var choice2 = {"slot": target_slot, "resource": random_effect}
		if not _is_duplicate_offer(choice2, choices):
			choices.append(choice2)
	
	# --- Choice 3 Logic ---
	var least_hits_slot = slot_manager.get_least_hits_slot()
	if least_hits_slot != -1 and not available_effects.is_empty():
		var random_effect = available_effects.pick_random()
		var choice3 = {"slot": least_hits_slot, "resource": random_effect}
		if not _is_duplicate_offer(choice3, choices):
			choices.append(choice3)

	while choices.size() < 3 and not available_effects.is_empty():
		var random_slot = randi_range(0, GlobalState.unlocked_slots - 1)
		var random_effect = available_effects.pick_random()
		if not random_effect: break
		var random_choice = {"slot": random_slot, "resource": random_effect}
		if not _is_duplicate_offer(random_choice, choices):
			choices.append(random_choice)
		available_effects.erase(random_effect)
	
	return choices

func _is_duplicate_offer(new_offer: Dictionary, existing_offers: Array) -> bool:
	for offer in existing_offers:
		if new_offer.slot == offer.slot and new_offer.resource == offer.resource:
			return true
	return false
