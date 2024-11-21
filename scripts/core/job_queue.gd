extends Node
class_name HumanizerJobQueue

# todo export thread count to plugin project settings
static var thread_count := 1 #max(1, OS.get_processor_count() / 4)

static var threads: Array[Thread] = []
static var thread_exit = false
static var job_semaphore: Semaphore = Semaphore.new()
static var job_mutex: Mutex = Mutex.new()
static var jobs: Array[Callable] = []

static var debug_run_on_main = false

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
	HumanizerTargetService.exit()
	HumanizerLogger.debug("job_queue shutdown")

static func add_job(callable: Callable):
	if thread_exit:
		return

	start()

	if debug_run_on_main:
		callable.call()
		return
	job_mutex.lock()
	jobs.push_back(callable)
	job_mutex.unlock()
	job_semaphore.post()

# todo fix crash on exit, main thread jobs are being queued holding references to characterbody3d, on thread_exit we ignore the jobs leading to orphaned nodes
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

