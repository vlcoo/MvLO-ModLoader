extends Node

const CONFIG_PATH: String = "user://settings.ini"

var remembered_tab_idx: int = 0
var remembered_mod_idx: String = ""

var timestamp: String
var config = ConfigFile.new()
var cache_is_old: bool


func _ready() -> void:
	timestamp = str(int(Time.get_unix_time_from_system()))

	var err: Error = config.load(CONFIG_PATH)
	if err != OK:
		cache_is_old = true
		config = ConfigFile.new()
	else:
		var last_timestamp: String = config.get_value("general", "last_updated")
		cache_is_old = _is_last_timestamp_old_enough(int(timestamp), int(last_timestamp))


func update_timestamp(to_zero: bool) -> void:
	config.set_value("general", "last_updated", "0" if to_zero else timestamp)
	config.save(CONFIG_PATH)


func _is_last_timestamp_old_enough(ts: int, lts: int) -> bool:
	var ts_h = ts / 3600
	var lts_h = lts / 3600
	var ts_m = (ts / 60) % 60
	return (ts_h == lts_h - 1 and ts_m >= 5) or ts_h > lts_h
