class_name HumanizerLogger

enum LogLevel { INFO, DEBUG }
static var log_level = LogLevel.INFO
static var log_file: FileAccess = FileAccess.open("user://humanizer.log", FileAccess.READ_WRITE)

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
	_log("profile", name + ": " + str(Time.get_ticks_msec() - timer) + "ms ")
	return obj

static func log_stack_trace(message):
	HumanizerLogger.info(message + "\n" + str(get_stack()) + "\n") # todo format it better