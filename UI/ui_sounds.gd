extends Node

## Soft UI SFX Free pack by heyheythere (CC BY 4.0).
const SOUNDS := {
	"hover": preload("res://Audio/soft-ui-sfx-free/WAV/hover/hover_tick_01.wav"),
	"click": preload("res://Audio/soft-ui-sfx-free/WAV/clicks/click_wood_01.wav"),
	"confirm": preload("res://Audio/soft-ui-sfx-free/WAV/confirm/confirm_pluck_01.wav"),
	"back": preload("res://Audio/soft-ui-sfx-free/WAV/cancel/back_01.wav"),
	"open": preload("res://Audio/soft-ui-sfx-free/WAV/windows/open_01.wav"),
	"close": preload("res://Audio/soft-ui-sfx-free/WAV/windows/close_01.wav"),
	"on": preload("res://Audio/soft-ui-sfx-free/WAV/toggles/toggle_on_01.wav"),
	"off": preload("res://Audio/soft-ui-sfx-free/WAV/toggles/toggle_off_01.wav"),
	"error": preload("res://Audio/soft-ui-sfx-free/WAV/error/error_01.wav"),
}
var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0
var _last_hover: int = -1000
var _last_slider: int = -1000
var _last_navigation: int = -1000


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(4):
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
		add_child(player)
		_players.append(player)


func _input(event: InputEvent) -> void:
	for action in [&"ui_up", &"ui_down", &"ui_left", &"ui_right", &"ui_focus_next", &"ui_focus_prev"]:
		if event.is_action_pressed(action):
			_last_navigation = Time.get_ticks_msec()
			break


func play(sound: String) -> void:
	if not SOUNDS.has(sound) or _players.is_empty():
		return
	var player: AudioStreamPlayer = _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	player.stream = SOUNDS[sound]
	player.volume_db = -20.0 if sound == "hover" else -12.0
	player.play()


func bind_controls(root: Node) -> void:
	if root.has_meta(&"ui_audio_bound"):
		return
	root.set_meta(&"ui_audio_bound", true)
	if root is ConfirmationDialog:
		bind_dialog(root)
		return
	if root is BaseButton:
		root.mouse_entered.connect(_hover.bind(root, false))
		root.focus_entered.connect(_hover.bind(root, true))
		if root is OptionButton:
			root.pressed.connect(play.bind("click"))
			root.item_selected.connect(_selected)
			root.get_popup().id_focused.connect(_popup_hover)
		elif root.toggle_mode:
			root.toggled.connect(_toggle)
		elif root.name not in [&"SettingsButton", &"DoneButton", &"CloseButton", &"ContinueButton", &"QuitButton", &"ExitButton"]:
			var sound := "confirm" if root.name in [&"PlayButton", &"MenuButton", &"ResetGraphics"] else "click"
			root.pressed.connect(play.bind(sound))
	elif root is Slider:
		root.value_changed.connect(_slider_changed.bind(root))
		root.focus_entered.connect(_hover.bind(root, true))
	for child in root.get_children():
		bind_controls(child)


func bind_dialog(dialog: ConfirmationDialog) -> void:
	if dialog.has_meta(&"ui_dialog_audio_bound"):
		return
	dialog.set_meta(&"ui_dialog_audio_bound", true)
	for button in [dialog.get_ok_button(), dialog.get_cancel_button()]:
		button.mouse_entered.connect(_hover.bind(button, false))
		button.focus_entered.connect(_hover.bind(button, true))
	dialog.confirmed.connect(play.bind("confirm"))
	dialog.about_to_popup.connect(play.bind("open"))
	dialog.canceled.connect(play.bind("back"))


func _hover(control: Control, keyboard: bool) -> void:
	if not control.is_visible_in_tree() or (control is BaseButton and control.disabled):
		return
	var now := Time.get_ticks_msec()
	if keyboard and now - _last_navigation > 100:
		return
	if now - _last_hover < 65:
		return
	_last_hover = now
	play("hover")


func _popup_hover(_index: int) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_hover >= 65:
		_last_hover = now
		play("hover")


func _selected(_index: int) -> void:
	play("confirm")


func _toggle(enabled: bool) -> void:
	play("on" if enabled else "off")


func _slider_changed(_value: float, slider: Slider) -> void:
	if not slider.is_visible_in_tree() or not slider.editable:
		return
	var now := Time.get_ticks_msec()
	if now - _last_slider >= 100:
		_last_slider = now
		play("hover")
