extends CanvasLayer

@export var tasks: Array[PlayerTask] = []
@export var task_font_size: int = 16
@export var task_color: Color = Color("302b25")
@export var completed_color: Color = Color("787269")

@onready var task_list: VBoxContainer = $TaskContainer/ScrollContainer/TaskList
var _labels: Dictionary = {}

func _ready() -> void:
	PlayerTasks.task_added.connect(_on_task_added)
	PlayerTasks.task_completed.connect(_on_task_completed)
	PlayerTasks.tasks_reset.connect(_rebuild)
	for task in tasks:
		PlayerTasks.add_task(task)
	_rebuild()

func _exit_tree() -> void:
	if PlayerTasks.task_added.is_connected(_on_task_added):
		PlayerTasks.task_added.disconnect(_on_task_added)
	if PlayerTasks.task_completed.is_connected(_on_task_completed):
		PlayerTasks.task_completed.disconnect(_on_task_completed)
	if PlayerTasks.tasks_reset.is_connected(_rebuild):
		PlayerTasks.tasks_reset.disconnect(_rebuild)

func _rebuild() -> void:
	for child in task_list.get_children():
		task_list.remove_child(child)
		child.queue_free()
	_labels.clear()
	for task in PlayerTasks.get_tasks():
		_on_task_added(task)

func _on_task_added(task: PlayerTask) -> void:
	if _labels.has(task.id):
		return
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("normal_font_size", task_font_size)
	task_list.add_child(label)
	_labels[task.id] = label
	_update_label(task)

func _on_task_completed(task_id: StringName) -> void:
	for task in PlayerTasks.get_tasks():
		if task.id == task_id:
			_update_label(task)
			return

func _update_label(task: PlayerTask) -> void:
	if not _labels.has(task.id):
		return
	var label: RichTextLabel = _labels[task.id]
	var safe_text := task.text.replace("[", "[lb]")
	var completed := PlayerTasks.is_completed(task.id)
	label.text = "[s]%s[/s]" % safe_text if completed else safe_text
	label.add_theme_color_override("default_color", completed_color if completed else task_color)
