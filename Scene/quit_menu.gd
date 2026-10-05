extends CanvasLayer

signal continue_pressed
signal quit_pressed

@onready var _title: Label = $Center/Panel/VBox/Title
@onready var _continue_btn: Button = $Center/Panel/VBox/ContinueButton
@onready var _quit_btn: Button = $Center/Panel/VBox/QuitButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 120
	visible = false
	_continue_btn.pressed.connect(func() -> void: continue_pressed.emit())
	_quit_btn.pressed.connect(func() -> void: quit_pressed.emit())
	_setup_button_feedback(_continue_btn)
	_setup_button_feedback(_quit_btn)


func open_menu(on_main_menu: bool = false) -> void:
	if on_main_menu:
		_title.text = "Quit the game?"
		_quit_btn.text = "Quit"
	else:
		_title.text = "Return to main menu?"
		_quit_btn.text = "Main Menu"
	visible = true
	_continue_btn.grab_focus()


func close_menu() -> void:
	visible = false


func _setup_button_feedback(btn: Button) -> void:
	btn.mouse_entered.connect(func() -> void: btn.modulate = Color(1.35, 1.35, 1.35))
	btn.mouse_exited.connect(func() -> void: btn.modulate = Color.WHITE)
	btn.button_down.connect(func() -> void: btn.modulate = Color(0.7, 0.7, 0.7))
	btn.button_up.connect(func() -> void:
		btn.modulate = Color(1.35, 1.35, 1.35) if btn.is_hovered() else Color.WHITE
	)
