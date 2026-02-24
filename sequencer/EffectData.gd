class_name EffectData
extends Resource

# This will hold the actual gameplay logic.
# You can drag one of your original .tres files (like FrailData.tres) onto this slot.
@export var status_effect: StatusEffectData

# A player-facing name for the effect. If empty, it will use the name from the StatusEffectData.
@export var display_name_override: String = ""

func get_display_name() -> String:
	if not display_name_override.is_empty():
		return display_name_override
	if status_effect != null and not status_effect.display_name.is_empty():
		return status_effect.display_name
	return "Unknown Effect"
