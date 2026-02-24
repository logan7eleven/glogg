extends Area2D

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var visual_pulse: Polygon2D = $VisualPulse
@onready var active_duration_timer: Timer = $ActiveDurationTimer

var _damage_to_deal: float
var _stun_duration: float
var _source_enemy_id: int
var _source_name: String
var _source_level: int
# --- NEW VARIABLE ---
var _source_slot_index: int = -1

# --- MODIFIED FUNCTION SIGNATURE ---
func setup_pulse(diameter: float, active_duration: float, damage: float, stun_dur: float, source_id: int, source_name: String, source_level: int, source_slot: int):
	_damage_to_deal = damage
	_stun_duration = stun_dur
	_source_enemy_id = source_id
	_source_name = source_name
	_source_level = source_level
	# --- NEW ---
	_source_slot_index = source_slot # Store the slot index
	
	var radius = diameter / 2.0
	if collision_shape.shape is CircleShape2D:
		(collision_shape.shape as CircleShape2D).radius = radius
	var points = PackedVector2Array()
	var num_circle_segments = 16
	for i in range(num_circle_segments + 1):
		var angle = TAU * i / num_circle_segments
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	visual_pulse.polygon = points
	visual_pulse.color = Color(1, 1, 0, 0.25)
	area_entered.connect(_on_area_entered)
	active_duration_timer.wait_time = active_duration
	active_duration_timer.timeout.connect(queue_free)
	active_duration_timer.start()
	monitoring = true
	monitorable = true

func _on_area_entered(area: Area2D):
	var enemy = _get_enemy_from_hitbox_area(area)
	if is_instance_valid(enemy) and enemy.get_instance_id() != _source_enemy_id:
		var source_desc = "%s Shock Pulse (Lvl %d)" % [_source_name, _source_level]
		
		enemy.take_damage(_damage_to_deal, _source_slot_index, source_desc, true)
		
		if enemy.has_method("apply_timed_stun"):
			enemy.apply_timed_stun(_stun_duration, "shock_stun")

func _get_enemy_from_hitbox_area(area: Area2D) -> EnemyBase:
	if area.owner is EnemyBase: return area.owner as EnemyBase
	var p = area.get_parent()
	if p is EnemyBase: return p as EnemyBase
	p = p.get_parent() if is_instance_valid(p) else null
	if p is EnemyBase: return p as EnemyBase
	return null
