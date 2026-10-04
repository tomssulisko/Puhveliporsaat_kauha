extends Node

## Where to put the player when returning to level 1.
var level1_reentry_position: Vector2 = Vector2.ZERO
var has_level1_reentry: bool = false


func remember_level1_exit(player_global: Vector2) -> void:
	# Nudge further inward than the enlarged gate trigger, so reentry does not auto-walk again.
	level1_reentry_position = player_global + Vector2(-90.0, 0.0)
	has_level1_reentry = true


func consume_level1_reentry() -> Variant:
	if not has_level1_reentry:
		return null
	has_level1_reentry = false
	return level1_reentry_position


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quit"):
		get_tree().quit()
