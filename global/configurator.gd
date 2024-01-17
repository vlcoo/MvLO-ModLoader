extends Node

enum DiscordStatus {IN_MENU, IN_GAME, IN_MULTIPLE, CLEARED}
enum WindowState {ATTENTION, RESTORED, MINIMIZED}

const CONFIG_PATH := "user://settings.ini"
const PROCESS_TIMER_TIME := 2
var themes: Array[Theme] = [
	preload("res://ui_resources/themes/BasicDark.tres"),
	preload("res://ui_resources/themes/BasicDark.tres"),
	preload("res://ui_resources/themes/BasicDark.tres")
]

var remembered_mod_idx := ""
var current_theme: Theme = null
var current_theme_id := 0
var previous_window_mode := Window.MODE_WINDOWED

var os_name: String
var timestamp: String
var config := ConfigFile.new()
var cache_is_old: bool

var current_processes: Array[ModProcess] = []
var process_timer: Timer = Timer.new()
signal process_ended(process: ModData)


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
		var last_timestamp = config.get_value("general", "last_updated")
		cache_is_old = _is_last_timestamp_old_enough(int(timestamp), int(last_timestamp))


func _on_ready() -> void:
	current_theme_id = int(get_config("theme"))
	current_theme = themes[current_theme_id]


func _on_tree_exiting() -> void:
	config.save(CONFIG_PATH)
	DiscordHandler.ClearDiscordStatus(true)


func _on_timer_timeout() -> void:
	for process: ModProcess in current_processes:
		if OS.is_process_running(process.pid):
			process.delta_timer_seconds += PROCESS_TIMER_TIME
		else:
			config.set_value("mod_timers", process.mod_id, int(config.get_value("mod_timers", process.mod_id, 0)) + process.delta_timer_seconds)
			current_processes.erase(process)
			process_ended.emit(process)
			if current_processes.is_empty(): 
				process_timer.stop()
				set_discord_status(DiscordStatus.IN_MENU)
				set_window_state(WindowState.RESTORED)
			elif current_processes.size() == 1: 
				set_discord_status(DiscordStatus.IN_GAME, current_processes[0].mod_id)
			else:
				set_discord_status(DiscordStatus.IN_MULTIPLE)


func set_window_state(state: WindowState) -> void:
	if not get_config("minimize", false): return
	
	match state:
		WindowState.ATTENTION:
			if not get_window().has_focus(): get_window().request_attention()
		WindowState.RESTORED:
			get_window().mode = previous_window_mode
			get_window().grab_focus()
		WindowState.MINIMIZED:
			previous_window_mode = get_window().mode
			get_window().mode = Window.MODE_MINIMIZED


func set_discord_status(status: DiscordStatus, mod_id: String = ""):
	if not get_config("discord-rpc", true): return
	
	match status:
		DiscordStatus.CLEARED:
			DiscordHandler.ClearDiscordStatus(false)
		DiscordStatus.IN_GAME:
			var moddata: ModData = ContentGetter.get_local_moddata(mod_id)
			if moddata.needs_discord_activity:
				assert(moddata != null, "An existing mod ID is expected if the Discord status is set to 'in-game'.")
				DiscordHandler.SetDiscordStatus(
					"• Playing" + (" vanilla" if mod_id == "vanilla" else " a mod") + " •",
					moddata.name,
					"nodata" if moddata.cover_image == null else mod_id,
					moddata.description,
					true
				)
			else: set_discord_status(DiscordStatus.CLEARED)
		DiscordStatus.IN_MULTIPLE:
			DiscordHandler.SetDiscordStatus(
				"• Playing multiple mods •",
				"",
				"menu",
				"A simple way to keep your mods organized and up to date.",
				true
			)
		DiscordStatus.IN_MENU:
			DiscordHandler.SetDiscordStatus(
				["Browsing", "Exploring", "Glancing at", "Examining", "Checking out", "Roaming around", "Touring", "Flipping thru"].pick_random() + " the mod gallery...",
				"",
				"menu",
				"A simple way to keep your mods organized and up to date.",
				false
			)


func add_process(mod_id: String, version: String, platform: String, pid: int) -> void:
	var current_process: ModProcess = ModProcess.new(pid, mod_id, version, platform)
	current_processes.append(current_process)
	if process_timer.is_stopped(): process_timer.start(PROCESS_TIMER_TIME)
	
	if current_processes.size() > 1: set_discord_status(DiscordStatus.IN_MULTIPLE)
	else: set_discord_status(DiscordStatus.IN_GAME, mod_id)
	set_window_state(WindowState.MINIMIZED)


func get_mod_pid(mod_id: String, version: String, platform: String) -> int:
	var found_process: Array[ModProcess] = current_processes.filter(func(p): return p.mod_id == mod_id && p.version == version && p.platform == platform)
	return -1 if found_process.is_empty() else found_process[0].pid


func get_config(variable: String, default: Variant = "") -> Variant:
	return config.get_value("general", variable, default)

func set_config(variable: String, value: Variant) -> void:
	config.set_value("general", variable, value)

func restore_config() -> void:
	OS.move_to_trash(ProjectSettings.globalize_path("user://settings.ini"))
	config = ConfigFile.new()
	# some default values
	set_config("all_platforms", os_name != "Windows")


func get_timer_mod(mod_id: String) -> int:
	return config.get_value("mod_timers", mod_id, 0)


func get_is_mod_favourite(mod_id: String) -> bool:
	return config.get_value("mod_favourites", mod_id, false)

func set_is_mod_favourite(mod_id: String, how: bool) -> void:
	if not how and config.has_section_key("mod_favourites", mod_id): config.erase_section_key("mod_favourites", mod_id)
	else: config.set_value("mod_favourites", mod_id, true)


func get_ts_mod(mod_id: String) -> String:
	return config.get_value("mod_timestamps", mod_id, "")

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
