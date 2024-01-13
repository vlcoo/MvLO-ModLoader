class_name ModProcess
extends Resource

var pid: int
var mod_id: String
var version: String
var platform: String
var delta_timer_seconds: int = 0


func _init(new_pid: int, new_mod_id: String, new_version: String, new_platform: String) -> void:
	self.pid = new_pid
	self.mod_id = new_mod_id
	self.version = new_version
	self.new_platform = new_platform
