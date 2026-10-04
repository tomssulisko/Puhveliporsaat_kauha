extends Area2D

## Drop on an Area2D; set target_scene in the inspector.
@export_file("*.tscn") var target_scene: String = ""


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body.name != "Player":
		return
	if target_scene.is_empty():
		push_warning("level_transition: target_scene missing on %s" % get_path())
		return
	var manager := get_node_or_null("/root/StorylineManager")
	if manager != null and manager.has_method("on_scene_about_to_change"):
		manager.on_scene_about_to_change()
	get_tree().change_scene_to_file(target_scene)
