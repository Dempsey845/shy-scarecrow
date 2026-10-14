extends Node3D
@export_file("*.tscn") var game_scene_path: String = "res://World/world.tscn"
@onready var _main: Control = %MainPanel
@onready var _settings: Control = %GraphicsSettings
@onready var _dialog: ConfirmationDialog = %QuitDialog
@onready var _status: Label = %StatusLabel
@onready var _play: Button = %PlayButton
@onready var _settings_button: Button = %SettingsButton
var _quitting: bool = false
var _starting: bool = false


func _ready() -> void:
	UISounds.bind_controls(_main)
	UISounds.bind_dialog(_dialog)
	_main.show()
	_play.grab_focus()


func _open_settings() -> void:
	_main.hide()
	_settings.open_settings()


func _on_settings_closed() -> void:
	_main.show()
	_settings_button.grab_focus()


func _flush_slider() -> void:
	if is_instance_valid(_settings):
		_settings.flush_pending()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		if _settings.visible:
			_settings.close_settings()
		elif not _dialog.visible:
			_request_quit()
		get_viewport().set_input_as_handled()


func _start_game() -> void:
	if _starting:
		return
	_flush_slider()
	var path := game_scene_path
	if not ResourceLoader.exists(path) and path == "res://World/world.tscn":
		for candidate in ["res://world.tscn", "res://World/World.tscn"]:
			if ResourceLoader.exists(candidate):
				path = candidate
				break
	if not ResourceLoader.exists(path):
		_status.text = "Set Game Scene Path on MainMenu to your world scene."
		return
	_starting = true
	_play.disabled = true
	var result := get_tree().change_scene_to_file(path)
	if result != OK:
		_starting = false
		_play.disabled = false
		_status.text = "Could not open the game scene. Please check its path."


func _request_quit() -> void:
	if OS.has_feature("web"):
		_status.text = "Thanks for playing — close this browser tab to leave."
		return
	_dialog.popup_centered(Vector2i(360, 160))


func _confirm_quit() -> void:
	if _quitting:
		return
	_quitting = true
	await get_tree().create_timer(0.2, true).timeout
	_flush_slider()
	get_tree().quit()


func _exit_tree() -> void:
	_flush_slider()
