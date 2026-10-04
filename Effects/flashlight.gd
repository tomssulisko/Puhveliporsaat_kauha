extends Node2D

@export var follow_speed: float = 10.0
@export var beam_range: float = 155.0
@export var beam_half_angle: float = 0.36
@export var cone_edge_softness: int = 10

@onready var soft_light: PointLight2D = $SoftLight
@onready var beam: PointLight2D = $Beam

var _beam_enabled: bool = true


func _ready() -> void:
	# Defer so the light's texture RID is fully registered before we replace it.
	call_deferred("_soften_beam_edges")
	set_beam_enabled(_beam_enabled)


func _process(delta: float) -> void:
	if not _beam_enabled:
		return
	var target_angle := global_position.angle_to_point(get_global_mouse_position())
	rotation = lerp_angle(rotation, target_angle, 1.0 - exp(-follow_speed * delta))


func set_beam_enabled(enabled: bool) -> void:
	_beam_enabled = enabled
	if beam != null:
		beam.enabled = enabled
	set_process(enabled)
	if not enabled:
		rotation = 0.0


func set_ambient_enabled(enabled: bool) -> void:
	visible = enabled
	if soft_light != null:
		soft_light.enabled = enabled


func is_beam_enabled() -> bool:
	return _beam_enabled and visible


## True if world point lies inside the flashlight cone.
func illuminates_point(world_pos: Vector2) -> bool:
	if not is_beam_enabled():
		return false
	var to_point := world_pos - global_position
	var dist := to_point.length()
	if dist < 8.0 or dist > beam_range:
		return false
	var angle_diff := absf(angle_difference(global_rotation, to_point.angle()))
	return angle_diff <= beam_half_angle


## Pickup highlight: beam cone OR soft ambient glow around the player.
func illuminates_for_pickup(world_pos: Vector2) -> bool:
	if not visible:
		return false
	# Beam check with a slightly wider angle so aiming at the item is forgiving.
	if is_beam_enabled():
		var to_point := world_pos - global_position
		var dist := to_point.length()
		if dist <= beam_range and dist >= 1.0:
			var angle_diff := absf(angle_difference(global_rotation, to_point.angle()))
			if angle_diff <= beam_half_angle * 1.35:
				return true
	if soft_light == null or not soft_light.enabled:
		return false
	var tex_r := 80.0
	if soft_light.texture != null:
		tex_r = float(soft_light.texture.get_width()) * 0.5
	# Generous radius: soft glow looks larger than its hard texture scale.
	var radius := maxf(70.0, tex_r * soft_light.texture_scale * 2.0)
	return global_position.distance_to(world_pos) <= radius


func _soften_beam_edges() -> void:
	if beam == null or beam.texture == null or cone_edge_softness <= 0:
		return
	var src := beam.texture.get_image()
	if src == null or src.is_empty():
		return
	src.convert(Image.FORMAT_RGBA8)
	var blurred := _box_blur_alpha(src, cone_edge_softness)
	if blurred == null or blurred.is_empty():
		return
	var tex := ImageTexture.new()
	tex.set_image(blurred)
	# Swap with light disabled so atlas teardown never sees a null RID.
	var was_enabled := beam.enabled
	beam.enabled = false
	beam.texture = tex
	beam.enabled = was_enabled


func _box_blur_alpha(src: Image, radius: int) -> Image:
	var w := src.get_width()
	var h := src.get_height()
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var r := maxi(1, radius)
	# Separable-ish two-pass approximation for soft cone edges.
	var tmp := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var sum_a := 0.0
			var sum_rgb := Vector3.ZERO
			var count := 0
			for dx in range(-r, r + 1):
				var xx := clampi(x + dx, 0, w - 1)
				var c := src.get_pixel(xx, y)
				sum_a += c.a
				sum_rgb += Vector3(c.r, c.g, c.b) * c.a
				count += 1
			var a := sum_a / float(count)
			var rgb := sum_rgb / maxf(sum_a, 0.0001)
			tmp.set_pixel(x, y, Color(rgb.x, rgb.y, rgb.z, a))
	for y in h:
		for x in w:
			var sum_a := 0.0
			var sum_rgb := Vector3.ZERO
			var count := 0
			for dy in range(-r, r + 1):
				var yy := clampi(y + dy, 0, h - 1)
				var c := tmp.get_pixel(x, yy)
				sum_a += c.a
				sum_rgb += Vector3(c.r, c.g, c.b) * c.a
				count += 1
			var a := sum_a / float(count)
			var rgb := sum_rgb / maxf(sum_a, 0.0001)
			out.set_pixel(x, y, Color(rgb.x, rgb.y, rgb.z, a))
	return out
