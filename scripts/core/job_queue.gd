class_name HumanizerJobQueue
extends Node

## Jobs are scheduled by the timer
## Enqueue a job with a dictionary with HumanizerJobQueue.enquque(job_data) 
## Ensure the job_data dictionary has a "callable" key pointing to the function
## The function should also accept a dictionary argument
## The job_data will be passed as the argument to the callable

static var Instance : HumanizerJobQueue

@export_range(1, 4, 1) var _n_threads: int = 1:
	set(value):
		_n_threads = value
		if Instance != null:
			Instance._n_threads = value
var _threads : Array[Thread] = []
var _queue : Array[Dictionary] = []

func _init() -> void:
	if Instance == null:
		Instance = self
	else:
		return
	
	for i in _n_threads:
		_threads.append(Thread.new())

func _ready() -> void:
	$QueueTimer.timeout.connect(_process_queue)

func _exit_tree() -> void:
	for t in _threads:
		t.wait_to_finish()

static func enqueue(job: Dictionary) -> void:
	Instance._queue.append(job)

func _process_queue() -> void:
	for thread : Thread in _threads:
		if _queue.is_empty():
			return
		if thread.is_alive():
			continue
		thread.wait_to_finish()
		var job_data := _queue[0]
		_queue.remove_at(0)
		thread.start(job_data.callable.bind(job_data))
