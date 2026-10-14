extends CanvasLayer
## Instance once in your gameplay scene. UI and signal connections live in the .tscn.
signal menu_opened
signal menu_closed

@export_file("*.tscn") var main_menu_scene_path: String = "res://UI/MainMenu/main_menu.tscn"
@export var toggle_action: StringName = &"ui_cancel"

@onready var _settings: Control = %GraphicsSettings
@onready var _settings_button: Button = %SettingsButton
@onready var _interface: Control = %PauseInterface
@onready var _continue: Button = %ContinueButton
@onready var _status: Label = %StatusLabel
@onready var _exit_dialog: ConfirmationDialog = %ExitDialog

var is_open: bool = false
var _owns_pause: bool = false
var _previous_mouse_mode: int = Input.MOUSE_MODE_VISIBLE
var _changing_scene: bool = false


func _ready() -> void:
	UISounds.bind_controls(_interface)
	UISounds.bind_dialog(_exit_dialog)
	_interface.hide()
	_exit_dialog.hide()
	if not InputMap.has_action(toggle_action):
		push_warning("PauseMenu toggle action does not exist: %s" % toggle_action)


func _input(event: InputEvent) -> void:
	if _changing_scene or not event.is_action_pressed(toggle_action) or event.is_echo():
		return
	if _settings.visible:
		# The settings scene handles Escape, returning to the still-paused menu.
		return
	# Let the dialog handle Escape as cancel, without also closing the pause menu.
	if _exit_dialog.visible:
		return
	if is_open:
		close_menu()
	elif not get_tree().paused:
		open_menu()
	else:
		# Another system owns this pause (e.g. a cutscene/dialogue).
		return
	get_viewport().set_input_as_handled()


func toggle_menu() -> void:
	if is_open:
		close_menu()
	else:
		open_menu()


func open_menu() -> bool:
	if is_open or _changing_scene or get_tree().paused:
		return false
	UISounds.play("open")
	_previous_mouse_mode = (
		Input.MOUSE_MODE_CAPTURED if OS.has_feature("web") else Input.mouse_mode
	)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_owns_pause = true
	get_tree().paused = true
	is_open = true
	_status.text = ""
	_interface.show()
	_continue.grab_focus()
	menu_opened.emit()
	return true


func close_menu() -> void:
	if not is_open or _changing_scene:
		return
	UISounds.play("close")
	_settings.close_settings()
	_exit_dialog.hide()
	_interface.hide()
	is_open = false
	_release_pause(true)
	menu_closed.emit()


func _release_pause(restore_mouse: bool) -> void:
	if _owns_pause and is_inside_tree():
		get_tree().paused = false
	_owns_pause = false
	if restore_mouse:
		Input.mouse_mode = _previous_mouse_mode


func _return_to_menu() -> void:
	if _changing_scene:
		return
	var path := main_menu_scene_path
	if not ResourceLoader.exists(path) and path == "res://UI/MainMenu/main_menu.tscn":
		for candidate in [
			"res://main_menu.tscn", "res://MainMenu/main_menu.tscn", "res://UI/main_menu.tscn"
		]:
			if ResourceLoader.exists(candidate):
				path = candidate
				break
	if not ResourceLoader.exists(path):
		_status.text = "Set Main Menu Scene Path on PauseMenu to your menu scene."
		return
	_changing_scene = true
	_release_pause(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var result := get_tree().change_scene_to_file(path)
	if result != OK:
		_changing_scene = false
		_owns_pause = true
		get_tree().paused = true
		_status.text = "Couldn't open the main menu. Please check its scene path."
	else:
		is_open = false


func _request_exit() -> void:
	if OS.has_feature("web"):
		_exit_dialog.title = "Thanks for playing"
		_exit_dialog.dialog_text = "Close this browser tab to leave the game."
		_exit_dialog.ok_button_text = "Understood"
	else:
		_exit_dialog.title = "Leaving so soon?"
		_exit_dialog.dialog_text = "Exit Shy Scarecrow?"
		_exit_dialog.ok_button_text = "Exit"
	_exit_dialog.popup_centered(Vector2i(360, 160))


func _confirm_exit() -> void:
	if OS.has_feature("web"):
		_exit_dialog.hide()
		_continue.grab_focus()
	else:
		if _changing_scene:
			return
		_changing_scene = true
		await get_tree().create_timer(0.2, true).timeout
		get_tree().quit()


func _exit_tree() -> void:
	# Removing the menu while it is open must not leave gameplay paused.
	if _owns_pause:
		get_tree().paused = false
		_owns_pause = false
		Input.mouse_mode = _previous_mouse_mode


func _open_settings() -> void:
	if not is_open or _changing_scene:
		return
	_interface.hide()
	_settings.open_settings()


func _on_settings_closed() -> void:
	if is_open and not _changing_scene:
		_interface.show()
		_settings_button.grab_focus()
