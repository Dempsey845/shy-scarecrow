extends Node

signal task_added(task: PlayerTask)
signal task_completed(task_id: StringName)
signal tasks_reset

var first_task: PlayerTask = preload("uid://lba5qcm0ggw6")

var _tasks: Array[PlayerTask] = []
var _by_id: Dictionary = {}
var _completed: Dictionary = {}

func add_task(task: PlayerTask) -> bool:
	if task == null or task.id == &"":
		push_warning("PlayerTasks: tasks need a non-empty ID.")
		return false
	if _by_id.has(task.id):
		if _by_id[task.id] != task:
			push_warning("PlayerTasks: duplicate task ID '%s'. Keeping the first resource." % task.id)
		return false
	_tasks.append(task)
	_by_id[task.id] = task
	task_added.emit(task)
	return true

func complete_task(task_id: StringName) -> bool:
	if task_id == &"" or _completed.has(task_id):
		return false

	_completed[task_id] = true
	task_completed.emit(task_id)
	return true

func is_completed(task_id: StringName) -> bool:
	return _completed.has(task_id)

func get_tasks() -> Array[PlayerTask]:
	return _tasks.duplicate()

func reset_tasks() -> void:
	clear_tasks()
	_tasks.append(first_task)

func clear_tasks() -> void:
	_tasks.clear()
	_by_id.clear()
	_completed.clear()
	tasks_reset.emit()

func is_all_tasks_completed() -> bool:
	if _tasks.is_empty():
		return false

	for task in _tasks:
		if not is_completed(task.id):
			return false

	return true