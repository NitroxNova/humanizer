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
var _semaphores : Array[Semaphore] = []
var _mutex : Mutex = Mutex.new()
var _queue : Array[Dictionary] = []
var _close_threads : bool = false


func _init() -> void:
	if Instance == null:
		Instance = self
	else:
		return
	
	for i in _n_threads:
		_threads.append(Thread.new())
		_semaphores.append(Semaphore.new())
		_threads[i].start(_process_queue.bind(_semaphores[i]))

func _exit_tree() -> void:
	_mutex.lock()
	_close_threads = true
	_mutex.unlock()
	for s in _semaphores:
		s.post()
	for t in _threads:
		t.wait_to_finish()

static func enqueue(job: Dictionary) -> void:
	Instance._mutex.lock()
	Instance._queue.append(job)
	Instance._mutex.unlock()
	for s in Instance._semaphores:
		s.post()

func _process_queue(semaphore : Semaphore) -> void:
	while true:
		var job_data : Dictionary
		var wait : bool
		
		_mutex.lock()
		var exit = _close_threads
		if not _queue.is_empty():
			job_data = _queue[0]
			_queue.remove_at(0)
		else:
			wait = true
		_mutex.unlock()
		
		if wait:
			semaphore.wait()
		else:
			call(job_data.callable.bind(job_data))
		if exit:
			break

