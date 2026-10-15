extends CanvasLayer

signal tutorial_finished
signal tutorial_closed

@export var open_on_ready: bool = true
@export var pause_game: bool = true

@onready var overlay: Control = $Overlay
@onready var panel: Control = $Overlay/TutorialPanel
@onready var pages: Control = $Overlay/TutorialPanel/Content/PagesScroll/Pages
@onready var back_button: Button = $Overlay/TutorialPanel/Content/Footer/Back
@onready var next_button: Button = $Overlay/TutorialPanel/Content/Footer/Next
@onready var counter: Label = $Overlay/TutorialPanel/Content/Footer/Counter
@onready var animation: AnimationPlayer = $AnimationPlayer

var page_index: int = 0
var busy: bool = false
var is_open: bool = false
var previous_pause: bool = false
var previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE

func _ready() -> void:
	UISounds.bind_controls(overlay)
	overlay.hide()
	panel.resized.connect(_update_pivot)
	if open_on_ready:
		call_deferred("open_tutorial")

func _update_pivot() -> void:
	panel.pivot_offset = panel.size * 0.5

func open_tutorial() -> void:
	if is_open or busy:
		return

	is_open = true
	busy = true
	previous_pause = get_tree().paused
	previous_mouse_mode = Input.mouse_mode

	if pause_game:
		get_tree().paused = true

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	page_index = 0
	_show_page()
	overlay.show()

	_update_pivot()

	UISounds.play("open")
	animation.play("open")
	await animation.animation_finished

	busy = false
	next_button.grab_focus()

func _show_page() -> void:
	for i in range(pages.get_child_count()):
		pages.get_child(i).visible = i == page_index

	back_button.disabled = page_index == 0
	counter.text = "%d / 3" % (page_index + 1)
	next_button.text = "Let's begin" if page_index == 2 else "Next"
	$Overlay/TutorialPanel/Content/PagesScroll.scroll_vertical = 0

func _on_next() -> void:
	if busy or not is_open:
		return
	if page_index == 2:
		close_tutorial(true)
	else:
		page_index += 1
		_show_page()

func _on_back() -> void:
	if busy or not is_open:
		return
	page_index = maxi(0, page_index - 1)
	_show_page()
	if page_index == 0:
		next_button.grab_focus()

func close_tutorial(completed: bool = false) -> void:
	if busy or not is_open:
		return
	busy = true
	UISounds.play("close")
	animation.play("close")
	await animation.animation_finished
	overlay.hide()
	if pause_game:
		get_tree().paused = previous_pause

	Input.mouse_mode = previous_mouse_mode

	is_open = false
	busy = false
	if completed:
		tutorial_finished.emit()
	tutorial_closed.emit()

func _on_close() -> void:
	close_tutorial()

func _input(event: InputEvent) -> void:
	if is_open and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close_tutorial()

func _exit_tree() -> void:
	if is_open:
		if pause_game:
			get_tree().paused = previous_pause

		Input.mouse_mode = previous_mouse_mode
