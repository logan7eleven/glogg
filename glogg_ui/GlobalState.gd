# GlobalState.gd (No Max Level Constraint)
extends Node

const BASE_DAMAGE: float = 1.0

signal upgrades_ready
signal slots_unlocked(new_slot_count: int)

var unlocked_slots: int = 4
var enemies_destroyed: int = 0
var enemies_per_wave_threshold: int = 4
# Structure: { slot_index: { "resource": StatusEffectData OR null, "level": int }, ... }
var slot_upgrade_data: Dictionary = {}

func _ready():
	initialize_slot_upgrades(unlocked_slots)

func initialize_slot_upgrades(_num_slots_from_signal: int):
	var old_data = slot_upgrade_data.duplicate()
	slot_upgrade_data.clear()
	for i in range(unlocked_slots):
		slot_upgrade_data[i] = old_data.get(i, {"resource": null, "level": 0})

func apply_slot_upgrade(slot_index: int, chosen_resource: StatusEffectData):
	if not slot_upgrade_data.has(slot_index):
		printerr("GlobalState: Invalid/locked slot index: %d" % slot_index); return
	if not is_instance_valid(chosen_resource):
		printerr("GlobalState: Invalid resource for slot %d" % slot_index); return

	var current_data = slot_upgrade_data[slot_index]
	var current_resource = current_data["resource"]

	if current_resource == chosen_resource:
		# Level up existing effect - NO MAX LEVEL CHECK HERE
		current_data["level"] += 1
		print("Levelled up '%s' on slot %d to level %d" % [chosen_resource.effect_id, slot_index, current_data["level"]])
	else:
		# Overwrite with new effect at level 1
		current_data["resource"] = chosen_resource
		current_data["level"] = 1

func get_slot_upgrade_data(slot_index: int) -> Dictionary:
	return slot_upgrade_data.get(slot_index, {"resource": null, "level": 0})

func unlock_next_slots(boss_level: int):
	var slots_to_add = 0
	if boss_level == 1: slots_to_add = 4 # To 8
	elif boss_level == 2: slots_to_add = 4 # To 12
	if slots_to_add > 0:
		unlocked_slots += slots_to_add
		initialize_slot_upgrades(unlocked_slots)
		emit_signal("slots_unlocked", unlocked_slots)

func increment_enemies_destroyed():
	enemies_destroyed += 1
	if enemies_destroyed >= enemies_per_wave_threshold:
		emit_signal("upgrades_ready")

func reset_enemies_destroyed(): enemies_destroyed = 0
func set_next_wave_threshold(threshold: int): enemies_per_wave_threshold = threshold
