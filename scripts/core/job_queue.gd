extends Node
class_name HumanizerJobQueue

static var thread_count := 1
static var threads: Array[Thread] = []
static var thread_exit = false
static var job_semaphore: Semaphore = Semaphore.new()
static var job_mutex: Mutex = Mutex.new()
static var jobs: Array[Callable] = []

static func start():
	if thread_exit:
		return
	if not threads.is_empty(): 
		return

	Engine.get_main_loop().get_root().tree_exiting.connect(exit) # graceful exit
	for i in range(0, thread_count):
		var thread = Thread.new()
		threads.append(thread)
		thread.start(_worker_thread)

	HumanizerLogger.debug("Setup thread pool with " + str(thread_count) + " threads")

func _exit_tree() -> void:
	exit()

static func exit():
	if threads.is_empty():
		return

	job_mutex.lock()
	thread_exit = true
	job_mutex.unlock()

	for thread in threads:
		job_semaphore.post()
	for thread in threads:
		if thread.is_started():
			thread.wait_to_finish()
	threads.clear()

	job_mutex.lock()
	jobs.clear()
	job_mutex.unlock()

	HumanizerResourceService.exit()
	HumanizerLogger.debug("job_queue has successfully shut down.")

static func add_job(callable: Callable):
	if thread_exit:
		return

	start()
	job_mutex.lock()
	jobs.push_back(callable)
	job_mutex.unlock()
	job_semaphore.post()
	# callable.call()

static func add_job_main_thread(callable: Callable):
	if thread_exit:
		return

	start()
	(func():
		if Engine.get_main_loop().get_root() == null: # why do i have to do this?
			return
		callable.call()
	).call_deferred()

static func _worker_thread():
	while true:
		job_semaphore.wait()
		if thread_exit:
			break
		job_mutex.lock()
		if len(jobs) > 0:
			var task = jobs[0]
			jobs.remove_at(0)
			job_mutex.unlock()
			task.call()
			continue
		else:
			job_mutex.unlock()

