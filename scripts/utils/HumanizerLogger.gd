class_name HumanizerLogger

enum LogLevel { INFO, DEBUG }
static var log_level = LogLevel.INFO
static var log_file: FileAccess = FileAccess.open("user://humanizer.log", FileAccess.READ_WRITE)

static var profile_db_mutex := Mutex.new()
static var profile_db = {}

static func _log(category: String, string: String):
	var message = "[humanizer " + category + "] " + str(string)
	print(message)
	log_file.store_string(message + "\n")

static func info(string: String):
	_log("info", string)

static func error(string: String):
	_log("error", string)

static func debug(string: String):
	if log_level != LogLevel.DEBUG:
		return
	_log("debug", string)

static func profile(name: String, callable: Callable):
	if log_level != LogLevel.DEBUG:
		return callable.call()
	var timer = Time.get_ticks_msec()
	var obj = callable.call()
	var elapsed = Time.get_ticks_msec() - timer
	# _log("profile", name + ": " + str(elapsed) + "ms ")

	profile_db_mutex.lock()
	if not profile_db.has(name):
		profile_db[name] = []
	profile_db[name].append(elapsed)
	profile_db_mutex.unlock()

	return obj

static func print_profile() -> String:
	profile_db_mutex.lock()
	var s := ""

	s += "### PROFILE ###\n"
	for key in profile_db.keys():
		var profile_times = profile_db[key]
		var count = len(profile_times)
		var time = 0
		for i in profile_times:
			time += i
		s += key + " " + str(time / count) + "ms\n"

	profile_db_mutex.unlock()
	return s

static func log_stack_trace(message):
	HumanizerLogger.info(message + "\n" + str(get_stack()) + "\n") # todo format it better