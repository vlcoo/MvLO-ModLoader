extends Node

const CONFIG_PATH: String = "user://settings.ini"
const PROCESS_TIMER_TIME: int = 10
var themes: Array[Theme] = [
	preload("res://ui_resources/themes/DefaultDark.tres"),
	preload("res://ui_resources/themes/NSMBDS.tres"),
	preload("res://ui_resources/themes/95/Classic95.tres")
]

var remembered_tab_idx: int = 0
var remembered_mod_idx: String = ""
var current_theme: Theme = null
var current_theme_id: int = 0

var os_name: String
var timestamp: String
var config = ConfigFile.new()
var cache_is_old: bool

var current_processes: Array[ModProcess] = []
var process_timer: Timer = Timer.new()
signal process_ended


func _ready() -> void:
	tree_exiting.connect(_on_tree_exiting)
	ready.connect(_on_ready)
	os_name = OS.get_name()
	timestamp = str(int(Time.get_unix_time_from_system()))

	add_child(process_timer)
	process_timer.timeout.connect(_on_timer_timeout)

	var err: Error = config.load(CONFIG_PATH)
	if err != OK:
		cache_is_old = true
		config = ConfigFile.new()
		# some default values
		set_config("all_platforms", os_name != "Windows")
	else:
		var last_timestamp: String = config.get_value("general", "last_updated")
		cache_is_old = _is_last_timestamp_old_enough(int(timestamp), int(last_timestamp))


func _on_ready() -> void:
	current_theme_id = int(get_config("theme"))
	current_theme = themes[current_theme_id]


func _on_tree_exiting() -> void:
	config.save(CONFIG_PATH)


func _on_timer_timeout() -> void:
	for process in current_processes:
		if OS.is_process_running(process.pid):
			process.delta_timer_seconds += PROCESS_TIMER_TIME
		else:
			config.set_value("mod_timers", process.mod_id, int(config.get_value("mod_timers", process.mod_id, 0)) + process.delta_timer_seconds)
			current_processes.erase(process)
			emit_signal("process_ended")
			if current_processes.is_empty(): process_timer.stop()
		print(process.delta_timer_seconds)


func add_process(mod_id: String, version: String, platform: String, pid: int) -> void:
	print("Adding process " + str(pid) + " for mod " + mod_id + "!")
	var current_process: ModProcess = ModProcess.new()
	current_process.pid = pid
	current_process.mod_id = mod_id
	current_process.platform = platform
	current_process.version = version
	current_processes.append(current_process)
	process_timer.start(PROCESS_TIMER_TIME)


func get_mod_pid(mod_id: String, version: String, platform: String) -> int:
	for process in current_processes:
		if process.mod_id == mod_id and process.version == version and process.platform == platform:
			return process.pid

	return -1


func get_config(variable: String) -> Variant:
	return config.get_value("general", variable, "")

func set_config(variable: String, value: Variant) -> void:
	config.set_value("general", variable, value)


func get_timer_mod(mod_id: String) -> int:
	return config.get_value("mod_timers", mod_id, 0)


func get_ts_mod(mod_id: String) -> String:
	if not config.has_section("mod_timestamps") or not config.has_section_key("mod_timestamps", mod_id):
		return ""
	return config.get_value("mod_timestamps", mod_id)

func set_ts_mod(mod_id: String, ts: String) -> void:
	if ts == "" and config.has_section_key("mod_timestamps", mod_id): config.erase_section_key("mod_timestamps", mod_id)
	else: config.set_value("mod_timestamps", mod_id, ts)


func update_timestamp(to_zero: bool) -> void:
	config.set_value("general", "last_updated", "0" if to_zero else timestamp)
	config.save(CONFIG_PATH)


@warning_ignore("integer_division")
func _is_last_timestamp_old_enough(ts: int, lts: int) -> bool:
	var ts_h = ts / 3600
	var lts_h = lts / 3600
	var ts_m = (ts / 60) % 60
	return (ts_h == lts_h - 1 and ts_m >= 5) or ts_h > lts_h + 1
