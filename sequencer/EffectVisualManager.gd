extends Node
class_name EffectVisualManager

const MASTER_SHADER = preload("res://shaders/master_shader.gdshader")
var shader_instance: ShaderMaterial
var target_sprite: CanvasItem

func initialize(sprite: CanvasItem):
	if not is_instance_valid(sprite): return
	target_sprite = sprite
	
	shader_instance = ShaderMaterial.new()
	shader_instance.shader = MASTER_SHADER
	
	var sprite_size = Vector2.ONE # A safe default to prevent division by zero

	# Explicitly check the sprite's type and get the texture size safely.
	# This is the key part we are adding back.
	if sprite is Sprite2D:
		if is_instance_valid(sprite.texture):
			sprite_size = sprite.texture.get_size()
	elif sprite is AnimatedSprite2D:
		if is_instance_valid(sprite.sprite_frames) and sprite.sprite_frames.has_animation("default"):
			var texture = sprite.sprite_frames.get_frame_texture("default", 0)
			if is_instance_valid(texture):
				sprite_size = texture.get_size()
	
	shader_instance.set_shader_parameter("sprite_dimensions", sprite_size)
	
	sprite.material = shader_instance
	
	set_process(false)

func set_effect_active(effect_id: String, active: bool):
	if not is_instance_valid(shader_instance): return
	var uniform_name = effect_id + "_active"
	shader_instance.set_shader_parameter(uniform_name, active)

func set_fear_color(color: Color):
	if not is_instance_valid(shader_instance): return
	shader_instance.set_shader_parameter("fear_color", color)

func trigger_flash():
	if not is_instance_valid(shader_instance): return
	
	shader_instance.set_shader_parameter("is_flashing", true)
	var timer = get_tree().create_timer(0.08, false)
	await timer.timeout
	
	if is_instance_valid(self) and is_instance_valid(shader_instance):
		shader_instance.set_shader_parameter("is_flashing", false)

func _exit_tree():
	if is_instance_valid(target_sprite) and is_instance_valid(target_sprite.material):
		target_sprite.material = null
