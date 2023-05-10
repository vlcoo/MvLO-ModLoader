extends Node

const URL_DB: String = "https://github.com/vlcoo/MvLO-ModLoader/raw/main/DB.zip"
const URL_GAMEFILES: String = "http://mvloml.vlcoo.net/DB.gamefiles.json"

@onready var requester_db: HTTPRequest = $HTTPRequestDB
@onready var requester_gamefiles: HTTPRequest = $HTTPRequestGamefiles

var db_request_complete = false
var gamefiles_request_complete = false

var moddatas: Dictionary = {}

signal cache_updated(succeeded: bool)


func _on_ready() -> void:
	if Configurator.cache_is_old or not _check_dbs_integrity():
		$AnimationPlayer.play("in")
		var error = requester_db.request(URL_DB) + requester_gamefiles.request(URL_GAMEFILES)
		if error != OK: err(str(error))
	else:
		await $Timer.timeout # dummy
		_populate_moddata_array(false)


func _on_requester_db_request_completed(_result: int, _response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	var reader: ZIPReader = ZIPReader.new()
	var error: Error = reader.open(requester_db.download_file)
	if error != OK:
		err("Unpacking failed. " + str(error))
		return

	for filename in reader.get_files():
		if filename.ends_with("/"):
			DirAccess.make_dir_absolute("user://" + filename)
		else:
			var file = FileAccess.open("user://" + filename, FileAccess.READ_WRITE if FileAccess.file_exists("user://" + filename) else FileAccess.WRITE)
			file.store_buffer(reader.read_file(filename))

	reader.close()

	db_request_complete = true
	if gamefiles_request_complete: _populate_moddata_array()


func _on_requester_gamefiles_request_completed(_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if response_code == 0:
		err("Invalid response. Try again later!")
	elif response_code == 200:
		Configurator.update_timestamp(false)
	gamefiles_request_complete = true
	if db_request_complete: _populate_moddata_array()


func _populate_moddata_array(hide_animation: bool = true) -> void:
	if not _check_dbs_integrity():
		err("DB not present locally.")
		return

	var json = JSON.parse_string(FileAccess.get_file_as_string("user://DB.gamefiles.json"))
	var dir = DirAccess.open("user://DB/mod_datas")
	if dir == null:
		Configurator.update_timestamp(true)
		err("DB not present locally! Please restart the program.")
		return
	if json == null:
		Configurator.update_timestamp(true)
		err("Service unavailable!")

	for filename in dir.get_files():
		var mod_id: String = filename.replace(".tres", "")
		var data: ModData = load(dir.get_current_dir() + "/" + filename)
		data.cover_image = load("user://DB/" + mod_id + "C.png")
		if FileAccess.file_exists("user://DB/" + mod_id + "I.png"):
			data.icon = load("user://DB/" + mod_id + "I.png")
		if json != null: data.gamefile_urls = json[mod_id]
		moddatas[mod_id] = data

	emit_signal("cache_updated", true)
	if hide_animation: $AnimationPlayer.play("out")
	pass


func _check_dbs_integrity() -> bool:
	return FileAccess.file_exists("user://DB.gamefiles.json") and DirAccess.dir_exists_absolute("user://DB")


func get_local_moddata(idx: String) -> ModData:
	return moddatas[idx] if moddatas.has(idx) else null


func err(text: String):
	$AcceptDialog.dialog_text = "Database could not be downloaded! Some info might be out of date.\n" + "Cause: " + text
	$AcceptDialog.popup_centered()
	emit_signal("cache_updated", false)
	$AnimationPlayer.play("out")
