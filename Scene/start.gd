extends Node2D

const HOVER_MOD := Color(1.35, 1.35, 1.35, 1.0)
const PRESSED_MOD := Color(0.7, 0.7, 0.7, 1.0)
const NORMAL_MOD := Color.WHITE


func _ready() -> void:
	AudioManager.play_ambient("linnut", 0.0, true)
	# Old invisible Button stole hover/clicks from the credits TextureButton.
	var legacy := get_node_or_null("Button") as Control
	if legacy != null:
		legacy.mouse_filter = Control.MOUSE_FILTER_IGNORE
		legacy.visible = false
	_setup_menu_button($TextureButton)
	_setup_menu_button($TextureButton2)


func _setup_menu_button(btn: TextureButton) -> void:
	if btn == null:
		return
	btn.modulate = NORMAL_MOD
	btn.mouse_entered.connect(_on_menu_hover.bind(btn, true))
	btn.mouse_exited.connect(_on_menu_hover.bind(btn, false))
	btn.button_down.connect(_on_menu_press.bind(btn, true))
	btn.button_up.connect(_on_menu_press.bind(btn, false))


func _on_menu_hover(btn: TextureButton, hovering: bool) -> void:
	if btn.button_pressed:
		btn.modulate = PRESSED_MOD
	else:
		btn.modulate = HOVER_MOD if hovering else NORMAL_MOD


func _on_menu_press(btn: TextureButton, pressing: bool) -> void:
	if pressing:
		btn.modulate = PRESSED_MOD
	else:
		btn.modulate = HOVER_MOD if btn.is_hovered() else NORMAL_MOD


func _on_texture_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scene/level_1.tscn")


func _on_texture_button_2_pressed() -> void:
	get_tree().change_scene_to_file("res://Scene/credits.tscn")


func _on_button_pressed() -> void:
	_on_texture_button_2_pressed()
