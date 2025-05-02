# bullet_slot_manager.gd (Added Hit Tracking - Cleaned)
extends Node

signal slots_initialized(num_slots: int)

class SlotStats:
	var damage: int = 0
	var kills: int = 0
	var hits: int = 0
	func reset(): damage = 0; kills = 0; hits = 0

var slots: Array[SlotStats] = []
var current_slot: int = 0

func _ready():
	if not GlobalState.is_connected("slots_unlocked", Callable(self, "initialize_slots")):
		GlobalState.connect("slots_unlocked", Callable(self, "initialize_slots"))
	initialize_slots(GlobalState.unlocked_slots)

func initialize_slots(num_active_slots: int):
	if num_active_slots == slots.size(): return
	slots.resize(num_active_slots)
	for i in range(slots.size()):
		if slots[i] == null: slots[i] = SlotStats.new()
		else: slots[i].reset()
	current_slot = 0
	emit_signal("slots_initialized", slots.size())

func get_next_slot() -> int:
	if slots.is_empty(): return -1
	var slot = current_slot
	current_slot = (current_slot + 1) % slots.size()
	return slot

func record_damage(slot_index: int, damage_amount: int = 1):
	if slot_index >= 0 and slot_index < slots.size():
		slots[slot_index].damage += damage_amount
		slots[slot_index].hits += 1

func record_kill(slot_index: int):
	if slot_index >= 0 and slot_index < slots.size():
		slots[slot_index].kills += 1

func get_slot_stats(slot_index: int) -> Dictionary:
	if slot_index >= 0 and slot_index < slots.size():
		return {"damage": slots[slot_index].damage, "kills": slots[slot_index].kills, "hits": slots[slot_index].hits}
	return {"damage": 0, "kills": 0, "hits": 0}

func reset_slot_stats():
	for slot in slots: slot.reset()

func get_performance_slots() -> Dictionary:
	""" Calculates indices for Most Hits (Spikes), Least Hits (Confusion), Most Kills (Frail). """
	if slots.is_empty(): return {"spikes": -1, "confusion": -1, "frail": -1}
	var most_hits = -1; var mh_slot = 0
	var least_hits = INF; var lh_slot = 0
	var most_kills = -1; var mk_slot = 0
	for i in range(slots.size()):
		var s = slots[i]
		if s.hits > most_hits: most_hits = s.hits; mh_slot = i
		if s.hits < least_hits: least_hits = s.hits; lh_slot = i
		if s.kills > most_kills: most_kills = s.kills; mk_slot = i
		# Add tie-breaking logic here if desired
	return {"spikes": mh_slot, "confusion": lh_slot, "frail": mk_slot} # Use effect ID as key
