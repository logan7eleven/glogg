extends Node

signal slots_initialized(num_slots: int)

class SlotStats:
	var damage: float = 0.0
	var kills: float = 0.0
	var hits: int = 0
	func reset(): damage = 0; kills = 0.0; hits = 0

var slots: Array[SlotStats] = []
var firing_order: Array[int] = []
var current_fire_index: int = 0

const BASE_SLOT_COUNT = 4

func _ready():
	if not GlobalState.is_connected("slots_unlocked", Callable(self, "initialize_slots")):
		GlobalState.connect("slots_unlocked", Callable(self, "initialize_slots"))
	initialize_slots(GlobalState.unlocked_slots)

func initialize_slots(num_active_slots: int):
	if num_active_slots == slots.size(): 
		# No change in slot count, do nothing.
		return

	# --- Smart Resumption Logic ---
	var last_fired_slot = -1
	if not firing_order.is_empty() and current_fire_index > 0:
		# Get the actual slot number (e.g., 2) that was just fired.
		last_fired_slot = firing_order[current_fire_index - 1]

	# --- Rebuild the Slot Data and Firing Order ---
	slots.resize(num_active_slots)
	for i in range(slots.size()):
		if slots[i] == null:
			slots[i] = SlotStats.new()
		else:
			# Don't reset stats of existing slots, only new ones.
			if i >= firing_order.size():
				slots[i].reset()

	_rebuild_firing_order(num_active_slots)

	# --- Find the next firing index after expansion ---
	if last_fired_slot != -1:
		# The next logical slot to fire is the one after the last one.
		var next_slot_to_fire = (last_fired_slot + 1) % BASE_SLOT_COUNT
		
		# Find the new position of that slot in our interleaved firing order.
		var new_index = firing_order.find(next_slot_to_fire)
		if new_index != -1:
			current_fire_index = new_index
		else:
			# Fallback in case something goes wrong.
			current_fire_index = 0
	else:
		# If it's the first time or we can't find the slot, reset to 0.
		current_fire_index = 0
	
	emit_signal("slots_initialized", slots.size())

func _rebuild_firing_order(num_slots: int):
	firing_order.clear()
	
	if num_slots < BASE_SLOT_COUNT:
		# Handle cases with less than 4 slots if needed.
		for i in range(num_slots):
			firing_order.append(i)
		return

	var expansion_sets = (num_slots / BASE_SLOT_COUNT) - 1
	
	for i in range(BASE_SLOT_COUNT):
		# Add the base slot (0, 1, 2, 3)
		firing_order.append(i)
		# Add the expansion slots that belong to this base slot
		for j in range(expansion_sets):
			var expansion_slot_index = BASE_SLOT_COUNT * (j + 1) + i
			if expansion_slot_index < num_slots:
				firing_order.append(expansion_slot_index)

func get_next_slot() -> int:
	if firing_order.is_empty(): 
		return -1
	
	# Get the slot number from our custom firing order.
	var slot_to_fire = firing_order[current_fire_index]
	
	# Move to the next position in the firing order for the next call.
	current_fire_index = (current_fire_index + 1) % firing_order.size()
	
	return slot_to_fire

func record_damage(slot_index: int, damage_amount: float = 1.0):
	if slot_index >= 0 and slot_index < slots.size():
		slots[slot_index].damage += damage_amount
		slots[slot_index].hits += 1

func record_kill(slot_index: int, credit: float = 1.0):
	if slot_index >= 0 and slot_index < slots.size():
		slots[slot_index].kills += credit

func record_bonus_damage(slot_index: int, damage_amount: float):
	if slot_index >= 0 and slot_index < slots.size():
		slots[slot_index].damage += damage_amount

func record_procedural_damage(slot_index: int, damage_amount: float):
	if slot_index >= 0 and slot_index < slots.size():
		slots[slot_index].damage += damage_amount

func get_slot_stats(slot_index: int) -> Dictionary:
	if slot_index >= 0 and slot_index < slots.size():
		return {"damage": slots[slot_index].damage, "kills": slots[slot_index].kills, "hits": slots[slot_index].hits}
	return {"damage": 0, "kills": 0, "hits": 0}

func reset_slot_stats():
	for slot in slots: slot.reset()

func get_most_hits_slot() -> int:
	if slots.is_empty(): return -1
	var most_hits = -1
	var mh_slot = 0
	for i in range(slots.size()):
		if slots[i].hits > most_hits:
			most_hits = slots[i].hits
			mh_slot = i
	return mh_slot
