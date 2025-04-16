extends Node

signal slot_stats_updated(slot_index: int, damage: int, kills: int)

# Slot statistics tracking
class SlotStats:
	var damage: int = 0
	var kills: int = 0
	
	func reset():
		damage = 0
		kills = 0

var slots: Array[SlotStats] = []
var current_slot: int = 0
var stats_timer: Timer

func _ready():
	# Set up timer for stats printing
	stats_timer = Timer.new()
	add_child(stats_timer)
	stats_timer.wait_time = 10.0  # 10 seconds
	stats_timer.timeout.connect(_print_stats)
	stats_timer.start()

func _print_stats():
	print("\n=== Slot Statistics ===")
	for i in range(slots.size()):
		print("Slot %d: Damage: %d, Kills: %d" % [i, slots[i].damage, slots[i].kills])
	print("=====================\n")

# Initialize slots based on shots per second directly
func initialize_slots(shots_per_sec: int):
	slots.clear()
	for i in range(shots_per_sec):
		slots.append(SlotStats.new())

func get_next_slot() -> int:
	var slot = current_slot
	current_slot = (current_slot + 1) % slots.size()
	return slot

func record_damage(slot_index: int):
	if slot_index >= 0 and slot_index < slots.size():
		slots[slot_index].damage += 1
		emit_signal("slot_stats_updated", slot_index, slots[slot_index].damage, slots[slot_index].kills)

func record_kill(slot_index: int):
	if slot_index >= 0 and slot_index < slots.size():
		slots[slot_index].kills += 1
		emit_signal("slot_stats_updated", slot_index, slots[slot_index].damage, slots[slot_index].kills)

func get_slot_stats(slot_index: int) -> Dictionary:
	if slot_index >= 0 and slot_index < slots.size():
		return {
			"damage": slots[slot_index].damage,
			"kills": slots[slot_index].kills
		}
	return {"damage": 0, "kills": 0}

func reset_slot_stats():
	for slot in slots:
		slot.reset()
	# Print stats after reset
	print("\n=== Stats Reset ===")
	_print_stats()
