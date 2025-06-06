extends Node

const BASE_DAMAGE: float = 1.0
const INITIAL_SLOTS = 4

signal upgrades_ready
signal slots_unlocked(new_slot_count: int)

var unlocked_slots: int = INITIAL_SLOTS
var enemies_destroyed: int = 0
var enemies_per_wave_threshold: int = 4
var slot_upgrade_data: Dictionary = {}

func _ready():
	if not self.is_connected("slots_unlocked", Callable(self, "initialize_slot_upgrades")):
		self.connect("slots_unlocked", Callable(self, "initialize_slot_upgrades"))
	reset_for_new_game()

func initialize_slot_upgrades(_num_slots_from_signal: int):
	var target_size = self.unlocked_slots 
	for i in range(slot_upgrade_data.size(), target_size):
		slot_upgrade_data[i] = {"resource": null, "level": 0}

func apply_slot_upgrade(slot_index: int, chosen_resource: StatusEffectData):
	var current_data = slot_upgrade_data[slot_index]
	var current_resource = current_data["resource"]
	if current_resource == chosen_resource:
		current_data["level"] += 1
		print("Levelled up '%s' on slot %d to level %d" % [chosen_resource.effect_id, slot_index, current_data["level"]])
	else:
		current_data["resource"] = chosen_resource
		current_data["level"] = 1

func get_slot_upgrade_data(slot_index: int) -> Dictionary:
	return slot_upgrade_data[slot_index]

func unlock_next_slots(boss_level: int):
	var slots_to_add = 0
	if boss_level == 1: slots_to_add = 4 # To 8
	elif boss_level == 2: slots_to_add = 4 # To 12
	if slots_to_add > 0:
		unlocked_slots += slots_to_add
		#initialize_slot_upgrades(unlocked_slots)
		emit_signal("slots_unlocked", unlocked_slots)

func increment_enemies_destroyed():
	enemies_destroyed += 1
	if enemies_destroyed >= enemies_per_wave_threshold:
		emit_signal("upgrades_ready")

func reset_enemies_destroyed(): 
	enemies_destroyed = 0
	
func set_next_wave_threshold(threshold: int):
	enemies_per_wave_threshold = threshold

func reset_for_new_game():
	unlocked_slots = INITIAL_SLOTS
	enemies_destroyed = 0
	enemies_per_wave_threshold = 4 
	var new_slot_data = {}
	for i in range(INITIAL_SLOTS):
		new_slot_data[i] = {"resource": null, "level": 0}
	slot_upgrade_data = new_slot_data 
	emit_signal("slots_unlocked", unlocked_slots)
