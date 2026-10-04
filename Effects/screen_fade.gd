extends CanvasLayer

## Fullscreen black fade used by death / scene transitions.
signal fade_finished

@onready var _rect: ColorRect = $ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 128
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.color = Color(0, 0, 0, 0)


func set_alpha(alpha: float) -> void:
	_rect.color.a = clampf(alpha, 0.0, 1.0)


func fade_to_black(duration: float = 0.8) -> void:
	await _tween_alpha(1.0, duration)


func fade_from_black(duration: float = 0.8) -> void:
	await _tween_alpha(0.0, duration)


func _tween_alpha(target: float, duration: float) -> void:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_rect, "color:a", target, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	fade_finished.emit()
