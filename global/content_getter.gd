extends Node

@onready var requester_db: HTTPRequest = $HTTPRequestDB
@onready var requester_timestamp: HTTPRequest = $HTTPRequestTimestamp

var db_request_complete = false
var gamefiles_request_complete = false

var moddatas: Array[ModData] = []

signal cache_updated(succeeded: bool)


func _on_ready() -> void:
	if Configurator.cache_is_old or not _check_dbs_integrity():
		$AnimationPlayer.play("in")
		# request dbs
	else:
		pass


func _on_requester_db_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	# parse first
	_unpack_db()

func _unpack_db() -> void:
	# extract db from zip and save

	db_request_complete = true
	if gamefiles_request_complete: _populate_moddata_array()


func _on_requester_gamefiles_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	# parse first
	gamefiles_request_complete = true
	if db_request_complete: _populate_moddata_array()


func _populate_moddata_array() -> void:
	# read from db folder
	emit_signal("cache_updated", true)
	$AnimationPlayer.play("out")
	pass


func _check_dbs_integrity() -> bool:
	return FileAccess.file_exists("user://DB.gamefiles.json") and DirAccess.dir_exists_absolute("user://DB")
