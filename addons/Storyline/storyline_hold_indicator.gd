@tool
extends Control
class_name StorylineHoldIndicator

## Näkyvän ympyrän halkaisija pikseleinä.
@export_range(24.0, 256.0, 1.0) var indicator_diameter: float = 128.0:
	set(value):
		indicator_diameter = clampf(value, 24.0, 256.0)
		_apply_layout()

@export_range(2.0, 24.0, 0.5) var ring_line_width: float = 12.0:
	set(value):
		ring_line_width = clampf(value, 2.0, 24.0)
		queue_redraw()

@export_range(0.0, 32.0, 1.0) var corner_margin: float = 8.0:
	set(value):
		corner_margin = maxf(value, 0.0)
		_apply_layout()

var progress: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 1
	var overlay := get_parent() as Control
	if overlay != null:
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var panel := overlay.get_parent() as Control
		if panel != null and not panel.resized.is_connected(_sync_overlay_to_panel):
			panel.resized.connect(_sync_overlay_to_panel)
		_sync_overlay_to_panel()
	_apply_layout()


func _sync_overlay_to_panel() -> void:
	var overlay := get_parent() as Control
	var panel := overlay.get_parent() as Control if overlay != null else null
	if overlay == null or panel == null:
		return
	overlay.position = Vector2.ZERO
	overlay.size = panel.size
	_apply_layout()


func set_progress(value: float) -> void:
	progress = clampf(value, 0.0, 1.0)
	visible = progress > 0.0
	queue_redraw()


func _apply_layout() -> void:
	var d := indicator_diameter
	var box := Vector2(d, d)
	custom_minimum_size = box
	size = box

	# IndicatorOverlay täyttää paneelin — ankkurit toimivat täällä.
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -d - corner_margin
	offset_top = -d - corner_margin
	offset_right = -corner_margin
	offset_bottom = -corner_margin

	queue_redraw()


func _draw() -> void:
	if progress <= 0.001:
		return

	var d := indicator_diameter
	var center := Vector2(d, d) * 0.5
	var radius := maxf(d * 0.5 - ring_line_width - 1.0, 4.0)
	const segments := 64
	var track_color := Color(1, 1, 1, 0.25)
	var fill_color := Color(1, 1, 1, 0.95)
	draw_arc(center, radius, 0.0, TAU, segments, track_color, ring_line_width, true)
	draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * progress, segments, fill_color, ring_line_width, true)
